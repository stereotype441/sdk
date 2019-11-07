// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library kernel.type_environment;

import 'ast.dart';
import 'class_hierarchy.dart';
import 'core_types.dart';
import 'type_algebra.dart';

import 'src/future_or.dart';
import 'src/hierarchy_based_type_environment.dart'
    show HierarchyBasedTypeEnvironment;

typedef void ErrorHandler(TreeNode node, String message);

abstract class TypeEnvironment extends SubtypeTester {
  final CoreTypes coreTypes;

  InterfaceType thisType;

  DartType returnType;
  DartType yieldType;
  AsyncMarker currentAsyncMarker = AsyncMarker.Sync;

  /// An error handler for use in debugging, or `null` if type errors should not
  /// be tolerated.  See [typeError].
  ErrorHandler errorHandler;

  TypeEnvironment.fromSubclass(this.coreTypes);

  factory TypeEnvironment(CoreTypes coreTypes, ClassHierarchy hierarchy) {
    return new HierarchyBasedTypeEnvironment(coreTypes, hierarchy);
  }

  Class get intClass => coreTypes.intClass;
  Class get numClass => coreTypes.numClass;
  Class get functionClass => coreTypes.functionClass;
  Class get futureOrClass => coreTypes.futureOrClass;
  Class get objectClass => coreTypes.objectClass;

  InterfaceType get objectLegacyRawType => coreTypes.objectLegacyRawType;
  InterfaceType get objectNullableRawType => coreTypes.objectNullableRawType;
  InterfaceType get nullType => coreTypes.nullType;
  InterfaceType get functionLegacyRawType => coreTypes.functionLegacyRawType;

  InterfaceType literalListType(DartType elementType) {
    return new InterfaceType(
        coreTypes.listClass, Nullability.legacy, <DartType>[elementType]);
  }

  InterfaceType literalSetType(DartType elementType) {
    return new InterfaceType(
        coreTypes.setClass, Nullability.legacy, <DartType>[elementType]);
  }

  InterfaceType literalMapType(DartType key, DartType value) {
    return new InterfaceType(
        coreTypes.mapClass, Nullability.legacy, <DartType>[key, value]);
  }

  InterfaceType iterableType(DartType type) {
    return new InterfaceType(
        coreTypes.iterableClass, Nullability.legacy, <DartType>[type]);
  }

  InterfaceType streamType(DartType type) {
    return new InterfaceType(
        coreTypes.streamClass, Nullability.legacy, <DartType>[type]);
  }

  InterfaceType futureType(DartType type,
      [Nullability nullability = Nullability.legacy]) {
    return new InterfaceType(
        coreTypes.futureClass, nullability, <DartType>[type]);
  }

  /// Removes a level of `Future<>` types wrapping a type.
  ///
  /// This implements the function `flatten` from the spec, which unwraps a
  /// layer of Future or FutureOr from a type.
  DartType unfutureType(DartType type) {
    if (type is InterfaceType) {
      if (type.classNode == coreTypes.futureOrClass ||
          type.classNode == coreTypes.futureClass) {
        return type.typeArguments[0];
      }
      // It is a compile-time error to implement, extend, or mixin FutureOr so
      // we aren't concerned with it.  If a class implements multiple
      // instantiations of Future, getTypeAsInstanceOf is responsible for
      // picking the least one in the sense required by the spec.
      InterfaceType future = getTypeAsInstanceOf(type, coreTypes.futureClass);
      if (future != null) {
        return future.typeArguments[0];
      }
    }
    return type;
  }

  /// Called if the computation of a static type failed due to a type error.
  ///
  /// This should never happen in production.  The frontend should report type
  /// errors, and either recover from the error during translation or abort
  /// compilation if unable to recover.
  ///
  /// By default, this throws an exception, since programs in kernel are assumed
  /// to be correctly typed.
  ///
  /// An [errorHandler] may be provided in order to override the default
  /// behavior and tolerate the presence of type errors.  This can be useful for
  /// debugging IR producers which are required to produce a strongly typed IR.
  void typeError(TreeNode node, String message) {
    if (errorHandler != null) {
      errorHandler(node, message);
    } else {
      throw '$message in $node';
    }
  }

