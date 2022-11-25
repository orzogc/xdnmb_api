import 'dart:convert';
import 'dart:io';

/// X岛链接
class XdnmbUrls {
  static const String xdnmbHost = 'www.nmbxd.com';

  /// X岛初始链接
  static const String _xdnmbOriginUrl = 'https://$xdnmbHost/';

  /// X岛现在的链接
  static const String _xdnmbCurrentUrl = 'https://www.nmbxd1.com/';

  /// X岛CDN初始链接
  static const String _cdnOriginUrl = 'https://image.nmb.best/';

  /// 公告链接
  static const String notice = 'https://nmb.ovear.info/nmb-notice.json';

  /// [XdnmbUrls]的单例
  static XdnmbUrls _urls = XdnmbUrls._internal(_xdnmbCurrentUrl, _cdnOriginUrl);

  /// X岛基础链接
  final String xdnmbBaseUrl;

  /// X岛CDN链接
  final String cdnUrl;

  /// CDN列表链接
  String get cdnList => '${xdnmbBaseUrl}Api/getCdnPath';

  /// 版块列表链接
  String get forumList => '${xdnmbBaseUrl}Api/getForumList';

  /// 时间线列表链接
  String get timelineList => '${xdnmbBaseUrl}Api/getTimelineList';

  /// 获取最新发的串的链接
  String get getLastPost => '${xdnmbBaseUrl}Api/getLastPost';

  /// 发串链接
  String get postNewThread => '${xdnmbBaseUrl}Home/Forum/doPostThread.html';

  /// 回串链接
  String get replyThread => '${xdnmbBaseUrl}Home/Forum/doReplyThread.html';

  /// 验证码图片链接
  String get verifyImage => '${xdnmbBaseUrl}Member/User/Index/verify.html';

  /// 用户登陆链接
  String get userLogin => '${xdnmbBaseUrl}Member/User/Index/login.html';

  /// 用户饼干链接
  String get cookiesList => '${xdnmbBaseUrl}Member/User/Cookie/index.html';

  /// 获取新饼干链接
  String get getNewCookie => '${xdnmbBaseUrl}Member/User/Cookie/apply.html';

  /// 注册帐号链接
  String get registerAccount =>
      '${xdnmbBaseUrl}Member/User/Index/sendRegister.html';

  /// 重置密码链接
  String get resetPassword =>
      '${xdnmbBaseUrl}Member/User/Index/sendForgotPassword.html';

  /// [XdnmbUrls]的内部构造器
  const XdnmbUrls._internal(this.xdnmbBaseUrl, this.cdnUrl);

  /// 构造[XdnmbUrls]，返回[XdnmbUrls]单例
  factory XdnmbUrls() => _urls;

  /// 版块链接
  ///
  /// [forumId]为版块ID，[page]从1开始算起
  String forum(int forumId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/showf?id=$forumId&page=$page';

  /// 网页版版块链接
  ///
  /// [forumId]为版块ID，[page]从1开始算起
  String htmlForum(int forumId, {int page = 1}) =>
      '${xdnmbBaseUrl}Forum/showf?id=$forumId&page=$page';

  /// 时间线链接
  ///
  /// [timelineId]为时间线ID，[page]从1开始算起
  String timeline(int timelineId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/timeline?id=$timelineId&page=$page';

  /// 串（帖子）链接
  ///
  /// [mainPostId]为主串ID，[page]从1开始算起
  String thread(int mainPostId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/thread?id=$mainPostId&page=$page';

  /// 串引用链接
  ///
  /// [postId]为串ID
  String reference(int postId) => '${xdnmbBaseUrl}Api/ref?id=$postId';

  /// 网页版串引用链接
  ///
  /// [postId]为串ID
  String htmlReference(int postId) =>
      '${xdnmbBaseUrl}Home/Forum/ref?id=$postId';

  /// 只看Po主的串的链接
  ///
  /// [mainPostId]为主串ID，[page]从1开始算起
  String onlyPoThread(int mainPostId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/po?id=$mainPostId&page=$page';

  /// 订阅链接
  ///
  /// [feedId]为订阅ID，[page]从1开始算起
  String feed(String feedId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/feed?uuid=${Uri.encodeQueryComponent(feedId)}&page=$page';

  /// 添加订阅的链接
  ///
  /// [feedId]为订阅ID，[mainPostId]为主串ID
  String addFeed(String feedId, int mainPostId) =>
      '${xdnmbBaseUrl}Api/addFeed?uuid=${Uri.encodeQueryComponent(feedId)}&tid=$mainPostId';

  /// 删除订阅的链接
  ///
  /// [feedId]为订阅ID，[mainPostId]为主串ID
  String deleteFeed(String feedId, int mainPostId) =>
      '${xdnmbBaseUrl}Api/delFeed?uuid=${Uri.encodeQueryComponent(feedId)}&tid=$mainPostId';

  /// 获取饼干的链接
  ///
  /// [cookieId]为饼干ID
  String getCookie(int cookieId) =>
      '${xdnmbBaseUrl}Member/User/Cookie/export/id/$cookieId.html';

  /// 删除饼干的链接
  ///
  /// [cookieId]为饼干ID
  String deleteCookie(int cookieId) =>
      '${xdnmbBaseUrl}Member/User/Cookie/delete/id/$cookieId.html';

  /// 更新链接
  static Future<XdnmbUrls> update() async {
    final client = HttpClient()..connectionTimeout = Duration(seconds: 10);

    try {
      HttpClientRequest request =
          await client.getUrl(Uri.parse(_xdnmbOriginUrl));
      request.followRedirects = false;
      HttpClientResponse response = await request.close();
      await response.drain();

      final baseUrl = response.isRedirect
          ? (response.headers.value(HttpHeaders.locationHeader) ??
              _xdnmbOriginUrl)
          : _xdnmbOriginUrl;

      request = await client.getUrl(Uri.parse('${baseUrl}Api/getCdnPath'));
      response = await request.close();
      final data = await response.transform(utf8.decoder).join();
      final decoded = json.decode(data);

      final cdnUrl = (decoded is List<dynamic> && decoded.isNotEmpty)
          ? (decoded[0]['url'] ?? _cdnOriginUrl)
          : _cdnOriginUrl;

      _urls = XdnmbUrls._internal(baseUrl, cdnUrl);

      return _urls;
    } catch (e) {
      rethrow;
    } finally {
      client.close();
    }
  }
}
