// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of "kernel_shadow_ast.dart";

class InferenceVisitor
    extends BodyVisitor1<ExpressionInferenceResult, DartType> {
  final ShadowTypeInferrer inferrer;

  Class mapEntryClass;

  // Stores the offset of the map entry found by inferMapEntry.
  int mapEntryOffset = null;

  // Stores the offset of the map spread found by inferMapEntry.
  int mapSpreadOffset = null;

  // Stores the offset of the iterable spread found by inferMapEntry.
  int iterableSpreadOffset = null;

  // Stores the type of the iterable spread found by inferMapEntry.
  DartType iterableSpreadType = null;

  InferenceVisitor(this.inferrer);

  @override
  ExpressionInferenceResult defaultExpression(
      Expression node, DartType typeContext) {
    unhandled("${node.runtimeType}", "InferenceVisitor", node.fileOffset,
        inferrer.helper.uri);
    return const ExpressionInferenceResult(const InvalidType());
  }

  @override
  ExpressionInferenceResult defaultStatement(Statement node, _) {
    unhandled("${node.runtimeType}", "InferenceVisitor", node.fileOffset,
        inferrer.helper.uri);
    return const ExpressionInferenceResult(const InvalidType());
  }

  @override
  ExpressionInferenceResult visitInvalidExpression(
          InvalidExpression node, DartType typeContext) =>
      const ExpressionInferenceResult(const BottomType());

  @override
  ExpressionInferenceResult visitIntLiteral(
          IntLiteral node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.coreTypes.intClass.rawType);

  @override
  ExpressionInferenceResult visitDoubleLiteral(
          DoubleLiteral node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.coreTypes.doubleClass.rawType);

  @override
  ExpressionInferenceResult visitAsExpression(
      AsExpression node, DartType typeContext) {
    inferrer.inferExpression(
        node.operand, const UnknownType(), !inferrer.isTopLevel,
        isVoidAllowed: true);
    return new ExpressionInferenceResult(node.type);
  }

  void visitAssertInitializerJudgment(AssertInitializerJudgment node) {
    inferrer.inferStatement(node.judgment);
  }

  void visitAssertStatementJudgment(AssertStatementJudgment node) {
    Expression conditionJudgment = node.conditionJudgment;
    Expression messageJudgment = node.messageJudgment;
    InterfaceType expectedType = inferrer.coreTypes.boolClass.rawType;
    inferrer.inferExpression(
        conditionJudgment, expectedType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(
        expectedType,
        getInferredType(conditionJudgment, inferrer),
        conditionJudgment,
        conditionJudgment.fileOffset);
    if (messageJudgment != null) {
      inferrer.inferExpression(
          messageJudgment, const UnknownType(), !inferrer.isTopLevel);
    }
  }

  @override
  ExpressionInferenceResult visitAwaitExpression(
      AwaitExpression node, DartType typeContext) {
    if (!inferrer.typeSchemaEnvironment.isEmptyContext(typeContext)) {
      typeContext = inferrer.wrapFutureOrType(typeContext);
    }
    Expression operand = node.operand;
    inferrer.inferExpression(operand, typeContext, true, isVoidAllowed: true);
    DartType inferredType = inferrer.typeSchemaEnvironment
        .unfutureType(getInferredType(operand, inferrer));
    inferrer.storeInferredType(node, inferredType);
    return new ExpressionInferenceResult(inferredType);
  }

  void visitBlockJudgment(BlockJudgment node) {
    for (Statement judgment in node.judgments) {
      inferrer.inferStatement(judgment);
    }
  }

  @override
  ExpressionInferenceResult visitBoolLiteral(
          BoolLiteral node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.coreTypes.boolClass.rawType);

  @override
  Null visitBreakStatement(BreakStatement node, _) {
    // No inference needs to be done.
  }

  ExpressionInferenceResult visitCascadeJudgment(
      CascadeJudgment node, DartType typeContext) {
    ExpressionInferenceResult result =
        inferrer.inferExpression(node.targetJudgment, typeContext, true);
    node.inferredType = result.inferredType;
    node.variable.type = getInferredType(node, inferrer);
    for (Expression judgment in node.cascadeJudgments) {
      inferrer.inferExpression(
          judgment, const UnknownType(), !inferrer.isTopLevel,
          isVoidAllowed: true);
    }
    return new ExpressionInferenceResult(node.inferredType);
  }

  @override
  ExpressionInferenceResult visitConditionalExpression(
      ConditionalExpression node, DartType typeContext) {
    Expression condition = node.condition;
    Expression then = node.then;
    Expression otherwise = node.otherwise;
    InterfaceType expectedType = inferrer.coreTypes.boolClass.rawType;
    inferrer.inferExpression(condition, expectedType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(
        expectedType,
        getInferredType(condition, inferrer),
        node.condition,
        node.condition.fileOffset);
    inferrer.inferExpression(then, typeContext, true, isVoidAllowed: true);
    inferrer.inferExpression(otherwise, typeContext, true, isVoidAllowed: true);
    DartType inferredType = inferrer.typeSchemaEnvironment
        .getStandardUpperBound(getInferredType(then, inferrer),
            getInferredType(otherwise, inferrer));
    node.staticType = inferredType;
    return new ExpressionInferenceResult(inferredType);
  }

  @override
  ExpressionInferenceResult visitConstructorInvocation(
      ConstructorInvocation node, DartType typeContext) {
    LibraryBuilder library = inferrer.engine.beingInferred[node.target];
    if (library != null) {
      // There is a cyclic dependency where inferring the types of the
      // initializing formals of a constructor required us to infer the
      // corresponding field type which required us to know the type of the
      // constructor.
      String name = node.target.enclosingClass.name;
      if (node.target.name.name.isNotEmpty) {
        // TODO(ahe): Use `inferrer.helper.constructorNameForDiagnostics`
        // instead. However, `inferrer.helper` may be null.
        name += ".${node.target.name.name}";
      }
      library.addProblem(
          templateCantInferTypeDueToCircularity.withArguments(name),
          node.target.fileOffset,
          name.length,
          node.target.fileUri);
      for (VariableDeclaration declaration
          in node.target.function.positionalParameters) {
        declaration.type ??= const InvalidType();
      }
      for (VariableDeclaration declaration
          in node.target.function.namedParameters) {
        declaration.type ??= const InvalidType();
      }
    } else if ((library = inferrer.engine.toBeInferred[node.target]) != null) {
      inferrer.engine.toBeInferred.remove(node.target);
      inferrer.engine.beingInferred[node.target] = library;
      for (VariableDeclaration declaration
          in node.target.function.positionalParameters) {
        inferrer.engine.inferInitializingFormal(declaration, node.target);
      }
      for (VariableDeclaration declaration
          in node.target.function.namedParameters) {
        inferrer.engine.inferInitializingFormal(declaration, node.target);
      }
      inferrer.engine.beingInferred.remove(node.target);
    }
    bool hasExplicitTypeArguments =
        getExplicitTypeArguments(node.arguments) != null;
    DartType inferredType = inferrer.inferInvocation(
        typeContext,
        node.fileOffset,
        node.target.function.functionType,
        computeConstructorReturnType(node.target),
        node.arguments,
        isConst: node.isConst);
    inferrer.storeInferredType(node, inferredType);
    if (!inferrer.isTopLevel) {
      SourceLibraryBuilder library = inferrer.library;
      if (!hasExplicitTypeArguments) {
        library.checkBoundsInConstructorInvocation(
            node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
            inferred: true);
      }
    }
    return new ExpressionInferenceResult(inferredType);
  }

  void visitContinueSwitchJudgment(ContinueSwitchJudgment node) {
    // No inference needs to be done.
  }

  ExpressionInferenceResult visitDeferredCheckJudgment(
      DeferredCheckJudgment node, DartType typeContext) {
    // Since the variable is not used in the body we don't need to type infer
    // it.  We can just type infer the body.
    ExpressionInferenceResult result = inferrer.inferExpression(
        node.expression, typeContext, true,
        isVoidAllowed: true);
    node.inferredType = result.inferredType;
    return new ExpressionInferenceResult(result.inferredType);
  }

  void visitDoJudgment(DoJudgment node) {
    Expression conditionJudgment = node.conditionJudgment;
    inferrer.inferStatement(node.body);
    InterfaceType boolType = inferrer.coreTypes.boolClass.rawType;
    inferrer.inferExpression(conditionJudgment, boolType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(
        boolType,
        getInferredType(conditionJudgment, inferrer),
        node.condition,
        node.condition.fileOffset);
  }

  ExpressionInferenceResult visitDoubleJudgment(
      DoubleJudgment node, DartType typeContext) {
    return new ExpressionInferenceResult(
        node.inferredType = inferrer.coreTypes.doubleClass.rawType);
  }

  void visitEmptyStatementJudgment(EmptyStatementJudgment node) {
    // No inference needs to be done.
  }

  void visitExpressionStatementJudgment(ExpressionStatementJudgment node) {
    inferrer.inferExpression(
        node.judgment, const UnknownType(), !inferrer.isTopLevel,
        isVoidAllowed: true);
  }

  ExpressionInferenceResult visitFactoryConstructorInvocationJudgment(
      FactoryConstructorInvocationJudgment node, DartType typeContext) {
    bool hadExplicitTypeArguments =
        getExplicitTypeArguments(node.arguments) != null;
    DartType inferredType = inferrer.inferInvocation(
        typeContext,
        node.fileOffset,
        node.target.function.functionType,
        computeConstructorReturnType(node.target),
        node.argumentJudgments,
        isConst: node.isConst);
    node.inferredType = inferredType;
    if (!inferrer.isTopLevel) {
      SourceLibraryBuilder library = inferrer.library;
      if (!hadExplicitTypeArguments) {
        library.checkBoundsInFactoryInvocation(
            node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
            inferred: true);
      }
    }
    return new ExpressionInferenceResult(inferredType);
  }

  void visitShadowFieldInitializer(ShadowFieldInitializer node) {
    ExpressionInferenceResult initializerResult =
        inferrer.inferExpression(node.value, node.field.type, true);
    DartType initializerType = initializerResult.inferredType;
    inferrer.ensureAssignable(
        node.field.type, initializerType, node.value, node.fileOffset);
  }

  void handleForInDeclaringVariable(
      VariableDeclaration variable, Expression iterable, Statement body,
      {bool isAsync: false}) {
    DartType elementType;
    bool typeNeeded = false;
    bool typeChecksNeeded = !inferrer.isTopLevel;
    if (VariableDeclarationJudgment.isImplicitlyTyped(variable)) {
      typeNeeded = true;
      elementType = const UnknownType();
    } else {
      elementType = variable.type;
    }

    DartType inferredType = inferForInIterable(
        iterable, elementType, typeNeeded || typeChecksNeeded,
        isAsync: isAsync);
    if (typeNeeded) {
      inferrer.instrumentation?.record(inferrer.uri, variable.fileOffset,
          'type', new InstrumentationValueForType(inferredType));
      variable.type = inferredType;
    }

    if (body != null) inferrer.inferStatement(body);

    VariableDeclaration tempVar =
        new VariableDeclaration(null, type: inferredType, isFinal: true);
    VariableGet variableGet = new VariableGet(tempVar)
      ..fileOffset = variable.fileOffset;
    TreeNode parent = variable.parent;
    Expression implicitDowncast = inferrer.ensureAssignable(
        variable.type, inferredType, variableGet, parent.fileOffset,
        template: templateForInLoopElementTypeNotAssignable);
    if (implicitDowncast != null) {
      parent.replaceChild(variable, tempVar);
      variable.initializer = implicitDowncast..parent = variable;
      if (body == null) {
        if (parent is ForInElement) {
          parent.prologue = variable;
        } else if (parent is ForInMapEntry) {
          parent.prologue = variable;
        } else {
          unhandled("${parent.runtimeType}", "handleForInDeclaringVariable",
              variable.fileOffset, variable.location.file);
        }
      } else {
        parent.replaceChild(body, combineStatements(variable, body));
      }
    }
  }

  DartType inferForInIterable(
      Expression iterable, DartType elementType, bool typeNeeded,
      {bool isAsync: false}) {
    Class iterableClass = isAsync
        ? inferrer.coreTypes.streamClass
        : inferrer.coreTypes.iterableClass;
    DartType context = inferrer.wrapType(elementType, iterableClass);
    inferrer.inferExpression(iterable, context, typeNeeded);
    DartType inferredExpressionType =
        inferrer.resolveTypeParameter(getInferredType(iterable, inferrer));
    inferrer.ensureAssignable(
        inferrer.wrapType(const DynamicType(), iterableClass),
        inferredExpressionType,
        iterable,
        iterable.fileOffset,
        template: templateForInLoopTypeNotIterable);
    DartType inferredType;
    if (typeNeeded) {
      inferredType = const DynamicType();
      if (inferredExpressionType is InterfaceType) {
        InterfaceType supertype = inferrer.classHierarchy
            .getTypeAsInstanceOf(inferredExpressionType, iterableClass);
        if (supertype != null) {
          inferredType = supertype.typeArguments[0];
        }
      }
    }
    return inferredType;
  }

  void handleForInWithoutVariable(
      VariableDeclaration variable, Expression iterable, Statement body,
      {bool isAsync: false}) {
    DartType elementType;
    bool typeChecksNeeded = !inferrer.isTopLevel;
    DartType syntheticWriteType;
    Expression syntheticAssignment;
    Expression rhs;
    ExpressionStatement statement =
        body is Block ? body.statements.first : body;
    SyntheticExpressionJudgment judgment = statement.expression;
    syntheticAssignment = judgment.desugared;
    if (syntheticAssignment is VariableSet) {
      syntheticWriteType = elementType = syntheticAssignment.variable.type;
      rhs = syntheticAssignment.value;
    } else if (syntheticAssignment is PropertySet ||
        syntheticAssignment is SuperPropertySet) {
      DartType receiverType = inferrer.thisType;
      ObjectAccessTarget writeTarget =
          inferrer.findPropertySetMember(receiverType, syntheticAssignment);
      syntheticWriteType =
          elementType = inferrer.getSetterType(writeTarget, receiverType);
      if (syntheticAssignment is PropertySet) {
        rhs = syntheticAssignment.value;
      } else if (syntheticAssignment is SuperPropertySet) {
        rhs = syntheticAssignment.value;
      }
    } else if (syntheticAssignment is StaticSet) {
      syntheticWriteType = elementType = syntheticAssignment.target.setterType;
      rhs = syntheticAssignment.value;
    } else if (syntheticAssignment is InvalidExpression) {
      elementType = const UnknownType();
    } else {
      unhandled(
          "${syntheticAssignment.runtimeType}",
          "handleForInStatementWithoutVariable",
          syntheticAssignment.fileOffset,
          inferrer.helper.uri);
    }

    DartType inferredType = inferForInIterable(
        iterable, elementType, typeChecksNeeded,
        isAsync: isAsync);
    if (typeChecksNeeded) {
      variable.type = inferredType;
    }

    inferrer.inferStatement(body);

    if (syntheticWriteType != null) {
      inferrer.ensureAssignable(
          greatestClosure(inferrer.coreTypes, syntheticWriteType),
          variable.type,
          rhs,
          rhs.fileOffset,
          template: templateForInLoopElementTypeNotAssignable,
          isVoidAllowed: true);
    }
  }

  @override
  Null visitForInStatement(ForInStatement node, _) {
    if (node.variable.name == null) {
      handleForInWithoutVariable(node.variable, node.iterable, node.body,
          isAsync: node.isAsync);
    } else {
      handleForInDeclaringVariable(node.variable, node.iterable, node.body,
          isAsync: node.isAsync);
    }
  }

  void visitForJudgment(ForJudgment node) {
    Expression conditionJudgment = node.conditionJudgment;
    for (VariableDeclaration variable in node.variables) {
      if (variable.name == null) {
        Expression initializer = variable.initializer;
        if (initializer != null) {
          ExpressionInferenceResult result = inferrer.inferExpression(
              initializer, const UnknownType(), true,
              isVoidAllowed: true);
          variable.type = result.inferredType;
        }
      } else {
        inferrer.inferStatement(variable);
      }
    }
    if (conditionJudgment != null) {
      InterfaceType expectedType = inferrer.coreTypes.boolClass.rawType;
      inferrer.inferExpression(
          conditionJudgment, expectedType, !inferrer.isTopLevel);
      inferrer.ensureAssignable(
          expectedType,
          getInferredType(conditionJudgment, inferrer),
          node.condition,
          node.condition.fileOffset);
    }
    for (Expression update in node.updateJudgments) {
      inferrer.inferExpression(
          update, const UnknownType(), !inferrer.isTopLevel,
          isVoidAllowed: true);
    }
    inferrer.inferStatement(node.body);
  }

  DartType visitFunctionNodeJudgment(
      FunctionNodeJudgment node,
      DartType typeContext,
      DartType returnContext,
      int returnTypeInstrumentationOffset) {
    return inferrer.inferLocalFunction(
        node, typeContext, returnTypeInstrumentationOffset, returnContext);
  }

  void visitFunctionDeclarationJudgment(FunctionDeclarationJudgment node) {
    inferrer.inferMetadataKeepingHelper(node.variable.annotations);
    DartType returnContext =
        node._hasImplicitReturnType ? null : node.function.returnType;
    DartType inferredType = visitFunctionNodeJudgment(
        node.functionJudgment, null, returnContext, node.fileOffset);
    node.variable.type = inferredType;
  }

  @override
  ExpressionInferenceResult visitFunctionExpression(
      FunctionExpression node, DartType typeContext) {
    DartType inferredType = visitFunctionNodeJudgment(
        node.function, typeContext, null, node.fileOffset);
    inferrer.storeInferredType(node, inferredType);
    return new ExpressionInferenceResult(inferredType);
  }

  void visitInvalidSuperInitializerJudgment(
      InvalidSuperInitializerJudgment node) {
    Substitution substitution = Substitution.fromSupertype(
        inferrer.classHierarchy.getClassAsInstanceOf(
            inferrer.thisType.classNode, node.target.enclosingClass));
    inferrer.inferInvocation(
        null,
        node.fileOffset,
        substitution.substituteType(
            node.target.function.functionType.withoutTypeParameters),
        inferrer.thisType,
        node.argumentsJudgment,
        skipTypeArgumentInference: true);
  }

  ExpressionInferenceResult visitIfNullJudgment(
      IfNullJudgment node, DartType typeContext) {
    Expression leftJudgment = node.leftJudgment;
    Expression rightJudgment = node.rightJudgment;
    // To infer `e0 ?? e1` in context K:
    // - Infer e0 in context K to get T0
    inferrer.inferExpression(leftJudgment, typeContext, true);
    DartType lhsType = getInferredType(leftJudgment, inferrer);
    node.variable.type = lhsType;
    // - Let J = T0 if K is `?` else K.
    // - Infer e1 in context J to get T1
    if (typeContext is UnknownType) {
      inferrer.inferExpression(rightJudgment, lhsType, true,
          isVoidAllowed: true);
    } else {
      inferrer.inferExpression(rightJudgment, typeContext, true,
          isVoidAllowed: true);
    }
    DartType rhsType = getInferredType(rightJudgment, inferrer);
    // - Let T = greatest closure of K with respect to `?` if K is not `_`, else
    //   UP(t0, t1)
    // - Then the inferred type is T.
    node.inferredType =
        inferrer.typeSchemaEnvironment.getStandardUpperBound(lhsType, rhsType);
    node.body.staticType = getInferredType(node, inferrer);
    return new ExpressionInferenceResult(node.inferredType);
  }

  void visitIfJudgment(IfJudgment node) {
    Expression conditionJudgment = node.conditionJudgment;
    InterfaceType expectedType = inferrer.coreTypes.boolClass.rawType;
    inferrer.inferExpression(
        conditionJudgment, expectedType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(
        expectedType,
        getInferredType(conditionJudgment, inferrer),
        node.condition,
        node.condition.fileOffset);
    inferrer.inferStatement(node.then);
    if (node.otherwise != null) {
      inferrer.inferStatement(node.otherwise);
    }
  }

  ExpressionInferenceResult visitIllegalAssignmentJudgment(
      IllegalAssignmentJudgment node, DartType typeContext) {
    if (node.write != null) {
      inferrer.inferExpression(
          node.write, const UnknownType(), !inferrer.isTopLevel);
    }
    inferrer.inferExpression(
        node.rhs, const UnknownType(), !inferrer.isTopLevel);
    node._replaceWithDesugared();
    node.inferredType = const DynamicType();
    return const ExpressionInferenceResult(const DynamicType());
  }

  ExpressionInferenceResult visitIndexAssignmentJudgment(
      IndexAssignmentJudgment node, DartType typeContext) {
    DartType receiverType = node._inferReceiver(inferrer);
    ObjectAccessTarget writeTarget =
        inferrer.findMethodInvocationMember(receiverType, node.write);
    // To replicate analyzer behavior, we base type inference on the write
    // member.  TODO(paulberry): would it be better to use the read member
    // when doing compound assignment?
    FunctionType calleeType =
        inferrer.getFunctionType(writeTarget, receiverType, false);
    DartType expectedIndexTypeForWrite;
    DartType indexContext = const UnknownType();
    DartType writeContext = const UnknownType();
    if (calleeType.positionalParameters.length >= 2) {
      // TODO(paulberry): we ought to get a context for the index expression
      // from the index formal parameter, but analyzer doesn't so for now we
      // replicate its behavior.
      expectedIndexTypeForWrite = calleeType.positionalParameters[0];
      writeContext = calleeType.positionalParameters[1];
    }
    inferrer.inferExpression(node.index, indexContext, true);
    DartType indexType = getInferredType(node.index, inferrer);
    node._storeLetType(inferrer, node.index, indexType);
    if (writeContext is! UnknownType) {
      inferrer.ensureAssignable(
          expectedIndexTypeForWrite,
          indexType,
          node._getInvocationArguments(inferrer, node.write).positional[0],
          node.write.fileOffset);
    }
    InvocationExpression read = node.read;
    DartType readType;
    if (read != null) {
      ObjectAccessTarget readMember = inferrer
          .findMethodInvocationMember(receiverType, read, instrumented: false);
      FunctionType calleeFunctionType =
          inferrer.getFunctionType(readMember, receiverType, false);
      inferrer.ensureAssignable(
          getPositionalParameterType(calleeFunctionType, 0),
          indexType,
          node._getInvocationArguments(inferrer, read).positional[0],
          read.fileOffset);
      readType = calleeFunctionType.returnType;
      MethodInvocation desugaredInvocation =
          read is MethodInvocation ? read : null;
      MethodContravarianceCheckKind checkKind =
          inferrer.preCheckInvocationContravariance(node.receiver, receiverType,
              readMember, desugaredInvocation, read.arguments, read);
      Expression replacedRead = inferrer.handleInvocationContravariance(
          checkKind,
          desugaredInvocation,
          read.arguments,
          read,
          readType,
          calleeFunctionType,
          read.fileOffset);
      node._storeLetType(inferrer, replacedRead, readType);
    }
    DartType inferredType =
        node._inferRhs(inferrer, readType, writeContext).inferredType;
    node._replaceWithDesugared();
    return new ExpressionInferenceResult(inferredType);
  }

  ExpressionInferenceResult visitIntJudgment(
      IntJudgment node, DartType typeContext) {
    if (inferrer.isDoubleContext(typeContext)) {
      double doubleValue = node.asDouble();
      if (doubleValue != null) {
        node.parent.replaceChild(
            node, new DoubleLiteral(doubleValue)..fileOffset = node.fileOffset);
        node.inferredType = inferrer.coreTypes.doubleClass.rawType;
        return new ExpressionInferenceResult(node.inferredType);
      }
    }
    Expression error = checkWebIntLiteralsErrorIfUnexact(
        inferrer, node.value, node.literal, node.fileOffset);
    if (error != null) {
      node.parent.replaceChild(node, error);
      node.inferredType = const BottomType();
      return const ExpressionInferenceResult(const BottomType());
    }
    node.inferredType = inferrer.coreTypes.intClass.rawType;
    return new ExpressionInferenceResult(node.inferredType);
  }

  ExpressionInferenceResult visitShadowLargeIntLiteral(
      ShadowLargeIntLiteral node, DartType typeContext) {
    if (inferrer.isDoubleContext(typeContext)) {
      double doubleValue = node.asDouble();
      if (doubleValue != null) {
        node.parent.replaceChild(
            node, new DoubleLiteral(doubleValue)..fileOffset = node.fileOffset);
        node.inferredType = inferrer.coreTypes.doubleClass.rawType;
        return new ExpressionInferenceResult(node.inferredType);
      }
    }

    int intValue = node.asInt64();
    if (intValue == null) {
      Expression replacement = inferrer.helper.desugarSyntheticExpression(
          inferrer.helper.buildProblem(
              templateIntegerLiteralIsOutOfRange.withArguments(node.literal),
              node.fileOffset,
              node.literal.length));
      node.parent.replaceChild(node, replacement);
      node.inferredType = const BottomType();
      return const ExpressionInferenceResult(const BottomType());
    }
    Expression error = checkWebIntLiteralsErrorIfUnexact(
        inferrer, intValue, node.literal, node.fileOffset);
    if (error != null) {
      node.parent.replaceChild(node, error);
      node.inferredType = const BottomType();
      return const ExpressionInferenceResult(const BottomType());
    }
    node.parent
        .replaceChild(node, IntLiteral(intValue)..fileOffset = node.fileOffset);
    node.inferredType = inferrer.coreTypes.intClass.rawType;
    return new ExpressionInferenceResult(node.inferredType);
  }

  void visitShadowInvalidInitializer(ShadowInvalidInitializer node) {
    inferrer.inferExpression(
        node.variable.initializer, const UnknownType(), !inferrer.isTopLevel);
  }

  void visitShadowInvalidFieldInitializer(ShadowInvalidFieldInitializer node) {
    inferrer.inferExpression(node.value, node.field.type, !inferrer.isTopLevel);
  }

  @override
  ExpressionInferenceResult visitIsExpression(
      IsExpression node, DartType typeContext) {
    inferrer.inferExpression(
        node.operand, const UnknownType(), !inferrer.isTopLevel);
    return new ExpressionInferenceResult(inferrer.coreTypes.boolClass.rawType);
  }

  @override
  Null visitLabeledStatement(LabeledStatement node, _) {
    inferrer.inferStatement(node.body);
  }

  DartType getSpreadElementType(DartType spreadType, bool isNullAware) {
    if (spreadType is InterfaceType) {
      InterfaceType supertype = inferrer.typeSchemaEnvironment
          .getTypeAsInstanceOf(spreadType, inferrer.coreTypes.iterableClass);
      if (supertype != null) return supertype.typeArguments[0];
      if (spreadType.classNode == inferrer.coreTypes.nullClass && isNullAware) {
        return spreadType;
      }
      return null;
    }
    if (spreadType is DynamicType) return const DynamicType();
    return null;
  }

  DartType inferElement(
      Expression element,
      TreeNode parent,
      DartType inferredTypeArgument,
      Map<TreeNode, DartType> inferredSpreadTypes,
      bool inferenceNeeded,
      bool typeChecksNeeded) {
    if (element is SpreadElement) {
      ExpressionInferenceResult spreadResult = inferrer.inferExpression(
          element.expression,
          new InterfaceType(inferrer.coreTypes.iterableClass,
              <DartType>[inferredTypeArgument]),
          inferenceNeeded || typeChecksNeeded,
          isVoidAllowed: true);
      DartType spreadType = spreadResult.inferredType;
      inferredSpreadTypes[element.expression] = spreadType;
      if (typeChecksNeeded) {
        DartType spreadElementType =
            getSpreadElementType(spreadType, element.isNullAware);
        if (spreadElementType == null) {
          if (spreadType is InterfaceType &&
              spreadType.classNode == inferrer.coreTypes.nullClass &&
              !element.isNullAware) {
            parent.replaceChild(
                element,
                inferrer.helper.desugarSyntheticExpression(inferrer.helper
                    .buildProblem(messageNonNullAwareSpreadIsNull,
                        element.expression.fileOffset, 1)));
          } else {
            parent.replaceChild(
                element,
                inferrer.helper.desugarSyntheticExpression(inferrer.helper
                    .buildProblem(
                        templateSpreadTypeMismatch.withArguments(spreadType),
                        element.expression.fileOffset,
                        1)));
          }
        } else if (spreadType is InterfaceType) {
          if (!inferrer.isAssignable(inferredTypeArgument, spreadElementType)) {
            parent.replaceChild(
                element,
                inferrer.helper.desugarSyntheticExpression(inferrer.helper
                    .buildProblem(
                        templateSpreadElementTypeMismatch.withArguments(
                            spreadElementType, inferredTypeArgument),
                        element.expression.fileOffset,
                        1)));
          }
        }
      }
      // Use 'dynamic' for error recovery.
      return element.elementType =
          getSpreadElementType(spreadType, element.isNullAware) ??
              const DynamicType();
    } else if (element is IfElement) {
      DartType boolType = inferrer.coreTypes.boolClass.rawType;
      ExpressionInferenceResult conditionResult = inferrer.inferExpression(
          element.condition, boolType, typeChecksNeeded,
          isVoidAllowed: false);
      DartType conditionType = conditionResult.inferredType;
      inferrer.ensureAssignable(boolType, conditionType, element.condition,
          element.condition.fileOffset);
      DartType thenType = inferElement(
          element.then,
          element,
          inferredTypeArgument,
          inferredSpreadTypes,
          inferenceNeeded,
          typeChecksNeeded);
      DartType otherwiseType;
      if (element.otherwise != null) {
        otherwiseType = inferElement(
            element.otherwise,
            element,
            inferredTypeArgument,
            inferredSpreadTypes,
            inferenceNeeded,
            typeChecksNeeded);
      }
      return otherwiseType == null
          ? thenType
          : inferrer.typeSchemaEnvironment
              .getStandardUpperBound(thenType, otherwiseType);
    } else if (element is ForElement) {
      for (VariableDeclaration declaration in element.variables) {
        if (declaration.name == null) {
          if (declaration.initializer != null) {
            ExpressionInferenceResult initializerResult =
                inferrer.inferExpression(declaration.initializer,
                    declaration.type, inferenceNeeded || typeChecksNeeded,
                    isVoidAllowed: true);
            declaration.type = initializerResult.inferredType;
          }
        } else {
          inferrer.inferStatement(declaration);
        }
      }
      if (element.condition != null) {
        inferrer.inferExpression(
            element.condition,
            inferrer.coreTypes.boolClass.rawType,
            inferenceNeeded || typeChecksNeeded,
            isVoidAllowed: false);
      }
      for (Expression expression in element.updates) {
        inferrer.inferExpression(expression, const UnknownType(),
            inferenceNeeded || typeChecksNeeded,
            isVoidAllowed: true);
      }
      return inferElement(element.body, element, inferredTypeArgument,
          inferredSpreadTypes, inferenceNeeded, typeChecksNeeded);
    } else if (element is ForInElement) {
      if (element.variable.name == null) {
        handleForInWithoutVariable(
            element.variable, element.iterable, element.prologue,
            isAsync: element.isAsync);
      } else {
        handleForInDeclaringVariable(
            element.variable, element.iterable, element.prologue,
            isAsync: element.isAsync);
      }
      if (element.problem != null) {
        inferrer.inferExpression(element.problem, const UnknownType(),
            inferenceNeeded || typeChecksNeeded,
            isVoidAllowed: true);
      }
      return inferElement(element.body, element, inferredTypeArgument,
          inferredSpreadTypes, inferenceNeeded, typeChecksNeeded);
    } else {
      ExpressionInferenceResult result = inferrer.inferExpression(
          element, inferredTypeArgument, inferenceNeeded || typeChecksNeeded,
          isVoidAllowed: true);
      DartType inferredType = result.inferredType;
      if (inferredTypeArgument is! UnknownType) {
        inferrer.ensureAssignable(
            inferredTypeArgument, inferredType, element, element.fileOffset,
            isVoidAllowed: inferredTypeArgument is VoidType);
      }
      return inferredType;
    }
  }

  void checkElement(Expression item, Expression parent, DartType typeArgument,
      Map<TreeNode, DartType> inferredSpreadTypes) {
    if (item is SpreadElement) {
      DartType spreadType = inferredSpreadTypes[item.expression];
      if (spreadType is DynamicType) {
        inferrer.ensureAssignable(inferrer.coreTypes.iterableClass.rawType,
            spreadType, item.expression, item.expression.fileOffset);
      }
    } else if (item is IfElement) {
      checkElement(item.then, item, typeArgument, inferredSpreadTypes);
      if (item.otherwise != null) {
        checkElement(item.otherwise, item, typeArgument, inferredSpreadTypes);
      }
    } else if (item is ForElement) {
      if (item.condition != null) {
        DartType conditionType = getInferredType(item.condition, inferrer);
        inferrer.ensureAssignable(inferrer.coreTypes.boolClass.rawType,
            conditionType, item.condition, item.condition.fileOffset);
      }
      checkElement(item.body, item, typeArgument, inferredSpreadTypes);
    } else if (item is ForInElement) {
      checkElement(item.body, item, typeArgument, inferredSpreadTypes);
    } else {
      // Do nothing.  Assignability checks are done during type inference.
    }
  }

  ExpressionInferenceResult visitListLiteralJudgment(
      ListLiteralJudgment node, DartType typeContext) {
    Class listClass = inferrer.coreTypes.listClass;
    InterfaceType listType = listClass.thisType;
    List<DartType> inferredTypes;
    DartType inferredTypeArgument;
    List<DartType> formalTypes;
    List<DartType> actualTypes;
    bool inferenceNeeded = node.typeArgument is ImplicitTypeArgument;
    bool typeChecksNeeded = !inferrer.isTopLevel;
    Map<TreeNode, DartType> inferredSpreadTypes;
    if (inferenceNeeded || typeChecksNeeded) {
      formalTypes = [];
      actualTypes = [];
      inferredSpreadTypes = new Map<TreeNode, DartType>.identity();
    }
    if (inferenceNeeded) {
      inferredTypes = [const UnknownType()];
      inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(listType,
          listClass.typeParameters, null, null, typeContext, inferredTypes,
          isConst: node.isConst);
      inferredTypeArgument = inferredTypes[0];
    } else {
      inferredTypeArgument = node.typeArgument;
    }
    if (inferenceNeeded || typeChecksNeeded) {
      for (int i = 0; i < node.expressions.length; ++i) {
        DartType type = inferElement(
            node.expressions[i],
            node,
            inferredTypeArgument,
            inferredSpreadTypes,
            inferenceNeeded,
            typeChecksNeeded);
        actualTypes.add(type);
        if (inferenceNeeded) {
          formalTypes.add(listType.typeArguments[0]);
        }
      }
    }
    if (inferenceNeeded) {
      inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(
          listType,
          listClass.typeParameters,
          formalTypes,
          actualTypes,
          typeContext,
          inferredTypes);
      inferredTypeArgument = inferredTypes[0];
      inferrer.instrumentation?.record(
          inferrer.uri,
          node.fileOffset,
          'typeArgs',
          new InstrumentationValueForTypeArgs([inferredTypeArgument]));
      node.typeArgument = inferredTypeArgument;
    }
    if (typeChecksNeeded) {
      for (int i = 0; i < node.expressions.length; i++) {
        checkElement(
            node.expressions[i], node, node.typeArgument, inferredSpreadTypes);
      }
    }
    node.inferredType = new InterfaceType(listClass, [inferredTypeArgument]);
    if (!inferrer.isTopLevel) {
      SourceLibraryBuilder library = inferrer.library;
      if (inferenceNeeded) {
        library.checkBoundsInListLiteral(
            node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
            inferred: true);
      }
    }

    return new ExpressionInferenceResult(node.inferredType);
  }

  @override
  ExpressionInferenceResult visitLogicalExpression(
      LogicalExpression node, DartType typeContext) {
    InterfaceType boolType = inferrer.coreTypes.boolClass.rawType;
    Expression left = node.left;
    Expression right = node.right;
    inferrer.inferExpression(left, boolType, !inferrer.isTopLevel);
    inferrer.inferExpression(right, boolType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(boolType, getInferredType(left, inferrer),
        node.left, node.left.fileOffset);
    inferrer.ensureAssignable(boolType, getInferredType(right, inferrer),
        node.right, node.right.fileOffset);
    return new ExpressionInferenceResult(boolType);
  }

  // Calculates the key and the value type of a spread map entry of type
  // spreadMapEntryType and stores them in output in positions offset and offset
  // + 1.  If the types can't be calculated, for example, if spreadMapEntryType
  // is a function type, the original values in output are preserved.
  void storeSpreadMapEntryElementTypes(DartType spreadMapEntryType,
      bool isNullAware, List<DartType> output, int offset) {
    if (spreadMapEntryType is InterfaceType) {
      InterfaceType supertype = inferrer.typeSchemaEnvironment
          .getTypeAsInstanceOf(spreadMapEntryType, inferrer.coreTypes.mapClass);
      if (supertype != null) {
        output[offset] = supertype.typeArguments[0];
        output[offset + 1] = supertype.typeArguments[1];
      } else if (spreadMapEntryType.classNode == inferrer.coreTypes.nullClass &&
          isNullAware) {
        output[offset] = output[offset + 1] = spreadMapEntryType;
      }
    }
    if (spreadMapEntryType is DynamicType) {
      output[offset] = output[offset + 1] = const DynamicType();
    }
  }

  // Note that inferMapEntry adds exactly two elements to actualTypes -- the
  // actual types of the key and the value.  The same technique is used for
  // actualTypesForSet, only inferMapEntry adds exactly one element to that
  // list: the actual type of the iterable spread elements in case the map
  // literal will be disambiguated as a set literal later.
  void inferMapEntry(
      MapEntry entry,
      TreeNode parent,
      DartType inferredKeyType,
      DartType inferredValueType,
      DartType spreadContext,
      List<DartType> actualTypes,
      List<DartType> actualTypesForSet,
      Map<TreeNode, DartType> inferredSpreadTypes,
      bool inferenceNeeded,
      bool typeChecksNeeded) {
    if (entry is SpreadMapEntry) {
      ExpressionInferenceResult spreadResult = inferrer.inferExpression(
          entry.expression, spreadContext, inferenceNeeded || typeChecksNeeded,
          isVoidAllowed: true);
      DartType spreadType = spreadResult.inferredType;
      inferredSpreadTypes[entry.expression] = spreadType;
      int length = actualTypes.length;
      actualTypes.add(null);
      actualTypes.add(null);
      storeSpreadMapEntryElementTypes(
          spreadType, entry.isNullAware, actualTypes, length);
      DartType actualKeyType = actualTypes[length];
      DartType actualValueType = actualTypes[length + 1];
      DartType actualElementType =
          getSpreadElementType(spreadType, entry.isNullAware);

      if (typeChecksNeeded) {
        if (actualKeyType == null) {
          if (spreadType is InterfaceType &&
              spreadType.classNode == inferrer.coreTypes.nullClass &&
              !entry.isNullAware) {
            parent.replaceChild(
                entry,
                new MapEntry(
                    inferrer.helper.desugarSyntheticExpression(inferrer.helper
                        .buildProblem(messageNonNullAwareSpreadIsNull,
                            entry.expression.fileOffset, 1)),
                    new NullLiteral())
                  ..fileOffset = entry.fileOffset);
          } else if (actualElementType != null) {
            // Don't report the error here, it might be an ambiguous Set.  The
            // error is reported in checkMapEntry if it's disambiguated as map.
            iterableSpreadType = spreadType;
          } else {
            parent.replaceChild(
                entry,
                new MapEntry(
                    inferrer.helper.desugarSyntheticExpression(inferrer.helper
                        .buildProblem(
                            templateSpreadMapEntryTypeMismatch
                                .withArguments(spreadType),
                            entry.expression.fileOffset,
                            1)),
                    new NullLiteral())
                  ..fileOffset = entry.fileOffset);
          }
        } else if (spreadType is InterfaceType) {
          Expression keyError;
          Expression valueError;
          if (!inferrer.isAssignable(inferredKeyType, actualKeyType)) {
            keyError = inferrer.helper.desugarSyntheticExpression(
                inferrer.helper.buildProblem(
                    templateSpreadMapEntryElementKeyTypeMismatch.withArguments(
                        actualKeyType, inferredKeyType),
                    entry.expression.fileOffset,
                    1));
          }
          if (!inferrer.isAssignable(inferredValueType, actualValueType)) {
            valueError = inferrer.helper.desugarSyntheticExpression(
                inferrer.helper.buildProblem(
                    templateSpreadMapEntryElementValueTypeMismatch
                        .withArguments(actualValueType, inferredValueType),
                    entry.expression.fileOffset,
                    1));
          }
          if (keyError != null || valueError != null) {
            keyError ??= new NullLiteral();
            valueError ??= new NullLiteral();
            parent.replaceChild(
                entry,
                new MapEntry(keyError, valueError)
                  ..fileOffset = entry.fileOffset);
          }
        }
      }

      // Use 'dynamic' for error recovery.
      if (actualKeyType == null) {
        actualKeyType = actualTypes[length] = const DynamicType();
        actualValueType = actualTypes[length + 1] = const DynamicType();
      }
      // Store the type in case of an ambiguous Set.  Use 'dynamic' for error
      // recovery.
      actualTypesForSet.add(actualElementType ?? const DynamicType());

      mapEntryClass ??=
          inferrer.coreTypes.index.getClass('dart:core', 'MapEntry');
      // TODO(dmitryas):  Handle the case of an ambiguous Set.
      entry.entryType = new InterfaceType(
          mapEntryClass, <DartType>[actualKeyType, actualValueType]);

      bool isMap = inferrer.typeSchemaEnvironment
          .isSubtypeOf(spreadType, inferrer.coreTypes.mapClass.rawType);
      bool isIterable = inferrer.typeSchemaEnvironment
          .isSubtypeOf(spreadType, inferrer.coreTypes.iterableClass.rawType);
      if (isMap && !isIterable) {
        mapSpreadOffset = entry.fileOffset;
      }
      if (!isMap && isIterable) {
        iterableSpreadOffset = entry.expression.fileOffset;
      }

      return;
    } else if (entry is IfMapEntry) {
      DartType boolType = inferrer.coreTypes.boolClass.rawType;
      ExpressionInferenceResult conditionResult = inferrer.inferExpression(
          entry.condition, boolType, typeChecksNeeded,
          isVoidAllowed: false);
      DartType conditionType = conditionResult.inferredType;
      inferrer.ensureAssignable(
          boolType, conditionType, entry.condition, entry.condition.fileOffset);
      // Note that this recursive invocation of inferMapEntry will add two types
      // to actualTypes; they are the actual types of the current invocation if
      // the 'else' branch is empty.
      inferMapEntry(
          entry.then,
          entry,
          inferredKeyType,
          inferredValueType,
          spreadContext,
          actualTypes,
          actualTypesForSet,
          inferredSpreadTypes,
          inferenceNeeded,
          typeChecksNeeded);
      if (entry.otherwise != null) {
        // We need to modify the actual types added in the recursive call to
        // inferMapEntry.
        DartType actualValueType = actualTypes.removeLast();
        DartType actualKeyType = actualTypes.removeLast();
        DartType actualTypeForSet = actualTypesForSet.removeLast();
        inferMapEntry(
            entry.otherwise,
            entry,
            inferredKeyType,
            inferredValueType,
            spreadContext,
            actualTypes,
            actualTypesForSet,
            inferredSpreadTypes,
            inferenceNeeded,
            typeChecksNeeded);
        int length = actualTypes.length;
        actualTypes[length - 2] = inferrer.typeSchemaEnvironment
            .getStandardUpperBound(actualKeyType, actualTypes[length - 2]);
        actualTypes[length - 1] = inferrer.typeSchemaEnvironment
            .getStandardUpperBound(actualValueType, actualTypes[length - 1]);
        int lengthForSet = actualTypesForSet.length;
        actualTypesForSet[lengthForSet - 1] = inferrer.typeSchemaEnvironment
            .getStandardUpperBound(
                actualTypeForSet, actualTypesForSet[lengthForSet - 1]);
      }
      return;
    } else if (entry is ForMapEntry) {
      for (VariableDeclaration declaration in entry.variables) {
        if (declaration.name == null) {
          if (declaration.initializer != null) {
            ExpressionInferenceResult result = inferrer.inferExpression(
                declaration.initializer,
                declaration.type,
                inferenceNeeded || typeChecksNeeded,
                isVoidAllowed: true);
            declaration.type = result.inferredType;
          }
        } else {
          inferrer.inferStatement(declaration);
        }
      }
      if (entry.condition != null) {
        inferrer.inferExpression(
            entry.condition,
            inferrer.coreTypes.boolClass.rawType,
            inferenceNeeded || typeChecksNeeded,
            isVoidAllowed: false);
      }
      for (Expression expression in entry.updates) {
        inferrer.inferExpression(expression, const UnknownType(),
            inferenceNeeded || typeChecksNeeded,
            isVoidAllowed: true);
      }
      // Actual types are added by the recursive call.
      return inferMapEntry(
          entry.body,
          entry,
          inferredKeyType,
          inferredValueType,
          spreadContext,
          actualTypes,
          actualTypesForSet,
          inferredSpreadTypes,
          inferenceNeeded,
          typeChecksNeeded);
    } else if (entry is ForInMapEntry) {
      if (entry.variable.name == null) {
        handleForInWithoutVariable(
            entry.variable, entry.iterable, entry.prologue,
            isAsync: entry.isAsync);
      } else {
        handleForInDeclaringVariable(
            entry.variable, entry.iterable, entry.prologue,
            isAsync: entry.isAsync);
      }
      if (entry.problem != null) {
        inferrer.inferExpression(entry.problem, const UnknownType(),
            inferenceNeeded || typeChecksNeeded,
            isVoidAllowed: true);
      }
      // Actual types are added by the recursive call.
      inferMapEntry(
          entry.body,
          entry,
          inferredKeyType,
          inferredValueType,
          spreadContext,
          actualTypes,
          actualTypesForSet,
          inferredSpreadTypes,
          inferenceNeeded,
          typeChecksNeeded);
    } else {
      ExpressionInferenceResult keyResult = inferrer.inferExpression(
          entry.key, inferredKeyType, true,
          isVoidAllowed: true);
      DartType keyType = keyResult.inferredType;
      ExpressionInferenceResult valueResult = inferrer.inferExpression(
          entry.value, inferredValueType, true,
          isVoidAllowed: true);
      DartType valueType = valueResult.inferredType;
      inferrer.ensureAssignable(
          inferredKeyType, keyType, entry.key, entry.key.fileOffset,
          isVoidAllowed: inferredKeyType is VoidType);
      inferrer.ensureAssignable(
          inferredValueType, valueType, entry.value, entry.value.fileOffset,
          isVoidAllowed: inferredValueType is VoidType);
      actualTypes.add(keyType);
      actualTypes.add(valueType);
      // Use 'dynamic' for error recovery.
      actualTypesForSet.add(const DynamicType());
      mapEntryOffset = entry.fileOffset;
      return;
    }
  }

  void checkMapEntry(
      MapEntry entry,
      TreeNode parent,
      Expression cachedKey,
      Expression cachedValue,
      DartType keyType,
      DartType valueType,
      Map<TreeNode, DartType> inferredSpreadTypes) {
    // It's disambiguated as a map literal.
    if (iterableSpreadOffset != null) {
      parent.replaceChild(
          entry,
          new MapEntry(
              inferrer.helper.desugarSyntheticExpression(inferrer.helper
                  .buildProblem(
                      templateSpreadMapEntryTypeMismatch
                          .withArguments(iterableSpreadType),
                      iterableSpreadOffset,
                      1)),
              new NullLiteral()));
    }
    if (entry is SpreadMapEntry) {
      DartType spreadType = inferredSpreadTypes[entry.expression];
      if (spreadType is DynamicType) {
        inferrer.ensureAssignable(inferrer.coreTypes.mapClass.rawType,
            spreadType, entry.expression, entry.expression.fileOffset);
      }
    } else if (entry is IfMapEntry) {
      checkMapEntry(entry.then, entry, cachedKey, cachedValue, keyType,
          valueType, inferredSpreadTypes);
      if (entry.otherwise != null) {
        checkMapEntry(entry.otherwise, entry, cachedKey, cachedValue, keyType,
            valueType, inferredSpreadTypes);
      }
    } else if (entry is ForMapEntry) {
      if (entry.condition != null) {
        DartType conditionType = getInferredType(entry.condition, inferrer);
        inferrer.ensureAssignable(inferrer.coreTypes.boolClass.rawType,
            conditionType, entry.condition, entry.condition.fileOffset);
      }
      checkMapEntry(entry.body, entry, cachedKey, cachedValue, keyType,
          valueType, inferredSpreadTypes);
    } else if (entry is ForInMapEntry) {
      checkMapEntry(entry.body, entry, cachedKey, cachedValue, keyType,
          valueType, inferredSpreadTypes);
    } else {
      // Do nothing.  Assignability checks are done during type inference.
    }
  }

  ExpressionInferenceResult visitMapLiteralJudgment(
      MapLiteralJudgment node, DartType typeContext) {
    Class mapClass = inferrer.coreTypes.mapClass;
    InterfaceType mapType = mapClass.thisType;
    List<DartType> inferredTypes;
    DartType inferredKeyType;
    DartType inferredValueType;
    List<DartType> formalTypes;
    List<DartType> actualTypes;
    List<DartType> actualTypesForSet;
    assert((node.keyType is ImplicitTypeArgument) ==
        (node.valueType is ImplicitTypeArgument));
    bool inferenceNeeded = node.keyType is ImplicitTypeArgument;
    bool typeContextIsMap = node.keyType is! ImplicitTypeArgument;
    bool typeContextIsIterable = false;
    if (!inferrer.isTopLevel && inferenceNeeded) {
      // Ambiguous set/map literal
      DartType context =
          inferrer.typeSchemaEnvironment.unfutureType(typeContext);
      if (context is InterfaceType) {
        typeContextIsMap = typeContextIsMap ||
            inferrer.classHierarchy
                .isSubtypeOf(context.classNode, inferrer.coreTypes.mapClass);
        typeContextIsIterable = typeContextIsIterable ||
            inferrer.classHierarchy.isSubtypeOf(
                context.classNode, inferrer.coreTypes.iterableClass);
        if (node.entries.isEmpty &&
            typeContextIsIterable &&
            !typeContextIsMap) {
          // Set literal
          SetLiteralJudgment setLiteral = new SetLiteralJudgment([],
              typeArgument: const ImplicitTypeArgument(), isConst: node.isConst)
            ..fileOffset = node.fileOffset;
          node.parent.replaceChild(node, setLiteral);
          visitSetLiteralJudgment(setLiteral, typeContext);
          node.inferredType = setLiteral.inferredType;
          return new ExpressionInferenceResult(node.inferredType);
        }
      }
    }
    bool typeChecksNeeded = !inferrer.isTopLevel;
    Map<TreeNode, DartType> inferredSpreadTypes;
    if (inferenceNeeded || typeChecksNeeded) {
      formalTypes = [];
      actualTypes = [];
      actualTypesForSet = [];
      inferredSpreadTypes = new Map<TreeNode, DartType>.identity();
    }
    if (inferenceNeeded) {
      inferredTypes = [const UnknownType(), const UnknownType()];
      inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(mapType,
          mapClass.typeParameters, null, null, typeContext, inferredTypes,
          isConst: node.isConst);
      inferredKeyType = inferredTypes[0];
      inferredValueType = inferredTypes[1];
    } else {
      inferredKeyType = node.keyType;
      inferredValueType = node.valueType;
    }
    List<Expression> cachedKeys = new List(node.entries.length);
    List<Expression> cachedValues = new List(node.entries.length);
    for (int i = 0; i < node.entries.length; i++) {
      MapEntry entry = node.entries[i];
      if (entry is! ControlFlowMapEntry) {
        cachedKeys[i] = node.entries[i].key;
        cachedValues[i] = node.entries[i].value;
      }
    }
    bool hasMapEntry = false;
    bool hasMapSpread = false;
    bool hasIterableSpread = false;
    if (inferenceNeeded || typeChecksNeeded) {
      mapEntryOffset = null;
      mapSpreadOffset = null;
      iterableSpreadOffset = null;
      iterableSpreadType = null;
      DartType spreadTypeContext = const UnknownType();
      if (typeContextIsIterable && !typeContextIsMap) {
        spreadTypeContext = inferrer.typeSchemaEnvironment
            .getTypeAsInstanceOf(typeContext, inferrer.coreTypes.iterableClass);
      } else if (!typeContextIsIterable && typeContextIsMap) {
        spreadTypeContext = new InterfaceType(inferrer.coreTypes.mapClass,
            <DartType>[inferredKeyType, inferredValueType]);
      }
      for (int i = 0; i < node.entries.length; ++i) {
        MapEntry entry = node.entries[i];
        inferMapEntry(
            entry,
            node,
            inferredKeyType,
            inferredValueType,
            spreadTypeContext,
            actualTypes,
            actualTypesForSet,
            inferredSpreadTypes,
            inferenceNeeded,
            typeChecksNeeded);
        if (inferenceNeeded) {
          formalTypes.add(mapType.typeArguments[0]);
          formalTypes.add(mapType.typeArguments[1]);
        }
      }
      hasMapEntry = mapEntryOffset != null;
      hasMapSpread = mapSpreadOffset != null;
      hasIterableSpread = iterableSpreadOffset != null;
    }
    if (inferenceNeeded) {
      bool canBeSet = !hasMapSpread && !hasMapEntry && !typeContextIsMap;
      bool canBeMap = !hasIterableSpread && !typeContextIsIterable;
      if (canBeSet && !canBeMap) {
        List<Expression> setElements = <Expression>[];
        List<DartType> formalTypesForSet = <DartType>[];
        InterfaceType setType = inferrer.coreTypes.setClass.thisType;
        for (int i = 0; i < node.entries.length; ++i) {
          setElements.add(convertToElement(node.entries[i], inferrer.helper));
          formalTypesForSet.add(setType.typeArguments[0]);
        }

        List<DartType> inferredTypesForSet = <DartType>[const UnknownType()];
        inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(
            setType,
            inferrer.coreTypes.setClass.typeParameters,
            null,
            null,
            typeContext,
            inferredTypesForSet,
            isConst: node.isConst);
        inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(
            inferrer.coreTypes.setClass.thisType,
            inferrer.coreTypes.setClass.typeParameters,
            formalTypesForSet,
            actualTypesForSet,
            typeContext,
            inferredTypesForSet);
        DartType inferredTypeArgument = inferredTypesForSet[0];
        inferrer.instrumentation?.record(
            inferrer.uri,
            node.fileOffset,
            'typeArgs',
            new InstrumentationValueForTypeArgs([inferredTypeArgument]));

        SetLiteralJudgment setLiteral = new SetLiteralJudgment(setElements,
            typeArgument: inferredTypeArgument, isConst: node.isConst)
          ..fileOffset = node.fileOffset;
        node.parent.replaceChild(node, setLiteral);
        if (typeChecksNeeded) {
          for (int i = 0; i < setLiteral.expressions.length; i++) {
            checkElement(setLiteral.expressions[i], setLiteral,
                setLiteral.typeArgument, inferredSpreadTypes);
          }
        }

        node.inferredType = setLiteral.inferredType =
            new InterfaceType(inferrer.coreTypes.setClass, inferredTypesForSet);
        return ExpressionInferenceResult(node.inferredType);
      }
      if (canBeSet && canBeMap && node.entries.isNotEmpty) {
        node.parent.replaceChild(
            node,
            inferrer.helper.desugarSyntheticExpression(inferrer.helper
                .buildProblem(messageCantDisambiguateNotEnoughInformation,
                    node.fileOffset, 1)));
        node.inferredType = const BottomType();
        return const ExpressionInferenceResult(const BottomType());
      }
      if (!canBeSet && !canBeMap) {
        if (!inferrer.isTopLevel) {
          node.parent.replaceChild(
              node,
              inferrer.helper.desugarSyntheticExpression(inferrer.helper
                  .buildProblem(messageCantDisambiguateAmbiguousInformation,
                      node.fileOffset, 1)));
        }
        node.inferredType = const BottomType();
        return const ExpressionInferenceResult(const BottomType());
      }
      inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(
          mapType,
          mapClass.typeParameters,
          formalTypes,
          actualTypes,
          typeContext,
          inferredTypes);
      inferredKeyType = inferredTypes[0];
      inferredValueType = inferredTypes[1];
      inferrer.instrumentation?.record(
          inferrer.uri,
          node.fileOffset,
          'typeArgs',
          new InstrumentationValueForTypeArgs(
              [inferredKeyType, inferredValueType]));
      node.keyType = inferredKeyType;
      node.valueType = inferredValueType;
    }
    if (typeChecksNeeded) {
      for (int i = 0; i < node.entries.length; ++i) {
        checkMapEntry(node.entries[i], node, cachedKeys[i], cachedValues[i],
            node.keyType, node.valueType, inferredSpreadTypes);
      }
    }
    node.inferredType =
        new InterfaceType(mapClass, [inferredKeyType, inferredValueType]);
    if (!inferrer.isTopLevel) {
      SourceLibraryBuilder library = inferrer.library;
      // Either both [_declaredKeyType] and [_declaredValueType] are omitted or
      // none of them, so we may just check one.
      if (inferenceNeeded) {
        library.checkBoundsInMapLiteral(
            node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
            inferred: true);
      }
    }
    return new ExpressionInferenceResult(node.inferredType);
  }

  ExpressionInferenceResult visitMethodInvocationJudgment(
      MethodInvocationJudgment node, DartType typeContext) {
    if (node.name.name == 'unary-' &&
        node.arguments.types.isEmpty &&
        node.arguments.positional.isEmpty &&
        node.arguments.named.isEmpty) {
      // Replace integer literals in a double context with the corresponding
      // double literal if it's exact.  For double literals, the negation is
      // folded away.  In any non-double context, or if there is no exact
      // double value, then the corresponding integer literal is left.  The
      // negation is not folded away so that platforms with web literals can
      // distinguish between (non-negated) 0x8000000000000000 represented as
      // integer literal -9223372036854775808 which should be a positive number,
      // and negated 9223372036854775808 represented as
      // -9223372036854775808.unary-() which should be a negative number.
      if (node.receiver is IntJudgment) {
        IntJudgment receiver = node.receiver;
        if (inferrer.isDoubleContext(typeContext)) {
          double doubleValue = receiver.asDouble(negated: true);
          if (doubleValue != null) {
            node.parent.replaceChild(
                node, DoubleLiteral(doubleValue)..fileOffset = node.fileOffset);
            node.inferredType = inferrer.coreTypes.doubleClass.rawType;
            return new ExpressionInferenceResult(node.inferredType);
          }
        }
        Expression error = checkWebIntLiteralsErrorIfUnexact(
            inferrer, receiver.value, receiver.literal, receiver.fileOffset);
        if (error != null) {
          node.parent.replaceChild(node, error);
          node.inferredType = const BottomType();
          return const ExpressionInferenceResult(const BottomType());
        }
      } else if (node.receiver is ShadowLargeIntLiteral) {
        ShadowLargeIntLiteral receiver = node.receiver;
        if (!receiver.isParenthesized) {
          if (inferrer.isDoubleContext(typeContext)) {
            double doubleValue = receiver.asDouble(negated: true);
            if (doubleValue != null) {
              node.parent.replaceChild(node,
                  DoubleLiteral(doubleValue)..fileOffset = node.fileOffset);
              node.inferredType = inferrer.coreTypes.doubleClass.rawType;
              return new ExpressionInferenceResult(node.inferredType);
            }
          }
          int intValue = receiver.asInt64(negated: true);
          if (intValue == null) {
            Expression error = inferrer.helper.desugarSyntheticExpression(
                inferrer.helper.buildProblem(
                    templateIntegerLiteralIsOutOfRange
                        .withArguments(receiver.literal),
                    receiver.fileOffset,
                    receiver.literal.length));
            node.parent.replaceChild(node, error);
            node.inferredType = const BottomType();
            return const ExpressionInferenceResult(const BottomType());
          }
          if (intValue != null) {
            Expression error = checkWebIntLiteralsErrorIfUnexact(
                inferrer, intValue, receiver.literal, receiver.fileOffset);
            if (error != null) {
              node.parent.replaceChild(node, error);
              node.inferredType = const BottomType();
              return const ExpressionInferenceResult(const BottomType());
            }
            node.receiver = IntLiteral(-intValue)
              ..fileOffset = node.receiver.fileOffset
              ..parent = node;
          }
        }
      }
    }
    ExpressionInferenceResult result = inferrer.inferMethodInvocation(
        node, node.receiver, node.fileOffset, node._isImplicitCall, typeContext,
        desugaredInvocation: node);
    node.inferredType = result.inferredType;
    return new ExpressionInferenceResult(result.inferredType);
  }

  ExpressionInferenceResult visitNamedFunctionExpressionJudgment(
      NamedFunctionExpressionJudgment node, DartType typeContext) {
    Expression initializer = node.variableJudgment.initializer;
    inferrer.inferExpression(initializer, typeContext, true);
    node.inferredType = getInferredType(initializer, inferrer);
    node.variable.type = node.inferredType;
    return new ExpressionInferenceResult(node.inferredType);
  }

  @override
  ExpressionInferenceResult visitNot(Not node, DartType typeContext) {
    Expression operand = node.operand;
    InterfaceType boolType = inferrer.coreTypes.boolClass.rawType;
    inferrer.inferExpression(operand, boolType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(boolType, getInferredType(operand, inferrer),
        node.operand, node.fileOffset);
    return new ExpressionInferenceResult(boolType);
  }

  ExpressionInferenceResult visitNullAwareMethodInvocationJudgment(
      NullAwareMethodInvocationJudgment node, DartType typeContext) {
    ExpressionInferenceResult result = inferrer.inferMethodInvocation(
        node, node.variable.initializer, node.fileOffset, false, typeContext,
        receiverVariable: node.variable,
        desugaredInvocation: node._desugaredInvocation);
    node.inferredType = result.inferredType;
    node.body.staticType = node.inferredType;
    return new ExpressionInferenceResult(result.inferredType);
  }

  ExpressionInferenceResult visitNullAwarePropertyGetJudgment(
      NullAwarePropertyGetJudgment node, DartType typeContext) {
    ExpressionInferenceResult result = inferrer.inferPropertyGet(
        node, node.receiverJudgment, node.fileOffset, typeContext,
        receiverVariable: node.variable, desugaredGet: node._desugaredGet);
    node.body.staticType = result.inferredType;
    return new ExpressionInferenceResult(result.inferredType);
  }

  @override
  ExpressionInferenceResult visitNullLiteral(
          NullLiteral node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.coreTypes.nullClass.rawType);

  @override
  ExpressionInferenceResult visitLet(Let node, DartType typeContext) {
    DartType variableType = node.variable.type;
    if (variableType == const DynamicType()) {
      return defaultExpression(node, typeContext);
    }
    Expression initializer = node.variable.initializer;
    inferrer.inferExpression(initializer, variableType, true,
        isVoidAllowed: true);
    Expression body = node.body;
    ExpressionInferenceResult result =
        inferrer.inferExpression(body, typeContext, true, isVoidAllowed: true);
    DartType inferredType = result.inferredType;
    // TODO(ahe): This shouldn't be needed. See InferredTypeVisitor.visitLet.
    inferrer.storeInferredType(node, inferredType);
    return new ExpressionInferenceResult(inferredType);
  }

  ExpressionInferenceResult visitPropertyAssignmentJudgment(
      PropertyAssignmentJudgment node, DartType typeContext) {
    DartType receiverType = node._inferReceiver(inferrer);

    DartType readType;
    if (node.read != null) {
      ObjectAccessTarget readTarget = inferrer
          .findPropertyGetMember(receiverType, node.read, instrumented: false);
      readType = inferrer.getGetterType(readTarget, receiverType);
      inferrer.handlePropertyGetContravariance(
          node.receiver,
          readTarget,
          node.read is PropertyGet ? node.read : null,
          node.read,
          readType,
          node.read.fileOffset);
      node._storeLetType(inferrer, node.read, readType);
    }
    ObjectAccessTarget writeTarget;
    if (node.write != null) {
      writeTarget = node._handleWriteContravariance(inferrer, receiverType);
    }
    // To replicate analyzer behavior, we base type inference on the write
    // member.  TODO(paulberry): would it be better to use the read member when
    // doing compound assignment?
    DartType writeContext = inferrer.getSetterType(writeTarget, receiverType);
    DartType inferredType =
        node._inferRhs(inferrer, readType, writeContext).inferredType;
    node.nullAwareGuard?.staticType = node.inferredType;
    Expression replacement;
    if (writeTarget.isExtensionMember) {
      node.parent.replaceChild(
          node,
          replacement = inferrer.helper.forest.createStaticInvocation(
              node.fileOffset,
              writeTarget.member,
              inferrer.helper.forest.createArguments(
                  node.fileOffset, [node.receiver, node.rhs])));
      inferrer.storeInferredType(replacement, inferredType);
    } else {
      node._replaceWithDesugared();
    }

    return new ExpressionInferenceResult(inferredType, replacement);
  }

  @override
  ExpressionInferenceResult visitPropertyGet(
      PropertyGet node, DartType typeContext) {
    return inferrer.inferPropertyGet(
        node, node.receiver, node.fileOffset, typeContext,
        desugaredGet: node, allowExtensionMethods: true);
  }

  void visitRedirectingInitializerJudgment(
      RedirectingInitializerJudgment node) {
    List<TypeParameter> classTypeParameters =
        node.target.enclosingClass.typeParameters;
    List<DartType> typeArguments =
        new List<DartType>(classTypeParameters.length);
    for (int i = 0; i < typeArguments.length; i++) {
      typeArguments[i] = new TypeParameterType(classTypeParameters[i]);
    }
    ArgumentsJudgment.setNonInferrableArgumentTypes(
        node.arguments, typeArguments);
    inferrer.inferInvocation(
        null,
        node.fileOffset,
        node.target.function.functionType,
        node.target.enclosingClass.thisType,
        node.argumentJudgments,
        skipTypeArgumentInference: true);
    ArgumentsJudgment.removeNonInferrableArgumentTypes(node.arguments);
  }

  @override
  ExpressionInferenceResult visitRethrow(Rethrow node, DartType typeContext) =>
      const ExpressionInferenceResult(const BottomType());

  void visitReturnJudgment(ReturnJudgment node) {
    Expression judgment = node.judgment;
    ClosureContext closureContext = inferrer.closureContext;
    DartType typeContext = !closureContext.isGenerator
        ? closureContext.returnOrYieldContext
        : const UnknownType();
    DartType inferredType;
    if (node.expression != null) {
      inferrer.inferExpression(judgment, typeContext, true,
          isVoidAllowed: true);
      inferredType = getInferredType(judgment, inferrer);
    } else {
      inferredType = inferrer.coreTypes.nullClass.rawType;
    }
    closureContext.handleReturn(inferrer, node, inferredType, node.isArrow);
  }

  ExpressionInferenceResult visitSetLiteralJudgment(
      SetLiteralJudgment node, DartType typeContext) {
    Class setClass = inferrer.coreTypes.setClass;
    InterfaceType setType = setClass.thisType;
    List<DartType> inferredTypes;
    DartType inferredTypeArgument;
    List<DartType> formalTypes;
    List<DartType> actualTypes;
    bool inferenceNeeded = node.typeArgument is ImplicitTypeArgument;
    bool typeChecksNeeded = !inferrer.isTopLevel;
    Map<TreeNode, DartType> inferredSpreadTypes;
    if (inferenceNeeded || typeChecksNeeded) {
      formalTypes = [];
      actualTypes = [];
      inferredSpreadTypes = new Map<TreeNode, DartType>.identity();
    }
    if (inferenceNeeded) {
      inferredTypes = [const UnknownType()];
      inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(setType,
          setClass.typeParameters, null, null, typeContext, inferredTypes,
          isConst: node.isConst);
      inferredTypeArgument = inferredTypes[0];
    } else {
      inferredTypeArgument = node.typeArgument;
    }
    if (inferenceNeeded || typeChecksNeeded) {
      for (int i = 0; i < node.expressions.length; ++i) {
        DartType type = inferElement(
            node.expressions[i],
            node,
            inferredTypeArgument,
            inferredSpreadTypes,
            inferenceNeeded,
            typeChecksNeeded);
        actualTypes.add(type);
        if (inferenceNeeded) {
          formalTypes.add(setType.typeArguments[0]);
        }
      }
    }
    if (inferenceNeeded) {
      inferrer.typeSchemaEnvironment.inferGenericFunctionOrType(
          setType,
          setClass.typeParameters,
          formalTypes,
          actualTypes,
          typeContext,
          inferredTypes);
      inferredTypeArgument = inferredTypes[0];
      inferrer.instrumentation?.record(
          inferrer.uri,
          node.fileOffset,
          'typeArgs',
          new InstrumentationValueForTypeArgs([inferredTypeArgument]));
      node.typeArgument = inferredTypeArgument;
    }
    if (typeChecksNeeded) {
      for (int i = 0; i < node.expressions.length; i++) {
        checkElement(
            node.expressions[i], node, node.typeArgument, inferredSpreadTypes);
      }
    }
    node.inferredType = new InterfaceType(setClass, [inferredTypeArgument]);
    if (!inferrer.isTopLevel) {
      SourceLibraryBuilder library = inferrer.library;
      if (inferenceNeeded) {
        library.checkBoundsInSetLiteral(
            node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
            inferred: true);
      }

      if (!library.loader.target.backendTarget.supportsSetLiterals) {
        inferrer.helper.transformSetLiterals = true;
      }
    }
    return new ExpressionInferenceResult(node.inferredType);
  }

  ExpressionInferenceResult visitStaticAssignmentJudgment(
      StaticAssignmentJudgment node, DartType typeContext) {
    DartType readType = const DynamicType(); // Only used in error recovery
    Expression read = node.read;
    if (read is StaticGet) {
      readType = read.target.getterType;
      node._storeLetType(inferrer, read, readType);
    }
    Member writeMember;
    DartType writeContext = const UnknownType();
    Expression write = node.write;
    if (write is StaticSet) {
      writeContext = write.target.setterType;
      writeMember = write.target;
      TypeInferenceEngine.resolveInferenceNode(writeMember);
    }
    DartType inferredType =
        node._inferRhs(inferrer, readType, writeContext).inferredType;
    node._replaceWithDesugared();
    return new ExpressionInferenceResult(inferredType);
  }

  @override
  ExpressionInferenceResult visitStaticGet(
      StaticGet node, DartType typeContext) {
    Member target = node.target;
    TypeInferenceEngine.resolveInferenceNode(target);
    DartType type = target.getterType;
    if (target is Procedure && target.kind == ProcedureKind.Method) {
      type = inferrer.instantiateTearOff(type, typeContext, node);
    }
    inferrer.storeInferredType(node, type);
    return new ExpressionInferenceResult(type);
  }

  @override
  ExpressionInferenceResult visitStaticInvocation(
      StaticInvocation node, DartType typeContext) {
    FunctionType calleeType = node.target != null
        ? node.target.function.functionType
        : new FunctionType([], const DynamicType());
    bool hadExplicitTypeArguments =
        getExplicitTypeArguments(node.arguments) != null;
    DartType inferredType = inferrer.inferInvocation(typeContext,
        node.fileOffset, calleeType, calleeType.returnType, node.arguments);
    inferrer.storeInferredType(node, inferredType);
    if (!inferrer.isTopLevel &&
        !hadExplicitTypeArguments &&
        node.target != null) {
      inferrer.library.checkBoundsInStaticInvocation(
          node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
          inferred: true);
    }
    return new ExpressionInferenceResult(inferredType);
  }

  @override
  ExpressionInferenceResult visitStringConcatenation(
      StringConcatenation node, DartType typeContext) {
    if (!inferrer.isTopLevel) {
      for (Expression expression in node.expressions) {
        inferrer.inferExpression(
            expression, const UnknownType(), !inferrer.isTopLevel);
      }
    }
    return new ExpressionInferenceResult(
        inferrer.coreTypes.stringClass.rawType);
  }

  @override
  ExpressionInferenceResult visitStringLiteral(
          StringLiteral node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.coreTypes.stringClass.rawType);

  void visitSuperInitializerJudgment(SuperInitializerJudgment node) {
    Substitution substitution = Substitution.fromSupertype(
        inferrer.classHierarchy.getClassAsInstanceOf(
            inferrer.thisType.classNode, node.target.enclosingClass));
    inferrer.inferInvocation(
        null,
        node.fileOffset,
        substitution.substituteType(
            node.target.function.functionType.withoutTypeParameters),
        inferrer.thisType,
        node.argumentJudgments,
        skipTypeArgumentInference: true);
  }

  ExpressionInferenceResult visitSuperMethodInvocationJudgment(
      SuperMethodInvocationJudgment node, DartType typeContext) {
    if (node.interfaceTarget != null) {
      inferrer.instrumentation?.record(inferrer.uri, node.fileOffset, 'target',
          new InstrumentationValueForMember(node.interfaceTarget));
    }
    ExpressionInferenceResult result = inferrer.inferMethodInvocation(
        node, null, node.fileOffset, false, typeContext,
        target: node.interfaceTarget != null
            ? new ObjectAccessTarget.interfaceMember(node.interfaceTarget)
            : const ObjectAccessTarget.unresolved(),
        methodName: node.name,
        arguments: node.arguments);
    node.inferredType = result.inferredType;
    return new ExpressionInferenceResult(result.inferredType);
  }

  ExpressionInferenceResult visitSuperPropertyGetJudgment(
      SuperPropertyGetJudgment node, DartType typeContext) {
    if (node.interfaceTarget != null) {
      inferrer.instrumentation?.record(inferrer.uri, node.fileOffset, 'target',
          new InstrumentationValueForMember(node.interfaceTarget));
    }
    return inferrer.inferPropertyGet(node, null, node.fileOffset, typeContext,
        readTarget: node.interfaceTarget != null
            ? new ObjectAccessTarget.interfaceMember(node.interfaceTarget)
            : const ObjectAccessTarget.unresolved(),
        propertyName: node.name);
  }

  void visitSwitchStatementJudgment(SwitchStatementJudgment node) {
    Expression expressionJudgment = node.expressionJudgment;
    inferrer.inferExpression(expressionJudgment, const UnknownType(), true);
    DartType expressionType = getInferredType(expressionJudgment, inferrer);

    for (SwitchCaseJudgment switchCase in node.caseJudgments) {
      for (Expression caseExpression in switchCase.expressionJudgments) {
        ExpressionInferenceResult caseExpressionResult =
            inferrer.inferExpression(caseExpression, expressionType, true);
        DartType caseExpressionType = caseExpressionResult.inferredType;

        // Check whether the expression type is assignable to the case
        // expression type.
        if (!inferrer.isAssignable(expressionType, caseExpressionType)) {
          inferrer.helper.addProblem(
              templateSwitchExpressionNotAssignable.withArguments(
                  expressionType, caseExpressionType),
              caseExpression.fileOffset,
              noLength,
              context: [
                messageSwitchExpressionNotAssignableCause.withLocation(
                    inferrer.uri, expressionJudgment.fileOffset, noLength)
              ]);
        }
      }
      inferrer.inferStatement(switchCase.body);
    }
  }

  ExpressionInferenceResult visitSymbolLiteralJudgment(
      SymbolLiteralJudgment node, DartType typeContext) {
    node.inferredType = inferrer.coreTypes.symbolClass.rawType;
    return new ExpressionInferenceResult(node.inferredType);
  }

  ExpressionInferenceResult visitInvalidConstructorInvocationJudgment(
      InvalidConstructorInvocationJudgment node, DartType typeContext) {
    FunctionType calleeType;
    DartType returnType;
    if (node.constructor != null) {
      calleeType = node.constructor.function.functionType;
      returnType = computeConstructorReturnType(node.constructor);
    } else {
      calleeType = new FunctionType([], const DynamicType());
      returnType = const DynamicType();
    }
    DartType inferredType = inferrer.inferInvocation(typeContext,
        node.fileOffset, calleeType, returnType, node.argumentJudgments);
    node.inferredType = inferredType;
    return visitSyntheticExpressionJudgment(node, typeContext);
  }

  ExpressionInferenceResult visitInvalidWriteJudgment(
      InvalidWriteJudgment node, DartType typeContext) {
    // When a compound assignment, the expression is already wrapping in
    // VariableDeclaration in _makeRead(). Otherwise, temporary associate
    // the expression with this node.
    node.expression.parent ??= node;

    inferrer.inferExpression(
        node.expression, const UnknownType(), !inferrer.isTopLevel);
    return visitSyntheticExpressionJudgment(node, typeContext);
  }

  ExpressionInferenceResult visitSyntheticExpressionJudgment(
      SyntheticExpressionJudgment node, DartType typeContext) {
    node._replaceWithDesugared();
    node.inferredType = const DynamicType();
    return const ExpressionInferenceResult(const DynamicType());
  }

  ExpressionInferenceResult visitThisExpression(
          ThisExpression node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.thisType);

  @override
  ExpressionInferenceResult visitThrow(Throw node, DartType typeContext) {
    inferrer.inferExpression(
        node.expression, const UnknownType(), !inferrer.isTopLevel);
    return const ExpressionInferenceResult(const BottomType());
  }

  void visitCatchJudgment(CatchJudgment node) {
    inferrer.inferStatement(node.body);
  }

  void visitTryCatchJudgment(TryCatchJudgment node) {
    inferrer.inferStatement(node.body);
    for (CatchJudgment catch_ in node.catchJudgments) {
      visitCatchJudgment(catch_);
    }
  }

  void visitTryFinallyJudgment(TryFinallyJudgment node) {
    inferrer.inferStatement(node.body);
    inferrer.inferStatement(node.finalizer);
  }

  ExpressionInferenceResult visitTypeLiteralJudgment(
      TypeLiteralJudgment node, DartType typeContext) {
    node.inferredType = inferrer.coreTypes.typeClass.rawType;
    return new ExpressionInferenceResult(node.inferredType);
  }

  ExpressionInferenceResult visitVariableAssignmentJudgment(
      VariableAssignmentJudgment node, DartType typeContext) {
    DartType readType;
    Expression read = node.read;
    if (read is VariableGet) {
      readType = read.promotedType ?? read.variable.type;
    }
    DartType writeContext = const UnknownType();
    Expression write = node.write;
    if (write is VariableSet) {
      writeContext = write.variable.type;
      if (read != null) {
        node._storeLetType(inferrer, read, writeContext);
      }
    }
    DartType inferredType =
        node._inferRhs(inferrer, readType, writeContext).inferredType;
    node._replaceWithDesugared();
    return new ExpressionInferenceResult(inferredType);
  }

  void visitVariableDeclarationJudgment(VariableDeclarationJudgment node) {
    Expression initializerJudgment = node.initializerJudgment;
    DartType declaredType =
        node._implicitlyTyped ? const UnknownType() : node.type;
    DartType inferredType;
    DartType initializerType;
    if (initializerJudgment != null) {
      ExpressionInferenceResult initializerResult = inferrer.inferExpression(
          initializerJudgment,
          declaredType,
          !inferrer.isTopLevel || node._implicitlyTyped,
          isVoidAllowed: true);
      initializerType = initializerResult.inferredType;
      inferredType = inferrer.inferDeclarationType(initializerType);
    } else {
      inferredType = const DynamicType();
    }
    if (node._implicitlyTyped) {
      inferrer.instrumentation?.record(inferrer.uri, node.fileOffset, 'type',
          new InstrumentationValueForType(inferredType));
      node.type = inferredType;
    }
    if (node.initializer != null) {
      Expression replacedInitializer = inferrer.ensureAssignable(
          node.type, initializerType, node.initializer, node.fileOffset,
          isVoidAllowed: node.type is VoidType);
      if (replacedInitializer != null) {
        node.initializer = replacedInitializer;
      }
    }
    if (!inferrer.isTopLevel) {
      SourceLibraryBuilder library = inferrer.library;
      if (node._implicitlyTyped) {
        library.checkBoundsInVariableDeclaration(
            node, inferrer.typeSchemaEnvironment, inferrer.helper.uri,
            inferred: true);
      }
    }
  }

  ExpressionInferenceResult visitUnresolvedTargetInvocationJudgment(
      UnresolvedTargetInvocationJudgment node, DartType typeContext) {
    ExpressionInferenceResult result =
        visitSyntheticExpressionJudgment(node, typeContext);
    inferrer.inferInvocation(
        typeContext,
        node.fileOffset,
        TypeInferrerImpl.unknownFunction,
        const DynamicType(),
        node.argumentsJudgment);
    return result;
  }

  ExpressionInferenceResult visitUnresolvedVariableAssignmentJudgment(
      UnresolvedVariableAssignmentJudgment node, DartType typeContext) {
    inferrer.inferExpression(node.rhs, const UnknownType(), true);
    node.inferredType = node.isCompound
        ? const DynamicType()
        : getInferredType(node.rhs, inferrer);
    return visitSyntheticExpressionJudgment(node, typeContext);
  }

  ExpressionInferenceResult visitVariableGetJudgment(
      VariableGetJudgment node, DartType typeContext) {
    VariableDeclarationJudgment variable = node.variable;
    bool mutatedInClosure = variable._mutatedInClosure;
    DartType declaredOrInferredType = variable.type;

    DartType promotedType = inferrer.typePromoter
        .computePromotedType(node._fact, node._scope, mutatedInClosure);
    if (promotedType != null) {
      inferrer.instrumentation?.record(inferrer.uri, node.fileOffset,
          'promotedType', new InstrumentationValueForType(promotedType));
    }
    node.promotedType = promotedType;
    DartType type = promotedType ?? declaredOrInferredType;
    if (variable._isLocalFunction) {
      type = inferrer.instantiateTearOff(type, typeContext, node);
    }
    node.inferredType = type;
    return new ExpressionInferenceResult(type);
  }

  void visitWhileJudgment(WhileJudgment node) {
    Expression conditionJudgment = node.conditionJudgment;
    InterfaceType expectedType = inferrer.coreTypes.boolClass.rawType;
    inferrer.inferExpression(
        conditionJudgment, expectedType, !inferrer.isTopLevel);
    inferrer.ensureAssignable(
        expectedType,
        getInferredType(conditionJudgment, inferrer),
        node.condition,
        node.condition.fileOffset);
    inferrer.inferStatement(node.body);
  }

  void visitYieldJudgment(YieldJudgment node) {
    Expression judgment = node.judgment;
    ClosureContext closureContext = inferrer.closureContext;
    if (closureContext.isGenerator) {
      DartType typeContext = closureContext.returnOrYieldContext;
      if (node.isYieldStar && typeContext != null) {
        typeContext = inferrer.wrapType(
            typeContext,
            closureContext.isAsync
                ? inferrer.coreTypes.streamClass
                : inferrer.coreTypes.iterableClass);
      }
      inferrer.inferExpression(judgment, typeContext, true);
    } else {
      inferrer.inferExpression(judgment, const UnknownType(), true);
    }
    closureContext.handleYield(inferrer, node.isYieldStar,
        getInferredType(judgment, inferrer), node.expression, node.fileOffset);
  }

  ExpressionInferenceResult visitLoadLibraryJudgment(
      LoadLibraryJudgment node, DartType typeContext) {
    node.inferredType =
        inferrer.typeSchemaEnvironment.futureType(const DynamicType());
    if (node.arguments != null) {
      FunctionType calleeType = new FunctionType([], node.inferredType);
      inferrer.inferInvocation(typeContext, node.fileOffset, calleeType,
          calleeType.returnType, node.argumentJudgments);
    }
    return new ExpressionInferenceResult(node.inferredType);
  }

  ExpressionInferenceResult visitLoadLibraryTearOffJudgment(
      LoadLibraryTearOffJudgment node, DartType typeContext) {
    node.inferredType = new FunctionType(
        [], inferrer.typeSchemaEnvironment.futureType(const DynamicType()));
    return new ExpressionInferenceResult(node.inferredType);
  }

  @override
  ExpressionInferenceResult visitCheckLibraryIsLoaded(
          CheckLibraryIsLoaded node, DartType typeContext) =>
      new ExpressionInferenceResult(inferrer.coreTypes.objectClass.rawType);
}
