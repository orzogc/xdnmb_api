import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:mime/mime.dart';

import 'client.dart';
import 'urls.dart';

part 'cookie.dart';

/// X岛API的异常
class XdnmbApiException implements Exception {
  /// 异常信息
  final String message;

  /// 构造[XdnmbApiException]
  const XdnmbApiException(this.message);

  @override
  String toString() {
    return 'XdnmbApiException: $message';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XdnmbApiException && message == other.message);

  @override
  int get hashCode => message.hashCode;
}

/// 公告
class Notice {
  /// 公告内容
  final String content;

  /// 公告发布的日期，只有年月日
  final DateTime date;

  /// 公告索引
  final int index;

  /// 公告是否有效
  final bool isValid;

  /// 构造[Notice]
  const Notice(this.content, this.date, this.index, [this.isValid = true]);

  /// 从JSON数据构造[Notice]
  factory Notice._fromJson(String data) {
    final Map<String, dynamic> decoded = json.decode(data);

    final String content = decoded['content'];
    final String dateString = decoded['date'].toString();
    final bool isValid = decoded['enable'] ?? false;

    final date = DateTime(
        int.parse(dateString.substring(0, 4)),
        int.parse(dateString.substring(4, 6)),
        int.parse(dateString.substring(6, 8)));
    final index = int.parse(dateString.substring(8));

    return Notice(content, date, index, isValid);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notice &&
          content == other.content &&
          date == other.date &&
          index == other.index &&
          isValid == other.isValid);

  @override
  int get hashCode => Object.hash(content, date, index, isValid);
}

/// X岛CDN
class Cdn {
  /// X岛CDN链接
  final String url;

  /// 比例？
  final double rate;

  /// 构造[Cdn]
  const Cdn(this.url, [this.rate = 0.0]);

  /// 略缩图链接
  String thumbImageUrl(PostBase post) => '${url}thumb/${post.imageFile}';

  /// 大图链接
  String imageUrl(PostBase post) => '${url}image/${post.imageFile}';

  /// 从JSON数据构造[Cdn]列表
  static List<Cdn> _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    String getUrl(Map<String, dynamic> map) {
      final url = map['url'];
      if (url == null) {
        throw XdnmbApiException('找不到url');
      }

      return url;
    }

    return <Cdn>[
      for (final Map<String, dynamic> map in decoded)
        Cdn(getUrl(map), map['rate'] ?? 0.0)
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cdn && url == other.url && rate == other.rate);

  @override
  int get hashCode => Object.hash(url, rate);
}

/// 版块的基本类型，其他版块类型要实现[ForumBase]
abstract class ForumBase {
  /// 版块ID
  int get id;

  /// 版块名字
  String get name;

  /// 版块显示的名字，如果是空字符串的话应该要显示[name]
  String get displayName;

  /// 版块信息
  String get message;

  /// 版块的最大页数，大于[maxPage]的均返回页数为[maxPage]的内容
  int get maxPage;

  /// 构造[ForumBase]
  const ForumBase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForumBase &&
          id == other.id &&
          name == other.name &&
          displayName == other.displayName &&
          message == other.message &&
          maxPage == other.maxPage);

  @override
  int get hashCode => Object.hash(id, name, displayName, message, maxPage);
}

/// [ForumBase]的扩展
extension ForumBaseExtension on ForumBase {
  /// 版块显示的名字
  String get showName => displayName.isNotEmpty ? displayName : name;
}

/// 时间线
class Timeline implements ForumBase {
  @override
  final int id;

  @override
  final String name;

  @override
  final String displayName;

  @override
  final String message;

  /// 时间线的最大页数，大于[maxPage]的均返回页数为[maxPage]的内容，默认为20
  @override
  final int maxPage;

  /// 构造[Timeline]
  const Timeline(
      {required this.id,
      required this.name,
      this.displayName = '',
      required this.message,
      this.maxPage = 20});

  /// 从JSON数据构造[Timeline]列表
  static List<Timeline> _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    return <Timeline>[
      for (final Map<String, dynamic> map in decoded)
        Timeline(
            id: map['id'],
            name: map['name'] ?? '未知时间线',
            displayName: map['display_name'] ?? '',
            message: map['notice'] ?? '',
            maxPage: map['max_page'] ?? 20)
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Timeline &&
          id == other.id &&
          name == other.name &&
          displayName == other.displayName &&
          message == other.message &&
          maxPage == other.maxPage);

  @override
  int get hashCode => Object.hash(id, name, displayName, message, maxPage);
}

/// 版块组
class ForumGroup {
  /// 版块组ID
  final int id;

  /// 版块组显示的排序，小的在前面
  final int sort;

  /// 版块组名字
  final String name;

  /// 总是'n'
  final String status;

  /// 构造[ForumGroup]
  const ForumGroup(
      {required this.id, this.sort = 1, required this.name, this.status = 'n'});

  /// 从map数据中构造[ForumGroup]
  ForumGroup._fromMap(Map<String, dynamic> map)
      : id = int.parse(map['id']),
        sort = int.tryParse(map['sort'] ?? '1') ?? 1,
        name = map['name'] ?? '未知版块组',
        status = map['status'] ?? 'n';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForumGroup &&
          id == other.id &&
          sort == other.sort &&
          name == other.name &&
          status == other.status);

  @override
  int get hashCode => Object.hash(id, sort, name, status);
}

/// 版块
class Forum implements ForumBase {
  @override
  final int id;

  /// 版块组ID
  final int forumGroupId;

  /// 版块显示的排序，小的在前面
  final int sort;

  @override
  final String name;

  @override
  final String displayName;

  /// 版规
  @override
  final String message;

  /// 版块内发串的最小时间间隔，单位为秒
  final int interval;

  /// 是否保护模式
  final bool safeMode;

  /// 自动删除串的时间间隔？
  final int autoDelete;

  /// 版块内主串数量，包括被删除的串
  final int threadCount;

  /// 大于0时需要饼干访问版块，数值是最低饼干槽要求？
  final int permissionLevel;

  final int forumFuseId;

  /// 版块创建时间，不一定准确
  final String createTime;

  /// 版块更新时间，不一定准确
  final String updateTime;

  /// 总是'n'
  final String status;

  /// 版块的最大页数，大于[maxPage]的均返回页数为[maxPage]的内容，
  /// 版块的最大页数的值最大为100
  @override
  int get maxPage =>
      threadCount > 0 ? (min((threadCount / 20).ceil(), 100)) : 1;

  /// 构造[Forum]
  const Forum(
      {required this.id,
      this.forumGroupId = 4,
      this.sort = 1,
      required this.name,
      this.displayName = '',
      required this.message,
      this.interval = 30,
      this.safeMode = false,
      this.autoDelete = 0,
      required this.threadCount,
      this.permissionLevel = 0,
      this.forumFuseId = 0,
      this.createTime = '',
      this.updateTime = '',
      this.status = 'n'});

  /// 从map数据构造[Forum]
  Forum._fromMap(Map<String, dynamic> map)
      : id = int.parse(map['id']),
        forumGroupId = int.tryParse(map['fgroup'] ?? '4') ?? 4,
        sort = int.tryParse(map['sort'] ?? '1') ?? 1,
        name = map['name'] ?? '未知版块',
        displayName = map['showName'] ?? '',
        message = map['msg'] ?? '',
        interval = int.tryParse(map['interval'] ?? '30') ?? 30,
        safeMode = (int.tryParse(map['safe_mode'] ?? '0') ?? 0) != 0,
        autoDelete = int.tryParse(map['auto_delete'] ?? '0') ?? 0,
        threadCount = int.tryParse(map['thread_count'] ?? '0') ?? 0,
        permissionLevel = int.tryParse(map['permission_level'] ?? '0') ?? 0,
        forumFuseId = int.tryParse(map['forum_fuse_id'] ?? '0') ?? 0,
        createTime = map['createdAt'] ?? '',
        updateTime = map['updateAt'] ?? '',
        status = map['status'] ?? 'n';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Forum &&
          id == other.id &&
          forumGroupId == other.forumGroupId &&
          sort == other.sort &&
          name == other.name &&
          displayName == other.displayName &&
          message == other.message &&
          interval == other.interval &&
          threadCount == other.threadCount &&
          permissionLevel == other.permissionLevel &&
          forumFuseId == other.forumFuseId &&
          createTime == other.createTime &&
          updateTime == other.updateTime &&
          status == other.status &&
          maxPage == other.maxPage);

  @override
  int get hashCode => Object.hash(
      id,
      forumGroupId,
      sort,
      name,
      displayName,
      message,
      interval,
      threadCount,
      permissionLevel,
      forumFuseId,
      createTime,
      updateTime,
      status,
      maxPage);
}

