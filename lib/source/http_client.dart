import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// 全局 HTTP 客户端（带内存 Cookie 管理，书源抓取共用，跨平台）
class Http {
  Http._();
  static final Http instance = Http._();

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.plain,
    followRedirects: true,
    maxRedirects: 10,
  ))
    ..interceptors.add(CookieManager(CookieJar()));

  Future<String> get(String url,
      {Map<String, String>? headers, String ua = defaultUa}) async {
    final resp = await _dio.get<String>(url,
        options: Options(
          headers: {'User-Agent': ua, ...?headers},
        ));
    return resp.data ?? '';
  }

  static const defaultUa =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  static Map<String, String> parseHeaders(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final j = jsonDecode(raw);
      if (j is Map) {
        return j.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }
}
