import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' hide Client;
import 'package:http/io_client.dart';

import 'client.dart';

/// X岛链接
final class XdnmbUrls {
  /// X岛域名
  static const String xdnmbHost = 'www.nmbxd.com';

  /// 获取CDN链接的接口的路径
  static const String _cdnPath = 'Api/getCdnPath';

  /// 获取备用API链接的接口的路径
  static const String _backupApiPath = 'Api/backupUrl';

  /// X岛初始链接
  static final Uri _originBaseUrl = Uri.parse('https://$xdnmbHost/');

  /// X岛现在的链接
  static final Uri _currentBaseUrl = Uri.parse('https://www.nmbxd1.com/');

  /// X岛现在的CDN链接
  static final Uri _currentCdnUrl = Uri.parse('https://image.nmb.best/');

  /// X岛现在的备用API链接
  static final Uri _currentBackupApiUrl = Uri.parse('https://api.nmb.best/');

  /// X岛公告链接
  static final Uri notice = Uri.parse('https://nmb.ovear.info/nmb-notice.json');

  /// [XdnmbUrls]的单例
  static XdnmbUrls _urls = XdnmbUrls._internal(
      baseUrl: _currentBaseUrl,
      cdnUrl: _currentCdnUrl,
      backupApiUrl: _currentBackupApiUrl);

  /// X岛基础链接
  final Uri baseUrl;

  /// X岛CDN链接
  final Uri cdnUrl;

  /// X岛备用API链接
  final Uri backupApiUrl;

  /// 是否使用备用API链接，默认不使用
  bool useBackupApi = false;

  /// X岛API链接
  Uri get apiUrl => useBackupApi ? backupApiUrl : baseUrl;

  /// CDN列表链接
  Uri get cdnList => apiUrl.replace(path: _cdnPath);

  /// 获取备用API链接的链接
  Uri get backupApiList => apiUrl.replace(path: _backupApiPath);

  /// 版块列表链接
  Uri get forumList => apiUrl.replace(path: 'Api/getForumList');

  /// 时间线列表链接
  Uri get timelineList => apiUrl.replace(path: 'Api/getTimelineList');

  /// 获取最新发的串的链接
  Uri get getLastPost => baseUrl.replace(path: 'Api/getLastPost');

  /// 发串链接
  Uri get postNewThread =>
      baseUrl.replace(path: 'Home/Forum/doPostThread.html');

  /// 回串链接
  Uri get replyThread => baseUrl.replace(path: 'Home/Forum/doReplyThread.html');

  /// 验证码图片链接
  Uri get verifyImage => baseUrl.replace(path: 'Member/User/Index/verify.html');

  /// 用户登陆链接
  Uri get userLogin => baseUrl.replace(path: 'Member/User/Index/login.html');

  /// 用户饼干链接
  Uri get cookiesList => baseUrl.replace(path: 'Member/User/Cookie/index.html');

  /// 获取新饼干链接
  Uri get getNewCookie =>
      baseUrl.replace(path: 'Member/User/Cookie/apply.html');

  /// 注册帐号链接
  Uri get registerAccount =>
      baseUrl.replace(path: 'Member/User/Index/sendRegister.html');

  /// 重置密码链接
  Uri get resetPassword =>
      baseUrl.replace(path: 'Member/User/Index/sendForgotPassword.html');

  /// [XdnmbUrls]的内部构造器
  XdnmbUrls._internal(
      {required this.baseUrl,
      required this.cdnUrl,
      required this.backupApiUrl});

  /// 构造[XdnmbUrls]，返回[XdnmbUrls]单例
  factory XdnmbUrls() => _urls;

  /// 版块链接
  ///
  /// [forumId]为版块ID，[page]从1开始算起
  Uri forum(int forumId, {int page = 1}) => apiUrl.replace(
      path: 'Api/showf', queryParameters: {'id': '$forumId', 'page': '$page'});

  /// 网页版版块链接
  ///
  /// [forumId]为版块ID，[page]从1开始算起
  Uri htmlForum(int forumId, {int page = 1}) => baseUrl.replace(
      path: 'Forum/showf',
      queryParameters: {'id': '$forumId', 'page': '$page'});

  /// 时间线链接
  ///
  /// [timelineId]为时间线ID，[page]从1开始算起
  Uri timeline(int timelineId, {int page = 1}) => apiUrl.replace(
      path: 'Api/timeline',
      queryParameters: {'id': '$timelineId', 'page': '$page'});

  /// 串（帖子）链接
  ///
  /// [mainPostId]为主串ID，[page]从1开始算起
  Uri thread(int mainPostId, {int page = 1}) => apiUrl.replace(
      path: 'Api/thread',
      queryParameters: {'id': '$mainPostId', 'page': '$page'});

