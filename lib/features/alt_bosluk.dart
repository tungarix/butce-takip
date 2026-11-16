import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Alt sayfa ve ayrı sayfa listelerinin altında bırakılacak boşluk: sistem çubuğu (viewPadding)
/// ya da klavye (viewInsets), hangisi büyükse. İkisi toplanmaz, çünkü klavye çubuğu da kapsar.
double altBosluk(BuildContext context) {
  final m = MediaQuery.of(context);
  return math.max(m.viewInsets.bottom, m.viewPadding.bottom);
}
