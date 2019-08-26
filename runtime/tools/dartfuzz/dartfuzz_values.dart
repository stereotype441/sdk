// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Class that represents some common Dart types.
///
/// TODO(ajcbik): generalize Dart types
///
class DartType {
  final String name;

  const DartType._withName(this.name);

  static const VOID = const DartType._withName('void');
  static const BOOL = const DartType._withName('bool');
  static const INT = const DartType._withName('int');
  static const DOUBLE = const DartType._withName('double');
  static const STRING = const DartType._withName('String');
  static const INT_LIST = const DartType._withName('List<int>');
  static const INT_SET = const DartType._withName('Set<int>');
  static const INT_STRING_MAP = const DartType._withName('Map<int, String>');

  // All value types.
  static const allTypes = [
    BOOL,
    INT,
    DOUBLE,
    STRING,
    INT_LIST,
    INT_SET,
    INT_STRING_MAP
  ];
}

/// Class with interesting values for fuzzing.
class DartFuzzValues {
  // Interesting characters.
  static const List<String> interestingChars = [
    '\\u2665',
    '\\u{1f600}', // rune
  ];

  // Regular characters.
  static const regularChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#&()+- ';

  // Interesting integer values.
  static const List<int> interestingIntegers = [
    0x0000000000000000,
    0x0000000000000001,
    0x0000000000000010,
    0x0000000000000020,
    0x0000000000000040,
    0x0000000000000064,
    0x000000000000007f,
    0x0000000000000080,
    0x0000000000000081,
    0x00000000000000ff,
    0x0000000000000100,
    0x0000000000000200,
    0x00000000000003e8,
    0x0000000000000400,
    0x0000000000001000,
    0x0000000000007fff,
    0x0000000000008000,
    0x0000000000008001,
    0x000000000000ffff,
    0x0000000000010000,
    0x0000000005ffff05,
    0x000000007fffffff,
    0x0000000080000000,
    0x0000000080000001,
    0x00000000ffffffff,
    0x0000000100000000,
    0x0000000100000001,
    0x0000000100000010,
    0x0000000100000020,
    0x0000000100000040,
    0x0000000100000064,
    0x000000010000007f,
    0x0000000100000080,
    0x0000000100000081,
    0x00000001000000ff,
    0x0000000100000100,
    0x0000000100000200,
    0x00000001000003e8,
    0x0000000100000400,
    0x0000000100001000,
    0x0000000100007fff,
    0x0000000100008000,
    0x0000000100008001,
    0x000000010000ffff,
    0x0000000100010000,
    0x0000000105ffff05,
    0x000000017fffffff,
    0x0000000180000000,
    0x0000000180000001,
    0x00000001ffffffff,
    0x7fffffff00000000,
    0x7fffffff00000001,
    0x7fffffff00000010,
    0x7fffffff00000020,
    0x7fffffff00000040,
    0x7fffffff00000064,
    0x7fffffff0000007f,
    0x7fffffff00000080,
    0x7fffffff00000081,
    0x7fffffff000000ff,
    0x7fffffff00000100,
    0x7fffffff00000200,
    0x7fffffff000003e8,
    0x7fffffff00000400,
    0x7fffffff00001000,
    0x7fffffff00007fff,
    0x7fffffff00008000,
    0x7fffffff00008001,
    0x7fffffff0000ffff,
    0x7fffffff00010000,
    0x7fffffff05ffff05,
    0x7fffffff7fffffff,
    0x7fffffff80000000,
    0x7fffffff80000001,
    0x7fffffffffffffff,
    0x8000000000000000,
    0x8000000000000001,
    0x8000000000000010,
    0x8000000000000020,
    0x8000000000000040,
    0x8000000000000064,
    0x800000000000007f,
    0x8000000000000080,
    0x8000000000000081,
    0x80000000000000ff,
    0x8000000000000100,
    0x8000000000000200,
    0x80000000000003e8,
    0x8000000000000400,
    0x8000000000001000,
    0x8000000000007fff,
    0x8000000000008000,
    0x8000000000008001,
    0x800000000000ffff,
    0x8000000000010000,
    0x8000000005ffff05,
    0x800000007fffffff,
    0x8000000080000000,
    0x8000000080000001,
    0x80000000ffffffff,
    0x8000000100000000,
    0x8000000100000001,
    0x8000000100000010,
    0x8000000100000020,
    0x8000000100000040,
    0x8000000100000064,
    0x800000010000007f,
    0x8000000100000080,
    0x8000000100000081,
    0x80000001000000ff,
    0x8000000100000100,
    0x8000000100000200,
    0x80000001000003e8,
    0x8000000100000400,
    0x8000000100001000,
    0x8000000100007fff,
    0x8000000100008000,
    0x8000000100008001,
    0x800000010000ffff,
    0x8000000100010000,
    0x8000000105ffff05,
    0x800000017fffffff,
    0x8000000180000000,
    0x8000000180000001,
    0x80000001ffffffff,
    0xffffffff00000000,
    0xffffffff00000001,
    0xffffffff00000010,
    0xffffffff00000020,
    0xffffffff00000040,
    0xffffffff00000064,
    0xffffffff0000007f,
    0xffffffff00000080,
    0xffffffff00000081,
    0xffffffff000000ff,
    0xffffffff00000100,
    0xffffffff00000200,
    0xffffffff000003e8,
    0xffffffff00000400,
    0xffffffff00001000,
    0xffffffff00007fff,
    0xffffffff00008000,
    0xffffffff00008001,
    0xffffffff0000ffff,
    0xffffffff00010000,
    0xffffffff05ffff05,
    0xffffffff7fffffff,
    0xffffffff80000000,
    0xffffffff80000001,
    0xfffffffffa0000fa,
    0xffffffffffff7fff,
    0xffffffffffff8000,
    0xffffffffffff8001,
    0xffffffffffffff7f,
    0xffffffffffffff80,
    0xffffffffffffff81,
    0xffffffffffffffff,
  ];
}