  /// True if [member] is a binary operator that returns an `int` if both
  /// operands are `int`, and otherwise returns `double`.
  ///
  /// This is a case of type-based overloading, which in Dart is only supported
  /// by giving special treatment to certain arithmetic operators.
  bool isOverloadedArithmeticOperator(Procedure member) {
    Class class_ = member.enclosingClass;
    if (class_ == coreTypes.intClass || class_ == coreTypes.numClass) {
      String name = member.name.name;
      return name == '+' ||
          name == '-' ||
          name == '*' ||
          name == 'remainder' ||
          name == '%';
    }
    return false;
  }

  /// Returns the static return type of an overloaded arithmetic operator
  /// (see [isOverloadedArithmeticOperator]) given the static type of the
  /// operands.
  ///
  /// If both types are `int`, the returned type is `int`.
  /// If either type is `double`, the returned type is `double`.
  /// If both types refer to the same type variable (typically with `num` as
  /// the upper bound), then that type variable is returned.
  /// Otherwise `num` is returned.
  DartType getTypeOfOverloadedArithmetic(DartType type1, DartType type2) {
    if (type1 == type2) return type1;

    if (type1 is InterfaceType && type2 is InterfaceType) {
      if (type1.classNode == type2.classNode) {
        return type1;
      }
      if (type1.classNode == coreTypes.doubleClass ||
          type2.classNode == coreTypes.doubleClass) {
        return coreTypes.doubleRawType(type1.nullability);
      }
    }

    return coreTypes.numRawType(type1.nullability);
  }
}

/// Tri-state logical result of a nullability-aware subtype check.
class IsSubtypeOf {
  /// Internal value constructed via [IsSubtypeOf.never].
  ///
  /// The integer values of [_valueNever], [_valueOnlyIfIgnoringNullabilities],
  /// and [_valueAlways] are important for the implementations of [_andValues],
  /// [_all], and [and].  They should be kept in sync.
  static const int _valueNever = 0;

  /// Internal value constructed via [IsSubtypeOf.onlyIfIgnoringNullabilities].
  static const int _valueOnlyIfIgnoringNullabilities = 1;

  /// Internal value constructed via [IsSubtypeOf.always].
  static const int _valueAlways = 3;

  static const List<IsSubtypeOf> _all = const <IsSubtypeOf>[
    const IsSubtypeOf.never(),
    const IsSubtypeOf.onlyIfIgnoringNullabilities(),
    null, // Deliberately left empty because there's no index value for that.
    const IsSubtypeOf.always()
  ];

  /// Combines results of subtype checks on parts into the overall result.
  ///
  /// It's an implementation detail for [and].  See the comment on [and] for
  /// more details and examples.  Both [value1] and [value2] should be chosen
  /// from [_valueNever], [_valueOnlyIfIgnoringNullabilities], and
  /// [_valueAlways].  The method produces the result which is one of
  /// [_valueNever], [_valueOnlyIfIgnoringNullabilities], and [_valueAlways].
  static int _andValues(int value1, int value2) => value1 & value2;

  /// Combines results of the checks on alternatives into the overall result.
  ///
  /// It's an implementation detail for [or].  See the comment on [or] for more
  /// details and examples.  Both [value1] and [value2] should be chosen from
  /// [_valueNever], [_valueOnlyIfIgnoringNullabilities], and [_valueAlways].
  /// The method produces the result which is one of [_valueNever],
  /// [_valueOnlyIfIgnoringNullabilities], and [_valueAlways].
  static int _orValues(int value1, int value2) => value1 | value2;

  /// The only state of an [IsSubtypeOf] object.
  final int _value;

  const IsSubtypeOf._internal(int value) : _value = value;

  /// Subtype check succeeds in both modes.
  const IsSubtypeOf.always() : this._internal(_valueAlways);

  /// Subtype check succeeds only if the nullability markers are ignored.
  ///
  /// It is assumed that if a subtype check succeeds for two types in full-NNBD
  /// mode, it also succeeds for those two types if the nullability markers on
  /// the types and all of their sub-terms are ignored (that is, in the pre-NNBD
  /// mode).  By contraposition, if a subtype check fails for two types when the
  /// nullability markers are ignored, it should also fail for those types in
  /// full-NNBD mode.
  const IsSubtypeOf.onlyIfIgnoringNullabilities()
      : this._internal(_valueOnlyIfIgnoringNullabilities);

