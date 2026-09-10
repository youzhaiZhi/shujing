/// Web 端暂不提供 JS 引擎（书源的 @js: 规则在 Web 预览中不可用）
Object? createJsRuntime() => null;

bool get jsSupported => false;
