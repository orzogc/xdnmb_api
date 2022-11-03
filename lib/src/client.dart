import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';

import 'xdnmb.dart';

/// 将cookie列表转化为cookie值
String _toCookies(Iterable<String> cookies) => cookies.join('; ');

/// [Response]的扩展
extension ResponseExtension on Response {
  /// 返回utf8编码的[body]，不用[body]是因为X岛返回的header可能不包含编码信息，
  /// 这样解码会出错
  String get utf8Body => utf8.decode(bodyBytes);
}

/// HTTP状态异常
class HttpStatusException implements Exception {
  /// 状态码
  final int statusCode;

  /// 构造[HttpStatusException]
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

/// multipart的实现
class Multipart extends MultipartRequest {
  /// 构造[Multipart]
  ///
  /// [url]为请求链接
  Multipart(String url) : super('POST', Uri.parse(url));

  /// 添加字段，值为[value]的字符串表达
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

/// HTTP client的实现
class Client extends IOClient {
  /// 默认连接超时时长
  static const Duration _defaultConnectionTimeout = Duration(seconds: 15);

  /// 默认连接空闲超时时长
  static const Duration _defaultIdleTimeout = Duration(seconds: 90);

  /// 默认`User-Agent`
  static const String _defaultUserAgent = 'xdnmb';

  /// `User-Agent`
  final String? userAgent;

  /// X岛的PHP session ID
  String? xdnmbPhpSessionId;

  /// 构造[Client]
  ///
  /// [client]为[HttpClient]
  ///
  /// [connectionTimeout]为连接超时时长，默认为15秒
  ///
  /// [idleTimeout]为连接空闲超时时长，默认为90秒
  Client(
      {HttpClient? client,
      Duration? connectionTimeout,
      Duration? idleTimeout,
      this.userAgent})
      : super((client ?? HttpClient())
          ..connectionTimeout = connectionTimeout ?? _defaultConnectionTimeout
          ..idleTimeout = idleTimeout ?? _defaultIdleTimeout);

  /// 返回cookie头
  Map<String, String>? _cookieHeasers(String? cookie) =>
      (cookie != null || xdnmbPhpSessionId != null)
          ? {
              HttpHeaders.cookieHeader: _toCookies([
                if (cookie != null) cookie,
                if (xdnmbPhpSessionId != null) xdnmbPhpSessionId!,
              ])
            }
          : null;

  /// GET请求
  Future<Response> xGet(String url, [String? cookie]) async {
    final response =
        await this.get(Uri.parse(url), headers: _cookieHeasers(cookie));
    _checkStatusCode(response);

    return response;
  }

  /// POST form请求
  Future<Response> xPostForm(String url, Map<String, String>? form,
      [String? cookie]) async {
    final response = await this
        .post(Uri.parse(url), headers: _cookieHeasers(cookie), body: form);
    _checkStatusCode(response);

    return response;
  }

  /// POST multipart请求
  Future<Response> xPostMultipart(Multipart multipart, [String? cookie]) async {
    if (cookie != null || xdnmbPhpSessionId != null) {
      multipart.headers[HttpHeaders.cookieHeader] = _toCookies([
        if (cookie != null) cookie,
        if (xdnmbPhpSessionId != null) xdnmbPhpSessionId!,
      ]);
    }
    final streamedResponse = await send(multipart);
    final response = await Response.fromStream(streamedResponse);
    _checkStatusCode(response);

    return response;
  }

  @override
  Future<IOStreamedResponse> send(BaseRequest request) async {
    // 添加User-Agent
    request.headers[HttpHeaders.userAgentHeader] =
        userAgent ?? _defaultUserAgent;
    final response = await super.send(request);

    // 获取xdnmbPhpSessionId
    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    if (setCookie != null) {
      final cookie = Cookie.fromSetCookieValue(setCookie);
      if (cookie.name == 'PHPSESSID') {
        xdnmbPhpSessionId = cookie.toCookie;
      }
    }

    return response;
  }
}

/// 检查HTTP状态码
void _checkStatusCode(Response response) {
  if (response.statusCode != HttpStatus.ok) {
    throw HttpStatusException(response.statusCode);
  }
}
