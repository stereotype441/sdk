// Copyright (c) 2017, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:kernel/ast.dart' as kernel;

import 'package:kernel/ast.dart'
    show
        Arguments,
        AsExpression,
        AsyncMarker,
        BottomType,
        Class,
        ConditionalExpression,
        ConstructorInvocation,
        DartType,
        DynamicType,
        Expression,
        Field,
        FunctionExpression,
        FunctionNode,
        FunctionType,
        Instantiation,
        InterfaceType,
        InvalidType,
        InvocationExpression,
        Let,
        ListLiteral,
        MapLiteral,
        Member,
        MethodInvocation,
        Name,
        NullLiteral,
        Procedure,
        ProcedureKind,
        PropertyGet,
        PropertySet,
        ReturnStatement,
        SetLiteral,
        Statement,
        StaticGet,
        SuperMethodInvocation,
        SuperPropertyGet,
        SuperPropertySet,
        Supertype,
        ThisExpression,
        TreeNode,
        TypeParameter,
        TypeParameterType,
        VariableDeclaration,
        VariableGet,
        VoidType;

import 'package:kernel/class_hierarchy.dart' show ClassHierarchy;

import 'package:kernel/core_types.dart' show CoreTypes;

import 'package:kernel/type_algebra.dart'
    show FreshTypeParameters, getFreshTypeParameters, Substitution;

import 'package:kernel/src/bounds_checks.dart' show calculateBounds;

import '../../base/instrumentation.dart'
    show
        Instrumentation,
        InstrumentationValueForMember,
        InstrumentationValueForType,
        InstrumentationValueForTypeArgs;

import '../builder/extension_builder.dart';
import '../builder/member_builder.dart';
import '../builder/procedure_builder.dart';

import '../fasta_codes.dart'
    show
        LocatedMessage,
        Message,
        Template,
        messageReturnFromVoidFunction,
        messageReturnWithoutExpression,
        messageVoidExpression,
        noLength,
        templateArgumentTypeNotAssignable,
        templateDuplicatedNamedArgument,
        templateImplicitCallOfNonMethod,
        templateInternalProblemNoInferredTypeStored,
        templateInternalProblemStoringMultipleInferredTypes,
        templateInvalidAssignment,
        templateInvalidCastFunctionExpr,
        templateInvalidCastLiteralList,
        templateInvalidCastLiteralMap,
        templateInvalidCastLiteralSet,
        templateInvalidCastLocalFunction,
        templateInvalidCastNewExpr,
        templateInvalidCastStaticMethod,
        templateInvalidCastTopLevelFunction,
        templateInvokeNonFunction,
        templateMixinInferenceNoMatchingClass,
        templateUndefinedGetter,
        templateUndefinedMethod,
        templateUndefinedSetter;

import '../kernel/expression_generator.dart' show buildIsNull;

import '../kernel/kernel_shadow_ast.dart'
    show
        ExpressionJudgment,
        ShadowTypeInferenceEngine,
        ShadowTypeInferrer,
        VariableDeclarationJudgment,
        getExplicitTypeArguments;

import '../kernel/type_algorithms.dart' show hasAnyTypeVariables;

import '../names.dart' show callName, unaryMinusName;

import '../problems.dart' show internalProblem, unexpected, unhandled;

import '../source/source_library_builder.dart' show SourceLibraryBuilder;

import 'inference_helper.dart' show InferenceHelper;

import 'type_constraint_gatherer.dart' show TypeConstraintGatherer;

import 'type_inference_engine.dart'
    show IncludesTypeParametersNonCovariantly, TypeInferenceEngine, Variance;

import 'type_promotion.dart' show TypePromoter;

import 'type_schema.dart' show isKnown, UnknownType;

import 'type_schema_elimination.dart' show greatestClosure;

import 'type_schema_environment.dart'
    show
        getNamedParameterType,
        getPositionalParameterType,
        TypeConstraint,
        TypeVariableEliminator,
        TypeSchemaEnvironment;

/// Given a [FunctionNode], gets the named parameter identified by [name], or
/// `null` if there is no parameter with the given name.
VariableDeclaration getNamedFormal(FunctionNode function, String name) {
  for (VariableDeclaration formal in function.namedParameters) {
    if (formal.name == name) return formal;
  }
  return null;
}

/// Given a [FunctionNode], gets the [i]th positional formal parameter, or
/// `null` if there is no parameter with that index.
VariableDeclaration getPositionalFormal(FunctionNode function, int i) {
  if (i < function.positionalParameters.length) {
    return function.positionalParameters[i];
  } else {
    return null;
  }
}

bool isOverloadableArithmeticOperator(String name) {
  return identical(name, '+') ||
      identical(name, '-') ||
      identical(name, '*') ||
      identical(name, '%');
}

/// Keeps track of information about the innermost function or closure being
/// inferred.
class ClosureContext {
  final bool isAsync;

  final bool isGenerator;

  /// The typing expectation for the subexpression of a `return` or `yield`
  /// statement inside the function.
  ///
  /// For non-generator async functions, this will be a "FutureOr" type (since
  /// it is permissible for such a function to return either a direct value or
  /// a future).
  ///
  /// For generator functions containing a `yield*` statement, the expected type
  /// for the subexpression of the `yield*` statement is the result of wrapping
  /// this typing expectation in `Stream` or `Iterator`, as appropriate.
  final DartType returnOrYieldContext;

  final DartType declaredReturnType;

  final bool _needToInferReturnType;

  /// The type that actually appeared as the subexpression of `return` or
  /// `yield` statements inside the function.
  ///
  /// For non-generator async functions, this is the "unwrapped" type (e.g. if
  /// the function is expected to return `Future<int>`, this is `int`).
  ///
  /// For generator functions containing a `yield*` statement, the type that
  /// appeared as the subexpression of the `yield*` statement was the result of
  /// wrapping this type in `Stream` or `Iterator`, as appropriate.
  DartType _inferredUnwrappedReturnOrYieldType;

  /// Whether the function is an arrow function.
  bool isArrow;

  /// A list of return statements in functions whose return type is being
  /// inferred.
  ///
  /// The returns are checked for validity after the return type is inferred.
  List<ReturnStatement> returnStatements;

  /// A list of return expression types in functions whose return type is
  /// being inferred.
  List<DartType> returnExpressionTypes;

  factory ClosureContext(TypeInferrerImpl inferrer, AsyncMarker asyncMarker,
      DartType returnContext, bool needToInferReturnType) {
    assert(returnContext != null);
    DartType declaredReturnType =
        greatestClosure(inferrer.coreTypes, returnContext);
    bool isAsync = asyncMarker == AsyncMarker.Async ||
        asyncMarker == AsyncMarker.AsyncStar;
    bool isGenerator = asyncMarker == AsyncMarker.SyncStar ||
        asyncMarker == AsyncMarker.AsyncStar;
    if (isGenerator) {
      if (isAsync) {
        returnContext = inferrer.getTypeArgumentOf(
            returnContext, inferrer.coreTypes.streamClass);
      } else {
        returnContext = inferrer.getTypeArgumentOf(
            returnContext, inferrer.coreTypes.iterableClass);
      }
    } else if (isAsync) {
      returnContext = inferrer.wrapFutureOrType(
          inferrer.typeSchemaEnvironment.unfutureType(returnContext));
    }
    return new ClosureContext._(isAsync, isGenerator, returnContext,
        declaredReturnType, needToInferReturnType);
  }

  ClosureContext._(this.isAsync, this.isGenerator, this.returnOrYieldContext,
      this.declaredReturnType, this._needToInferReturnType) {
    if (_needToInferReturnType) {
      returnStatements = [];
      returnExpressionTypes = [];
    }
  }

  bool checkValidReturn(TypeInferrerImpl inferrer, DartType returnType,
      ReturnStatement statement, DartType expressionType) {
    // The rules for valid returns for functions with return type T and possibly
    // a return expression with static type S.
    DartType flattenedReturnType = isAsync
        ? inferrer.typeSchemaEnvironment.unfutureType(returnType)
        : returnType;
    if (statement.expression == null) {
      // Sync: return; is a valid return if T is void, dynamic, or Null.
      // Async: return; is a valid return if flatten(T) is void, dynamic, or
      // Null.
      if (flattenedReturnType is VoidType ||
          flattenedReturnType is DynamicType ||
          flattenedReturnType == inferrer.coreTypes.nullClass.rawType) {
        return true;
      }
      statement.expression = inferrer.helper.wrapInProblem(
          new NullLiteral()..fileOffset = statement.fileOffset,
          messageReturnWithoutExpression,
          noLength)
        ..parent = statement;
      return false;
    }

    // Arrow functions are valid if:
    // Sync: T is void or return exp; is a valid for a block-bodied function.
    // Async: flatten(T) is void or return exp; is valid for a block-bodied
    // function.
    if (isArrow && flattenedReturnType is VoidType) return true;

    // Sync: invalid if T is void and S is not void, dynamic, or Null
    // Async: invalid if T is void and flatten(S) is not void, dynamic, or Null.
    DartType flattenedExpressionType = isAsync
        ? inferrer.typeSchemaEnvironment.unfutureType(expressionType)
        : expressionType;
    if (returnType is VoidType &&
        flattenedExpressionType is! VoidType &&
        flattenedExpressionType is! DynamicType &&
        flattenedExpressionType != inferrer.coreTypes.nullClass.rawType) {
      statement.expression = inferrer.helper.wrapInProblem(
          statement.expression, messageReturnFromVoidFunction, noLength)
        ..parent = statement;
      return false;
    }

    // Sync: invalid if S is void and T is not void, dynamic, or Null.
    // Async: invalid if flatten(S) is void and flatten(T) is not void, dynamic,
    // or Null.
    if (flattenedExpressionType is VoidType &&
        flattenedReturnType is! VoidType &&
        flattenedReturnType is! DynamicType &&
        flattenedReturnType != inferrer.coreTypes.nullClass.rawType) {
      statement.expression = inferrer.helper
          .wrapInProblem(statement.expression, messageVoidExpression, noLength)
            ..parent = statement;
      return false;
    }

    // The caller will check that the return expression is assignable to the
    // return type.
    return true;
  }

  /// Updates the inferred return type based on the presence of a return
  /// statement returning the given [type].
  void handleReturn(TypeInferrerImpl inferrer, ReturnStatement statement,
      DartType type, bool isArrow) {
    if (isGenerator) return;
    // The first return we see tells us if we have an arrow function.
    if (this.isArrow == null) {
      this.isArrow = isArrow;
    } else {
      assert(this.isArrow == isArrow);
    }

    if (_needToInferReturnType) {
      // Add the return to a list to be checked for validity after we've
      // inferred the return type.
      returnStatements.add(statement);
      returnExpressionTypes.add(type);

      // The return expression has to be assignable to the return type
      // expectation from the downwards inference context.
      if (statement.expression != null &&
          inferrer.ensureAssignable(returnOrYieldContext, type,
                  statement.expression, statement.fileOffset,
                  isReturnFromAsync: isAsync, isVoidAllowed: true) !=
              null) {
        // Not assignable, use the expectation.
        type = greatestClosure(inferrer.coreTypes, returnOrYieldContext);
      }
      DartType unwrappedType = type;
      if (isAsync) {
        unwrappedType = inferrer.typeSchemaEnvironment.unfutureType(type);
      }
      if (_inferredUnwrappedReturnOrYieldType == null) {
        _inferredUnwrappedReturnOrYieldType = unwrappedType;
      } else {
        _inferredUnwrappedReturnOrYieldType = inferrer.typeSchemaEnvironment
            .getStandardUpperBound(
                _inferredUnwrappedReturnOrYieldType, unwrappedType);
      }
      return;
    }

    // If we are not inferring a type we can immediately check that the return
    // is valid.
    if (checkValidReturn(inferrer, declaredReturnType, statement, type) &&
        statement.expression != null) {
      inferrer.ensureAssignable(returnOrYieldContext, type,
          statement.expression, statement.fileOffset,
          isReturnFromAsync: isAsync, isVoidAllowed: true);
    }
  }