/// 版块列表
class ForumList {
  /// 版块群列表
  final List<ForumGroup> forumGroupList;

  /// 版块列表
  final List<Forum> forumList;

  /// 时间线列表
  final List<Timeline>? timelineList;

  /// 构造[ForumList]
  const ForumList(this.forumGroupList, this.forumList, [this.timelineList]);

  /// 从JSON数据构造[ForumList]
  factory ForumList._fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);
    final forumGroupList = <ForumGroup>[];
    final forumList = <Forum>[];
    List<Timeline>? timelineList;

    for (final Map<String, dynamic> map in decoded) {
      forumGroupList.add(ForumGroup._fromMap(map));

      for (final Map<String, dynamic> forum in map['forums']) {
        final id = int.parse(forum['id']);
        if (id < 0) {
          timelineList ??= <Timeline>[];
          timelineList.add(Timeline(
              id: id,
              name: forum['name'] ?? '未知时间线',
              message: forum['msg'] ?? ''));
        } else {
          forumList.add(Forum._fromMap(forum));
        }
      }
    }

    return ForumList(forumGroupList, forumList, timelineList);
  }
}

/// 网页版版块
class HtmlForum implements ForumBase {
  @override
  final int id;

  @override
  final String name;

  /// 总是返回空字符串，所以版块名字显示用[name]
  @override
  String get displayName => '';

  /// 版规
  @override
  final String message;

  /// 版块的最大页数，大于[maxPage]的均返回页数为[maxPage]的内容，版块的最大页数总是100
  @override
  int get maxPage => 100;

  /// 构造[HtmlForum]
  const HtmlForum(
      {required this.id, required this.name, required this.message});

  /// 从HTML数据构造[HtmlForum]，[forumId]为版块ID
  factory HtmlForum._fromHtml(int forumId, String data) {
    final document = parse(data);
    _handleDocument(document);

    Element? element = document.querySelector('h2.h-title');
    if (element == null) {
      throw XdnmbApiException('没找到版块名字');
    }
    final name = element.innerHtml;

    element = document.querySelector('div.h-forum-header');
    if (element == null) {
      throw XdnmbApiException('没找到版块信息');
    }
    final message = element.innerHtml._trimWhiteSpace();

    return HtmlForum(id: forumId, name: name, message: message);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HtmlForum &&
          id == other.id &&
          name == other.name &&
          displayName == other.displayName &&
          message == other.message &&
          maxPage == other.maxPage);

  @override
  int get hashCode => Object.hash(id, name, displayName, message, maxPage);
}

/// 串的基本类型，其他串类型要实现[PostBase]
abstract class PostBase {
  /// 串的ID
  int get id;

  /// 串所在版块的ID
  ///
  /// 主串的[forumId]跟随实际版块，但由于移串，回串的[forumId]可能和主串的不相等
  int? get forumId;

  /// 主串的回串数量，包含被删除的串，回串的[replyCount]为0
  int? get replyCount;

  /// 图片
  String get image;

  /// 图片的扩展名
  String get imageExtension;

  /// 发表时间
  DateTime get postTime;

  /// 用户饼干名字
  String get userHash;

  /// 串的名称
  String get name;

  /// 串的标题
  String get title;

  /// 串的内容
  String get content;

  /// 串是否sage（锁住回复）
  bool? get isSage;

  /// 用户是否管理员（红名）
  bool get isAdmin;

  /// 串是否被隐藏
  bool? get isHidden;

  /// 构造[PostBase]
  const PostBase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostBase &&
          id == other.id &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          title == other.title &&
          content == other.content &&
          isSage == other.isSage &&
          isAdmin == other.isAdmin &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(
      id,
      forumId,
      replyCount,
      image,
      imageExtension,
      postTime,
      userHash,
      name,
      title,
      content,
      isSage,
      isAdmin,
      isHidden);
}

/// [PostBase]的扩展
extension BasePostExtension on PostBase {
  /// 主串可能的最大页数
  int? get maxPage => replyCount != null
      ? replyCount! > 0
          ? (replyCount! / 19).ceil()
          : (replyCount! == 0 ? 1 : null)
      : null;

  /// 串是否有图片
  bool get hasImage => image.isNotEmpty;

  /// 串图片名字
  String? get imageFile => hasImage ? '$image$imageExtension' : null;

  /// 串略缩图链接
  String? get thumbImageUrl =>
      hasImage ? '${XdnmbUrls().cdnUrl}thumb/$imageFile' : null;

  /// 串大图链接
  String? get imageUrl =>
      hasImage ? '${XdnmbUrls().cdnUrl}image/$imageFile' : null;
}

/// 串
class Post implements PostBase {
  @override
  final int id;

  @override
  final int forumId;

  @override
  final int replyCount;

  @override
  final String image;

  @override
  final String imageExtension;

  @override
  final DateTime postTime;

  @override
  final String userHash;

  @override
  final String name;

  @override
  final String title;

  @override
  final String content;

  @override
  final bool isSage;

  @override
  final bool isAdmin;

  @override
  final bool isHidden;

  /// 构造[Post]
  const Post(
      {required this.id,
      required this.forumId,
      required this.replyCount,
      this.image = '',
      this.imageExtension = '',
      required this.postTime,
      required this.userHash,
      this.name = '无名氏',
      this.title = '无标题',
      required this.content,
      this.isSage = false,
      this.isAdmin = false,
      this.isHidden = false});

  /// 从map数据构造[Post]
  Post._formMap(Map<String, dynamic> map)
      : id = map['id'],
        forumId = map['fid'],
        replyCount = map['ReplyCount'] ?? 0,
        image = map['img'] ?? '',
        imageExtension = map['ext'] ?? '',
        postTime = _parseTimeString(map['now']),
        userHash = map['user_hash'],
        name = map['name'] ?? '无名氏',
        title = map['title'] ?? '无标题',
        content = map['content'],
        isSage = (map['sage'] ?? 0) != 0,
        isAdmin = (map['admin'] ?? 0) != 0,
        isHidden = (map['Hide'] ?? 0) != 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Post &&
          id == other.id &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          title == other.title &&
          content == other.content &&
          isSage == other.isSage &&
          isAdmin == other.isAdmin &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(
      id,
      forumId,
      replyCount,
      image,
      imageExtension,
      postTime,
      userHash,
      name,
      title,
      content,
      isSage,
      isAdmin,
      isHidden);
}

/// 版块里的串
class ForumThread {
  /// 主串
  final Post mainPost;

  /// 主串的最后的回复，最多5个。
  ///
  /// 由于删串的原因，即使[mainPost]的`replyCount`大于5，[recentReplies]的长度也不一定等于5，
  /// 而且[mainPost]的`replyCount`小于等于5时和[recentReplies]的长度也不一定相等。
  final List<Post> recentReplies;

  /// 除去[recentReplies]外剩下的回复的数量
  final int? remainReplies;

  /// 主串可能的最大页数
  int get maxPage =>
      mainPost.replyCount > 0 ? (mainPost.replyCount / 19).ceil() : 1;

  /// 构造[ForumThread]
  const ForumThread(this.mainPost, this.recentReplies, [this.remainReplies]);

  /// 从JSON数据构造[ForumThread]列表
  static List<ForumThread> _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    return <ForumThread>[
      for (final Map<String, dynamic> forumThread in decoded)
        ForumThread(
            Post._formMap(forumThread),
            <Post>[
              for (final Map<String, dynamic> reply in forumThread['Replies'])
                Post._formMap(reply)
            ],
            forumThread['RemainReplies'])
    ];
  }
}