  /// 串引用链接
  ///
  /// [postId]为串ID
  Uri reference(int postId) =>
      apiUrl.replace(path: 'Api/ref', queryParameters: {'id': '$postId'});

  /// 网页版串引用链接
  ///
  /// [postId]为串ID
  Uri htmlReference(int postId) => baseUrl
      .replace(path: 'Home/Forum/ref', queryParameters: {'id': '$postId'});

  /// 只看Po主的串的链接
  ///
  /// [mainPostId]为主串ID，[page]从1开始算起
  Uri onlyPoThread(int mainPostId, {int page = 1}) => apiUrl.replace(
      path: 'Api/po', queryParameters: {'id': '$mainPostId', 'page': '$page'});

  /// 订阅链接
  ///
  /// [feedId]为订阅ID，[page]从1开始算起
  Uri feed(String feedId, {int page = 1}) => apiUrl.replace(
      path: 'Api/feed', queryParameters: {'uuid': feedId, 'page': '$page'});

  /// 网页版订阅链接
  ///
  /// [page]从1开始算起
  Uri htmlFeed({int page = 1}) =>
      baseUrl.replace(path: 'Forum/feed/page/$page.html');

  /// 添加订阅的链接
  ///
  /// [feedId]为订阅ID，[mainPostId]为主串ID
  Uri addFeed(String feedId, int mainPostId) => apiUrl.replace(
      path: 'Api/addFeed',
      queryParameters: {'uuid': feedId, 'tid': '$mainPostId'});

  /// 网页版添加订阅的链接
  ///
  /// [mainPostId]为主串ID
  Uri addHtmlFeed(int mainPostId) =>
      baseUrl.replace(path: 'Home/Forum/addFeed/tid/$mainPostId.html');

  /// 删除订阅的链接
  ///
  /// [feedId]为订阅ID，[mainPostId]为主串ID
  Uri deleteFeed(String feedId, int mainPostId) => apiUrl.replace(
      path: 'Api/delFeed',
      queryParameters: {'uuid': feedId, 'tid': '$mainPostId'});

  /// 网页版删除订阅的链接
  ///
  /// [mainPostId]为主串ID
  Uri deleteHtmlFeed(int mainPostId) =>
      baseUrl.replace(path: 'Home/Forum/delFeed/tid/$mainPostId.html');

  /// 获取饼干的链接
  ///
  /// [cookieId]为饼干ID
  Uri getCookie(int cookieId) =>
      baseUrl.replace(path: 'Member/User/Cookie/export/id/$cookieId.html');

  /// 删除饼干的链接
  ///
  /// [cookieId]为饼干ID
  Uri deleteCookie(int cookieId) =>
      baseUrl.replace(path: 'Member/User/Cookie/delete/id/$cookieId.html');

  /// 是否X岛基础链接
  bool isBaseUrl(Uri url) => url.host == baseUrl.host;

  /// 是否X岛备用API链接
  bool isBackupApiUrl(Uri url) => url.host == backupApiUrl.host;

  /// 更新链接
  ///
  /// [client]为http client
  static Future<XdnmbUrls> update([IOClient? client]) async {
    client = client ??
        IOClient(
            HttpClient()..connectionTimeout = Client.defaultConnectionTimeout);

    try {
      final request = Request('GET', _originBaseUrl)..followRedirects = false;
      Response response = await Response.fromStream(await client.send(request));
      final baseUrl = response.isRedirect
          ? Uri.parse(response.headers[HttpHeaders.locationHeader] ??
              _originBaseUrl.toString())
          : _originBaseUrl;

      response = await client.get(baseUrl.replace(path: _cdnPath));
      dynamic decoded = json.decode(response.utf8Body);
      final cdnUrl = (decoded is List<dynamic> && decoded.isNotEmpty)
          ? Uri.parse(decoded[0]['url'] ?? _currentCdnUrl.toString())
          : _currentCdnUrl;

      response = await client.get(baseUrl.replace(path: _backupApiPath));
      decoded = json.decode(response.utf8Body);
      final backupApiUrl = (decoded is List<dynamic> && decoded.isNotEmpty)
          ? Uri.parse(decoded[0] ?? _currentBackupApiUrl.toString())
          : _currentBackupApiUrl;

      final urls = XdnmbUrls._internal(
          baseUrl: baseUrl, cdnUrl: cdnUrl, backupApiUrl: backupApiUrl)
        ..useBackupApi = _urls.useBackupApi;
      _urls = urls;

      return _urls;
    } catch (e) {
      rethrow;
    }
  }
}
