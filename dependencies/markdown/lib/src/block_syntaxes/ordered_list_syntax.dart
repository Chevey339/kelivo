// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../patterns.dart';
import 'list_syntax.dart';

/// Parses ordered lists.
class OrderedListSyntax extends ListSyntax {
  @override
  RegExp get pattern => listPattern;

  const OrderedListSyntax();
}