  void handleYield(TypeInferrerImpl inferrer, bool isYieldStar, DartType type,
      Expression expression, int fileOffset) {
    if (!isGenerator) return;
    DartType expectedType = isYieldStar
        ? _wrapAsyncOrGenerator(inferrer, returnOrYieldContext)
        : returnOrYieldContext;
    if (inferrer.ensureAssignable(expectedType, type, expression, fileOffset,
            isReturnFromAsync: isAsync) !=
        null) {
      type = greatestClosure(inferrer.coreTypes, expectedType);
    }
    if (_needToInferReturnType) {
      DartType unwrappedType = type;
      if (isYieldStar) {
        unwrappedType = inferrer.getDerivedTypeArgumentOf(
                type,
                isAsync
                    ? inferrer.coreTypes.streamClass
                    : inferrer.coreTypes.iterableClass) ??
            type;
      }
      if (_inferredUnwrappedReturnOrYieldType == null) {
        _inferredUnwrappedReturnOrYieldType = unwrappedType;
      } else {
        _inferredUnwrappedReturnOrYieldType = inferrer.typeSchemaEnvironment
            .getStandardUpperBound(
                _inferredUnwrappedReturnOrYieldType, unwrappedType);
      }
    }
  }

  DartType inferReturnType(TypeInferrerImpl inferrer) {
    assert(_needToInferReturnType);
    DartType inferredType =
        inferrer.inferReturnType(_inferredUnwrappedReturnOrYieldType);
    if (!inferrer.typeSchemaEnvironment
        .isSubtypeOf(inferredType, returnOrYieldContext)) {
      // If the inferred return type isn't a subtype of the context, we use the
      // context.
      inferredType = greatestClosure(inferrer.coreTypes, returnOrYieldContext);
    }

    inferredType = _wrapAsyncOrGenerator(inferrer, inferredType);
    for (int i = 0; i < returnStatements.length; ++i) {
      checkValidReturn(inferrer, inferredType, returnStatements[i],
          returnExpressionTypes[i]);
    }

    return inferredType;
  }

  DartType _wrapAsyncOrGenerator(TypeInferrerImpl inferrer, DartType type) {
    if (isGenerator) {
      if (isAsync) {
        return inferrer.wrapType(type, inferrer.coreTypes.streamClass);
      } else {
        return inferrer.wrapType(type, inferrer.coreTypes.iterableClass);
      }
    } else if (isAsync) {
      return inferrer.wrapFutureType(type);
    } else {
      return type;
    }
  }
}

/// Enum denoting the kinds of contravariance check that might need to be
/// inserted for a method call.
enum MethodContravarianceCheckKind {
  /// No contravariance check is needed.
  none,

  /// The return value from the method call needs to be checked.
  checkMethodReturn,

  /// The method call needs to be desugared into a getter call, followed by an
  /// "as" check, followed by an invocation of the resulting function object.
  checkGetterReturn,
}

/// Keeps track of the local state for the type inference that occurs during
/// compilation of a single method body or top level initializer.
///
/// This class describes the interface for use by clients of type inference
/// (e.g. BodyBuilder).  Derived classes should derive from [TypeInferrerImpl].
abstract class TypeInferrer {
  final CoreTypes coreTypes;

  TypeInferrer.private(this.coreTypes);

  factory TypeInferrer(
      ShadowTypeInferenceEngine engine,
      Uri uri,
      bool topLevel,
      InterfaceType thisType,
      SourceLibraryBuilder library) = ShadowTypeInferrer.private;

  SourceLibraryBuilder get library;

  /// Gets the [TypePromoter] that can be used to perform type promotion within
  /// this method body or initializer.
  TypePromoter get typePromoter;

  /// Gets the [TypeSchemaEnvironment] being used for type inference.
  TypeSchemaEnvironment get typeSchemaEnvironment;

  /// The URI of the code for which type inference is currently being
  /// performed--this is used for testing.
  Uri get uri;

  /// Performs full type inference on the given field initializer.
  void inferFieldInitializer(InferenceHelper helper, DartType declaredType,
      kernel.Expression initializer);

  /// Performs type inference on the given function body.
  void inferFunctionBody(InferenceHelper helper, DartType returnType,
      AsyncMarker asyncMarker, Statement body);

  /// Performs type inference on the given constructor initializer.
  void inferInitializer(InferenceHelper helper, kernel.Initializer initializer);

  /// Performs type inference on the given metadata annotations.
  void inferMetadata(
      InferenceHelper helper, List<kernel.Expression> annotations);

  /// Performs type inference on the given metadata annotations keeping the
  /// existing helper if possible.
  void inferMetadataKeepingHelper(List<kernel.Expression> annotations);

  /// Performs type inference on the given function parameter initializer
  /// expression.
  void inferParameterInitializer(InferenceHelper helper,
      kernel.Expression initializer, DartType declaredType);
}

/// Derived class containing generic implementations of [TypeInferrer].
///
/// This class contains as much of the implementation of type inference as
/// possible without knowing the identity of the type parameters.  It defers to
/// abstract methods for everything else.
abstract class TypeInferrerImpl extends TypeInferrer {
  /// Marker object to indicate that a function takes an unknown number
  /// of arguments.
  static final FunctionType unknownFunction =
      new FunctionType(const [], const DynamicType());

  final TypeInferenceEngine engine;

  @override
  final Uri uri;

  /// Indicates whether the construct we are currently performing inference for
  /// is outside of a method body, and hence top level type inference rules
  /// should apply.
  final bool isTopLevel;

  final ClassHierarchy classHierarchy;

  final Instrumentation instrumentation;

  final TypeSchemaEnvironment typeSchemaEnvironment;

  final InterfaceType thisType;

  @override
  final SourceLibraryBuilder library;

  final Map<TreeNode, DartType> inferredTypesMap = <TreeNode, DartType>{};

  InferenceHelper helper;

  /// Context information for the current closure, or `null` if we are not
  /// inside a closure.
  ClosureContext closureContext;

  /// The [Substitution] inferred by the last [inferInvocation], or `null` if
  /// the last invocation didn't require any inference.
  Substitution lastInferredSubstitution;

  /// The [FunctionType] of the callee in the last [inferInvocation], or `null`
  /// if the last invocation didn't require any inference.
  FunctionType lastCalleeType;

  TypeInferrerImpl.private(
      this.engine, this.uri, bool topLevel, this.thisType, this.library)
      : assert(library != null),
        classHierarchy = engine.classHierarchy,
        instrumentation = topLevel ? null : engine.instrumentation,
        typeSchemaEnvironment = engine.typeSchemaEnvironment,
        isTopLevel = topLevel,
        super.private(engine.coreTypes);

  DartType storeInferredType(TreeNode node, DartType type) {
    if (node is ExpressionJudgment) {
      return node.inferredType = type;
    } else {
      if (inferredTypesMap.containsKey(node)) {
        internalProblem(
            templateInternalProblemStoringMultipleInferredTypes.withArguments(
                inferredTypesMap[node], "${node.runtimeType}"),
            node.fileOffset,
            uri);
      }
      return inferredTypesMap[node] = type;
    }
  }

  DartType readInferredType(TreeNode node) {
    if (!inferredTypesMap.containsKey(node) && !isTopLevel) {
      internalProblem(
          templateInternalProblemNoInferredTypeStored
              .withArguments("${node.runtimeType}"),
          node.fileOffset,
          uri);
    }
    return inferredTypesMap[node];
  }

  /// Gets the type promoter that should be used to promote types during
  /// inference.
  TypePromoter get typePromoter;

  bool isDoubleContext(DartType typeContext) {
    // A context is a double context if double is assignable to it but int is
    // not.  That is the type context is a double context if it is:
    //   * double
    //   * FutureOr<T> where T is a double context
    //
    // We check directly, rather than using isAssignable because it's simpler.
    while (typeContext is InterfaceType &&
        typeContext.classNode == coreTypes.futureOrClass &&
        typeContext.typeArguments.isNotEmpty) {
      InterfaceType type = typeContext;
      typeContext = type.typeArguments.first;
    }
    return typeContext == coreTypes.doubleClass.rawType;
  }

  bool isAssignable(DartType expectedType, DartType actualType) {
    return typeSchemaEnvironment.isSubtypeOf(expectedType, actualType) ||
        typeSchemaEnvironment.isSubtypeOf(actualType, expectedType);
  }

