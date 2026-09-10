import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:enough_convert/gbk.dart';

/// 全局 HTTP 客户端（带内存 Cookie 管理，书源抓取共用，跨平台）
class Http {
  Http._();
  static final Http instance = Http._();

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.bytes,
    followRedirects: true,
    maxRedirects: 10,
    validateStatus: (s) => s != null && s >= 200 && s < 400,
  ))
    ..interceptors.add(CookieManager(CookieJar()));

  static final _gbk = gbk;

  Future<String> get(String url,
      {Map<String, String>? headers, String ua = defaultUa}) async {
    final resp = await _dio.get<List<int>>(url,
        options: Options(
          headers: {'User-Agent': ua, ...?headers},
        ));
    return _decode(resp);
  }

  String _decode(Response<List<int>> resp) {
    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) return '';
    final charset = _charsetOf(resp, bytes);
    try {
      if (charset.contains('gb')) {
        return _gbk.decode(bytes);
      }
      if (charset.contains('big5')) {
        return const Utf8Decoder(allowMalformed: true).convert(bytes);
      }
    } catch (_) {}
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }

  String _charsetOf(Response<List<int>> resp, List<int> bytes) {
    final ct = (resp.headers.value('content-type') ?? '').toLowerCase();
    var m = RegExp(r'charset=([\w-]+)').firstMatch(ct);
    if (m != null) return m.group(1)!;
    // 从 HTML meta 里嗅探（只看前 2KB）
    final head = String.fromCharCodes(bytes.take(2048));
    m = RegExp(r'''charset=["']?([\w-]+)''', caseSensitive: false).firstMatch(head);
    return m?.group(1)?.toLowerCase() ?? 'utf-8';
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
