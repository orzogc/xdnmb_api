import 'package:test/test.dart';
import 'package:xdnmb_api/src/urls.dart';

void main() async {
  test("gets the xdnmb's base URL", () async {
    final urls = await XdnmbUrls.update();

    expect(urls.xdnmbBaseUrl, equals('https://www.nmbxd1.com/'));
    expect(urls.cdnUrl, equals('https://image.nmb.best/'));
    expect(identical(urls, XdnmbUrls()), isTrue);
  });
}