  /// Checks whether [actualType] can be assigned to the greatest closure of
  /// [expectedType], and inserts an implicit downcast if appropriate.
  Expression ensureAssignable(DartType expectedType, DartType actualType,
      Expression expression, int fileOffset,
      {bool isReturnFromAsync: false,
      bool isVoidAllowed: false,
      Template<Message Function(DartType, DartType)> template}) {
    assert(expectedType != null);
    expectedType = greatestClosure(coreTypes, expectedType);

    DartType initialExpectedType = expectedType;
    if (isReturnFromAsync && !isAssignable(expectedType, actualType)) {
      // If the body of the function is async, the expected return type has the
      // shape FutureOr<T>.  We check both branches for FutureOr here: both T
      // and Future<T>.
      DartType unfuturedExpectedType =
          typeSchemaEnvironment.unfutureType(expectedType);
      DartType futuredExpectedType = wrapFutureType(unfuturedExpectedType);
      if (isAssignable(unfuturedExpectedType, actualType)) {
        expectedType = unfuturedExpectedType;
      } else if (isAssignable(futuredExpectedType, actualType)) {
        expectedType = futuredExpectedType;
      }
    }

    // We don't need to insert assignability checks when doing top level type
    // inference since top level type inference only cares about the type that
    // is inferred (the kernel code is discarded).
    if (isTopLevel) return null;

    // If an interface type is being assigned to a function type, see if we
    // should tear off `.call`.
    // TODO(paulberry): use resolveTypeParameter.  See findInterfaceMember.
    if (actualType is InterfaceType) {
      Class classNode = (actualType as InterfaceType).classNode;
      Member callMember =
          classHierarchy.getInterfaceMember(classNode, callName);
      if (callMember is Procedure && callMember.kind == ProcedureKind.Method) {
        if (_shouldTearOffCall(expectedType, actualType)) {
          // Replace expression with:
          // `let t = expression in t == null ? null : t.call`
          TreeNode parent = expression.parent;
          VariableDeclaration t =
              new VariableDeclaration.forValue(expression, type: actualType)
                ..fileOffset = fileOffset;
          Expression nullCheck =
              buildIsNull(new VariableGet(t), fileOffset, helper);
          PropertyGet tearOff =
              new PropertyGet(new VariableGet(t), callName, callMember)
                ..fileOffset = fileOffset;
          actualType = getGetterTypeForMemberTarget(callMember, actualType);
          ConditionalExpression conditional = new ConditionalExpression(
              nullCheck,
              new NullLiteral()..fileOffset = fileOffset,
              tearOff,
              actualType);
          Let let = new Let(t, conditional)..fileOffset = fileOffset;
          parent?.replaceChild(expression, let);
          expression = let;
        }
      }
    }

    if (actualType is VoidType && !isVoidAllowed) {
      // Error: not assignable.  Perform error recovery.
      TreeNode parent = expression.parent;
      Expression errorNode =
          helper.wrapInProblem(expression, messageVoidExpression, noLength);
      parent?.replaceChild(expression, errorNode);
      return errorNode;
    }

    if (expectedType == null ||
        typeSchemaEnvironment.isSubtypeOf(actualType, expectedType)) {
      // Types are compatible.
      return null;
    }

    if (!typeSchemaEnvironment.isSubtypeOf(expectedType, actualType)) {
      // Error: not assignable.  Perform error recovery.
      TreeNode parent = expression.parent;
      Expression errorNode = new AsExpression(
          expression,
          // TODO(ahe): The outline phase doesn't correctly remove invalid
          // uses of type variables, for example, on static members. Once
          // that has been fixed, we should always be able to use
          // [expectedType] directly here.
          hasAnyTypeVariables(expectedType) ? const BottomType() : expectedType)
        ..isTypeError = true
        ..fileOffset = expression.fileOffset;
      if (expectedType is! InvalidType && actualType is! InvalidType) {
        errorNode = helper.wrapInProblem(
            errorNode,
            (template ?? templateInvalidAssignment)
                .withArguments(actualType, expectedType),
            noLength);
      }
      parent?.replaceChild(expression, errorNode);
      return errorNode;
    } else {
      Template<Message Function(DartType, DartType)> template =
          _getPreciseTypeErrorTemplate(expression);
      if (template != null) {
        // The type of the expression is known precisely, so an implicit
        // downcast is guaranteed to fail.  Insert a compile-time error.
        TreeNode parent = expression.parent;
        Expression errorNode = helper.wrapInProblem(expression,
            template.withArguments(actualType, expectedType), noLength);
        parent?.replaceChild(expression, errorNode);
        return errorNode;
      } else {
        // Insert an implicit downcast.
        TreeNode parent = expression.parent;
        AsExpression typeCheck =
            new AsExpression(expression, initialExpectedType)
              ..isTypeError = true
              ..fileOffset = fileOffset;
        parent?.replaceChild(expression, typeCheck);
        return typeCheck;
      }
    }
  }

  bool isNull(DartType type) {
    return type is InterfaceType && type.classNode == coreTypes.nullClass;
  }

  /// Finds a member of [receiverType] called [name], and if it is found,
  /// reports it through instrumentation using [fileOffset].
  ///
  /// For the case where [receiverType] is a [FunctionType], and the name
  /// is `call`, the string 'call' is returned as a sentinel object.
  ///
  /// For the case where [receiverType] is `dynamic`, and the name is declared
  /// in Object, the member from Object is returned though the call may not end
  /// up targeting it if the arguments do not match (the basic principle is that
  /// the Object member is used for inferring types only if noSuchMethod cannot
  /// be targeted due to, e.g., an incorrect argument count).
  ObjectAccessTarget findInterfaceMember(
      DartType receiverType, Name name, int fileOffset,
      {Template<Message Function(String, DartType)> errorTemplate,
      Expression expression,
      Expression receiver,
      bool setter: false,
      bool instrumented: true,
      bool includeExtensionMethods: false}) {
    assert(receiverType != null && isKnown(receiverType));

    receiverType = resolveTypeParameter(receiverType);

    if (receiverType is FunctionType && name.name == 'call') {
      return const ObjectAccessTarget.callFunction();
    }

    Class classNode = receiverType is InterfaceType
        ? receiverType.classNode
        : coreTypes.objectClass;
    Member interfaceMember =
        _getInterfaceMember(classNode, name, setter, fileOffset);
    ObjectAccessTarget target = interfaceMember != null
        ? new ObjectAccessTarget.interfaceMember(interfaceMember)
        : const ObjectAccessTarget.unresolved();
    if (instrumented &&
        receiverType != const DynamicType() &&
        target.isInstanceMember) {
      instrumentation?.record(uri, fileOffset, 'target',
          new InstrumentationValueForMember(target.member));
    }

    if (target.isUnresolved && includeExtensionMethods) {
      // TODO(johnniwinther): Find the most specific method.
      library.scope.forEachExtension((ExtensionBuilder extensionBuilder) {
        MemberBuilder memberBuilder =
            extensionBuilder.lookupLocalMember(name.name, setter: setter);
        if (memberBuilder != null && !memberBuilder.isStatic) {
          ProcedureBuilder procedureBuilder = memberBuilder;
          if (procedureBuilder != null) {
            DartType onType = extensionBuilder.extension.onType;
            // TODO(johnniwinther): Handle generic extensions.
            if (typeSchemaEnvironment.isSubtypeOf(receiverType, onType)) {
              target = new ObjectAccessTarget.extensionMember(
                  procedureBuilder.target,
                  procedureBuilder.kind,
                  extensionBuilder.typeParameters?.length ?? 0);
            }
          }
        }
      });
    }

    if (!isTopLevel &&
        target.isUnresolved &&
        receiverType is! DynamicType &&
        receiverType is! InvalidType &&
        !(receiverType == coreTypes.functionClass.rawType &&
            name.name == 'call') &&
        errorTemplate != null) {
      int length = name.name.length;
      if (identical(name.name, callName.name) ||
          identical(name.name, unaryMinusName.name)) {
        length = 1;
      }
      expression.parent.replaceChild(
          expression,
          helper.desugarSyntheticExpression(helper.buildProblem(
              errorTemplate.withArguments(name.name, receiverType),
              fileOffset,
              length)));
    }
    return target;
  }

  /// Finds a member of [receiverType] called [name] and records it in
  /// [methodInvocation].
  ObjectAccessTarget findMethodInvocationMember(
      DartType receiverType, InvocationExpression methodInvocation,
      {bool instrumented: true}) {
    // TODO(paulberry): could we add getters to InvocationExpression to make
    // these is-checks unnecessary?
    if (methodInvocation is MethodInvocation) {
      ObjectAccessTarget interfaceTarget = findInterfaceMember(
          receiverType, methodInvocation.name, methodInvocation.fileOffset,
          errorTemplate: templateUndefinedMethod,
          expression: methodInvocation,
          receiver: methodInvocation.receiver,
          instrumented: instrumented,
          includeExtensionMethods: true);
      if (interfaceTarget.isInstanceMember) {
        Member interfaceMember = interfaceTarget.member;
        if (receiverType == const DynamicType() &&
            interfaceMember is Procedure) {
          Arguments arguments = methodInvocation.arguments;
          FunctionNode signature = interfaceMember.function;
          if (arguments.positional.length < signature.requiredParameterCount ||
              arguments.positional.length >
                  signature.positionalParameters.length) {
            return const ObjectAccessTarget.unresolved();
          }
          for (kernel.NamedExpression argument in arguments.named) {
            if (!signature.namedParameters
                .any((declaration) => declaration.name == argument.name)) {
              return const ObjectAccessTarget.unresolved();
            }
          }
          if (instrumented && instrumentation != null) {
            instrumentation.record(uri, methodInvocation.fileOffset, 'target',
                new InstrumentationValueForMember(interfaceMember));
          }
        }
        methodInvocation.interfaceTarget = interfaceMember;
      }
      return interfaceTarget;
    } else if (methodInvocation is SuperMethodInvocation) {
      assert(receiverType != const DynamicType());
      ObjectAccessTarget interfaceTarget = findInterfaceMember(
          receiverType, methodInvocation.name, methodInvocation.fileOffset,
          instrumented: instrumented);
      if (interfaceTarget.isInstanceMember) {
        methodInvocation.interfaceTarget = interfaceTarget.member;
      }
      return interfaceTarget;
    } else {
      throw unhandled("${methodInvocation.runtimeType}",
          "findMethodInvocationMember", methodInvocation.fileOffset, uri);
    }
  }

  /// Finds a member of [receiverType] called [name], and if it is found,
  /// reports it through instrumentation and records it in [propertyGet].
  ObjectAccessTarget findPropertyGetMember(
      DartType receiverType, Expression propertyGet,
      {bool instrumented: true}) {
    // TODO(paulberry): could we add a common base class to PropertyGet and
    // SuperPropertyGet to make these is-checks unnecessary?
    if (propertyGet is PropertyGet) {
      ObjectAccessTarget readTarget = findInterfaceMember(
          receiverType, propertyGet.name, propertyGet.fileOffset,
          errorTemplate: templateUndefinedGetter,
          expression: propertyGet,
          receiver: propertyGet.receiver,
          instrumented: instrumented);
      if (readTarget.isInstanceMember) {
        if (instrumented &&
            instrumentation != null &&
            receiverType == const DynamicType()) {
          instrumentation.record(uri, propertyGet.fileOffset, 'target',
              new InstrumentationValueForMember(readTarget.member));
        }
        propertyGet.interfaceTarget = readTarget.member;
      }
      return readTarget;
    } else if (propertyGet is SuperPropertyGet) {
      assert(receiverType != const DynamicType());
      ObjectAccessTarget interfaceMember = findInterfaceMember(
          receiverType, propertyGet.name, propertyGet.fileOffset,
          instrumented: instrumented);
      if (interfaceMember.isInstanceMember) {
        propertyGet.interfaceTarget = interfaceMember.member;
      }
      return interfaceMember;
    } else {
      return unhandled("${propertyGet.runtimeType}", "findPropertyGetMember",
          propertyGet.fileOffset, uri);
    }
  }

  /// Finds a member of [receiverType] called [name], and if it is found,
  /// reports it through instrumentation and records it in [propertySet].
  ObjectAccessTarget findPropertySetMember(
      DartType receiverType, Expression propertySet,
      {bool instrumented: true}) {
    if (propertySet is PropertySet) {
      ObjectAccessTarget writeTarget = findInterfaceMember(
          receiverType, propertySet.name, propertySet.fileOffset,
          errorTemplate: templateUndefinedSetter,
          expression: propertySet,
          receiver: propertySet.receiver,
          setter: true,
          instrumented: instrumented,
          includeExtensionMethods: true);
      if (writeTarget.isInstanceMember) {
        if (instrumented &&
            instrumentation != null &&
            receiverType == const DynamicType()) {
          instrumentation.record(uri, propertySet.fileOffset, 'target',
              new InstrumentationValueForMember(writeTarget.member));
        }
        propertySet.interfaceTarget = writeTarget.member;
      }
      return writeTarget;
    } else if (propertySet is SuperPropertySet) {
      assert(receiverType != const DynamicType());
      ObjectAccessTarget interfaceMember = findInterfaceMember(
          receiverType, propertySet.name, propertySet.fileOffset,
          setter: true, instrumented: instrumented);
      if (interfaceMember.isInstanceMember) {
        propertySet.interfaceTarget = interfaceMember.member;
      }
      return interfaceMember;
    } else {
      throw unhandled("${propertySet.runtimeType}", "findPropertySetMember",
          propertySet.fileOffset, uri);
    }
  }