/// X岛匿名版官方tip，一部分是广告
class Tip implements PostBase {
  /// 串的ID，默认为`9999999`
  @override
  final int id;

  @override
  final String userHash;

  /// 用户是否管理员（红名），默认是红名
  @override
  final bool isAdmin;

  @override
  final String title;

  @override
  final DateTime postTime;

  @override
  final String content;

  @override
  final String image;

  @override
  final String imageExtension;

  @override
  final String name;

  /// 串所在版块的ID，总是返回`null`
  @override
  int? get forumId => null;

  /// 串的回串数量，总是返回`null`
  @override
  int? get replyCount => null;

  /// 串是否sage，总是返回`null`
  @override
  bool? get isSage => null;

  /// 串是否被隐藏，总是返回`null`
  @override
  bool? get isHidden => null;

  /// 构造[Tip]
  const Tip(
      {this.id = 9999999,
      required this.userHash,
      this.isAdmin = true,
      this.title = '无标题',
      required this.postTime,
      required this.content,
      this.image = '',
      this.imageExtension = '',
      this.name = '无名氏'});

  /// 从map数据构造[Tip]
  Tip._fromMap(Map<String, dynamic> map)
      : id = map['id'] ?? 9999999,
        userHash = map['user_hash'] ?? '',
        isAdmin = (map['admin'] ?? 1) != 0,
        title = map['title'] ?? '无标题',
        postTime = _parseTimeString(map['now'] ?? '2099-01-01 00:00:01'),
        content = map['content'] ?? '',
        image = map['img'] ?? '',
        imageExtension = map['ext'] ?? '',
        name = map['name'] ?? '无名氏';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tip &&
          id == other.id &&
          userHash == other.userHash &&
          isAdmin == other.isAdmin &&
          title == other.title &&
          postTime == other.postTime &&
          content == other.content &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          name == other.name &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          isSage == other.isSage &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(
      id,
      userHash,
      isAdmin,
      title,
      postTime,
      content,
      image,
      imageExtension,
      name,
      forumId,
      replyCount,
      isSage,
      isHidden);
}

/// 帖子（串）
class Thread {
  /// 主串
  final Post mainPost;

  /// 主串某一页的回复
  ///
  /// [replies]长度为0时可能这一页和后面的页数都没有回复，
  /// 也有可能是因为这一页的回复都被删光，可利用[maxPage]判断
  ///
  /// 通常一页最多19个回复
  final List<Post> replies;

  /// 官方tip，随机出现
  final Tip? tip;

  /// 主串可能的最大页数
  int get maxPage =>
      mainPost.replyCount > 0 ? (mainPost.replyCount / 19).ceil() : 1;

  /// 构造[Thread]
  const Thread(this.mainPost, this.replies, [this.tip]);

  /// 从JSON数据构造[Thread]
  factory Thread._fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    final mainPost = Post._formMap(decoded);
    late final List<Post> replies;
    Tip? tip;
    final List<dynamic> replyList = decoded['Replies'];

    if (replyList.isNotEmpty) {
      if (replyList[0]['fid'] == null) {
        tip = Tip._fromMap(replyList[0]);
      } else {
        tip = null;
      }
      replies = <Post>[
        for (final Map<String, dynamic> reply
            in tip == null ? replyList : replyList.skip(1))
          Post._formMap(reply)
      ];
    } else {
      replies = <Post>[];
      tip = null;
    }

    return Thread(mainPost, replies, tip);
  }
}

/// 串引用的基础类型，其他串引用类型要继承[ReferenceBase]
abstract class ReferenceBase implements PostBase {
  /// 串所在版块的ID，总是返回`null`
  @override
  int? get forumId => null;

  /// 串的回串数量，总是返回`null`
  @override
  int? get replyCount => null;

  /// 串是否被隐藏，总是返回`null`
  @override
  bool? get isHidden => null;

  /// 构造[ReferenceBase]
  const ReferenceBase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceBase &&
          id == other.id &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          title == other.title &&
          content == other.content &&
          isSage == other.isSage &&
          isAdmin == other.isAdmin &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(id, image, imageExtension, postTime, userHash,
      name, title, content, isSage, isAdmin, forumId, replyCount, isHidden);
}

/// 串引用
class Reference extends ReferenceBase {
  @override
  final int id;

  @override
  final String image;

  @override
  final String imageExtension;

  @override
  final DateTime postTime;

  @override
  final String userHash;

  @override
  final String name;

  @override
  final String title;

  @override
  final String content;

  @override
  final bool isSage;

  /// 总是'n'
  final String status;

  @override
  final bool isAdmin;

  /// 构造[Reference]
  const Reference(
      {required this.id,
      this.image = '',
      this.imageExtension = '',
      required this.postTime,
      required this.userHash,
      this.name = '无名氏',
      this.title = '无标题',
      required this.content,
      this.isSage = false,
      this.status = 'n',
      this.isAdmin = false});

  /// 从JSON数据构造[Reference]
  factory Reference._fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    final id = decoded['id'];
    final image = decoded['img'] ?? '';
    final imageExtension = decoded['ext'] ?? '';
    final postTime = _parseTimeString(decoded['now']);
    final userHash = decoded['user_hash'];
    final name = decoded['name'] ?? '无名氏';
    final title = decoded['title'] ?? '无标题';
    final content = decoded['content'];
    final isSage = (decoded['sage'] ?? 0) != 0;
    final status = decoded['status'] ?? 'n';
    final isAdmin = (decoded['admin'] ?? 0) != 0;

    return Reference(
        id: id,
        image: image,
        imageExtension: imageExtension,
        postTime: postTime,
        userHash: userHash,
        name: name,
        title: title,
        content: content,
        isSage: isSage,
        status: status,
        isAdmin: isAdmin);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reference &&
          id == other.id &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          title == other.title &&
          content == other.content &&
          isSage == other.isSage &&
          status == other.status &&
          isAdmin == other.isAdmin &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(
      id,
      image,
      imageExtension,
      postTime,
      userHash,
      name,
      title,
      content,
      isSage,
      status,
      isAdmin,
      forumId,
      replyCount,
      isHidden);
}

/// 网页版串引用
class HtmlReference extends ReferenceBase {
  @override
  final int id;

  @override
  final String image;

  @override
  final String imageExtension;

  @override
  final DateTime postTime;

  @override
  final String userHash;

  @override
  final String name;

  @override
  final String title;

  @override
  final String content;

  @override
  final bool isAdmin;

  /// 主串ID，目前只有引用串是主串才不是`null`
  final int? mainPostId;

  /// 串是否sage，总是返回`null`
  @override
  bool? get isSage => null;

  /// 构造[HtmlReference]
  const HtmlReference(
      {required this.id,
      this.image = '',
      this.imageExtension = '',
      required this.postTime,
      required this.userHash,
      this.name = '无名氏',
      this.title = '无标题',
      required this.content,
      this.isAdmin = false,
      this.mainPostId});

