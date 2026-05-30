import 'package:flutter/foundation.dart';

class UIStateService {
  UIStateService._();
  static final UIStateService instance = UIStateService._();

  /// True when a detail / reservation sheet is currently open.
  final ValueNotifier<bool> isDetailOpen = ValueNotifier<bool>(false);

  /// Ko je nastavljen, HomeScreen preklopi na ta zavihek (npr. Moje objave).
  final ValueNotifier<int?> requestedNavIndex = ValueNotifier<int?>(null);

  void requestMineTab() {
    requestedNavIndex.value = -1; // sentinel: HomeScreen izračuna indeks
  }
}
