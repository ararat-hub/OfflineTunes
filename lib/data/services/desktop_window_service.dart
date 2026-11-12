import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../theme/theme_provider.dart';

class DesktopWindowService extends ChangeNotifier with WindowListener {
  final Future<void> Function()? onMinimize;
  DesktopWindowService({this.onMinimize}) {
    if (Platform.isWindows) windowManager.addListener(this);
  }
  bool _compact = false;
  bool _busy = false;
  bool get compact => _compact;
  bool get busy => _busy;
  Rect? _normalBounds;
  bool _wasMaximized = false;
  String? error;

  Future<void> enterWidget(ThemeProvider theme, {bool youtube = false}) async {
    if (_busy || _compact || !Platform.isWindows) return;
    _busy = true;
    error = null;
    try {
      _wasMaximized = await windowManager.isMaximized();
      if (_wasMaximized) await windowManager.unmaximize();
      _normalBounds = await windowManager.getBounds();
      await windowManager
          .setMinimumSize(Size(youtube ? 480 : 360, youtube ? 480 : 250));
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
          windowButtonVisibility: false);
      await windowManager.setAlwaysOnTop(theme.widgetOnTop);
      _compact = true;
      notifyListeners();
      await windowManager.setSize(Size(
          youtube ? theme.widgetWidth.clamp(480, 800) : theme.widgetWidth,
          youtube ? theme.widgetHeight.clamp(480, 700) : theme.widgetHeight));
    } catch (e) {
      debugPrint('Enter floating widget: $e');
      error = 'Не удалось открыть виджет.';
    }
    _busy = false;
    notifyListeners();
  }

  Future<void> restore() async {
    if (_busy || !_compact) return;
    _busy = true;
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal,
          windowButtonVisibility: true);
      await windowManager.setMinimumSize(const Size(480, 600));
      await windowManager
          .setBounds(_normalBounds ?? const Rect.fromLTWH(50, 50, 1280, 760));
      if (_wasMaximized) await windowManager.maximize();
      _compact = false;
      error = null;
    } catch (e) {
      debugPrint('Restore player window: $e');
      error = 'Не удалось развернуть плеер.';
    }
    _busy = false;
    notifyListeners();
  }

  Future<void> drag() => windowManager.startDragging();
  Future<void> setPinned(bool value) => windowManager.setAlwaysOnTop(value);
  Future<void> minimize() => windowManager.minimize();
  @override
  void onWindowMinimize() {
    onMinimize?.call();
  }

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    super.dispose();
  }
}