  /// 从HTML数据构造[HtmlReference]
  factory HtmlReference._fromHtml(String data) {
    final document = parse(data);
    _handleDocument(document);

    Element? element = document.querySelector('a.h-threads-info-id');
    if (element == null) {
      throw XdnmbApiException('HtmlReference里没找到id');
    }
    final str = _RegExp._parseNum.stringMatch(element.innerHtml);
    if (str == null) {
      throw XdnmbApiException('该串不存在');
    }
    final id = int.parse(str);

    int? mainPostId;
    final href = element.attributes['href'];
    if (href != null) {
      final str = _RegExp._parseMainPostId.firstMatch(href)?[1];
      if (str != null) {
        mainPostId = int.parse(str);
      } else {
        mainPostId = null;
      }
    } else {
      mainPostId = null;
    }

    late final String image;
    late final String imageExtension;
    element = document.querySelector('img.h-threads-img');
    if (element == null) {
      image = '';
      imageExtension = '';
    } else {
      final img = element.attributes['src'];
      if (img == null) {
        throw XdnmbApiException('HtmlReference里没找到image');
      }
      final match = _RegExp._parseThumbImage.firstMatch(img);
      if (match == null) {
        throw XdnmbApiException('HtmlReference里没找到image');
      }
      image = match[1]!;
      imageExtension = match[2] ?? '';
    }

    element = document.querySelector('span.h-threads-info-createdat');
    if (element == null) {
      throw XdnmbApiException('HtmlReference里没找到postTime');
    }
    final postTime = _parseTimeString(element.innerHtml);

    late final String userHash;
    late final bool isAdmin;
    element = document.querySelector('span.h-threads-info-uid');
    if (element == null) {
      throw XdnmbApiException('HtmlReference里没找到userHash');
    }
    final child = element.querySelector('font');
    if (child != null) {
      isAdmin = true;
      userHash = child.innerHtml;
    } else {
      isAdmin = false;
      final match = _RegExp._parseUserHash.firstMatch(element.innerHtml);
      if (match == null) {
        throw XdnmbApiException('HtmlReference里没找到userHash');
      }
      userHash = match[1]!;
    }

    element = document.querySelector('span.h-threads-info-email');
    if (element == null) {
      throw XdnmbApiException('HtmlReference里没找到name');
    }
    final name = element.innerHtml;

    element = document.querySelector('span.h-threads-info-title');
    if (element == null) {
      throw XdnmbApiException('HtmlReference里没找到title');
    }
    final title = element.innerHtml;

    element = document.querySelector('div.h-threads-content');
    if (element == null) {
      throw XdnmbApiException('HtmlReference里没找到content');
    }
    final content = element.innerHtml._trimWhiteSpace();

    return HtmlReference(
        id: id,
        image: image,
        imageExtension: imageExtension,
        postTime: postTime,
        userHash: userHash,
        name: name,
        title: title,
        content: content,
        isAdmin: isAdmin,
        mainPostId: mainPostId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HtmlReference &&
          id == other.id &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          title == other.title &&
          content == other.content &&
          isAdmin == other.isAdmin &&
          mainPostId == other.mainPostId &&
          isSage == other.isSage &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(
      id,
      image,
      imageExtension,
      postTime,
      userHash,
      name,
      title,
      content,
      isAdmin,
      mainPostId,
      isSage,
      forumId,
      replyCount,
      isHidden);
}

/// 订阅
class Feed implements PostBase {
  @override
  final int id;

  /// 主串用户ID
  final int userId;

  @override
  final int forumId;

  @override
  final int replyCount;

  /// 最近回复的串的ID，最多5个
  final List<int> recentReplies;

  /// 总是空字符串
  final String category;

  /// 图片的文件ID
  final int fileId;

  @override
  final String image;

  @override
  final String imageExtension;

  @override
  final DateTime postTime;

  @override
  final String userHash;

  @override
  final String name;

  /// 串的邮箱
  final String email;

  @override
  final String title;

  @override
  final String content;

  /// 总是'n'
  final String status;

  @override
  final bool isAdmin;

  @override
  final bool isHidden;

  /// 总是空字符串
  final String po;

  /// 串是否sage，总是返回`null`
  @override
  bool? get isSage => null;

  /// 构造[Feed]
  const Feed(
      {required this.id,
      this.userId = 0,
      required this.forumId,
      required this.replyCount,
      required this.recentReplies,
      this.category = '',
      this.fileId = 0,
      this.image = '',
      this.imageExtension = '',
      required this.postTime,
      required this.userHash,
      this.name = '',
      this.email = '',
      this.title = '',
      required this.content,
      this.status = 'n',
      this.isAdmin = false,
      this.isHidden = false,
      this.po = ''});

  /// 从JSON数据构造[Feed]列表
  static List<Feed> _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    return <Feed>[
      for (final Map<String, dynamic> map in decoded)
        Feed(
            id: int.parse(map['id']),
            userId: int.tryParse(map['user_id'] ?? '0') ?? 0,
            forumId: int.parse(map['fid']),
            replyCount: int.tryParse(map['reply_count'] ?? '0') ?? 0,
            recentReplies: (map['recent_replies'] ?? '').isEmpty
                ? <int>[]
                : List<int>.from(json.decode(map['recent_replies'])),
            category: map['category'] ?? '',
            fileId: int.tryParse(map['file_id'] ?? '0') ?? 0,
            image: map['img'] ?? '',
            imageExtension: map['ext'] ?? '',
            postTime: _parseTimeString(map['now']),
            userHash: map['user_hash'],
            name: map['name'] ?? '',
            email: map['email'] ?? '',
            title: map['title'] ?? '',
            content: map['content'],
            status: map['status'] ?? 'n',
            isAdmin: (int.tryParse(map['admin'] ?? '0') ?? 0) != 0,
            isHidden: (int.tryParse(map['hide'] ?? '0') ?? 0) != 0,
            po: map['po'] ?? '')
    ];
  }
}

/// 最新发的串
class LastPost implements PostBase {
  @override
  final int id;

  /// 主串ID，为`null`说明[LastPost]是主串
  final int? mainPostId;

  @override
  final DateTime postTime;

  @override
  final String userHash;

  @override
  final String name;

  /// 串的邮箱
  final String email;

  @override
  final String title;

  @override
  final String content;

  @override
  final bool isSage;

  @override
  final bool isAdmin;

  /// 串所在版块的ID，总是返回`null`
  @override
  int? get forumId => null;

  /// 主串的回串数量，总是返回`null`
  @override
  int? get replyCount => null;

  /// 图片，总是返回空字符串
  @override
  String get image => '';

  /// 图片的扩展名，总是返回空字符串
  @override
  String get imageExtension => '';

  /// 串是否被隐藏，总是返回`null`
  @override
  bool? get isHidden => null;

  /// 构造[LastPost]
  const LastPost(
      {required this.id,
      this.mainPostId,
      required this.postTime,
      required this.userHash,
      this.name = '无名氏',
      this.email = '',
      this.title = '无标题',
      required this.content,
      this.isSage = false,
      this.isAdmin = false});

  /// 从JSON数据构造[LastPost]
  static LastPost? _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    if (decoded is Map<String, dynamic>) {
      final int? mainPostId = decoded['resto'];

      return LastPost(
          id: decoded['id'],
          mainPostId: mainPostId != 0 ? mainPostId : null,
          postTime: _parseTimeString(decoded['now']),
          userHash: decoded['user_hash'],
          name: decoded['name'] ?? '无名氏',
          email: decoded['email'] ?? '',
          title: decoded['title'] ?? '无标题',
          content: decoded['content'],
          isSage: (decoded['sage'] ?? 0) != 0,
          isAdmin: (decoded['admin'] ?? 0) != 0);
    } else {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LastPost &&
          id == other.id &&
          mainPostId == other.mainPostId &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          email == other.email &&
          title == other.title &&
          content == other.content &&
          isSage == other.isSage &&
          isAdmin == other.isAdmin &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          isHidden == other.isHidden);

  @override
  int get hashCode => Object.hash(
      id,
      mainPostId,
      postTime,
      userHash,
      name,
      email,
      title,
      content,
      isSage,
      isAdmin,
      forumId,
      replyCount,
      image,
      imageExtension,
      isHidden);
}

/// 图片类型，目前X岛只支持`jpeg`、`png`、`gif`三种图片格式
enum ImageType {
  jpeg,
  png,
  gif;

  /// 图片类型的mine type
  String mineType() {
    switch (this) {
      case jpeg:
        return 'image/jpeg';
      case png:
        return 'image/png';
      case gif:
        return 'image/gif';
    }
  }

  /// 从mine type构造[ImageType]
  static ImageType? fromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return jpeg;
      case 'image/png':
        return png;
      case 'image/gif':
        return gif;
      default:
        return null;
    }
  }
}

/// 图片
class Image {
  /// 图片名字
  final String filename;

  /// 图片数据
  final List<int> data;

  /// 图片类型
  late final ImageType imageType;

  /// 构造[Image]
  Image(this.filename, this.data, [ImageType? imageType]) {
    if (imageType != null) {
      this.imageType = imageType;
    } else {
      final mimeType = lookupMimeType(filename, headerBytes: data);

      if (mimeType == null) {
        throw XdnmbApiException('无效的图片格式');
      } else {
        final imageType = ImageType.fromMimeType(mimeType);

        if (imageType == null) {
          throw XdnmbApiException('无效的图片格式');
        } else {
          this.imageType = imageType;
        }
      }
    }
  }

