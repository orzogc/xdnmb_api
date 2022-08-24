import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';

import 'xdnmb.dart';

String _toCookies(Iterable<String> cookies) => cookies.join('; ');

class HttpStatusException implements Exception {
  final int statusCode;

  final String? body;

  const HttpStatusException(this.statusCode, [this.body]);

  @override
  String toString() {
    var result =
        "HttpStatusException: the HTTP response's status code is $statusCode";
    if (body != null) {
      result += ", the body is '$body'";
    }

    return result;
  }
}

class Multipart extends MultipartRequest {
  Multipart(String url) : super('POST', Uri.parse(url));

  void add(String field, Object value) => fields[field] = value.toString();

  void addBytes(String field, List<int> value,
          {String? filename, String? contentType}) =>
      files.add(
        MultipartFile.fromBytes(field, value,
            filename: filename,
            contentType:
                contentType != null ? MediaType.parse(contentType) : null),
      );
}

class Client extends IOClient {
  static const Duration _idleTimeout = Duration(seconds: 90);

  static const String _userAgent = 'xdnmb';

  String? xdnmbPhpSessionId;

  Client({Duration timeout = const Duration(seconds: 15)})
      : super(HttpClient()
          ..connectionTimeout = timeout
          ..idleTimeout = _idleTimeout);

  @override
  Future<IOStreamedResponse> send(BaseRequest request) async {
    request.headers[HttpHeaders.userAgentHeader] = _userAgent;
    final response = await super.send(request);

    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    if (setCookie != null) {
      final cookie = Cookie.fromSetCookieValue(setCookie);
      if (cookie.name == 'PHPSESSID') {
        xdnmbPhpSessionId = cookie.toCookie;
      }
    }

    return response;
  }

  Future<Response> xGet(String url, [String? cookie]) async {
    final response = await this.get(Uri.parse(url),
        headers: cookie != null || xdnmbPhpSessionId != null
            ? {
                HttpHeaders.cookieHeader: _toCookies([
                  if (cookie != null) cookie,
                  if (xdnmbPhpSessionId != null) xdnmbPhpSessionId!,
                ])
              }
            : null);
    _checkStatusCode(response);

    return response;
  }

  Future<Response> xPostForm(String url, Map<String, String>? form,
      [String? cookie]) async {
    final response = await this.post(Uri.parse(url),
        headers: cookie != null || xdnmbPhpSessionId != null
            ? {
                HttpHeaders.cookieHeader: _toCookies([
                  if (cookie != null) cookie,
                  if (xdnmbPhpSessionId != null) xdnmbPhpSessionId!,
                ])
              }
            : null,
        body: form);
    _checkStatusCode(response);

    return response;
  }

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
}

void _checkStatusCode(Response response) {
  if (response.statusCode != HttpStatus.ok) {
    final body = response.body;
    if (body.isEmpty) {
      throw HttpStatusException(response.statusCode);
    }
    throw HttpStatusException(response.statusCode, body);
  }
}