  /// Returns the type of [target] when accessed as a getter on [receiverType].
  ///
  /// For instance
  ///
  ///    class Class<T> {
  ///      T method() {}
  ///      T getter => null;
  ///    }
  ///
  ///    Class<int> c = ...
  ///    c.method; // The getter type is `int Function()`.
  ///    c.getter; // The getter type is `int`.
  ///
  DartType getGetterType(ObjectAccessTarget target, DartType receiverType) {
    switch (target.kind) {
      case ObjectAccessTargetKind.callFunction:
        return receiverType;
      case ObjectAccessTargetKind.unresolved:
        return const DynamicType();
      case ObjectAccessTargetKind.instanceMember:
        return getGetterTypeForMemberTarget(target.member, receiverType);
      case ObjectAccessTargetKind.extensionMember:
        switch (target.extensionMethodKind) {
          case ProcedureKind.Method:
            FunctionType functionType = target.member.function.functionType;
            // TODO(johnniwinther): Handle tear off of generic extensions.
            return new FunctionType(
                functionType.positionalParameters.skip(1).toList(),
                functionType.returnType,
                namedParameters: functionType.namedParameters,
                typeParameters: functionType.typeParameters
                    .skip(target.extensionTypeParameterCount)
                    .toList(),
                requiredParameterCount:
                    functionType.requiredParameterCount - 1);
          case ProcedureKind.Getter:
            return target.member.function.returnType;
          case ProcedureKind.Setter:
          case ProcedureKind.Factory:
          case ProcedureKind.Operator:
            break;
        }
    }
    throw unhandled('$target', 'getGetterType', null, null);
  }

  /// Returns the getter type of [member] on a receiver of type [receiverType].
  ///
  /// For instance
  ///
  ///    class Class<T> {
  ///      T method() {}
  ///      T getter => null;
  ///    }
  ///
  ///    Class<int> c = ...
  ///    c.method; // The getter type is `int Function()`.
  ///    c.getter; // The getter type is `int`.
  ///
  DartType getGetterTypeForMemberTarget(
      Member interfaceMember, DartType receiverType) {
    Class memberClass = interfaceMember.enclosingClass;
    assert(
        interfaceMember is kernel.Field || interfaceMember is kernel.Procedure,
        "Unexpected interface member $interfaceMember.");
    DartType calleeType = interfaceMember.getterType;
    if (memberClass.typeParameters.isNotEmpty) {
      receiverType = resolveTypeParameter(receiverType);
      if (receiverType is InterfaceType) {
        InterfaceType castedType =
            classHierarchy.getTypeAsInstanceOf(receiverType, memberClass);
        calleeType = Substitution.fromInterfaceType(castedType)
            .substituteType(calleeType);
      }
    }
    return calleeType;
  }

  /// Returns the type of [target] when accessed as an invocation on
  /// [receiverType].
  ///
  /// If the target is known not to be invokable [unknownFunction] is returned.
  ///
  /// For instance
  ///
  ///    class Class<T> {
  ///      T method() {}
  ///      T Function() getter1 => null;
  ///      T getter2 => null;
  ///    }
  ///
  ///    Class<int> c = ...
  ///    c.method; // The getter type is `int Function()`.
  ///    c.getter1; // The getter type is `int Function()`.
  ///    c.getter2; // The getter type is [unknownFunction].
  ///
  FunctionType getFunctionType(
      ObjectAccessTarget target, DartType receiverType, bool followCall) {
    switch (target.kind) {
      case ObjectAccessTargetKind.callFunction:
        return _getFunctionType(receiverType, followCall);
      case ObjectAccessTargetKind.unresolved:
        return unknownFunction;
      case ObjectAccessTargetKind.instanceMember:
        return _getFunctionType(
            getGetterTypeForMemberTarget(target.member, receiverType),
            followCall);
      case ObjectAccessTargetKind.extensionMember:
        switch (target.extensionMethodKind) {
          case ProcedureKind.Method:
            return target.member.function.functionType;
          case ProcedureKind.Getter:
            // TODO(johnniwinther): Handle implicit .call on extension getter.
            return _getFunctionType(target.member.function.returnType, false);
          case ProcedureKind.Setter:
          case ProcedureKind.Factory:
          case ProcedureKind.Operator:
            break;
        }
    }
    throw unhandled('$target', 'getFunctionType', null, null);
  }

  FunctionType _getFunctionType(DartType calleeType, bool followCall) {
    if (calleeType is FunctionType) {
      return calleeType;
    } else if (followCall && calleeType is InterfaceType) {
      Member member =
          _getInterfaceMember(calleeType.classNode, callName, false, -1);
      if (member != null) {
        DartType callType = getGetterTypeForMemberTarget(member, calleeType);
        if (callType is FunctionType) {
          return callType;
        }
      }
    }
    return unknownFunction;
  }

  DartType getDerivedTypeArgumentOf(DartType type, Class class_) {
    if (type is InterfaceType) {
      InterfaceType typeAsInstanceOfClass =
          classHierarchy.getTypeAsInstanceOf(type, class_);
      if (typeAsInstanceOfClass != null) {
        return typeAsInstanceOfClass.typeArguments[0];
      }
    }
    return null;
  }

  /// Gets the initializer for the given [field], or `null` if there is no
  /// initializer.
  Expression getFieldInitializer(Field field);

  /// If the [member] is a forwarding stub, return the target it forwards to.
  /// Otherwise return the given [member].
  Member getRealTarget(Member member) {
    if (member is Procedure && member.isForwardingStub) {
      return member.forwardingStubInterfaceTarget;
    }
    return member;
  }

  DartType getSetterType(ObjectAccessTarget target, DartType receiverType) {
    switch (target.kind) {
      case ObjectAccessTargetKind.unresolved:
        return const DynamicType();
      case ObjectAccessTargetKind.instanceMember:
        Member interfaceMember = target.member;
        Class memberClass = interfaceMember.enclosingClass;
        DartType setterType;
        if (interfaceMember is Procedure) {
          assert(interfaceMember.kind == ProcedureKind.Setter);
          List<VariableDeclaration> setterParameters =
              interfaceMember.function.positionalParameters;
          setterType = setterParameters.length > 0
              ? setterParameters[0].type
              : const DynamicType();
        } else if (interfaceMember is Field) {
          setterType = interfaceMember.type;
        } else {
          throw unhandled(interfaceMember.runtimeType.toString(),
              'getSetterType', null, null);
        }
        if (memberClass.typeParameters.isNotEmpty) {
          receiverType = resolveTypeParameter(receiverType);
          if (receiverType is InterfaceType) {
            InterfaceType castedType =
                classHierarchy.getTypeAsInstanceOf(receiverType, memberClass);
            setterType = Substitution.fromInterfaceType(castedType)
                .substituteType(setterType);
          }
        }
        return setterType;
      case ObjectAccessTargetKind.extensionMember:
        switch (target.extensionMethodKind) {
          case ProcedureKind.Setter:
            // TODO(johnniwinther): Is this valid if the method is generic?
            return target.member.function.positionalParameters[1].type;
          case ProcedureKind.Method:
          case ProcedureKind.Getter:
          case ProcedureKind.Factory:
          case ProcedureKind.Operator:
            break;
        }
        // TODO(johnniwinther): Compute the right setter type.
        return const DynamicType();
      case ObjectAccessTargetKind.callFunction:
    }
    throw unhandled(target.runtimeType.toString(), 'getSetterType', null, null);
  }

  DartType getTypeArgumentOf(DartType type, Class class_) {
    if (type is InterfaceType && identical(type.classNode, class_)) {
      return type.typeArguments[0];
    } else {
      return const UnknownType();
    }
  }

  /// Adds an "as" check to a [MethodInvocation] if necessary due to
  /// contravariance.
  ///
  /// The returned expression is the [AsExpression], if one was added; otherwise
  /// it is the [MethodInvocation].
  Expression handleInvocationContravariance(
      MethodContravarianceCheckKind checkKind,
      MethodInvocation desugaredInvocation,
      Arguments arguments,
      Expression expression,
      DartType inferredType,
      FunctionType functionType,
      int fileOffset) {
    Expression expressionToReplace = desugaredInvocation ?? expression;
    switch (checkKind) {
      case MethodContravarianceCheckKind.checkMethodReturn:
        TreeNode parent = expressionToReplace.parent;
        AsExpression replacement =
            new AsExpression(expressionToReplace, inferredType)
              ..isTypeError = true
              ..fileOffset = fileOffset;
        parent.replaceChild(expressionToReplace, replacement);
        if (instrumentation != null) {
          int offset = arguments.fileOffset == -1
              ? expression.fileOffset
              : arguments.fileOffset;
          instrumentation.record(uri, offset, 'checkReturn',
              new InstrumentationValueForType(inferredType));
        }
        return replacement;
      case MethodContravarianceCheckKind.checkGetterReturn:
        TreeNode parent = expressionToReplace.parent;
        PropertyGet propertyGet = new PropertyGet(desugaredInvocation.receiver,
            desugaredInvocation.name, desugaredInvocation.interfaceTarget);
        AsExpression asExpression = new AsExpression(propertyGet, functionType)
          ..isTypeError = true
          ..fileOffset = fileOffset;
        MethodInvocation replacement = new MethodInvocation(
            asExpression, callName, desugaredInvocation.arguments);
        parent.replaceChild(expressionToReplace, replacement);
        if (instrumentation != null) {
          int offset = arguments.fileOffset == -1
              ? expression.fileOffset
              : arguments.fileOffset;
          instrumentation.record(uri, offset, 'checkGetterReturn',
              new InstrumentationValueForType(functionType));
        }
        return replacement;
      case MethodContravarianceCheckKind.none:
        break;
    }
    return expressionToReplace;
  }