  /// Subtype check fails in both modes.
  const IsSubtypeOf.never() : this._internal(_valueNever);

  /// Checks if two types are in relation based solely on their nullabilities.
  ///
  /// This is useful on its own if the types are known to be the same modulo the
  /// nullability attribute, but mostly it's useful to combine the result from
  /// [IsSubtypeOf.basedSolelyOnNullabilities] via [and] with the partial
  /// results obtained from other type parts. For example, the overall result
  /// for `List<int>? <: List<num>*` can be computed as `Ra.join(Rn)` where `Ra`
  /// is the result of a subtype check on the arguments `int` and `num`, and
  /// `Rn` is the result of [IsSubtypeOf.basedSolelyOnNullabilities] on the
  /// types `List<int>?` and `List<num>*`.
  factory IsSubtypeOf.basedSolelyOnNullabilities(
      DartType subtype, DartType supertype) {
    if (subtype.isPotentiallyNullable && supertype.isPotentiallyNonNullable) {
      return const IsSubtypeOf.onlyIfIgnoringNullabilities();
    }
    return const IsSubtypeOf.always();
  }

  /// Combines results for the type parts into the overall result for the type.
  ///
  /// For example, the result of `A<B1, C1> <: A<B2, C2>` can be computed from
  /// the results of the checks `B1 <: B2` and `C1 <: C2`.  Using the binary
  /// outcome of the checks, the combination of the check results on parts is
  /// simply done via `&&`, and [and] is the analog to `&&` for the ternary
  /// outcome.  So, in the example above the overall result is computed as
  /// `Rb.and(Rc)` where `Rb` is the result of `B1 <: B2`, `Rc` is the result
  /// of `C1 <: C2`.
  IsSubtypeOf and(IsSubtypeOf other) {
    return _all[_andValues(_value, other._value)];
  }

  /// Shorts the computation of [and] if `this` is [IsSubtypeOf.never].
  ///
  /// Use this instead of [and] for optimization in case the argument to [and]
  /// is, for example, a potentially expensive subtype check.  Unlike [and],
  /// [andSubtypeCheckFor] will immediately return if `this` was constructed as
  /// [IsSubtypeOf.never] because the right-hand side will not change the
  /// overall result anyway.
  IsSubtypeOf andSubtypeCheckFor(
      DartType subtype, DartType supertype, SubtypeTester tester) {
    if (_value == _valueNever) return this;
    return this
        .and(tester.performNullabilityAwareSubtypeCheck(subtype, supertype));
  }

  /// Combines results of the checks on alternatives into the overall result.
  ///
  /// For example, the result of `T <: FutureOr<S>` can be computed from the
  /// results of the checks `T <: S` and `T <: Future<S>`.  Using the binary
  /// outcome of the checks, the combination of the check results on parts is
  /// simply done via logical "or", and [or] is the analog to "or" for the
  /// ternary outcome.  So, in the example above the overall result is computed
  /// as `Rs.or(Rf)` where `Rs` is the result of `T <: S`, `Rf` is the result of
  /// `T <: Future<S>`.
  IsSubtypeOf or(IsSubtypeOf other) {
    return _all[_orValues(_value, other._value)];
  }

  /// Shorts the computation of [or] if `this` is [IsSubtypeOf.always].
  ///
  /// Use this instead of [or] for optimization in case the argument to [or] is,
  /// for example, a potentially expensive subtype check.  Unlike [or],
  /// [orSubtypeCheckFor] will immediately return if `this` was constructed
  /// as [IsSubtypeOf.always] because the right-hand side will not change the
  /// overall result anyway.
  IsSubtypeOf orSubtypeCheckFor(
      DartType subtype, DartType supertype, SubtypeTester tester) {
    if (_value == _valueAlways) return this;
    return this
        .or(tester.performNullabilityAwareSubtypeCheck(subtype, supertype));
  }

  bool isSubtypeWhenIgnoringNullabilities() {
    return _value != _valueNever;
  }

  bool isSubtypeWhenUsingNullabilities() {
    return _value == _valueAlways;
  }

