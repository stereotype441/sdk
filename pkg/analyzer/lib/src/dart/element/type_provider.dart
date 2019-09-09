// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/constant/value.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart';

/// Provide common functionality shared by the various TypeProvider
/// implementations.
abstract class TypeProviderBase implements TypeProvider {
  @override
  List<InterfaceType> get nonSubtypableTypes => <InterfaceType>[
        boolType,
        doubleType,
        intType,
        nullType,
        numType,
        stringType
      ];

  @override
  bool isObjectGetter(String id) {
    PropertyAccessorElement element = objectType.element.getGetter(id);
    return (element != null && !element.isStatic);
  }

  @override
  bool isObjectMember(String id) {
    return isObjectGetter(id) || isObjectMethod(id);
  }

  @override
  bool isObjectMethod(String id) {
    MethodElement element = objectType.element.getMethod(id);
    return (element != null && !element.isStatic);
  }
}

class TypeProviderImpl extends TypeProviderBase {
  final NullabilitySuffix _nullabilitySuffix;
  final LibraryElement _coreLibrary;
  final LibraryElement _asyncLibrary;

  InterfaceType _boolType;
  InterfaceType _deprecatedType;
  InterfaceType _doubleType;
  InterfaceType _functionType;
  InterfaceType _futureDynamicType;
  InterfaceType _futureNullType;
  InterfaceType _futureOrNullType;
  InterfaceType _futureOrType;
  InterfaceType _futureType;
  InterfaceType _intType;
  InterfaceType _iterableDynamicType;
  InterfaceType _iterableObjectType;
  InterfaceType _iterableType;
  InterfaceType _listType;
  InterfaceType _mapType;
  InterfaceType _mapObjectObjectType;
  DartObjectImpl _nullObject;
  InterfaceType _nullType;
  InterfaceType _numType;
  InterfaceType _objectType;
  InterfaceType _setType;
  InterfaceType _stackTraceType;
  InterfaceType _streamDynamicType;
  InterfaceType _streamType;
  InterfaceType _stringType;
  InterfaceType _symbolType;
  InterfaceType _typeType;

  /// Initialize a newly created type provider to provide the types defined in
  /// the given [coreLibrary] and [asyncLibrary].
  TypeProviderImpl(
    LibraryElement coreLibrary,
    LibraryElement asyncLibrary, {
    NullabilitySuffix nullabilitySuffix = NullabilitySuffix.star,
  })  : _nullabilitySuffix = nullabilitySuffix,
        _coreLibrary = coreLibrary,
        _asyncLibrary = asyncLibrary;

  @override
  InterfaceType get boolType {
    _boolType ??= _getType(_coreLibrary, "bool");
    return _boolType;
  }

  @override
  DartType get bottomType {
    if (_nullabilitySuffix == NullabilitySuffix.none) {
      return BottomTypeImpl.instance;
    }
    return BottomTypeImpl.instanceLegacy;
  }

  @override
  InterfaceType get deprecatedType {
    _deprecatedType ??= _getType(_coreLibrary, "Deprecated");
    return _deprecatedType;
  }

  @override
  InterfaceType get doubleType {
    _doubleType ??= _getType(_coreLibrary, "double");
    return _doubleType;
  }

  @override
  DartType get dynamicType => DynamicTypeImpl.instance;

  @override
  InterfaceType get functionType {
    _functionType ??= _getType(_coreLibrary, "Function");
    return _functionType;
  }

  @override
  InterfaceType get futureDynamicType {
    _futureDynamicType ??= futureType.instantiate(<DartType>[dynamicType]);
    return _futureDynamicType;
  }

  @override
  InterfaceType get futureNullType {
    _futureNullType ??= futureType.instantiate(<DartType>[nullType]);
    return _futureNullType;
  }

  @override
  InterfaceType get futureOrNullType {
    _futureOrNullType ??= futureOrType.instantiate(<DartType>[nullType]);
    return _futureOrNullType;
  }

  @override
  InterfaceType get futureOrType {
    _futureOrType ??= _getType(_asyncLibrary, "FutureOr");
    return _futureOrType;
  }