  /// Add an "as" check if necessary due to contravariance.
  ///
  /// Returns the "as" check if it was added; otherwise returns the original
  /// expression.
  Expression handlePropertyGetContravariance(
      Expression receiver,
      ObjectAccessTarget readTarget,
      PropertyGet desugaredGet,
      Expression expression,
      DartType inferredType,
      int fileOffset) {
    bool checkReturn = false;
    if (receiver != null &&
        readTarget.isInstanceMember &&
        receiver is! ThisExpression) {
      Member interfaceMember = readTarget.member;
      if (interfaceMember is Procedure) {
        checkReturn = returnedTypeParametersOccurNonCovariantly(
            interfaceMember.enclosingClass,
            interfaceMember.function.returnType);
      } else if (interfaceMember is Field) {
        checkReturn = returnedTypeParametersOccurNonCovariantly(
            interfaceMember.enclosingClass, interfaceMember.type);
      }
    }
    Expression replacedExpression = desugaredGet ?? expression;
    if (checkReturn) {
      Expression expressionToReplace = replacedExpression;
      TreeNode parent = expressionToReplace.parent;
      replacedExpression = new AsExpression(expressionToReplace, inferredType)
        ..isTypeError = true
        ..fileOffset = fileOffset;
      parent.replaceChild(expressionToReplace, replacedExpression);
    }
    if (instrumentation != null && checkReturn) {
      instrumentation.record(uri, expression.fileOffset, 'checkReturn',
          new InstrumentationValueForType(inferredType));
    }
    return replacedExpression;
  }

  /// Modifies a type as appropriate when inferring a declared variable's type.
  DartType inferDeclarationType(DartType initializerType) {
    if (initializerType is BottomType ||
        (initializerType is InterfaceType &&
            initializerType.classNode == coreTypes.nullClass)) {
      // If the initializer type is Null or bottom, the inferred type is
      // dynamic.
      // TODO(paulberry): this rule is inherited from analyzer behavior but is
      // not spec'ed anywhere.
      return const DynamicType();
    }
    return initializerType;
  }

  /// Performs type inference on the given [expression].
  ///
  /// [typeContext] is the expected type of the expression, based on surrounding
  /// code.  [typeNeeded] indicates whether it is necessary to compute the
  /// actual type of the expression.  If [typeNeeded] is `true`,
  /// [ExpressionInferenceResult.inferredType] is the actual type of the
  /// expression; otherwise `null`.
  ///
  /// Derived classes should override this method with logic that dispatches on
  /// the expression type and calls the appropriate specialized "infer" method.
  ExpressionInferenceResult inferExpression(
      kernel.Expression expression, DartType typeContext, bool typeNeeded,
      {bool isVoidAllowed});

  @override
  void inferFieldInitializer(
    InferenceHelper helper,
    DartType context,
    kernel.Expression initializer,
  ) {
    assert(closureContext == null);
    assert(!isTopLevel);
    this.helper = helper;
    ExpressionInferenceResult result =
        inferExpression(initializer, context, true, isVoidAllowed: true);
    ensureAssignable(
        context, result.inferredType, initializer, initializer.fileOffset,
        isVoidAllowed: context is VoidType);
    this.helper = null;
  }

  @override
  void inferFunctionBody(InferenceHelper helper, DartType returnType,
      AsyncMarker asyncMarker, Statement body) {
    assert(closureContext == null);
    this.helper = helper;
    closureContext = new ClosureContext(this, asyncMarker, returnType, false);
    inferStatement(body);
    closureContext = null;
    this.helper = null;
  }

  /// Performs the type inference steps that are shared by all kinds of
  /// invocations (constructors, instance methods, and static methods).
  DartType inferInvocation(DartType typeContext, int offset,
      FunctionType calleeType, DartType returnType, Arguments arguments,
      {bool isOverloadedArithmeticOperator: false,
      DartType receiverType,
      bool skipTypeArgumentInference: false,
      bool isConst: false}) {
    lastInferredSubstitution = null;
    lastCalleeType = null;
    List<TypeParameter> calleeTypeParameters = calleeType.typeParameters;
    if (calleeTypeParameters.isNotEmpty) {
      // It's possible that one of the callee type parameters might match a type
      // that already exists as part of inference (e.g. the type of an
      // argument).  This might happen, for instance, in the case where a
      // function or method makes a recursive call to itself.  To avoid the
      // callee type parameters accidentally matching a type that already
      // exists, and creating invalid inference results, we need to create fresh
      // type parameters for the callee (see dartbug.com/31759).
      // TODO(paulberry): is it possible to find a narrower set of circumstances
      // in which me must do this, to avoid a performance regression?
      FreshTypeParameters fresh = getFreshTypeParameters(calleeTypeParameters);
      calleeType = fresh.applyToFunctionType(calleeType);
      returnType = fresh.substitute(returnType);
      calleeTypeParameters = fresh.freshTypeParameters;
    }
    List<DartType> explicitTypeArguments = getExplicitTypeArguments(arguments);
    bool inferenceNeeded = !skipTypeArgumentInference &&
        explicitTypeArguments == null &&
        calleeTypeParameters.isNotEmpty;
    bool typeChecksNeeded = !isTopLevel;
    List<DartType> inferredTypes;
    Substitution substitution;
    List<DartType> formalTypes;
    List<DartType> actualTypes;
    if (inferenceNeeded || typeChecksNeeded) {
      formalTypes = [];
      actualTypes = [];
    }
    if (inferenceNeeded) {
      if (isConst && typeContext != null) {
        typeContext =
            new TypeVariableEliminator(coreTypes).substituteType(typeContext);
      }
      inferredTypes = new List<DartType>.filled(
          calleeTypeParameters.length, const UnknownType());
      typeSchemaEnvironment.inferGenericFunctionOrType(returnType,
          calleeTypeParameters, null, null, typeContext, inferredTypes);
      substitution =
          Substitution.fromPairs(calleeTypeParameters, inferredTypes);
    } else if (explicitTypeArguments != null &&
        calleeTypeParameters.length == explicitTypeArguments.length) {
      substitution =
          Substitution.fromPairs(calleeTypeParameters, explicitTypeArguments);
    } else if (calleeTypeParameters.length != 0) {
      substitution = Substitution.fromPairs(
          calleeTypeParameters,
          new List<DartType>.filled(
              calleeTypeParameters.length, const DynamicType()));
    }
    // TODO(paulberry): if we are doing top level inference and type arguments
    // were omitted, report an error.
    int i = 0;
    _forEachArgument(arguments, (name, expression) {
      DartType formalType = name != null
          ? getNamedParameterType(calleeType, name)
          : getPositionalParameterType(calleeType, i++);
      DartType inferredFormalType = substitution != null
          ? substitution.substituteType(formalType)
          : formalType;
      ExpressionInferenceResult result = inferExpression(
          expression,
          inferredFormalType,
          inferenceNeeded ||
              isOverloadedArithmeticOperator ||
              typeChecksNeeded);
      if (inferenceNeeded || typeChecksNeeded) {
        formalTypes.add(formalType);
        actualTypes.add(result.inferredType);
      }
      if (isOverloadedArithmeticOperator) {
        returnType = typeSchemaEnvironment.getTypeOfOverloadedArithmetic(
            receiverType, result.inferredType);
      }
    });

    // Check for and remove duplicated named arguments.
    List<kernel.NamedExpression> named = arguments.named;
    if (named.length == 2) {
      if (named[0].name == named[1].name) {
        String name = named[1].name;
        Expression error = helper.desugarSyntheticExpression(
            helper.buildProblem(
                templateDuplicatedNamedArgument.withArguments(name),
                named[1].fileOffset,
                name.length));
        arguments.named = [new kernel.NamedExpression(named[1].name, error)];
        formalTypes.removeLast();
        actualTypes.removeLast();
      }
    } else if (named.length > 2) {
      Map<String, kernel.NamedExpression> seenNames =
          <String, kernel.NamedExpression>{};
      bool hasProblem = false;
      int namedTypeIndex = arguments.positional.length;
      List<kernel.NamedExpression> uniqueNamed = <kernel.NamedExpression>[];
      for (kernel.NamedExpression expression in named) {
        String name = expression.name;
        if (seenNames.containsKey(name)) {
          hasProblem = true;
          kernel.NamedExpression prevNamedExpression = seenNames[name];
          prevNamedExpression.value = helper.desugarSyntheticExpression(
              helper.buildProblem(
                  templateDuplicatedNamedArgument.withArguments(name),
                  expression.fileOffset,
                  name.length))
            ..parent = prevNamedExpression;
          formalTypes.removeAt(namedTypeIndex);
          actualTypes.removeAt(namedTypeIndex);
        } else {
          seenNames[name] = expression;
          uniqueNamed.add(expression);
          namedTypeIndex++;
        }
      }
      if (hasProblem) {
        arguments.named = uniqueNamed;
      }
    }

    if (inferenceNeeded) {
      typeSchemaEnvironment.inferGenericFunctionOrType(
          returnType,
          calleeTypeParameters,
          formalTypes,
          actualTypes,
          typeContext,
          inferredTypes);
      substitution =
          Substitution.fromPairs(calleeTypeParameters, inferredTypes);
      instrumentation?.record(uri, offset, 'typeArgs',
          new InstrumentationValueForTypeArgs(inferredTypes));
      arguments.types.clear();
      arguments.types.addAll(inferredTypes);
    }
    if (typeChecksNeeded && !identical(calleeType, unknownFunction)) {
      LocatedMessage argMessage =
          helper.checkArgumentsForType(calleeType, arguments, offset);
      if (argMessage != null) {
        helper.addProblem(
            argMessage.messageObject, argMessage.charOffset, argMessage.length);
      } else {
        // Argument counts and names match. Compare types.
        int numPositionalArgs = arguments.positional.length;
        for (int i = 0; i < formalTypes.length; i++) {
          DartType formalType = formalTypes[i];
          DartType expectedType = substitution != null
              ? substitution.substituteType(formalType)
              : formalType;
          DartType actualType = actualTypes[i];
          Expression expression = i < numPositionalArgs
              ? arguments.positional[i]
              : arguments.named[i - numPositionalArgs].value;
          ensureAssignable(
              expectedType, actualType, expression, expression.fileOffset,
              isVoidAllowed: expectedType is VoidType,
              template: templateArgumentTypeNotAssignable);
        }
      }
    }
    DartType inferredType;
    lastInferredSubstitution = substitution;
    lastCalleeType = calleeType;
    inferredType = substitution == null
        ? returnType
        : substitution.substituteType(returnType);
    return inferredType;
  }