  String toString() {
    switch (_value) {
      case _valueAlways:
        return "IsSubtypeOf.always";
      case _valueNever:
        return "IsSubtypeOf.never";
      case _valueOnlyIfIgnoringNullabilities:
        return "IsSubtypeOf.onlyIfIgnoringNullabilities";
    }
    return "IsSubtypeOf.<unknown value '${_value}'>";
  }
}

enum SubtypeCheckMode {
  withNullabilities,
  ignoringNullabilities,
}

/// The part of [TypeEnvironment] that deals with subtype tests.
///
/// This lives in a separate class so it can be tested independently of the SDK.
abstract class SubtypeTester {
  InterfaceType get objectLegacyRawType;
  InterfaceType get objectNullableRawType;
  InterfaceType get nullType;
  InterfaceType get functionLegacyRawType;
  Class get objectClass;
  Class get functionClass;
  Class get futureOrClass;
  InterfaceType futureType(DartType type,
      [Nullability nullability = Nullability.legacy]);

  static List<Object> typeChecks;

  InterfaceType getTypeAsInstanceOf(InterfaceType type, Class superclass);

  /// Determines if the given type is at the top of the type hierarchy.  May be
  /// overridden in subclasses.
  bool isTop(DartType type) {
    return type is DynamicType ||
        type is VoidType ||
        type == objectLegacyRawType ||
        type == objectNullableRawType;
  }

  /// Can be use to collect type checks. To use:
  /// 1. Rename `isSubtypeOf` to `_isSubtypeOf`.
  /// 2. Rename `_collect_isSubtypeOf` to `isSubtypeOf`.
  /// 3. Comment out the call to `_isSubtypeOf` below.
  // ignore:unused_element
  bool _collect_isSubtypeOf(
      DartType subtype, DartType supertype, SubtypeCheckMode mode) {
    bool result = true;
    //result = _isSubtypeOf(subtype, supertype, mode);
    typeChecks ??= <Object>[];
    typeChecks.add([subtype, supertype, result]);
    return result;
  }

  /// Returns true if [subtype] is a subtype of [supertype].
  bool isSubtypeOf(
      DartType subtype, DartType supertype, SubtypeCheckMode mode) {
    IsSubtypeOf result =
        performNullabilityAwareSubtypeCheck(subtype, supertype);
    switch (mode) {
      case SubtypeCheckMode.ignoringNullabilities:
        return result.isSubtypeWhenIgnoringNullabilities();
      case SubtypeCheckMode.withNullabilities:
        return result.isSubtypeWhenUsingNullabilities();
      default:
        throw new StateError("Unhandled subtype checking mode '$mode'");
    }
  }

  /// Performs a nullability-aware subtype check.
  ///
  /// The outcome is described in the comments to [IsSubtypeOf].
  IsSubtypeOf performNullabilityAwareSubtypeCheck(
      DartType subtype, DartType supertype) {
    subtype = subtype.unalias;
    supertype = supertype.unalias;
    if (identical(subtype, supertype)) return const IsSubtypeOf.always();
    if (subtype is BottomType) return const IsSubtypeOf.always();
    if (subtype is NeverType) {
      return supertype is BottomType
          ? const IsSubtypeOf.never()
          : new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype);
    }
    if (subtype == nullType) {
      // TODO(dmitryas): Remove InvalidType from subtype relation.
      if (supertype is InvalidType) {
        // The return value is supposed to keep the backward compatibility.
        return const IsSubtypeOf.always();
      }

      Nullability supertypeNullability =
          computeNullability(supertype, futureOrClass);
      if (supertypeNullability == Nullability.nullable ||
          supertypeNullability == Nullability.legacy) {
        return const IsSubtypeOf.always();
      }
      // See rule 4 of the subtype rules from the Dart Language Specification.
      return supertype is BottomType || supertype is NeverType
          ? const IsSubtypeOf.never()
          : const IsSubtypeOf.onlyIfIgnoringNullabilities();
    }
    if (isTop(supertype)) return const IsSubtypeOf.always();

