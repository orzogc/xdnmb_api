part of 'xdnmb.dart';

/// X岛饼干
class XdnmbCookie {
  /// 饼干的userhash
  final String userHash;

  /// 饼干显示的名字
  final String? name;

  /// 饼干ID
  final int? id;

  /// 饼干的cookie值
  String get cookie => 'userhash=$userHash';

  /// 构造[XdnmbCookie]
  const XdnmbCookie(this.userHash, {this.name, this.id});

  /// 从JSON数据构造[XdnmbCookie]
  factory XdnmbCookie._fromJson(String data, {int? id}) {
    final Map<String, dynamic> decoded = json.decode(data);

    return XdnmbCookie(decoded['cookie'], name: decoded['name'], id: id);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XdnmbCookie &&
          userHash == other.userHash &&
          name == other.name &&
          id == other.id);

  @override
  int get hashCode => Object.hash(userHash, name, id);
}

/// 饼干列表
class CookiesList {
  /// 帐号是否能获取新饼干
  final bool canGetCookie;

  /// 帐号目前拥有的饼干数
  final int currentCookiesNum;

  /// 帐号能够拥有的最大饼干数（饼干槽）
  final int totalCookiesNum;

  /// 帐号饼干ID列表
  final List<int> cookiesIdList;

  /// 构造[CookiesList]
  const CookiesList(
      {required this.canGetCookie,
      required this.currentCookiesNum,
      required this.totalCookiesNum,
      required this.cookiesIdList});
}

/// [Cookie]的扩展
extension CookieExtension on Cookie {
  /// 将[Cookie]转化为cookie值
  String get toCookie => '$name=$value';
}
