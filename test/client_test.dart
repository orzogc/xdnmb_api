import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:xdnmb_api/xdnmb_api.dart';
import 'package:xdnmb_api/src/client.dart';

void main() async {
  group("Client", () {
    final client = Client();

    test('.get() performs a HTTP GET request', () async {
      final cookie = XdnmbCookie("cookies1");
      final url = 'https://httpbin.org/get?foo=bar&baz=qux';
      final response = await client.xGet(url, cookie.cookie);
      final Map<String, dynamic> body = json.decode(response.body);

      expect(response.headers[HttpHeaders.contentTypeHeader]!,
          equals('application/json'));
      expect(body['args']['foo'], equals('bar'));
      expect(body['args']['baz'], equals('qux'));
      expect(body['headers']['Accept-Encoding'], equals('gzip'));
      expect(body['headers']['Cookie'], equals(cookie.toString()));
      expect(body['headers']['User-Agent'], equals('xdnmb'));
      expect(body['url'], equals(url));
    });

    test('.postForm() performs a HTTP POST form request', () async {
      final cookie = XdnmbCookie("cookies2");
      final url = 'https://httpbin.org/post?foo=bar';
      final form = {'baz': 'qux'};
      final response = await client.xPostForm(url, form, cookie.cookie);
      final Map<String, dynamic> body = json.decode(response.body);

      expect(response.headers[HttpHeaders.contentTypeHeader]!,
          equals('application/json'));
      expect(body['args']['foo'], equals('bar'));
      expect(body['form']['baz'], equals('qux'));
      expect(body['headers']['Accept-Encoding'], equals('gzip'));
      expect(body['headers']['Content-Type'],
          contains('application/x-www-form-urlencoded'));
      expect(body['headers']['Cookie'], equals(cookie.toString()));
      expect(body['headers']['User-Agent'], equals('xdnmb'));
      expect(body['url'], equals(url));
    });

    test('.postMultipart() performs a HTTP POST multipart request', () async {
      final cookie = XdnmbCookie("cookies3");
      final url = 'https://httpbin.org/post?foo=bar';
      final multipart = Multipart(url)
        ..add('baz', 'qux')
        ..addBytes('image', utf8.encode('abcdefg'),
            filename: 'abc.png', contentType: 'image/png');
      final response = await client.xPostMultipart(multipart, cookie.cookie);
      final Map<String, dynamic> body = json.decode(response.body);

      expect(response.headers[HttpHeaders.contentTypeHeader]!,
          equals('application/json'));
      expect(body['args']['foo'], equals('bar'));
      expect(body['files']['image'], equals('abcdefg'));
      expect(body['form']['baz'], equals('qux'));
      expect(body['headers']['Accept-Encoding'], equals('gzip'));
      expect(body['headers']['Content-Type'],
          contains('multipart/form-data; boundary='));
      expect(body['headers']['Cookie'], equals(cookie.toString()));
      expect(body['headers']['User-Agent'], equals('xdnmb'));
      expect(body['url'], equals(url));
    });
  });
}