    // Handle FutureOr<T> union type.
    if (subtype is InterfaceType &&
        identical(subtype.classNode, futureOrClass)) {
      var subtypeArg = subtype.typeArguments[0];
      if (supertype is InterfaceType &&
          identical(supertype.classNode, futureOrClass)) {
        var supertypeArg = supertype.typeArguments[0];
        // FutureOr<A> <: FutureOr<B> iff A <: B
        return performNullabilityAwareSubtypeCheck(subtypeArg, supertypeArg);
      }

      // given t1 is Future<A> | A, then:
      // (Future<A> | A) <: t2 iff Future<A> <: t2 and A <: t2.
      return performNullabilityAwareSubtypeCheck(subtypeArg, supertype)
          .andSubtypeCheckFor(
              futureType(subtypeArg, Nullability.nonNullable), supertype, this)
          .and(new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype));
    }

    if (supertype is InterfaceType && supertype.classNode == objectClass) {
      assert(supertype.nullability == Nullability.nonNullable);
      return new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype);
    }

    if (supertype is InterfaceType &&
        identical(supertype.classNode, futureOrClass)) {
      // given t2 is Future<A> | A, then:
      // t1 <: (Future<A> | A) iff t1 <: Future<A> or t1 <: A
      Nullability unitedNullability =
          computeNullabilityOfFutureOr(supertype, futureOrClass);
      DartType supertypeArg = supertype.typeArguments[0];
      DartType supertypeFuture = futureType(supertypeArg, unitedNullability);
      return performNullabilityAwareSubtypeCheck(subtype, supertypeFuture)
          .orSubtypeCheckFor(
              subtype, supertypeArg.withNullability(unitedNullability), this);
    }

    if (subtype is InterfaceType && supertype is InterfaceType) {
      var upcastType = getTypeAsInstanceOf(subtype, supertype.classNode);
      if (upcastType == null) return const IsSubtypeOf.never();
      IsSubtypeOf result = const IsSubtypeOf.always();
      for (int i = 0; i < upcastType.typeArguments.length; ++i) {
        // Termination: the 'supertype' parameter decreases in size.
        int variance = upcastType.classNode.typeParameters[i].variance;
        DartType leftType = upcastType.typeArguments[i];
        DartType rightType = supertype.typeArguments[i];
        if (variance == Variance.contravariant) {
          result = result
              .and(performNullabilityAwareSubtypeCheck(rightType, leftType));
          if (!result.isSubtypeWhenIgnoringNullabilities()) {
            return const IsSubtypeOf.never();
          }
        } else if (variance == Variance.invariant) {
          result = result.and(
              performNullabilityAwareMutualSubtypesCheck(leftType, rightType));
          if (!result.isSubtypeWhenIgnoringNullabilities()) {
            return const IsSubtypeOf.never();
          }
        } else {
          result = result
              .and(performNullabilityAwareSubtypeCheck(leftType, rightType));
          if (!result.isSubtypeWhenIgnoringNullabilities()) {
            return const IsSubtypeOf.never();
          }
        }
      }
      return result
          .and(new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype));
    }
    if (subtype is TypeParameterType) {
      if (supertype is TypeParameterType) {
        IsSubtypeOf result = const IsSubtypeOf.always();
        if (subtype.parameter == supertype.parameter) {
          if (supertype.promotedBound != null) {
            return performNullabilityAwareSubtypeCheck(
                    subtype,
                    new TypeParameterType(supertype.parameter,
                        supertype.typeParameterTypeNullability))
                .andSubtypeCheckFor(subtype, supertype.bound, this);
          } else {
            // Promoted bound should always be a subtype of the declared bound.
            // TODO(dmitryas): Use the following assertion when type promotion
            // is updated.
            // assert(subtype.promotedBound == null ||
            //     performNullabilityAwareSubtypeCheck(
            //         subtype.bound, supertype.bound)
            //         .isSubtypeWhenUsingNullabilities());
            assert(subtype.promotedBound == null ||
                performNullabilityAwareSubtypeCheck(
                        subtype.bound, supertype.bound)
                    .isSubtypeWhenIgnoringNullabilities());
            result = const IsSubtypeOf.always();
          }
        } else {
          result =
              performNullabilityAwareSubtypeCheck(subtype.bound, supertype);
        }
        if (subtype.nullability == Nullability.undetermined &&
            supertype.nullability == Nullability.undetermined) {
          // The two nullabilities are undetermined, but are connected via
          // additional constraint, namely that they will be equal at run time.
          return result;
        }
        return result.and(
            new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype));
      }
      // Termination: if there are no cyclically bound type parameters, this
      // recursive call can only occur a finite number of times, before reaching
      // a shrinking recursive call (or terminating).
      return performNullabilityAwareSubtypeCheck(subtype.bound, supertype)
          .and(new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype));
    }
    if (subtype is FunctionType) {
      if (supertype is InterfaceType && supertype.classNode == functionClass) {
        return new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype);
      }
      if (supertype is FunctionType) {
        return _performNullabilityAwareFunctionSubtypeCheck(subtype, supertype);
      }
    }
    return const IsSubtypeOf.never();
  }

  IsSubtypeOf performNullabilityAwareMutualSubtypesCheck(
      DartType type1, DartType type2) {
    // TODO(dmitryas): Replace it with one recursive descent instead of two.
    return performNullabilityAwareSubtypeCheck(type1, type2)
        .andSubtypeCheckFor(type2, type1, this);
  }

  IsSubtypeOf _performNullabilityAwareFunctionSubtypeCheck(
      FunctionType subtype, FunctionType supertype) {
    if (subtype.requiredParameterCount > supertype.requiredParameterCount) {
      return const IsSubtypeOf.never();
    }
    if (subtype.positionalParameters.length <
        supertype.positionalParameters.length) {
      return const IsSubtypeOf.never();
    }
    if (subtype.typeParameters.length != supertype.typeParameters.length) {
      return const IsSubtypeOf.never();
    }

    IsSubtypeOf result = const IsSubtypeOf.always();
    if (subtype.typeParameters.isNotEmpty) {
      var substitution = <TypeParameter, DartType>{};
      for (int i = 0; i < subtype.typeParameters.length; ++i) {
        var subParameter = subtype.typeParameters[i];
        var superParameter = supertype.typeParameters[i];
        substitution[subParameter] =
            new TypeParameterType(superParameter, Nullability.legacy);
      }
      for (int i = 0; i < subtype.typeParameters.length; ++i) {
        var subParameter = subtype.typeParameters[i];
        var superParameter = supertype.typeParameters[i];
        var subBound = substitute(subParameter.bound, substitution);
        // Termination: if there are no cyclically bound type parameters, this
        // recursive call can only occur a finite number of times before
        // reaching a shrinking recursive call (or terminating).
        result = result.and(performNullabilityAwareMutualSubtypesCheck(
            superParameter.bound, subBound));
        if (!result.isSubtypeWhenIgnoringNullabilities()) {
          return const IsSubtypeOf.never();
        }
      }
      subtype = substitute(subtype.withoutTypeParameters, substitution);
    }
    result = result.and(performNullabilityAwareSubtypeCheck(
        subtype.returnType, supertype.returnType));
    if (!result.isSubtypeWhenIgnoringNullabilities()) {
      return const IsSubtypeOf.never();
    }
    for (int i = 0; i < supertype.positionalParameters.length; ++i) {
      var supertypeParameter = supertype.positionalParameters[i];
      var subtypeParameter = subtype.positionalParameters[i];
      // Termination: Both types shrink in size.
      result = result.and(performNullabilityAwareSubtypeCheck(
          supertypeParameter, subtypeParameter));
      if (!result.isSubtypeWhenIgnoringNullabilities()) {
        return const IsSubtypeOf.never();
      }
    }
    int subtypeNameIndex = 0;
    for (NamedType supertypeParameter in supertype.namedParameters) {
      while (subtypeNameIndex < subtype.namedParameters.length &&
          subtype.namedParameters[subtypeNameIndex].name !=
              supertypeParameter.name) {
        ++subtypeNameIndex;
      }
      if (subtypeNameIndex == subtype.namedParameters.length) {
        return const IsSubtypeOf.never();
      }
      NamedType subtypeParameter = subtype.namedParameters[subtypeNameIndex];
      // Termination: Both types shrink in size.
      result = result.and(performNullabilityAwareSubtypeCheck(
          supertypeParameter.type, subtypeParameter.type));
      if (!result.isSubtypeWhenIgnoringNullabilities()) {
        return const IsSubtypeOf.never();
      }
    }
    return result
        .and(new IsSubtypeOf.basedSolelyOnNullabilities(subtype, supertype));
  }
}
