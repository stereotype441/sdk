// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Test functions with void return type, and functions that take no args.

import "package:expect/expect.dart";
import "dart:wasm";
import "dart:typed_data";

void main() {
  // int64_t x = 0;
  // void set(int64_t a, int64_t b) { x = a + b; }
  // int64_t get() { return x; }
  var data = Uint8List.fromList([
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0a, 0x02, 0x60,
    0x02, 0x7e, 0x7e, 0x00, 0x60, 0x00, 0x01, 0x7e, 0x03, 0x03, 0x02, 0x00,
    0x01, 0x04, 0x05, 0x01, 0x70, 0x01, 0x01, 0x01, 0x05, 0x03, 0x01, 0x00,
    0x02, 0x06, 0x08, 0x01, 0x7f, 0x01, 0x41, 0x90, 0x88, 0x04, 0x0b, 0x07,
    0x16, 0x03, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00, 0x03,
    0x73, 0x65, 0x74, 0x00, 0x00, 0x03, 0x67, 0x65, 0x74, 0x00, 0x01, 0x0a,
    0x1e, 0x02, 0x10, 0x00, 0x41, 0x00, 0x20, 0x01, 0x20, 0x00, 0x7c, 0x37,
    0x03, 0x80, 0x88, 0x80, 0x80, 0x00, 0x0b, 0x0b, 0x00, 0x41, 0x00, 0x29,
    0x03, 0x80, 0x88, 0x80, 0x80, 0x00, 0x0b, 0x0b, 0x0f, 0x01, 0x00, 0x41,
    0x80, 0x08, 0x0b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]);

  var inst = WasmModule(data).instantiate(WasmImports("env")
    ..addMemory("memory", WasmMemory(256, 1024))
    ..addGlobal<Int32>("__memory_base", 1024, false));
  var setFn = inst.lookupFunction<Void Function(Int64, Int64)>("set");
  var getFn = inst.lookupFunction<Int64 Function()>("get");
  Expect.isNull(setFn.call([123, 456]));
  int n = getFn.call([]);
  Expect.equals(123 + 456, n);
}
