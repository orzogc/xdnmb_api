import 'package:test/test.dart';
import 'package:xdnmb_api/src/urls.dart';

const bool _useBackupApi = false;

void main() async {
  test("updates xdnmb's URLs", () async {
    XdnmbUrls().useBackupApi = _useBackupApi;
    final urls = await XdnmbUrls.update();

    expect(urls.baseUrl, equals(Uri.parse('https://www.nmbxd1.com/')));
    expect(urls.cdnUrl, equals(Uri.parse('https://image.nmb.best/')));
    expect(urls.backupApiUrl, equals(Uri.parse('https://api.nmb.best')));
    expect(urls.useBackupApi, equals(_useBackupApi));
    expect(identical(urls, XdnmbUrls()), isTrue);
  });
}