  /// 读取图片文件，返回[Image]
  static Future<Image> fromFile(String path) async {
    final file = File(path);
    final filename = file.uri.pathSegments.last;
    final data = await file.readAsBytes();

    return Image(filename, data);
  }
}

/// 颜文字
class Emoticon {
  /// X岛匿名版官方颜文字列表
  static const List<Emoticon> list = [
    Emoticon(name: '|∀ﾟ', text: '|∀ﾟ'),
    Emoticon(name: '(´ﾟДﾟ`)', text: '(´ﾟДﾟ`)'),
    Emoticon(name: '(;´Д`)', text: '(;´Д`)'),
    Emoticon(name: '(｀･ω･)', text: '(｀･ω･)'),
    Emoticon(name: '(=ﾟωﾟ)=', text: '(=ﾟωﾟ)='),
    Emoticon(name: '| ω・´)', text: '| ω・´)'),
    Emoticon(name: '|-` )', text: '|-` )'),
    Emoticon(name: '|д` )', text: '|д` )'),
    Emoticon(name: '|ー` )', text: '|ー` )'),
    Emoticon(name: '|∀` )', text: '|∀` )'),
    Emoticon(name: '(つд⊂)', text: '(つд⊂)'),
    Emoticon(name: '(ﾟДﾟ≡ﾟДﾟ)', text: '(ﾟДﾟ≡ﾟДﾟ)'),
    Emoticon(name: '(＾o＾)ﾉ', text: '(＾o＾)ﾉ'),
    Emoticon(name: '(|||ﾟДﾟ)', text: '(|||ﾟДﾟ)'),
    Emoticon(name: '( ﾟ∀ﾟ)', text: '( ﾟ∀ﾟ)'),
    Emoticon(name: '( ´∀`)', text: '( ´∀`)'),
    Emoticon(name: '(*´∀`)', text: '(*´∀`)'),
    Emoticon(name: '(*ﾟ∇ﾟ)', text: '(*ﾟ∇ﾟ)'),
    Emoticon(name: '(*ﾟーﾟ)', text: '(*ﾟーﾟ)'),
    Emoticon(name: '(　ﾟ 3ﾟ)', text: '(　ﾟ 3ﾟ)'),
    Emoticon(name: '( ´ー`)', text: '( ´ー`)'),
    Emoticon(name: '( ・_ゝ・)', text: '( ・_ゝ・)'),
    Emoticon(name: '( ´_ゝ`)', text: '( ´_ゝ`)'),
    Emoticon(name: '(*´д`)', text: '(*´д`)'),
    Emoticon(name: '(・ー・)', text: '(・ー・)'),
    Emoticon(name: '(・∀・)', text: '(・∀・)'),
    Emoticon(name: '(ゝ∀･)', text: '(ゝ∀･)'),
    Emoticon(name: '(〃∀〃)', text: '(〃∀〃)'),
    Emoticon(name: '(*ﾟ∀ﾟ*)', text: '(*ﾟ∀ﾟ*)'),
    Emoticon(name: '( ﾟ∀。)', text: '( ﾟ∀。)'),
    Emoticon(name: '( `д´)', text: '( `д´)'),
    Emoticon(name: '(`ε´ )', text: '(`ε´ )'),
    Emoticon(name: '(`ヮ´ )', text: '(`ヮ´ )'),
    Emoticon(name: 'σ`∀´)', text: 'σ`∀´)'),
    Emoticon(name: ' ﾟ∀ﾟ)σ', text: ' ﾟ∀ﾟ)σ'),
    Emoticon(name: 'ﾟ ∀ﾟ)ノ', text: 'ﾟ ∀ﾟ)ノ'),
    Emoticon(name: '(╬ﾟдﾟ)', text: '(╬ﾟдﾟ)'),
    Emoticon(name: '(|||ﾟдﾟ)', text: '(|||ﾟдﾟ)'),
    Emoticon(name: '( ﾟдﾟ)', text: '( ﾟдﾟ)'),
    Emoticon(name: 'Σ( ﾟдﾟ)', text: 'Σ( ﾟдﾟ)'),
    Emoticon(name: '( ;ﾟдﾟ)', text: '( ;ﾟдﾟ)'),
    Emoticon(name: '( ;´д`)', text: '( ;´д`)'),
    Emoticon(name: '(　д ) ﾟ ﾟ', text: '(　д ) ﾟ ﾟ'),
    Emoticon(name: '( ☉д⊙)', text: '( ☉д⊙)'),
    Emoticon(name: '(((　ﾟдﾟ)))', text: '(((　ﾟдﾟ)))'),
    Emoticon(name: '( ` ・´)', text: '( ` ・´)'),
    Emoticon(name: '( ´д`)', text: '( ´д`)'),
    Emoticon(name: '( -д-)', text: '( -д-)'),
    Emoticon(name: '(>д<)', text: '(>д<)'),
    Emoticon(name: '･ﾟ( ﾉд`ﾟ)', text: '･ﾟ( ﾉд`ﾟ)'),
    Emoticon(name: '( TдT)', text: '( TдT)'),
    Emoticon(name: '(￣∇￣)', text: '(￣∇￣)'),
    Emoticon(name: '(￣3￣)', text: '(￣3￣)'),
    Emoticon(name: '(￣ｰ￣)', text: '(￣ｰ￣)'),
    Emoticon(name: '(￣ . ￣)', text: '(￣ . ￣)'),
    Emoticon(name: '(￣皿￣)', text: '(￣皿￣)'),
    Emoticon(name: '(￣艸￣)', text: '(￣艸￣)'),
    Emoticon(name: '(￣︿￣)', text: '(￣︿￣)'),
    Emoticon(name: '(￣︶￣)', text: '(￣︶￣)'),
    Emoticon(name: 'ヾ(´ωﾟ｀)', text: 'ヾ(´ωﾟ｀)'),
    Emoticon(name: '(*´ω`*)', text: '(*´ω`*)'),
    Emoticon(name: '(・ω・)', text: '(・ω・)'),
    Emoticon(name: '( ´・ω)', text: '( ´・ω)'),
    Emoticon(name: '(｀・ω)', text: '(｀・ω)'),
    Emoticon(name: '(´・ω・`)', text: '(´・ω・`)'),
    Emoticon(name: '(`・ω・´)', text: '(`・ω・´)'),
    Emoticon(name: '( `_っ´)', text: '( `_っ´)'),
    Emoticon(name: '( `ー´)', text: '( `ー´)'),
    Emoticon(name: '( ´_っ`)', text: '( ´_っ`)'),
    Emoticon(name: '( ´ρ`)', text: '( ´ρ`)'),
    Emoticon(name: '( ﾟωﾟ)', text: '( ﾟωﾟ)'),
    Emoticon(name: '(oﾟωﾟo)', text: '(oﾟωﾟo)'),
    Emoticon(name: '(　^ω^)', text: '(　^ω^)'),
    Emoticon(name: '(｡◕∀◕｡)', text: '(｡◕∀◕｡)'),
    Emoticon(name: r'/( ◕‿‿◕ )\', text: r'/( ◕‿‿◕ )\'),
    Emoticon(name: 'ヾ(´ε`ヾ)', text: 'ヾ(´ε`ヾ)'),
    Emoticon(name: '(ノﾟ∀ﾟ)ノ', text: '(ノﾟ∀ﾟ)ノ'),
    Emoticon(name: '(σﾟдﾟ)σ', text: '(σﾟдﾟ)σ'),
    Emoticon(name: '(σﾟ∀ﾟ)σ', text: '(σﾟ∀ﾟ)σ'),
    Emoticon(name: '|дﾟ )', text: '|дﾟ )'),
    Emoticon(name: '┃電柱┃', text: '┃電柱┃'),
    Emoticon(name: 'ﾟ(つд`ﾟ)', text: 'ﾟ(つд`ﾟ)'),
    Emoticon(name: 'ﾟÅﾟ )　', text: 'ﾟÅﾟ )　'),
    Emoticon(name: '⊂彡☆))д`)', text: '⊂彡☆))д`)'),
    Emoticon(name: '⊂彡☆))д´)', text: '⊂彡☆))д´)'),
    Emoticon(name: '⊂彡☆))∀`)', text: '⊂彡☆))∀`)'),
    Emoticon(name: '(´∀((☆ミつ', text: '(´∀((☆ミつ'),
    Emoticon(name: '･ﾟ( ﾉヮ´ )', text: '･ﾟ( ﾉヮ´ )'),
    Emoticon(name: '(ﾉ)`ω´(ヾ)', text: '(ﾉ)`ω´(ヾ)'),
    Emoticon(name: 'ᕕ( ᐛ )ᕗ', text: 'ᕕ( ᐛ )ᕗ'),
    Emoticon(name: '(　ˇωˇ)', text: '(　ˇωˇ)'),
    Emoticon(name: '( ｣ﾟДﾟ)｣＜', text: '( ｣ﾟДﾟ)｣＜'),
    Emoticon(name: '( ›´ω`‹ )', text: '( ›´ω`‹ )'),
    Emoticon(name: '(;´ヮ`)7', text: '(;´ヮ`)7'),
    Emoticon(name: '(`ゥ´ )', text: '(`ゥ´ )'),
    Emoticon(name: '(`ᝫ´ )', text: '(`ᝫ´ )'),
    Emoticon(name: '( ᑭ`д´)ᓀ))д´)ᑫ', text: '( ᑭ`д´)ᓀ))д´)ᑫ'),
    Emoticon(name: 'σ( ᑒ )', text: 'σ( ᑒ )'),
    Emoticon(name: '齐齐蛤尔', text: '(`ヮ´ )σ`∀´) ﾟ∀ﾟ)σ'),
    Emoticon(
        name: '大嘘',
        text: '吁~~~~　　rnm，退钱！\n 　　　/　　　/ \n(　ﾟ 3ﾟ) `ー´) `д´) `д´)\n'),
    Emoticon(name: '防剧透', text: '[h] [/h]'),
    Emoticon(name: '骰子', text: '[n]'),
    Emoticon(name: '高级骰子', text: '[n,m]'),
  ];

  /// 颜文字名称
  final String name;

  /// 颜文字内容
  final String text;

  /// 构造[Emoticon]
  const Emoticon({required this.name, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Emoticon && name == other.name && text == other.text);

  @override
  int get hashCode => Object.hash(name, text);
}

/// 举报理由
class ReportReason {
  /// X岛匿名版官方的举报理由
  static const List<ReportReason> list = [
    ReportReason(reason: '黄赌毒', text: '黄赌毒'),
    ReportReason(reason: '政治敏感', text: '政治敏感'),
    ReportReason(reason: '谣言欺诈', text: '谣言欺诈'),
    ReportReason(reason: '广告q群', text: '广告q群'),
    ReportReason(reason: '引战辱骂', text: '引战辱骂'),
    ReportReason(reason: '串版', text: '串版'),
    ReportReason(reason: '错字自删', text: '错字自删'),
    ReportReason(reason: '错饼自删', text: '错饼自删'),
  ];

  /// 举报理由
  final String reason;

  /// 举报理由的文字
  final String text;

  /// 构造[ReportReason]
  const ReportReason({required this.reason, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportReason && reason == other.reason && text == other.text);

  @override
  int get hashCode => Object.hash(reason, text);
}

/// X岛匿名版API
class XdnmbApi {
  /// HTTP client
  final Client _client;

  /// 用户饼干
  XdnmbCookie? xdnmbCookie;

  /// 用户的cookie
  Cookie? xdnmbUserCookie;

  /// 用户是否登陆
  bool get isLogin => xdnmbUserCookie != null;

  /// 是否拥有PHP session ID
  bool get hasPhpSessionId => _client.xdnmbPhpSessionId != null;

  /// 用户cookie的值
  String? get _userCookie => xdnmbUserCookie?.toCookie;

  /// 构造[XdnmbApi]
  ///
  /// [userHash]为饼干[XdnmbCookie]的`userHash`
  ///
  /// [client]为[HttpClient]
  ///
  /// [connectionTimeout]为连接超时时长，默认为15秒
  ///
  /// [idleTimeout]为连接空闲超时时长，默认为90秒
  ///
  /// [userAgent]为`User-Agent`，默认为`xdnmb`
  XdnmbApi(
      {String? userHash,
      HttpClient? client,
      Duration? connectionTimeout,
      Duration? idleTimeout,
      String? userAgent})
      : _client = Client(
            client: client,
            connectionTimeout: connectionTimeout,
            idleTimeout: idleTimeout,
            userAgent: userAgent),
        xdnmbCookie = userHash != null ? XdnmbCookie(userHash) : null;

  /// 更新X岛链接
  Future<void> updateUrls() => XdnmbUrls.update();

  /// 获取X岛公告
  Future<Notice> getNotice() async {
    final response = await _client.xGet(XdnmbUrls.notice);

    return Notice._fromJson(response.utf8Body);
  }

  /// 获取CDN列表
  ///
  /// [cookie]为饼干的cookie值
  Future<List<Cdn>> getCdnList({String? cookie}) async {
    final response =
        await _client.xGet(XdnmbUrls().cdnList, cookie ?? xdnmbCookie?.cookie);

    return Cdn._fromJson(response.utf8Body);
  }

  /// 获取版块列表
  ///
  /// [cookie]为饼干的cookie值
  Future<ForumList> getForumList({String? cookie}) async {
    final response = await _client.xGet(
        XdnmbUrls().forumList, cookie ?? xdnmbCookie?.cookie);

    return ForumList._fromJson(response.utf8Body);
  }

  /// 获取时间线列表
  ///
  /// [cookie]为饼干的cookie值
  Future<List<Timeline>> getTimelineList({String? cookie}) async {
    final response = await _client.xGet(
        XdnmbUrls().timelineList, cookie ?? xdnmbCookie?.cookie);

    return Timeline._fromJson(response.utf8Body);
  }

  /// 获取网页版版块信息
  ///
  /// [forumId]为版块ID，[cookie]为饼干的cookie值
  Future<HtmlForum> getHtmlForumInfo(int forumId, {String? cookie}) async {
    if (forumId <= 0) {
      throw XdnmbApiException('版块ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().htmlForum(forumId), cookie ?? xdnmbCookie?.cookie);

    return HtmlForum._fromHtml(forumId, response.utf8Body);
  }

  /// 获取版块里的串
  ///
  /// [forumId]为版块ID，[page]为页数，最小值为1，最大值为100，[cookie]为饼干的cookie值
  ///
  /// 一页最多20串
  Future<List<ForumThread>> getForum(int forumId,
      {int page = 1, String? cookie}) async {
    if (forumId <= 0) {
      throw XdnmbApiException('版块ID要大于0');
    }
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().forum(forumId, page: page), cookie ?? xdnmbCookie?.cookie);

    return ForumThread._fromJson(response.utf8Body);
  }

  /// 获取时间线里的串
  ///
  /// [timelineId]为时间线ID，[page]为页数，最小值为1，最大值根据[Timeline.maxPage]，
  /// [cookie]为饼干的cookie值
  ///
  /// 一页最多20串。
  Future<List<ForumThread>> getTimeline(int timelineId,
      {int page = 1, String? cookie}) async {
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().timeline(timelineId, page: page),
        cookie ?? xdnmbCookie?.cookie);

    return ForumThread._fromJson(response.utf8Body);
  }

  /// 获取帖子（串）内容
  ///
  /// [mainPostId]为主串ID，[page]为页数，最小值为1，[cookie]为饼干的cookie值
  ///
  /// 一页最多19个回复
  ///
  /// 没有饼干的话只能浏览前100页
  Future<Thread> getThread(int mainPostId,
      {int page = 1, String? cookie}) async {
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().thread(mainPostId, page: page),
        cookie ?? xdnmbCookie?.cookie);

    return Thread._fromJson(response.utf8Body);
  }

  /// 获取只看Po的帖子（串）的内容
  ///
  /// [mainPostId]为主串ID，[page]为页数，最小值为1，[cookie]为饼干的cookie值
  ///
  /// 一页最多19个回复
  ///
  /// 没有饼干的话只能浏览前100页？
  Future<Thread> getOnlyPoThread(int mainPostId,
      {int page = 1, String? cookie}) async {
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().onlyPoThread(mainPostId, page: page),
        cookie ?? xdnmbCookie?.cookie);

    return Thread._fromJson(response.utf8Body);
  }

  /// 获取串引用
  ///
  /// [postId]为串ID，[cookie]为饼干的cookie值
  Future<Reference> getReference(int postId, {String? cookie}) async {
    if (postId <= 0) {
      throw XdnmbApiException('串的ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().reference(postId), cookie ?? xdnmbCookie?.cookie);

    return Reference._fromJson(response.utf8Body);
  }

  /// 获取网页版串引用
  ///
  /// [postId]为串ID，[cookie]为饼干的cookie值
  Future<HtmlReference> getHtmlReference(int postId, {String? cookie}) async {
    if (postId <= 0) {
      throw XdnmbApiException('串的ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().htmlReference(postId), cookie ?? xdnmbCookie?.cookie);

    return HtmlReference._fromHtml(response.utf8Body);
  }

  /// 获取订阅
  ///
  /// [feedId]为订阅ID，[page]为页数，最小值为1，[cookie]为饼干的cookie值
  ///
  /// 一页最多10个订阅
  Future<List<Feed>> getFeed(String feedId,
      {int page = 1, String? cookie}) async {
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().feed(feedId, page: page), cookie ?? xdnmbCookie?.cookie);

    return Feed._fromJson(response.utf8Body);
  }

  /// 添加订阅
  ///
  /// [feedId]为订阅ID，[mainPostId]为主串ID，[cookie]为饼干的cookie值
  Future<void> addFeed(String feedId, int mainPostId, {String? cookie}) async {
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().addFeed(feedId, mainPostId), cookie ?? xdnmbCookie?.cookie);
    final String decoded = json.decode(response.utf8Body);

    if (!decoded.contains('订阅大成功')) {
      throw XdnmbApiException(decoded);
    }
  }

  /// 删除订阅
  ///
  /// [feedId]为订阅ID，[mainPostId]为主串ID，[cookie]为饼干的cookie值
  Future<void> deleteFeed(String feedId, int mainPostId,
      {String? cookie}) async {
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().deleteFeed(feedId, mainPostId),
        cookie ?? xdnmbCookie?.cookie);
    final String decoded = json.decode(response.utf8Body);

    if (!decoded.contains('取消订阅成功')) {
      throw XdnmbApiException(decoded);
    }
  }

  /// 获取最新发的串
  ///
  /// 发新串后第一次调用会返回最新发的串，再次调用会返回`null`
  ///
  /// 没饼干会返回`null`
  Future<LastPost?> getLastPost({String? cookie}) async {
    final response = await _client.xGet(
        XdnmbUrls().getLastPost, cookie ?? xdnmbCookie?.cookie);

    return LastPost._fromJson(response.utf8Body);
  }

  /// 发表新串
  ///
  /// [forumId]为版块ID，[content]为串的内容，[name]为串的名称，
  /// [email]为串的邮箱，其实没用，[title]为串的标题，
  /// [watermark]为是否添加图片水印，默认不添加，
  /// [image]为串的图片，[cookie]为饼干的cookie值
  ///
  /// 发串需要饼干（[xdnmbCookie]或[cookie]）
  Future<void> postNewThread(
      {required int forumId,
      required String content,
      String? name,
      String? email,
      String? title,
      bool watermark = false,
      Image? image,
      String? cookie}) async {
    cookie = cookie ?? xdnmbCookie?.cookie;
    if (cookie == null) {
      throw XdnmbApiException('发串需要饼干');
    }
    if (forumId <= 0) {
      throw XdnmbApiException('版块ID要大于0');
    }
    if (content.isEmpty && image == null) {
      throw XdnmbApiException('不发图时串的内容不能为空');
    }

    final multipart = Multipart(XdnmbUrls().postNewThread)
      ..add('fid', forumId)
      ..add('content', content);
    if (name != null) {
      multipart.add('name', name);
    }
    if (email != null) {
      multipart.add('email', email);
    }
    if (title != null) {
      multipart.add('title', title);
    }
    // 要没水印的话必须没有'water'字段
    if (watermark) {
      multipart.add('water', watermark);
    }
    if (image != null) {
      multipart.addBytes('image', image.data,
          filename: image.filename, contentType: image.imageType.mineType());
    }

    final response = await _client.xPostMultipart(multipart, cookie);
    _handleHtml(response.utf8Body);
  }

  /// 发表新串
  ///
  /// [forumId]为版块ID，[content]为串的内容，[name]为串的名称，
  /// [email]为串的邮箱，其实没用，[title]为串的标题，
  /// [watermark]为是否添加图片水印，默认不添加，
  /// [imageFile]为图片文件路径，[cookie]为饼干的cookie值
  ///
  /// 发串需要饼干（[xdnmbCookie]或[cookie]）
  Future<void> postNewThreadWithImage(
          {required int forumId,
          required String content,
          required String imageFile,
          String? name,
          String? email,
          String? title,
          bool watermark = false,
          String? cookie}) async =>
      postNewThread(
          forumId: forumId,
          content: content,
          name: name,
          email: email,
          title: title,
          watermark: watermark,
          image: await Image.fromFile(imageFile),
          cookie: cookie);

  /// 回串
  ///
  /// [mainPostId]为要回复的主串ID，[content]为串的内容，[name]为串的名称，
  /// [email]为串的邮箱，其实没用，[title]为串的标题，
  /// [watermark]为是否添加图片水印，默认不添加，
  /// [image]为串的图片，[cookie]为饼干的cookie值
  ///
  /// 回串需要饼干（[xdnmbCookie]或[cookie]）
  Future<void> replyThread(
      {required int mainPostId,
      required String content,
      String? name,
      String? email,
      String? title,
      bool watermark = false,
      Image? image,
      String? cookie}) async {
    cookie = cookie ?? xdnmbCookie?.cookie;
    if (cookie == null) {
      throw XdnmbApiException('回串需要饼干');
    }
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }
    if (content.isEmpty && image == null) {
      throw XdnmbApiException('不发图时串的内容不能为空');
    }

    final multipart = Multipart(XdnmbUrls().replyThread)
      ..add('resto', mainPostId)
      ..add('content', content);
    if (name != null) {
      multipart.add('name', name);
    }
    if (email != null) {
      multipart.add('email', email);
    }
    if (title != null) {
      multipart.add('title', title);
    }
    // 要没水印的话必须没有'water'字段
    if (watermark) {
      multipart.add('water', watermark);
    }
    if (image != null) {
      multipart.addBytes('image', image.data,
          contentType: image.imageType.mineType(), filename: image.filename);
    }

    final response = await _client.xPostMultipart(multipart, cookie);
    _handleHtml(response.utf8Body);
  }

  /// 回串
  ///
  /// [mainPostId]为要回复的主串ID，[content]为串的内容，[name]为串的名称，
  /// [email]为串的邮箱，其实没用，[title]为串的标题，
  /// [watermark]为是否添加图片水印，默认不添加，
  /// [imageFile]为图片文件路径，[cookie]为饼干的cookie值
  ///
  /// 回串需要饼干（[xdnmbCookie]或[cookie]）
  Future<void> replyThreadWithImage(
          {required int mainPostId,
          required String content,
          required String imageFile,
          String? name,
          String? email,
          String? title,
          bool watermark = false,
          String? cookie}) async =>
      replyThread(
          mainPostId: mainPostId,
          content: content,
          name: name,
          email: email,
          title: title,
          watermark: watermark,
          image: await Image.fromFile(imageFile),
          cookie: cookie);

  /// 关闭HTTP client
  void close() => _client.close();

  /// 获取验证码图片
  Future<Uint8List> getVerifyImage() async =>
      (await _client.xGet(XdnmbUrls().verifyImage)).bodyBytes;

  /// 用户登陆
  ///
  /// [email]为用户邮箱，[password]为用户密码，[verify]为验证码
  Future<void> userLogin(
      {required String email,
      required String password,
      required String verify}) async {
    if (!hasPhpSessionId) {
      throw XdnmbApiException('用户登陆需要PHPSESSID');
    }

    final response = await _client.xPostForm(XdnmbUrls().userLogin, {
      'email': email,
      'password': password,
      'verify': verify,
    });
    _handleHtml(response.utf8Body);

    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    if (setCookie == null) {
      throw XdnmbApiException('用户登陆失败');
    }
    final cookie = Cookie.fromSetCookieValue(setCookie);
    if (cookie.name != 'memberUserspapapa') {
      throw XdnmbApiException('用户登陆失败');
    }
    xdnmbUserCookie = cookie;
  }

  /// 获取饼干信息
  ///
  /// [cookieId]为饼干ID，[userCookie]为用户的cookie值
  ///
  /// 获取饼干信息需要用户已经登陆或[userCookie]
  Future<XdnmbCookie> getCookie(int cookieId, {String? userCookie}) async {
    userCookie = userCookie ?? _userCookie;
    if (userCookie == null) {
      throw XdnmbApiException('获取饼干需要用户Cookie');
    }
    final response =
        await _client.xGet(XdnmbUrls().getCookie(cookieId), userCookie);
    final document = parse(response.utf8Body);
    _handleDocument(document);

    final element = document.querySelector('.tpl-form-maintext img');
    if (element == null) {
      throw XdnmbApiException('获取饼干失败');
    }
    final imageUrl = element.attributes['src'];
    if (imageUrl == null) {
      throw XdnmbApiException('获取饼干失败');
    }

    final text = Uri.parse(imageUrl).queryParameters['text'];
    if (text == null) {
      throw XdnmbApiException('获取饼干失败');
    }

    return XdnmbCookie._fromJson(
        utf8.decode(base64.decode(text)).replaceAll('+', '%20'),
        id: cookieId);
  }

  /// 获取饼干列表
  ///
  /// [userCookie]为用户的cookie值
  ///
  /// 获取饼干列表需要用户已经登陆或[userCookie]
  Future<CookiesList> getCookiesList({String? userCookie}) async {
    userCookie = userCookie ?? _userCookie;
    if (userCookie == null) {
      throw XdnmbApiException('获取饼干列表需要用户Cookie');
    }
    final response = await _client.xGet(XdnmbUrls().cookiesList, userCookie);
    final document = parse(response.utf8Body);
    _handleDocument(document);

    Element? element = document.querySelector('b.am-text-success');
    late final bool canGetCookie;
    if (element == null) {
      element = document.querySelector('b.am-text-danger');
      if (element == null) {
        throw XdnmbApiException('获取饼干是否开放领取失败');
      } else if (element.innerHtml.contains('已关闭')) {
        canGetCookie = false;
      } else {
        throw XdnmbApiException('获取饼干是否开放领取失败');
      }
    } else if (element.innerHtml.contains('已开放')) {
      canGetCookie = true;
    } else {
      throw XdnmbApiException('获取饼干是否开放领取失败');
    }

    element = document.querySelector('b.am-text-primary');
    if (element == null) {
      throw XdnmbApiException('获取饼干数量失败');
    }
    final match = _RegExp._cookieNum.firstMatch(element.innerHtml);
    if (match == null) {
      throw XdnmbApiException('获取饼干数量失败');
    }
    final currentCookiesNum = int.parse(match[1]!);
    final totalCookiesNum = int.parse(match[2]!);

    final idList = document.querySelectorAll('tr td:first-child').map((e) {
      final next = e.nextElementSibling;
      if (next == null) {
        throw XdnmbApiException('获取饼干ID失败');
      }
      final id = int.tryParse(next.innerHtml);
      if (id == null) {
        throw XdnmbApiException('获取饼干ID失败');
      }
      return id;
    });
    if (idList.length != currentCookiesNum) {
      throw XdnmbApiException('获取饼干ID失败');
    }

    return CookiesList(
        canGetCookie: canGetCookie,
        currentCookiesNum: currentCookiesNum,
        totalCookiesNum: totalCookiesNum,
        cookiesIdList: idList.toList());
  }

  /// 获取新饼干
  ///
  /// [verify]为验证码，[userCookie]为用户的cookie值
  ///
  /// 获取新饼干需要用户已经登陆或[userCookie]
  Future<void> getNewCookie(
      {required String verify, String? userCookie}) async {
    userCookie = userCookie ?? _userCookie;
    if (!hasPhpSessionId || userCookie == null) {
      throw XdnmbApiException('获取新饼干需要PHPSESSID和用户Cookie');
    }

    final response = await _client.xPostForm(
        XdnmbUrls().getNewCookie, {'verify': verify}, userCookie);
    _handleHtml(response.utf8Body);
  }

  /// 删除饼干
  ///
  /// [cookieId]为饼干ID，[verify]为验证码，[userCookie]为用户的cookie值
  ///
  /// 删除饼干需要用户已经登陆或[userCookie]
  Future<void> deleteCookie(
      {required int cookieId,
      required String verify,
      String? userCookie}) async {
    userCookie = userCookie ?? _userCookie;
    if (!hasPhpSessionId || userCookie == null) {
      throw XdnmbApiException('删除饼干需要PHPSESSID和用户Cookie');
    }

    final response = await _client.xPostForm(
        XdnmbUrls().deleteCookie(cookieId), {'verify': verify}, userCookie);
    _handleHtml(response.utf8Body);
  }
}

/// 处理HTTP响应里JSON数据里的错误
void _handleJsonError(dynamic decoded) {
  if (decoded is String) {
    throw XdnmbApiException(decoded);
  }
  if (decoded is Map<String, dynamic> && decoded['error'] != null) {
    throw XdnmbApiException(decoded['error'].toString());
  }
}

/// 处理HTML DOCUMENT数据
String? _handleDocument(Document document) {
  final success = document.querySelector('p.success');
  if (success != null) {
    return success.innerHtml;
  }

  final error = document.querySelector('p.error');
  if (error != null) {
    throw XdnmbApiException(error.innerHtml);
  }

  return null;
}

/// 处理HTML数据
String? _handleHtml(String data) => _handleDocument(parse(data));

/// 解析串时间格式，返回UTC时间
DateTime _parseTimeString(String timeString) {
  final time = timeString.replaceFirst(_RegExp._parseDay, 'T');

  return DateTime.parse('$time+0800');
}

/// 正则表达式
abstract class _RegExp {
  /// 提取日期
  static final RegExp _parseDay = RegExp(r'\(.*\)');

