part of 'xdnmb.dart';

class XdnmbCookie {
  late final String userHash;

  late final String? name;

  final int? id;

  String get cookie => 'userhash=$userHash';

  XdnmbCookie(this.userHash, {this.name, this.id});

  XdnmbCookie._fromJson(String data, {this.id}) {
    final Map<String, dynamic> decoded = json.decode(data);

    userHash = decoded['cookie'];
    name = decoded['name'];
  }
}

class CookiesList {
  final bool canGetCookie;

  final int currentCookiesNum;

  final int totalCookiesNum;

  final List<int> cookiesIdList;

  const CookiesList._internal(
      {required this.canGetCookie,
      required this.currentCookiesNum,
      required this.totalCookiesNum,
      required this.cookiesIdList});
}

extension CookieExtension on Cookie {
  String get toCookie => '$name=$value';
}
