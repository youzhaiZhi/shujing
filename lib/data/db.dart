/// 条件导出：Web 用 WASM 版，原生用 sqflite
export 'db_io.dart' if (dart.library.js_interop) 'db_web.dart';
