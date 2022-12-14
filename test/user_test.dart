import 'dart:io';

import 'package:test/test.dart';
import 'package:xdnmb_api/src/xdnmb.dart';

void main() async {
  group('XdnmbUserApi', () {
    final email = Platform.environment['XdnmbAccountEmail']!;
    final password = Platform.environment['XdnmbAccountPassword']!;
    final verifyImageFile = Platform.environment['XdnmbVerifyImageFile']!;
    final xdnmb = XdnmbApi();
    CookiesList? list;

    test('getVerifyImage() gets the verifying image', () async {
      final image = await xdnmb.getVerifyImage();
      final file = File(verifyImageFile);
      await file.writeAsBytes(image);

      expect(image, isNotEmpty);
    });

    test('userLogin() login as user', () async {
      final verify = stdin.readLineSync();
      await xdnmb.userLogin(
          email: email, password: password, verify: verify!.trim());

      expect(xdnmb.xdnmbUserCookie, isNotNull);
      expect(xdnmb.xdnmbUserCookie!.name, equals('memberUserspapapa'));
      expect(xdnmb.xdnmbUserCookie!.value, isNotEmpty);
    });

    test('getCookiesList() gets the list of cookies', () async {
      list = await xdnmb.getCookiesList();

      expect(list!.currentCookiesNum, lessThanOrEqualTo(list!.totalCookiesNum));
      expect(list!.currentCookiesNum, equals(list!.cookiesIdList.length));
    });

    test('getCookie() gets the cookie', () async {
      if (list!.currentCookiesNum > 0) {
        final cookie = await xdnmb.getCookie(list!.cookiesIdList.first);

        expect(cookie.userHash, isNotEmpty);
        expect(cookie.name, isNotEmpty);
        expect(cookie.id, equals(list!.cookiesIdList.first));
      }
    });

    test(
      'deleteCookie() deletes a cookie',
      () async {
        final image = await xdnmb.getVerifyImage();
        final file = File(verifyImageFile);
        await file.writeAsBytes(image);
        final verify = stdin.readLineSync();
        final cookieId = list!.cookiesIdList.last;
        await xdnmb.deleteCookie(cookieId: cookieId, verify: verify!.trim());
        list = await xdnmb.getCookiesList();

        expect(list!.cookiesIdList.any((id) => id == cookieId), isFalse);
      },
      /* skip: list == null || list!.cookiesList.isEmpty
            ? 'user has no cookies'
            : null */
    );

    test(
      'getNewCookie() gets a new cookie',
      () async {
        final image = await xdnmb.getVerifyImage();
        final file = File(verifyImageFile);
        await file.writeAsBytes(image);
        final verify = stdin.readLineSync();
        await xdnmb.getNewCookie(verify: verify!.trim());
        final oldNum = list!.currentCookiesNum;
        list = await xdnmb.getCookiesList();

        expect(list!.currentCookiesNum, equals(oldNum + 1));
      },
      /* skip: list == null || list!.currentCookiesNum >= list!.totalCookiesNum
            ? 'user can\'t get more cookies'
            : null */
    );
  });
}
