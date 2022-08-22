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
      files.add(MultipartFile.fromBytes(field, value,
          filename: filename,
          contentType:
              contentType != null ? MediaType.parse(contentType) : null));
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

/* import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:form_data/form_data.dart';

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

enum Method { get, post }

class Request {
  final Method method;

  final String url;

  final List<String>? cookies;

  late final Map<String, String>? headers;

  late final List<int>? body;

  Request(
      {required this.method,
      required this.url,
      this.cookies,
      this.headers,
      this.body});

  Request.get(this.url, {this.cookies, this.headers})
      : method = Method.get,
        body = null;

  Request.postForm(this.url, Map<String, String> form,
      {this.cookies, Map<String, String>? headers})
      : method = Method.post {
    var pairs = <List<String>>[];
    form.forEach((key, value) {
      pairs.add(
          [Uri.encodeQueryComponent(key), Uri.encodeQueryComponent(value)]);
    });
    final bodyString = pairs.map((pair) => '${pair[0]}=${pair[1]}').join('&');
    body = utf8.encode(bodyString);

    this.headers = headers ?? HashMap()
      ..[HttpHeaders.contentTypeHeader] = 'application/x-www-form-urlencoded';
  }

  Request.postMultipart(this.url, FormData multipart,
      {this.cookies, Map<String, String>? headers})
      : method = Method.post {
    body = multipart.body;

    this.headers = headers ?? HashMap()
      ..[HttpHeaders.contentTypeHeader] = multipart.contentType;
  }
}

class Response {
  final HttpHeaders headers;

  final String body;

  const Response(this.headers, this.body);
}

class Client {
  final HttpClient _httpClient;

  static const Duration _idleTimeout = Duration(seconds: 90);

  static const String _userAgent = 'xdnmb';

  Client({Duration timeout = const Duration(seconds: 15)})
      : _httpClient = HttpClient()
          ..connectionTimeout = timeout
          ..idleTimeout = _idleTimeout;

  Future<Response> send(Request request) async {
    final httpRequest =
        await _httpClient.openUrl(request.method.name, Uri.parse(request.url));

    httpRequest.headers.set(HttpHeaders.userAgentHeader, _userAgent);

    if (request.cookies != null) {
      for (final cookie in request.cookies!) {
        httpRequest.headers.add(HttpHeaders.cookieHeader, cookie);
      }
    }

    if (request.headers != null) {
      request.headers!
          .forEach((key, value) => httpRequest.headers.add(key, value));
    }

    if (request.body != null) {
      httpRequest.headers
          .set(HttpHeaders.contentLengthHeader, request.body!.length);
      httpRequest.add(request.body!);
    }

    final response = await httpRequest.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != HttpStatus.ok) {
      if (body.isEmpty) {
        throw HttpStatusException(response.statusCode);
      }
      throw HttpStatusException(response.statusCode, body);
    }

    return Response(response.headers, body);
  }

  Future<Response> get(String url, [String? cookie]) async {
    final request = Request.get(url, cookies: cookie == null ? null : [cookie]);

    return await send(request);
  }

  Future<Response> postForm(String url, Map<String, String> form,
      [String? cookie]) async {
    final request =
        Request.postForm(url, form, cookies: cookie == null ? null : [cookie]);

    return await send(request);
  }

  Future<Response> postMultipart(String url, FormData multipart,
      [String? cookie]) async {
    final request = Request.postMultipart(url, multipart,
        cookies: cookie == null ? null : [cookie]);

    return await send(request);
  }

  void close({bool force = false}) {
    _httpClient.close(force: force);
  }
}
 */
