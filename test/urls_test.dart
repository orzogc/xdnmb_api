import 'package:test/test.dart';
import 'package:xdnmb_api/src/urls.dart';

const bool _useHttps = true;

void main() async {
  test("gets the xdnmb's base URL", () async {
    final urls = await XdnmbUrls.update(useHttps: _useHttps);

    expect(urls.baseUrl, equals(Uri.parse('https://www.nmbxd1.com/')));
    expect(urls.cdnUrl, equals(Uri.parse('https://image.nmb.best/')));
    expect(urls.backupApiUrl, equals(Uri.parse('https://api.nmb.best')));
    expect(urls.useHttps, isTrue);
    expect(urls.useBackupApi, isFalse);
    expect(identical(urls, XdnmbUrls()), isTrue);
  });
}
