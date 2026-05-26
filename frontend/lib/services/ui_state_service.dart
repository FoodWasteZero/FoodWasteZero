import 'package:flutter/foundation.dart';

class UIStateService {
  UIStateService._();
  static final UIStateService instance = UIStateService._();

  /// True when a detail / reservation sheet is currently open.
  final ValueNotifier<bool> isDetailOpen = ValueNotifier<bool>(false);
}