  @override
  InterfaceType get futureType {
    _futureType ??= _getType(_asyncLibrary, "Future");
    return _futureType;
  }

  @override
  InterfaceType get intType {
    _intType ??= _getType(_coreLibrary, "int");
    return _intType;
  }

  @override
  InterfaceType get iterableDynamicType {
    _iterableDynamicType ??= iterableType.instantiate(<DartType>[dynamicType]);
    return _iterableDynamicType;
  }

  @override
  InterfaceType get iterableObjectType {
    _iterableObjectType ??= iterableType.instantiate(<DartType>[objectType]);
    return _iterableObjectType;
  }

  @override
  InterfaceType get iterableType {
    _iterableType ??= _getType(_coreLibrary, "Iterable");
    return _iterableType;
  }

  @override
  InterfaceType get listType {
    _listType ??= _getType(_coreLibrary, "List");
    return _listType;
  }

  @override
  InterfaceType get mapObjectObjectType {
    return _mapObjectObjectType ??=
        mapType.instantiate(<DartType>[objectType, objectType]);
  }

  @override
  InterfaceType get mapType {
    _mapType ??= _getType(_coreLibrary, "Map");
    return _mapType;
  }

  @override
  DartType get neverType => BottomTypeImpl.instance;

  @override
  DartObjectImpl get nullObject {
    if (_nullObject == null) {
      _nullObject = new DartObjectImpl(nullType, NullState.NULL_STATE);
    }
    return _nullObject;
  }

  @override
  InterfaceType get nullType {
    _nullType ??= _getType(_coreLibrary, "Null");
    return _nullType;
  }

  @override
  InterfaceType get numType {
    _numType ??= _getType(_coreLibrary, "num");
    return _numType;
  }

  @override
  InterfaceType get objectType {
    _objectType ??= _getType(_coreLibrary, "Object");
    return _objectType;
  }

  @override
  InterfaceType get setType {
    return _setType ??= _getType(_coreLibrary, "Set");
  }

  @override
  InterfaceType get stackTraceType {
    _stackTraceType ??= _getType(_coreLibrary, "StackTrace");
    return _stackTraceType;
  }

  @override
  InterfaceType get streamDynamicType {
    _streamDynamicType ??= streamType.instantiate(<DartType>[dynamicType]);
    return _streamDynamicType;
  }

  @override
  InterfaceType get streamType {
    _streamType ??= _getType(_asyncLibrary, "Stream");
    return _streamType;
  }

  @override
  InterfaceType get stringType {
    _stringType ??= _getType(_coreLibrary, "String");
    return _stringType;
  }

  @override
  InterfaceType get symbolType {
    _symbolType ??= _getType(_coreLibrary, "Symbol");
    return _symbolType;
  }

  @override
  InterfaceType get typeType {
    _typeType ??= _getType(_coreLibrary, "Type");
    return _typeType;
  }

  @override
  VoidType get voidType => VoidTypeImpl.instance;

  TypeProviderImpl withNullability(NullabilitySuffix nullabilitySuffix) {
    if (_nullabilitySuffix == nullabilitySuffix) {
      return this;
    }
    return TypeProviderImpl(_coreLibrary, _asyncLibrary,
        nullabilitySuffix: nullabilitySuffix);
  }

  /// Return the type with the given [name] from the given [library], or
  /// throw a [StateError] if there is no class with the given name.
  InterfaceType _getType(LibraryElement library, String name) {
    var element = library.getType(name);
    if (element == null) {
      throw StateError('No definition of type $name');
    }

    var typeArguments = const <DartType>[];
    var typeParameters = element.typeParameters;
    if (typeParameters.isNotEmpty) {
      typeArguments = typeParameters.map((e) {
        return TypeParameterTypeImpl(
          e,
          nullabilitySuffix: _nullabilitySuffix,
        );
      }).toList(growable: false);
    }

    return InterfaceTypeImpl.explicit(
      element,
      typeArguments,
      nullabilitySuffix: _nullabilitySuffix,
    );
  }
}