  /// 提取饼干数量和饼干槽数量
  static final RegExp _cookieNum = RegExp(r'([0-9])/([0-9])');

  /// 提取串号
  static final RegExp _parseNum = RegExp(r'[0-9]+');

  /// 提取主串ID
  static final RegExp _parseMainPostId = RegExp(r't/([0-9]+)');

  /// 提取图片链接
  static final RegExp _parseThumbImage = RegExp(r'thumb/([^\.]+)(\..*)?');

  /// 提取用户饼干名字
  static final RegExp _parseUserHash = RegExp(r'ID:(.+)');
}

/// [String]的扩展
///
/// 代码来自 <https://github.com/dart-lang/sdk/blob/main/sdk/lib/_internal/vm/lib/string_patch.dart>
extension _StringExtension on String {
  /// 第一个非空格字符的位置
  int _firstNonWhitespace() {
    int first = 0;
    for (; first < length; first++) {
      final code = codeUnitAt(first);
      if (code != 0x0A && code != 0x20) {
        break;
      }
    }

    return first;
  }

  /// 最后一个非空格字符的位置
  int _lastNonWhitespace() {
    int last = length - 1;
    for (; last >= 0; last--) {
      final code = codeUnitAt(last);
      if (code != 0x0A && code != 0x20) {
        break;
      }
    }

    return last;
  }

  /// 去掉字符串前后两端的换行和空格（`U+000A`和`U+0020`）
  String _trimWhiteSpace() {
    int first = _firstNonWhitespace();
    if (length == first) {
      // String contains only whitespaces.
      return "";
    }

    int last = _lastNonWhitespace() + 1;
    if ((first == 0) && (last == length)) {
      // Returns this string since it does not have leading or trailing
      // whitespaces.
      return this;
    }

    return substring(first, last);
  }
}