  DartType inferLocalFunction(FunctionNode function, DartType typeContext,
      int fileOffset, DartType returnContext) {
    bool hasImplicitReturnType = false;
    if (returnContext == null) {
      hasImplicitReturnType = true;
      returnContext = const DynamicType();
    }
    if (!isTopLevel) {
      List<VariableDeclaration> positionalParameters =
          function.positionalParameters;
      for (int i = 0; i < positionalParameters.length; i++) {
        VariableDeclaration parameter = positionalParameters[i];
        inferMetadataKeepingHelper(parameter.annotations);
        if (parameter.initializer != null) {
          inferExpression(parameter.initializer, parameter.type, !isTopLevel);
        }
      }
      for (VariableDeclaration parameter in function.namedParameters) {
        inferMetadataKeepingHelper(parameter.annotations);
        inferExpression(parameter.initializer, parameter.type, !isTopLevel);
      }
    }

    // Let `<T0, ..., Tn>` be the set of type parameters of the closure (with
    // `n`=0 if there are no type parameters).
    List<TypeParameter> typeParameters = function.typeParameters;

    // Let `(P0 x0, ..., Pm xm)` be the set of formal parameters of the closure
    // (including required, positional optional, and named optional parameters).
    // If any type `Pi` is missing, denote it as `_`.
    List<VariableDeclaration> formals = function.positionalParameters.toList()
      ..addAll(function.namedParameters);

    // Let `B` denote the closure body.  If `B` is an expression function body
    // (`=> e`), treat it as equivalent to a block function body containing a
    // single `return` statement (`{ return e; }`).

    // Attempt to match `K` as a function type compatible with the closure (that
    // is, one having n type parameters and a compatible set of formal
    // parameters).  If there is a successful match, let `<S0, ..., Sn>` be the
    // set of matched type parameters and `(Q0, ..., Qm)` be the set of matched
    // formal parameter types, and let `N` be the return type.
    Substitution substitution;
    List<DartType> formalTypesFromContext =
        new List<DartType>.filled(formals.length, null);
    if (typeContext is FunctionType) {
      for (int i = 0; i < formals.length; i++) {
        if (i < function.positionalParameters.length) {
          formalTypesFromContext[i] =
              getPositionalParameterType(typeContext, i);
        } else {
          formalTypesFromContext[i] =
              getNamedParameterType(typeContext, formals[i].name);
        }
      }
      returnContext = typeContext.returnType;

      // Let `[T/S]` denote the type substitution where each `Si` is replaced
      // with the corresponding `Ti`.
      Map<TypeParameter, DartType> substitutionMap =
          <TypeParameter, DartType>{};
      for (int i = 0; i < typeContext.typeParameters.length; i++) {
        substitutionMap[typeContext.typeParameters[i]] =
            i < typeParameters.length
                ? new TypeParameterType(typeParameters[i])
                : const DynamicType();
      }
      substitution = Substitution.fromMap(substitutionMap);
    } else {
      // If the match is not successful because  `K` is `_`, let all `Si`, all
      // `Qi`, and `N` all be `_`.

      // If the match is not successful for any other reason, this will result
      // in a type error, so the implementation is free to choose the best
      // error recovery path.
      substitution = Substitution.empty;
    }

    // Define `Ri` as follows: if `Pi` is not `_`, let `Ri` be `Pi`.
    // Otherwise, if `Qi` is not `_`, let `Ri` be the greatest closure of
    // `Qi[T/S]` with respect to `?`.  Otherwise, let `Ri` be `dynamic`.
    for (int i = 0; i < formals.length; i++) {
      VariableDeclarationJudgment formal = formals[i];
      if (VariableDeclarationJudgment.isImplicitlyTyped(formal)) {
        DartType inferredType;
        if (formalTypesFromContext[i] == coreTypes.nullClass.rawType) {
          inferredType = coreTypes.objectClass.rawType;
        } else if (formalTypesFromContext[i] != null) {
          inferredType = greatestClosure(coreTypes,
              substitution.substituteType(formalTypesFromContext[i]));
        } else {
          inferredType = const DynamicType();
        }
        instrumentation?.record(uri, formal.fileOffset, 'type',
            new InstrumentationValueForType(inferredType));
        formal.type = inferredType;
      }
    }

    // Let `N'` be `N[T/S]`.  The [ClosureContext] constructor will adjust
    // accordingly if the closure is declared with `async`, `async*`, or
    // `sync*`.
    if (returnContext is! UnknownType) {
      returnContext = substitution.substituteType(returnContext);
    }

    // Apply type inference to `B` in return context `N’`, with any references
    // to `xi` in `B` having type `Pi`.  This produces `B’`.
    bool needToSetReturnType = hasImplicitReturnType;
    ClosureContext oldClosureContext = this.closureContext;
    ClosureContext closureContext = new ClosureContext(
        this, function.asyncMarker, returnContext, needToSetReturnType);
    this.closureContext = closureContext;
    inferStatement(function.body);

    // If the closure is declared with `async*` or `sync*`, let `M` be the
    // least upper bound of the types of the `yield` expressions in `B’`, or
    // `void` if `B’` contains no `yield` expressions.  Otherwise, let `M` be
    // the least upper bound of the types of the `return` expressions in `B’`,
    // or `void` if `B’` contains no `return` expressions.
    DartType inferredReturnType;
    if (needToSetReturnType) {
      inferredReturnType = closureContext.inferReturnType(this);
    }

    // Then the result of inference is `<T0, ..., Tn>(R0 x0, ..., Rn xn) B` with
    // type `<T0, ..., Tn>(R0, ..., Rn) -> M’` (with some of the `Ri` and `xi`
    // denoted as optional or named parameters, if appropriate).
    if (needToSetReturnType) {
      instrumentation?.record(uri, fileOffset, 'returnType',
          new InstrumentationValueForType(inferredReturnType));
      function.returnType = inferredReturnType;
    }
    this.closureContext = oldClosureContext;
    return function.functionType;
  }

  @override
  void inferMetadata(
      InferenceHelper helper, List<kernel.Expression> annotations) {
    if (annotations != null) {
      this.helper = helper;
      inferMetadataKeepingHelper(annotations);
      this.helper = null;
    }
  }

  @override
  void inferMetadataKeepingHelper(List<kernel.Expression> annotations) {
    if (annotations != null) {
      // Place annotations in a temporary list literal so that they will have a
      // parent.  This is necessary in case any of the annotations need to get
      // replaced during type inference.
      List<TreeNode> parents = annotations.map((e) => e.parent).toList();
      new ListLiteral(annotations);
      for (Expression annotation in annotations) {
        inferExpression(annotation, const UnknownType(), !isTopLevel);
      }
      for (int i = 0; i < annotations.length; ++i) {
        annotations[i].parent = parents[i];
      }
    }
  }

  /// Performs the core type inference algorithm for method invocations (this
  /// handles both null-aware and non-null-aware method invocations).
  ExpressionInferenceResult inferMethodInvocation(
      kernel.Expression expression,
      kernel.Expression receiver,
      int fileOffset,
      bool isImplicitCall,
      DartType typeContext,
      {VariableDeclaration receiverVariable,
      MethodInvocation desugaredInvocation,
      ObjectAccessTarget target,
      Name methodName,
      Arguments arguments}) {
    assert(desugaredInvocation == null || target == null);
    assert(desugaredInvocation != null || target != null);
    // First infer the receiver so we can look up the method that was invoked.
    DartType receiverType;
    if (receiver == null) {
      receiverType = thisType;
    } else {
      ExpressionInferenceResult result =
          inferExpression(receiver, const UnknownType(), true);
      receiverType = result.inferredType;
    }
    receiverVariable?.type = receiverType;
    if (desugaredInvocation != null) {
      target = findMethodInvocationMember(receiverType, desugaredInvocation);
      methodName = desugaredInvocation.name;
      arguments = desugaredInvocation.arguments;
    }
    assert(
        target != null,
        "No target for ${expression} with desugared "
        "invocation ${desugaredInvocation}.");
    bool isOverloadedArithmeticOperator = target.isInstanceMember &&
        target.member is Procedure &&
        typeSchemaEnvironment.isOverloadedArithmeticOperatorAndType(
            target.member, receiverType);
    DartType calleeType = getGetterType(target, receiverType);
    FunctionType functionType =
        getFunctionType(target, receiverType, !isImplicitCall);

    if (!target.isUnresolved &&
        calleeType is! DynamicType &&
        calleeType != coreTypes.functionClass.rawType &&
        identical(functionType, unknownFunction)) {
      TreeNode parent = expression.parent;
      kernel.Expression error = helper.wrapInProblem(expression,
          templateInvokeNonFunction.withArguments(methodName.name), noLength);
      parent?.replaceChild(expression, error);
      return const ExpressionInferenceResult(const DynamicType());
    }
    MethodContravarianceCheckKind checkKind = preCheckInvocationContravariance(
        receiver,
        receiverType,
        target,
        desugaredInvocation,
        arguments,
        expression);
    Expression replacement;
    if (target.isExtensionMember) {
      expression.parent.replaceChild(
          expression,
          replacement = helper.forest.createStaticInvocation(
              expression.fileOffset,
              target.member,
              arguments = helper.forest.createArguments(
                  arguments.fileOffset, [receiver, ...arguments.positional],
                  named: arguments.named,
                  types: getExplicitTypeArguments(arguments))));
    }
    DartType inferredType = inferInvocation(typeContext, fileOffset,
        functionType, functionType.returnType, arguments,
        isOverloadedArithmeticOperator: isOverloadedArithmeticOperator,
        receiverType: receiverType);
    if (methodName.name == '==') {
      inferredType = coreTypes.boolClass.rawType;
    }
    handleInvocationContravariance(checkKind, desugaredInvocation, arguments,
        expression, inferredType, functionType, fileOffset);
    if (isImplicitCall && target.isInstanceMember) {
      Member member = target.member;
      if (!(member is Procedure && member.kind == ProcedureKind.Method)) {
        TreeNode parent = expression.parent;
        Expression errorNode = helper.wrapInProblem(
            expression,
            templateImplicitCallOfNonMethod.withArguments(receiverType),
            noLength);
        parent?.replaceChild(expression, errorNode);
      }
    }

    // If [arguments] were inferred, check them.
    // TODO(dmitryas): Figure out why [library] is sometimes null? Answer:
    // because top level inference never got a library. This has changed so
    // we always have a library. Should we still skip this for top level
    // inference?
    if (!isTopLevel) {
      // [actualReceiverType], [interfaceTarget], and [actualMethodName] below
      // are for a workaround for the cases like the following:
      //
      //     class C1 { var f = new C2(); }
      //     class C2 { int call<X extends num>(X x) => 42; }
      //     main() { C1 c = new C1(); c.f("foobar"); }
      DartType actualReceiverType;
      Member interfaceTarget;
      Name actualMethodName;
      if (calleeType is InterfaceType) {
        actualReceiverType = calleeType;
        interfaceTarget = null;
        actualMethodName = callName;
      } else {
        actualReceiverType = receiverType;
        interfaceTarget = target.isInstanceMember ? target.member : null;
        actualMethodName = methodName;
      }
      library.checkBoundsInMethodInvocation(
          actualReceiverType,
          typeSchemaEnvironment,
          classHierarchy,
          this,
          actualMethodName,
          interfaceTarget,
          arguments,
          helper.uri,
          fileOffset,
          inferred: getExplicitTypeArguments(arguments) == null);
    }

    return new ExpressionInferenceResult(inferredType, replacement);
  }

  @override
  void inferParameterInitializer(InferenceHelper helper,
      kernel.Expression initializer, DartType declaredType) {
    assert(closureContext == null);
    this.helper = helper;
    assert(declaredType != null);
    ExpressionInferenceResult result =
        inferExpression(initializer, declaredType, true);
    ensureAssignable(
        declaredType, result.inferredType, initializer, initializer.fileOffset);
    this.helper = null;
  }

