import 'dart:convert';
import 'dart:io';

class XdnmbUrls {
  static const String _xdnmbOriginUrl = 'https://www.nmbxd.com/';

  static const String _xdnmbCurrentUrl = 'https://www.nmbxd1.com/';

  static const String originCdnUrl = 'https://image.nmb.best/';

  static const String notice = 'https://nmb.ovear.info/nmb-notice.json';

  static XdnmbUrls _urls = XdnmbUrls._internal(_xdnmbCurrentUrl, originCdnUrl);

  final String xdnmbBaseUrl;

  final String cdnUrl;

  String get cdnList => '${xdnmbBaseUrl}Api/getCdnPath';

  String get forumList => '${xdnmbBaseUrl}Api/getForumList';

  String get timelineList => '${xdnmbBaseUrl}Api/getTimelineList';

  String get postNewThread => '${xdnmbBaseUrl}Home/Forum/doPostThread.html';

  String get replyThread => '${xdnmbBaseUrl}Home/Forum/doReplyThread.html';

  String get verifyImage => '${xdnmbBaseUrl}Member/User/Index/verify.html';

  String get userLogin => '${xdnmbBaseUrl}Member/User/Index/login.html';

  String get cookiesList => '${xdnmbBaseUrl}Member/User/Cookie/index.html';

  String get getNewCookie => '${xdnmbBaseUrl}Member/User/Cookie/apply.html';

  String get registerAccount =>
      '${xdnmbBaseUrl}Member/User/Index/sendRegister.html';

  String get resetPassword =>
      '${xdnmbBaseUrl}Member/User/Index/sendForgotPassword.html';

  const XdnmbUrls._internal(this.xdnmbBaseUrl, this.cdnUrl);

  factory XdnmbUrls() => _urls;

  /// [page]从1开始算起
  String forum(int forumId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/showf?id=$forumId&page=$page';

  String htmlForum(int forumId, {int page = 1}) =>
      '${xdnmbBaseUrl}Forum/showf?id=$forumId&page=$page';

  String timeline(int timelineId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/timeline?id=$timelineId&page=$page';

  String thread(int mainPostId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/thread?id=$mainPostId&page=$page';

  String reference(int postId) => '${xdnmbBaseUrl}Api/ref?id=$postId';

  String htmlReference(int postId) =>
      '${xdnmbBaseUrl}Home/Forum/ref?id=$postId';

  String onlyPoThread(int mainPostId, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/po?id=$mainPostId&page=$page';

  String feed(String uuid, {int page = 1}) =>
      '${xdnmbBaseUrl}Api/feed?uuid=${Uri.encodeQueryComponent(uuid)}&page=$page';

  String addFeed(String uuid, int mainPostId) =>
      '${xdnmbBaseUrl}Api/addFeed?uuid=${Uri.encodeQueryComponent(uuid)}&tid=$mainPostId';

  String deleteFeed(String uuid, int mainPostId) =>
      '${xdnmbBaseUrl}Api/delFeed?uuid=${Uri.encodeQueryComponent(uuid)}&tid=$mainPostId';

  String getCookie(int cookieId) =>
      '${xdnmbBaseUrl}Member/User/Cookie/export/id/$cookieId.html';

  String deleteCookie(int cookieId) =>
      '${xdnmbBaseUrl}Member/User/Cookie/delete/id/$cookieId.html';

  static Future<XdnmbUrls> update() async {
    final client = HttpClient()..connectionTimeout = Duration(seconds: 10);

    try {
      var request = await client.getUrl(Uri.parse(_xdnmbOriginUrl));
      request.followRedirects = false;
      var response = await request.close();
      await response.drain();

      final baseUrl = response.isRedirect
          ? (response.headers.value(HttpHeaders.locationHeader) ??
              _xdnmbOriginUrl)
          : _xdnmbOriginUrl;

      request = await client.getUrl(Uri.parse('${baseUrl}Api/getCdnPath'));
      response = await request.close();
      final data = await response.transform(utf8.decoder).join();
      final decoded = json.decode(data);

      var cdnUrl = originCdnUrl;
      if (decoded is List<dynamic> && decoded.isNotEmpty) {
        cdnUrl = decoded[0]['url'] ?? originCdnUrl;
      }

      _urls = XdnmbUrls._internal(baseUrl, cdnUrl);

      return _urls;
    } finally {
      client.close();
    }
  }
}
