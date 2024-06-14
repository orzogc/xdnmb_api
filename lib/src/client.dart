import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' hide Client;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';

import 'urls.dart';
import 'xdnmb.dart';

/// 将 cookie 列表转化为 cookie 值
String _toCookies(Iterable<String> cookies) => cookies.join('; ');

/// [Response] 的扩展
extension ResponseExtension on Response {
  /// 返回 utf8 编码的 [body]，不用 [body] 是因为 X 岛返回的 header 可能不包含编码信息，
  /// 这样解码会出错
  String get utf8Body => utf8.decode(bodyBytes);
}

/// HTTP 状态异常
class HttpStatusException implements Exception {
  /// 状态码
  final int statusCode;

  /// 构造 [HttpStatusException]
  const HttpStatusException(this.statusCode);

  @override
  String toString() =>
      "HttpStatusException: the HTTP response's status code is $statusCode";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HttpStatusException && statusCode == other.statusCode);

  @override
  int get hashCode => statusCode.hashCode;
}

/// multipart 的实现
class Multipart extends MultipartRequest {
  /// 构造 [Multipart]
  ///
  /// [url] 为请求链接
  Multipart(Uri url) : super('POST', url);

  /// 添加字段，值为 [value] 的字符串表达
  void add(String field, Object value) => fields[field] = value.toString();

  /// 添加字段
  void addBytes(String field, List<int> value,
          {String? filename, String? contentType}) =>
      files.add(
        MultipartFile.fromBytes(
          field,
          value,
          filename: filename,
          contentType:
              contentType != null ? MediaType.parse(contentType) : null,
        ),
      );
}

/// HTTP client 的实现
class Client extends IOClient {
  /// 默认连接超时时长
  static const Duration defaultConnectionTimeout = Duration(seconds: 15);

  /// 默认连接空闲超时时长
  static const Duration _defaultIdleTimeout = Duration(seconds: 90);

  /// 默认`User-Agent`
  static const String _defaultUserAgent = 'xdnmb';

  /// X 岛的 PHP session ID
  String? xdnmbPhpSessionId;

  /// X 岛备用 API 的 PHP session ID
  String? _xdnmbBackupApiPhpSessionId;

  /// 构造 [Client]
  ///
  /// [client] 为 [HttpClient]
  ///
  /// [connectionTimeout] 为连接超时时长，默认为 15 秒
  ///
  /// [idleTimeout] 为连接空闲超时时长，默认为 90 秒
  Client(
      {HttpClient? client,
      Duration? connectionTimeout,
      Duration? idleTimeout,
      String? userAgent})
      : super((client ?? HttpClient())
          ..connectionTimeout = connectionTimeout ?? defaultConnectionTimeout
          ..idleTimeout = idleTimeout ?? _defaultIdleTimeout
          ..userAgent = userAgent ?? _defaultUserAgent);

  /// [xdnmbPhpSessionId] 有效
  bool _xdnmbPhpSessionIdIsValid(Uri url) =>
      xdnmbPhpSessionId != null && XdnmbUrls().isBaseUrl(url);

  /// [_xdnmbBackupApiPhpSessionId] 有效
  bool _xdnmbBackupApiPhpSessionIdIsValid(Uri url) =>
      _xdnmbBackupApiPhpSessionId != null && XdnmbUrls().isBackupApiUrl(url);

  /// 返回 cookie 头
  Map<String, String>? _cookieHeasers(Uri url, String? cookie) =>
      (cookie != null ||
              _xdnmbPhpSessionIdIsValid(url) ||
              _xdnmbBackupApiPhpSessionIdIsValid(url))
          ? {
              HttpHeaders.cookieHeader: _toCookies([
                if (cookie != null) cookie,
                if (_xdnmbPhpSessionIdIsValid(url)) xdnmbPhpSessionId!,
                if (_xdnmbBackupApiPhpSessionIdIsValid(url))
                  _xdnmbBackupApiPhpSessionId!,
              ])
            }
          : null;

  /// GET 请求
  Future<Response> xGet(Uri url, [String? cookie]) async {
    final response = await this.get(url, headers: _cookieHeasers(url, cookie));
    _checkStatusCode(response);

    return response;
  }

  /// POST form 请求
  Future<Response> xPostForm(Uri url, Map<String, String>? form,
      [String? cookie]) async {
    final response =
        await this.post(url, headers: _cookieHeasers(url, cookie), body: form);
    _checkStatusCode(response);

    return response;
  }

  /// POST multipart 请求
  Future<Response> xPostMultipart(Multipart multipart, [String? cookie]) async {
    if (cookie != null ||
        _xdnmbPhpSessionIdIsValid(multipart.url) ||
        _xdnmbBackupApiPhpSessionIdIsValid(multipart.url)) {
      multipart.headers[HttpHeaders.cookieHeader] = _toCookies([
        if (cookie != null) cookie,
        if (_xdnmbPhpSessionIdIsValid(multipart.url)) xdnmbPhpSessionId!,
        if (_xdnmbBackupApiPhpSessionIdIsValid(multipart.url))
          _xdnmbBackupApiPhpSessionId!,
      ]);
    }
    final streamedResponse = await send(multipart);
    final response = await Response.fromStream(streamedResponse);
    _checkStatusCode(response);

    return response;
  }

  @override
  Future<IOStreamedResponse> send(BaseRequest request) async {
    final response = await super.send(request);

    // 获取 xdnmbPhpSessionId 和_xdnmbBackupApiPhpSessionId
    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    if (setCookie != null) {
      final cookies = setCookie.split(RegExp(r',(?! )'));
      for (final c in cookies) {
        try {
          final cookie = Cookie.fromSetCookieValue(c);
          if (cookie.name == 'PHPSESSID') {
            final urls = XdnmbUrls();
            if (urls.isBaseUrl(request.url)) {
              xdnmbPhpSessionId = cookie.toCookie;
            } else if (urls.isBackupApiUrl(request.url)) {
              _xdnmbBackupApiPhpSessionId = cookie.toCookie;
            }
          }
        } catch (e) {
          print('解析 set-cookie 出现错误：$e');
        }
      }
    }

    return response;
  }
}

/// 检查 HTTP 状态码
void _checkStatusCode(Response response) {
  if (response.statusCode != HttpStatus.ok) {
    throw HttpStatusException(response.statusCode);
  }
}