  /// Performs the core type inference algorithm for property gets (this handles
  /// both null-aware and non-null-aware property gets).
  ExpressionInferenceResult inferPropertyGet(Expression expression,
      Expression receiver, int fileOffset, DartType typeContext,
      {VariableDeclaration receiverVariable,
      PropertyGet desugaredGet,
      ObjectAccessTarget readTarget,
      Name propertyName,
      bool allowExtensionMethods: false}) {
    // First infer the receiver so we can look up the getter that was invoked.
    DartType receiverType;
    if (receiver == null) {
      receiverType = thisType;
    } else {
      ExpressionInferenceResult result =
          inferExpression(receiver, const UnknownType(), true);
      receiverType = result.inferredType;
    }
    receiverVariable?.type = receiverType;
    propertyName ??= desugaredGet.name;
    if (desugaredGet != null) {
      readTarget = findInterfaceMember(receiverType, propertyName, fileOffset,
          errorTemplate: templateUndefinedGetter,
          expression: expression,
          receiver: receiver,
          includeExtensionMethods: allowExtensionMethods);
      if (readTarget.isInstanceMember) {
        if (instrumentation != null && receiverType == const DynamicType()) {
          instrumentation.record(uri, desugaredGet.fileOffset, 'target',
              new InstrumentationValueForMember(readTarget.member));
        }
        desugaredGet.interfaceTarget = readTarget.member;
      }
    }
    DartType inferredType = getGetterType(readTarget, receiverType);
    Expression replacedExpression = handlePropertyGetContravariance(receiver,
        readTarget, desugaredGet, expression, inferredType, fileOffset);
    Expression replacement;
    if (readTarget.isInstanceMember) {
      Member member = readTarget.member;
      if (member is Procedure && member.kind == ProcedureKind.Method) {
        inferredType =
            instantiateTearOff(inferredType, typeContext, replacedExpression);
      }
    } else if (readTarget.isExtensionMember) {
      int fileOffset = expression.fileOffset;
      switch (readTarget.extensionMethodKind) {
        case kernel.ProcedureKind.Getter:
          expression.parent.replaceChild(
              expression,
              replacement = expression = helper.forest.createStaticInvocation(
                  fileOffset,
                  readTarget.member,
                  helper.forest.createArguments(fileOffset, [receiver])));
          break;
        case kernel.ProcedureKind.Method:

          // Create instance method tear off by converting
          //
          //    extension E on A {
          //      method() {}
          //    }
          //    A a = ...
          //    a.method;
          //
          // into
          //
          //    E|method(A #this) {}
          //    A a ...
          //    let #1 = a in () => E|method(#1);
          //

          //VariableDeclaration variable = helper.forest
          //    .createVariableDeclarationForValue(fileOffset, receiver,
          //        type: receiverType);
          //expression.parent.replaceChild(
          //    expression,
          //    replacement = expression = helper.forest.createLet(
          //        variable,
          //        helper.createExtensionTearOff(
          //            expression.fileOffset,
          //            readTarget.member,
          //            variable,
          //            // TODO(johnniwinther): Support generic extensions.
          //            [],
          //            receiver)));

          // TODO(johnniwinther): The encoding above doesn't work on the VM
          // (silently stops execution!) and dart2js (crashes due to invalid
          // closure scope result). We use this instead:

          // Create instance method tear off by converting
          //
          //    extension E on A {
          //      method() {}
          //    }
          //    A a = ...
          //    a.method;
          //
          // into
          //
          //    E|method(A #this) {}
          //    A a ...
          //    ((#1) => () => E|method(#1))(a);
          //

          VariableDeclaration variable = helper.forest
              .createVariableDeclaration("#", 0,
                  isFinal: true, type: receiverType);
          expression.parent.replaceChild(
              expression,
              replacement = expression = helper.forest.createFunctionInvocation(
                  fileOffset,
                  helper.forest.createFunctionExpression(
                      fileOffset,
                      helper.forest.createFunctionNode(
                        helper.forest.createReturnStatement(
                            fileOffset,
                            helper.createExtensionTearOff(
                                fileOffset, readTarget.member, variable, [])),
                        positionalParameters: [variable],
                        requiredParameterCount: 1,
                      )),
                  helper.forest.createArguments(fileOffset, [receiver])));
          break;
        case kernel.ProcedureKind.Setter:
        case kernel.ProcedureKind.Factory:
        case kernel.ProcedureKind.Operator:
          unhandled('$readTarget', "inferPropertyGet", fileOffset, uri);
          break;
      }
    }
    storeInferredType(expression, inferredType);
    return new ExpressionInferenceResult(inferredType, replacement);
  }

  /// Modifies a type as appropriate when inferring a closure return type.
  DartType inferReturnType(DartType returnType) {
    return returnType ?? typeSchemaEnvironment.nullType;
  }

  /// Performs type inference on the given [statement].
  ///
  /// Derived classes should override this method with logic that dispatches on
  /// the statement type and calls the appropriate specialized "infer" method.
  void inferStatement(Statement statement);

  /// Performs the type inference steps necessary to instantiate a tear-off
  /// (if necessary).
  DartType instantiateTearOff(
      DartType tearoffType, DartType context, Expression expression) {
    if (tearoffType is FunctionType &&
        context is FunctionType &&
        context.typeParameters.isEmpty) {
      List<TypeParameter> typeParameters = tearoffType.typeParameters;
      if (typeParameters.isNotEmpty) {
        List<DartType> inferredTypes = new List<DartType>.filled(
            typeParameters.length, const UnknownType());
        FunctionType instantiatedType = tearoffType.withoutTypeParameters;
        typeSchemaEnvironment.inferGenericFunctionOrType(
            instantiatedType, typeParameters, [], [], context, inferredTypes);
        if (!isTopLevel) {
          TreeNode parent = expression.parent;
          parent.replaceChild(
              expression,
              new Instantiation(expression, inferredTypes)
                ..fileOffset = expression.fileOffset);
        }
        Substitution substitution =
            Substitution.fromPairs(typeParameters, inferredTypes);
        return substitution.substituteType(instantiatedType);
      }
    }
    return tearoffType;
  }

  /// True if the returned [type] has non-covariant occurrences of any of
  /// [class_]'s type parameters.
  ///
  /// A non-covariant occurrence of a type parameter is either a contravariant
  /// or an invariant position.
  ///
  /// A contravariant position is to the left of an odd number of arrows. For
  /// example, T occurs contravariantly in T -> T0, T0 -> (T -> T1),
  /// (T0 -> T) -> T1 but not in (T -> T0) -> T1.
  ///
  /// An invariant position is without a bound of a type parameter. For example,
  /// T occurs invariantly in `S Function<S extends T>()` and
  /// `void Function<S extends C<T>>(S)`.
  static bool returnedTypeParametersOccurNonCovariantly(
      Class class_, DartType type) {
    if (class_.typeParameters.isEmpty) return false;
    IncludesTypeParametersNonCovariantly checker =
        new IncludesTypeParametersNonCovariantly(class_.typeParameters,
            // We are checking the returned type (field/getter type or return
            // type of a method) and this is a covariant position.
            initialVariance: Variance.covariant);
    return type.accept(checker);
  }

  /// Determines the dispatch category of a [MethodInvocation] and returns a
  /// boolean indicating whether an "as" check will need to be added due to
  /// contravariance.
  MethodContravarianceCheckKind preCheckInvocationContravariance(
      Expression receiver,
      DartType receiverType,
      ObjectAccessTarget target,
      MethodInvocation desugaredInvocation,
      Arguments arguments,
      Expression expression) {
    if (target.isInstanceMember) {
      Member interfaceMember = target.member;
      if (interfaceMember is Field ||
          interfaceMember is Procedure &&
              interfaceMember.kind == ProcedureKind.Getter) {
        DartType getType = getGetterType(target, receiverType);
        if (getType is DynamicType) {
          return MethodContravarianceCheckKind.none;
        }
        if (receiver != null && receiver is! ThisExpression) {
          if ((interfaceMember is Field &&
                  returnedTypeParametersOccurNonCovariantly(
                      interfaceMember.enclosingClass, interfaceMember.type)) ||
              (interfaceMember is Procedure &&
                  returnedTypeParametersOccurNonCovariantly(
                      interfaceMember.enclosingClass,
                      interfaceMember.function.returnType))) {
            return MethodContravarianceCheckKind.checkGetterReturn;
          }
        }
      } else if (receiver != null &&
          receiver is! ThisExpression &&
          interfaceMember is Procedure &&
          returnedTypeParametersOccurNonCovariantly(
              interfaceMember.enclosingClass,
              interfaceMember.function.returnType)) {
        return MethodContravarianceCheckKind.checkMethodReturn;
      }
    }
    return MethodContravarianceCheckKind.none;
  }

  /// If the given [type] is a [TypeParameterType], resolve it to its bound.
  DartType resolveTypeParameter(DartType type) {
    DartType resolveOneStep(DartType type) {
      if (type is TypeParameterType) {
        return type.bound;
      } else {
        return null;
      }
    }

    DartType resolved = resolveOneStep(type);
    if (resolved == null) return type;

    // Detect circularities using the tortoise-and-hare algorithm.
    type = resolved;
    DartType hare = resolveOneStep(type);
    if (hare == null) return type;
    while (true) {
      if (identical(type, hare)) {
        // We found a circularity.  Give up and return `dynamic`.
        return const DynamicType();
      }

      // Hare takes two steps
      DartType step1 = resolveOneStep(hare);
      if (step1 == null) return hare;
      DartType step2 = resolveOneStep(step1);
      if (step2 == null) return hare;
      hare = step2;

      // Tortoise takes one step
      type = resolveOneStep(type);
    }
  }

  DartType wrapFutureOrType(DartType type) {
    if (type is InterfaceType &&
        identical(type.classNode, coreTypes.futureOrClass)) {
      return type;
    }
    // TODO(paulberry): If [type] is a subtype of `Future`, should we just
    // return it unmodified?
    return new InterfaceType(
        coreTypes.futureOrClass, <DartType>[type ?? const DynamicType()]);
  }

  DartType wrapFutureType(DartType type) {
    DartType typeWithoutFutureOr = type ?? const DynamicType();
    return new InterfaceType(
        coreTypes.futureClass, <DartType>[typeWithoutFutureOr]);
  }

  DartType wrapType(DartType type, Class class_) {
    return new InterfaceType(class_, <DartType>[type ?? const DynamicType()]);
  }

  void _forEachArgument(
      Arguments arguments, void callback(String name, Expression expression)) {
    for (Expression expression in arguments.positional) {
      callback(null, expression);
    }
    for (kernel.NamedExpression namedExpression in arguments.named) {
      callback(namedExpression.name, namedExpression.value);
    }
  }

  Member _getInterfaceMember(
      Class class_, Name name, bool setter, int charOffset) {
    Member member = engine.hierarchyBuilder.getCombinedMemberSignatureKernel(
        class_, name, setter, charOffset, library);
    if (member == null && library.isPatch) {
      // TODO(dmitryas): Hack for parts.
      member ??=
          classHierarchy.getInterfaceMember(class_, name, setter: setter);
    }
    return TypeInferenceEngine.resolveInferenceNode(member);
  }

