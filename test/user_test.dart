import 'dart:io';

import 'package:test/test.dart';
import 'package:xdnmb_api/src/xdnmb.dart';

void main() async {
  group('XdnmbUserApi', () {
    final email = Platform.environment['XdnmbAccountEmail']!;
    final password = Platform.environment['XdnmbAccountPassword']!;
    final verifyImageFile = Platform.environment['XdnmbVerifyImageFile']!;
    final xdnmb = XdnmbApi();
    CookieList? list;

    test('getPhpSessionId() gets the PHP session ID', () async {
      await xdnmb.getPhpSessionId();

      expect(xdnmb.xdnmbPhpSessionId, isNotNull);
      expect(xdnmb.xdnmbPhpSessionId!.name, equals('PHPSESSID'));
      expect(xdnmb.xdnmbPhpSessionId!.value, isNotEmpty);
    });

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
      expect(list!.currentCookiesNum, equals(list!.cookiesList.length));
    });

    test(
      'deleteCookie() deletes a cookie',
      () async {
        final image = await xdnmb.getVerifyImage();
        final file = File(verifyImageFile);
        await file.writeAsBytes(image);
        final verify = stdin.readLineSync();
        final cookieId = list!.cookiesList.last.id!;
        await xdnmb.deleteCookie(cookieId: cookieId, verify: verify!.trim());
        list = await xdnmb.getCookiesList();

        expect(
            list!.cookiesList.any((cookie) => cookie.id == cookieId), isFalse);
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
