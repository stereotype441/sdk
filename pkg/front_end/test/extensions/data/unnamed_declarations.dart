// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class A1 {}

/*class: extension#0:
 builder-name=extension#0,
 builder-onTypes=[A1],
 builder-supertype=Object,
 cls-name=extension#0,
 cls-supertype=Object
*/
extension on A1 {
  /*member: extension#0|method:
     builder-name=method,
     builder-params=[#this],
     member-name=extension#0|method,
     member-params=[#this]
  */
  method() {}
}

/*class: extension#1:
 builder-name=extension#1,
 builder-onTypes=[A1],
 builder-supertype=Object,
 cls-name=extension#1,
 cls-supertype=Object
*/
extension on A1 {
  /*member: extension#1|method:
     builder-name=method,
     builder-params=[#this],
     member-name=extension#1|method,
     member-params=[#this]
  */
  method() {}
}

class B1<T> {}

/*class: extension#2:
 builder-name=extension#2,
 builder-onTypes=[B1<T>],
 builder-supertype=Object,
 builder-type-params=[T],
 cls-name=extension#2,
 cls-supertype=Object,
 cls-type-params=[T]
*/
extension <T> on B1<T> {
  /*member: extension#2|method:
     builder-name=method,
     builder-params=[#this],
     builder-type-params=[T],
     member-name=extension#2|method,
     member-params=[#this],
     member-type-params=[#T]
  */
  method() {}
}

// TODO(johnniwinther): Remove class type parameters.
/*class: extension#3:
 builder-name=extension#3,
 builder-onTypes=[B1<A1>],
 builder-supertype=Object,
 cls-name=extension#3,
 cls-supertype=Object
*/
extension on B1<A1> {
  /*member: extension#3|method:
     builder-name=method,
     builder-params=[#this],
     member-name=extension#3|method,
     member-params=[#this]
  */
  method() {}
}

// TODO(johnniwinther): Remove class type parameters.
/*class: extension#4:
 builder-name=extension#4,
 builder-onTypes=[B1<T>],
 builder-supertype=Object,
 builder-type-params=[T extends A1],
 cls-name=extension#4,
 cls-supertype=Object,
 cls-type-params=[T extends A1]
*/
extension <T extends A1> on B1<T> {
  /*member: extension#4|method:
     builder-name=method,
     builder-params=[#this],
     builder-type-params=[T extends A1],
     member-name=extension#4|method,
     member-params=[#this],
     member-type-params=[#T extends A1]
  */
  method() {}
}

main() {}