  /// Determines if the given [expression]'s type is precisely known at compile
  /// time.
  ///
  /// If it is, an error message template is returned, which can be used by the
  /// caller to report an invalid cast.  Otherwise, `null` is returned.
  Template<Message Function(DartType, DartType)> _getPreciseTypeErrorTemplate(
      Expression expression) {
    if (expression is ListLiteral) {
      return templateInvalidCastLiteralList;
    }
    if (expression is MapLiteral) {
      return templateInvalidCastLiteralMap;
    }
    if (expression is SetLiteral) {
      return templateInvalidCastLiteralSet;
    }
    if (expression is FunctionExpression) {
      return templateInvalidCastFunctionExpr;
    }
    if (expression is ConstructorInvocation) {
      return templateInvalidCastNewExpr;
    }
    if (expression is StaticGet) {
      Member target = expression.target;
      if (target is Procedure && target.kind == ProcedureKind.Method) {
        if (target.enclosingClass != null) {
          return templateInvalidCastStaticMethod;
        } else {
          return templateInvalidCastTopLevelFunction;
        }
      }
      return null;
    }
    if (expression is VariableGet) {
      VariableDeclaration variable = expression.variable;
      if (variable is VariableDeclarationJudgment &&
          VariableDeclarationJudgment.isLocalFunction(variable)) {
        return templateInvalidCastLocalFunction;
      }
    }
    return null;
  }

  bool _shouldTearOffCall(DartType expectedType, DartType actualType) {
    if (expectedType is InterfaceType &&
        expectedType.classNode == typeSchemaEnvironment.futureOrClass) {
      expectedType = (expectedType as InterfaceType).typeArguments[0];
    }
    if (expectedType is FunctionType) return true;
    if (expectedType == typeSchemaEnvironment.rawFunctionType) {
      if (!typeSchemaEnvironment.isSubtypeOf(actualType, expectedType)) {
        return true;
      }
    }
    return false;
  }
}

abstract class MixinInferrer {
  final CoreTypes coreTypes;
  final TypeConstraintGatherer gatherer;

  MixinInferrer(this.coreTypes, this.gatherer);

  Supertype asInstantiationOf(Supertype type, Class superclass);

  void reportProblem(Message message, Class cls);

  void generateConstraints(
      Class mixinClass, Supertype baseType, Supertype mixinSupertype) {
    if (mixinSupertype.typeArguments.isEmpty) {
      // The supertype constraint isn't generic; it doesn't constrain anything.
    } else if (mixinSupertype.classNode.isAnonymousMixin) {
      // We have either a mixin declaration `mixin M<X0, ..., Xn> on S0, S1` or
      // a VM-style super mixin `abstract class M<X0, ..., Xn> extends S0 with
      // S1` where S0 and S1 are superclass constraints that possibly have type
      // arguments.
      //
      // It has been compiled by naming the superclass to either:
      //
      // abstract class S0&S1<...> extends Object implements S0, S1 {}
      // abstract class M<X0, ..., Xn> extends S0&S1<...> ...
      //
      // for a mixin declaration, or else:
      //
      // abstract class S0&S1<...> = S0 with S1;
      // abstract class M<X0, ..., Xn> extends S0&S1<...>
      //
      // for a VM-style super mixin.  The type parameters of S0&S1 are the X0,
      // ..., Xn that occurred free in S0 and S1.  Treat S0 and S1 as separate
      // supertype constraints by recursively calling this algorithm.
      //
      // In the Dart VM the mixin application classes themselves are all
      // eliminated by translating them to normal classes.  In that case, the
      // mixin appears as the only interface in the introduced class.  We
      // support three forms for the superclass constraints:
      //
      // abstract class S0&S1<...> extends Object implements S0, S1 {}
      // abstract class S0&S1<...> = S0 with S1;
      // abstract class S0&S1<...> extends S0 implements S1 {}
      Class mixinSuperclass = mixinSupertype.classNode;
      if (mixinSuperclass.mixedInType == null &&
          mixinSuperclass.implementedTypes.length != 1 &&
          (mixinSuperclass.superclass != coreTypes.objectClass ||
              mixinSuperclass.implementedTypes.length != 2)) {
        unexpected(
            'Compiler-generated mixin applications have a mixin or else '
                'implement exactly one type',
            '$mixinSuperclass implements '
                '${mixinSuperclass.implementedTypes.length} types',
            mixinSuperclass.fileOffset,
            mixinSuperclass.fileUri);
      }
      Substitution substitution = Substitution.fromSupertype(mixinSupertype);
      Supertype s0, s1;
      if (mixinSuperclass.implementedTypes.length == 2) {
        s0 = mixinSuperclass.implementedTypes[0];
        s1 = mixinSuperclass.implementedTypes[1];
      } else if (mixinSuperclass.implementedTypes.length == 1) {
        s0 = mixinSuperclass.supertype;
        s1 = mixinSuperclass.implementedTypes.first;
      } else {
        s0 = mixinSuperclass.supertype;
        s1 = mixinSuperclass.mixedInType;
      }
      s0 = substitution.substituteSupertype(s0);
      s1 = substitution.substituteSupertype(s1);
      generateConstraints(mixinClass, baseType, s0);
      generateConstraints(mixinClass, baseType, s1);
    } else {
      // Find the type U0 which is baseType as an instance of mixinSupertype's
      // class.
      Supertype supertype =
          asInstantiationOf(baseType, mixinSupertype.classNode);
      if (supertype == null) {
        reportProblem(
            templateMixinInferenceNoMatchingClass.withArguments(mixinClass.name,
                baseType.classNode.name, mixinSupertype.asInterfaceType),
            mixinClass);
        return;
      }
      InterfaceType u0 = Substitution.fromSupertype(baseType)
          .substituteSupertype(supertype)
          .asInterfaceType;
      // We want to solve U0 = S0 where S0 is mixinSupertype, but we only have
      // a subtype constraints.  Solve for equality by solving
      // both U0 <: S0 and S0 <: U0.
      InterfaceType s0 = mixinSupertype.asInterfaceType;
      gatherer.trySubtypeMatch(u0, s0);
      gatherer.trySubtypeMatch(s0, u0);
    }
  }

  void infer(Class classNode) {
    Supertype mixedInType = classNode.mixedInType;
    assert(mixedInType.typeArguments.every((t) => t == const UnknownType()));
    // Note that we have no anonymous mixin applications, they have all
    // been named.  Note also that mixin composition has been translated
    // so that we only have mixin applications of the form `S with M`.
    Supertype baseType = classNode.supertype;
    Class mixinClass = mixedInType.classNode;
    Supertype mixinSupertype = mixinClass.supertype;
    // Generate constraints based on the mixin's supertype.
    generateConstraints(mixinClass, baseType, mixinSupertype);
    // Solve them to get a map from type parameters to upper and lower
    // bounds.
    Map<TypeParameter, TypeConstraint> result = gatherer.computeConstraints();
    // Generate new type parameters with the solution as bounds.
    List<TypeParameter> parameters = mixinClass.typeParameters.map((p) {
      TypeConstraint constraint = result[p];
      // Because we solved for equality, a valid solution has a parameter
      // either unconstrained or else with identical upper and lower bounds.
      if (constraint != null && constraint.upper != constraint.lower) {
        reportProblem(
            templateMixinInferenceNoMatchingClass.withArguments(mixinClass.name,
                baseType.classNode.name, mixinSupertype.asInterfaceType),
            mixinClass);
        return p;
      }
      assert(constraint == null || constraint.upper == constraint.lower);
      bool exact =
          constraint != null && constraint.upper != const UnknownType();
      return new TypeParameter(
          p.name, exact ? constraint.upper : p.bound, p.defaultType);
    }).toList();
    // Bounds might mention the mixin class's type parameters so we have to
    // substitute them before calling instantiate to bounds.
    Substitution substitution = Substitution.fromPairs(
        mixinClass.typeParameters,
        parameters.map((p) => new TypeParameterType(p)).toList());
    for (TypeParameter p in parameters) {
      p.bound = substitution.substituteType(p.bound);
    }
    // Use instantiate to bounds.
    List<DartType> bounds = calculateBounds(parameters, coreTypes.objectClass);
    for (int i = 0; i < mixedInType.typeArguments.length; ++i) {
      mixedInType.typeArguments[i] = bounds[i];
    }
  }
}

/// The result of an expression inference.
class ExpressionInferenceResult {
  /// The inferred type of the expression.
  final DartType inferredType;

  /// If not-null, the [replacement] that replaced the inferred expression.
  final Expression replacement;

  const ExpressionInferenceResult(this.inferredType, [this.replacement]);
}

enum ObjectAccessTargetKind {
  instanceMember,
  callFunction,
  unresolved,
  extensionMember,
}

/// Result for performing an access on an object, like `o.foo`, `o.foo()` and
/// `o.foo = ...`.
class ObjectAccessTarget {
  final ObjectAccessTargetKind kind;
  final Member member;

  const ObjectAccessTarget.internal(this.kind, this.member);

  /// Creates an access to the instance [member].
  factory ObjectAccessTarget.interfaceMember(Member member) {
    assert(member != null);
    return new ObjectAccessTarget.internal(
        ObjectAccessTargetKind.instanceMember, member);
  }

  /// Creates an access to the extension [member].
  factory ObjectAccessTarget.extensionMember(
          Member member, ProcedureKind kind, int typeParameters) =
      ExtensionAccessTarget;

  /// Creates an access to a 'call' method on a function, i.e. a function
  /// invocation.
  const ObjectAccessTarget.callFunction()
      : this.internal(ObjectAccessTargetKind.callFunction, null);

  /// Creates an access with no target.
  ///
  /// Done depending on context this may or may not be an error. For instance
  /// if the receiver has type `dynamic` this is not an error.
  const ObjectAccessTarget.unresolved()
      : this.internal(ObjectAccessTargetKind.unresolved, null);

  /// Returns `true` if this is an access to an instance member.
  bool get isInstanceMember => kind == ObjectAccessTargetKind.instanceMember;

  /// Returns `true` if this is an access to an extension member.
  bool get isExtensionMember => kind == ObjectAccessTargetKind.extensionMember;

  /// Returns `true` if this is an access to the 'call' method on a function.
  bool get isCallFunction => kind == ObjectAccessTargetKind.callFunction;

  /// Returns `true` if this is an access without a known target.
  bool get isUnresolved => kind == ObjectAccessTargetKind.unresolved;

  /// Returns the original procedure kind, if this is an extension method
  /// target.
  ///
  /// This is need because getters, setters, and methods are converted into
  /// top level methods, but access and invocation should still be treated as
  /// if they are the original procedure kind.
  ProcedureKind get extensionMethodKind =>
      throw new UnsupportedError('ObjectAccessTarget.extensionMethodKind');

  /// Returns the number of type parameters of an extension method that comes
  /// from the extension declaration.
  int get extensionTypeParameterCount => throw new UnsupportedError(
      'ObjectAccessTarget.extensionTypeParameterCount');

  @override
  String toString() => 'ObjectAccessTarget($kind,$member)';
}

class ExtensionAccessTarget extends ObjectAccessTarget {
  final ProcedureKind extensionMethodKind;
  final int extensionTypeParameterCount;

  ExtensionAccessTarget(
      Member member, this.extensionMethodKind, this.extensionTypeParameterCount)
      : super.internal(ObjectAccessTargetKind.extensionMember, member);

  @override
  String toString() =>
      'ExtensionAccessTarget($kind,$member,$extensionMethodKind)';
}
