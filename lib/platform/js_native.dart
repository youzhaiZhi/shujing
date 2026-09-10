import 'package:flutter_js/flutter_js.dart';

/// 原生端 JS 引擎（flutter_js / QuickJS）
Object createJsRuntime() => getJavascriptRuntime();

bool get jsSupported => true;
