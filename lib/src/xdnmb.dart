import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:mime/mime.dart';

import 'client.dart';
import 'urls.dart';

part 'cookie.dart';

class XdnmbApiException implements Exception {
  final String message;

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

class Notice {
  final String content;

  /// 公告发布的日期，部分格式未明
  final int date;

  final bool isValid;

  const Notice(this.content, this.date, [this.isValid = true]);

  static Notice _fromJson(String data) {
    final Map<String, dynamic> decoded = json.decode(data);

    final content = decoded['content'] ?? '';
    final date = decoded['date'] ?? 0;
    final isValid = decoded['enable'] ?? false;

    return Notice(content, date, isValid);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notice &&
          content == other.content &&
          date == other.date &&
          isValid == other.isValid);

  @override
  int get hashCode => Object.hash(content, date, isValid);
}

class Cdn {
  final String url;

  final double rate;

  const Cdn(this.url, [this.rate = 0.0]);

  String thumbImageUrl(PostBase post) => '${url}thumb/${post.imageFile()}';

  String imageUrl(PostBase post) => '${url}image/${post.imageFile()}';

  static List<Cdn> _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);

    return <Cdn>[
      for (final Map<String, dynamic> map in decoded)
        Cdn(map['url'] ?? XdnmbUrls.originCdnUrl, map['rate'] ?? 0.0)
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cdn && url == other.url && rate == other.rate);

  @override
  int get hashCode => Object.hash(url, rate);
}

abstract class ForumBase {
  int get id;

  String get name;

  String get displayName;

  String get message;

  int get maxPage;

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

extension ForumBaseExtension on ForumBase {
  String get showName => displayName.isNotEmpty ? displayName : name;
}

class Timeline implements ForumBase {
  @override
  final int id;

  @override
  final String name;

  /// 时间线显示的名字，如果是空字符串的话应该要显示[name]
  @override
  final String displayName;

  @override
  final String message;

  /// 时间线的最大页数，大于[maxPage]的均显示页数为[maxPage]的内容，默认为20
  @override
  final int maxPage;

  const Timeline(
      {required this.id,
      required this.name,
      this.displayName = '',
      required this.message,
      this.maxPage = 20});

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

class ForumGroup {
  final int id;

  /// 板块组显示的排序，小的在前面
  final int sort;

  final String name;

  /// 总是'n'
  final String status;

  const ForumGroup(
      {required this.id, this.sort = 1, required this.name, this.status = 'n'});

  ForumGroup._fromMap(Map<String, dynamic> map)
      : id = int.parse(map['id']),
        sort = int.tryParse(map['sort'] ?? '1') ?? 1,
        name = map['name'] ?? '未知板块组',
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

class Forum implements ForumBase {
  @override
  final int id;

  final int forumGroupId;

  final int sort;

  @override
  final String name;

  /// 板块显示的名字，如果是空字符串的话应该要显示[name]
  @override
  final String displayName;

  @override
  final String message;

  final int interval;

  final int threadCount;

  /// 大于0时需要饼干访问板块
  final int permissionLevel;

  final int forumFuseId;

  final String createTime;

  final String updateTime;

  /// 总是'n'
  final String status;

  @override
  int get maxPage => 100;

  const Forum(
      {required this.id,
      this.forumGroupId = 4,
      this.sort = 1,
      required this.name,
      this.displayName = '',
      required this.message,
      this.interval = 30,
      required this.threadCount,
      this.permissionLevel = 0,
      this.forumFuseId = 0,
      this.createTime = '',
      this.updateTime = '',
      this.status = 'n'});

  Forum._fromMap(Map<String, dynamic> map)
      : id = int.parse(map['id']),
        forumGroupId = int.tryParse(map['fgroup'] ?? '4') ?? 4,
        sort = int.tryParse(map['sort'] ?? '1') ?? 1,
        name = map['name'] ?? '未知板块',
        displayName = map['showName'] ?? '',
        message = map['msg'] ?? '',
        interval = int.tryParse(map['interval'] ?? '30') ?? 30,
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

class ForumList {
  final List<ForumGroup> forumGroupList;

  final List<Forum> forumList;

  final List<Timeline>? timelineList;

  const ForumList(this.forumGroupList, this.forumList, [this.timelineList]);

  static ForumList _fromJson(String data) {
    final decoded = json.decode(data);
    _handleJsonError(decoded);
    final forumGroupList = <ForumGroup>[];
    final forumList = <Forum>[];
    List<Timeline>? timelineList;

    var hasTimeline = false;
    for (final Map<String, dynamic> map in decoded) {
      forumGroupList.add(ForumGroup._fromMap(map));

      for (final Map<String, dynamic> forum in map['forums']) {
        final id = int.parse(forum['id']);
        if (id < 0) {
          if (!hasTimeline) {
            timelineList = <Timeline>[];
            hasTimeline = true;
          }
          timelineList!.add(Timeline(
              id: id,
              name: forum['name'] ?? '未知时间线',
              message: forum['msg'] ?? ''));
        } else {
          forumList.add(Forum._fromMap(forum));
        }
      }

      if (!hasTimeline) {
        timelineList = null;
      }
    }

    return ForumList(forumGroupList, forumList, timelineList);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForumList &&
          forumGroupList == other.forumGroupList &&
          forumList == other.forumList &&
          timelineList == other.timelineList);

  @override
  int get hashCode => Object.hash(forumGroupList, forumList, timelineList);
}

abstract class PostBase {
  int get id;

  int? get forumId;

  int? get replyCount;

  String get image;

  String get imageExtension;

  DateTime get postTime;

  String get userHash;

  String get name;

  String get title;

  String get content;

  bool? get isSage;

  bool get isAdmin;

  bool? get isHidden;

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

extension BasePostExtension on PostBase {
  bool hasImage() => image.isNotEmpty;

  String? imageFile() => hasImage() ? '$image$imageExtension' : null;

  String? thumbImageUrl() =>
      hasImage() ? '${XdnmbUrls().cdnUrl}thumb/${imageFile()}' : null;

  String? imageUrl() =>
      hasImage() ? '${XdnmbUrls().cdnUrl}image/${imageFile()}' : null;
}

/// X岛匿名版的串
class Post implements PostBase {
  @override
  final int id;

  /// 串所在板块的ID
  ///
  /// 主串的[forumId]跟随实际板块，但由于移串，回串的[forumId]可能和主串的不相等
  @override
  final int forumId;

  /// 主串的回串数量，包含被删除的串。
  ///
  /// 回串的[replyCount]为0。
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
        isSage = (map['sage'] ?? 0) == 0 ? false : true,
        isAdmin = (map['admin'] ?? 0) == 0 ? false : true,
        isHidden = (map['Hide'] ?? 0) == 0 ? false : true;

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

class ForumThread {
  final Post mainPost;

  /// 主串的最后的回复，最多5个。
  ///
  /// 由于删串的原因，即使[mainPost]的`replyCount`大于5，[recentReplies]的长度也不一定等于5，
  /// 而且[mainPost]的`replyCount`小于等于5时和[recentReplies]的长度也不一定相等。
  final List<Post> recentReplies;

  final int? remainReplies;

  const ForumThread(this.mainPost, this.recentReplies, [this.remainReplies]);

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForumThread &&
          mainPost == other.mainPost &&
          recentReplies == other.recentReplies &&
          remainReplies == other.remainReplies);

  @override
  int get hashCode => Object.hash(mainPost, recentReplies, remainReplies);
}

class Tip implements PostBase {
  @override
  final int id;

  @override
  final String userHash;

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

  @override
  int? get forumId => null;

  @override
  int? get replyCount => null;

  @override
  bool? get isSage => null;

  @override
  bool? get isHidden => null;

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

  Tip._fromMap(Map<String, dynamic> map)
      : id = map['id'] ?? 9999999,
        userHash = map['user_hash'] ?? '',
        isAdmin = (map['admin'] ?? 1) == 0 ? false : true,
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

class Thread {
  final Post mainPost;

  /// 主串某一页的回复。
  ///
  /// [replies]长度为0时说明这一页和后面的页数都没有回复。
  final List<Post> replies;

  final Tip? tip;

  const Thread(this.mainPost, this.replies, [this.tip]);

  static Thread _fromJson(String data) {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Thread &&
          mainPost == other.mainPost &&
          replies == other.replies &&
          tip == other.tip);

  @override
  int get hashCode => Object.hash(mainPost, replies, tip);
}

abstract class ReferenceBase implements PostBase {
  @override
  int? get forumId => null;

  @override
  int? get replyCount => null;

  @override
  bool? get isHidden => null;

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

  static Reference _fromJson(String data) {
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
    final isSage = (decoded['sage'] ?? 0) == 0 ? false : true;
    final status = decoded['status'] ?? 'n';
    final isAdmin = (decoded['admin'] ?? 0) == 0 ? false : true;

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

  final int? mainPostId;

  @override
  bool? get isSage => null;

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

  static HtmlReference _fromHtml(String data) {
    final document = parse(data);
    _handleDocument(document);

    var element = document.querySelector('a.h-threads-info-id');
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
    final content = element.innerHtml.trim();

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

class Feed implements PostBase {
  @override
  final int id;

  final int userId;

  @override
  final int forumId;

  @override
  final int replyCount;

  final List<int> recentReplies;

  final String category;

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

  final String po;

  @override
  bool? get isSage => null;

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
            isAdmin:
                (int.tryParse(map['admin'] ?? '0') ?? 0) == 0 ? false : true,
            isHidden:
                (int.tryParse(map['hide'] ?? '0') ?? 0) == 0 ? false : true,
            po: map['po'] ?? '')
    ];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Feed &&
          id == other.id &&
          userId == other.userId &&
          forumId == other.forumId &&
          replyCount == other.replyCount &&
          recentReplies == other.recentReplies &&
          category == other.category &&
          fileId == other.fileId &&
          image == other.image &&
          imageExtension == other.imageExtension &&
          postTime == other.postTime &&
          userHash == other.userHash &&
          name == other.name &&
          email == other.email &&
          title == other.title &&
          content == other.content &&
          status == other.status &&
          isAdmin == other.isAdmin &&
          isHidden == other.isHidden &&
          po == other.po &&
          isSage == other.isSage);

  @override
  int get hashCode => Object.hash(
      id,
      userId,
      forumId,
      replyCount,
      recentReplies,
      category,
      fileId,
      image,
      imageExtension,
      postTime,
      userHash,
      name,
      email,
      title,
      content,
      status,
      isAdmin,
      isHidden,
      po,
      isSage);
}

enum ImageType {
  jpeg,
  png,
  gif;

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

class Image {
  final String filename;

  final List<int> data;

  late final ImageType imageType;

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

  static Future<Image> fromFile(String path) async {
    final file = File(path);
    final filename = file.uri.pathSegments.last;
    final data = await file.readAsBytes();

    return Image(filename, data);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Image &&
          filename == other.filename &&
          data == other.data &&
          imageType == other.imageType);

  @override
  int get hashCode => Object.hash(filename, data, imageType);
}

class Emoticon {
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
        name: '大嘘', text: '吁~~~~　　rnm，退钱！\n 　　　/　　　/ \n(　ﾟ 3ﾟ) `ー´) `д´) `д´)'),
    Emoticon(name: '防剧透', text: '[h] [/h]'),
    Emoticon(name: '骰子', text: '[n]'),
    Emoticon(name: '高级骰子', text: '[n,m]'),
  ];

  final String name;

  final String text;

  const Emoticon({required this.name, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Emoticon && name == other.name && text == other.text);

  @override
  int get hashCode => Object.hash(name, text);
}

class ReportReason {
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

  final String reason;

  final String text;

  const ReportReason({required this.reason, required this.text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportReason && reason == other.reason && text == other.text);

  @override
  int get hashCode => Object.hash(reason, text);
}

class XdnmbApi {
  final Client _client;

  XdnmbCookie? xdnmbCookie;

  Cookie? xdnmbUserCookie;

  bool get isLogin => xdnmbUserCookie != null;

  bool get hasPhpSessionId => _client.xdnmbPhpSessionId != null;

  String? get _userCookie => xdnmbUserCookie?.toCookie;

  XdnmbApi({String? userHash, Duration timeout = const Duration(seconds: 15)})
      : _client = Client(timeout: timeout),
        xdnmbCookie = userHash == null ? null : XdnmbCookie(userHash);

  Future<void> updateUrls() => XdnmbUrls.update();

  Future<Notice> getNotice() async {
    final response = await _client.xGet(XdnmbUrls.notice);

    return Notice._fromJson(response.utf8Body);
  }

  Future<List<Cdn>> getCdnList({String? cookie}) async {
    final response =
        await _client.xGet(XdnmbUrls().cdnList, cookie ?? xdnmbCookie?.cookie);

    return Cdn._fromJson(response.utf8Body);
  }

  Future<ForumList> getForumList({String? cookie}) async {
    final response = await _client.xGet(
        XdnmbUrls().forumList, cookie ?? xdnmbCookie?.cookie);

    return ForumList._fromJson(response.utf8Body);
  }

  Future<List<Timeline>> getTimelineList({String? cookie}) async {
    final response = await _client.xGet(
        XdnmbUrls().timelineList, cookie ?? xdnmbCookie?.cookie);

    return Timeline._fromJson(response.utf8Body);
  }

  /// [page]最大为100。
  ///
  /// 一页最多20串。
  Future<List<ForumThread>> getForum(int forumId,
      {int page = 1, String? cookie}) async {
    if (forumId <= 0) {
      throw XdnmbApiException('板块ID要大于0');
    }
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().forum(forumId, page: page), cookie ?? xdnmbCookie?.cookie);

    return ForumThread._fromJson(response.utf8Body);
  }

  Future<String> getHtmlForumMessage(int forumId,
      {int page = 1, String? cookie}) async {
    if (forumId <= 0) {
      throw XdnmbApiException('板块ID要大于0');
    }
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().htmlForum(forumId, page: page),
        cookie ?? xdnmbCookie?.cookie);
    final document = parse(response.utf8Body);
    _handleDocument(document);

    final rule = document.querySelector('div.h-forum-header');
    if (rule == null) {
      throw XdnmbApiException('没找到板块信息');
    }

    return rule.innerHtml.trim();
  }

  /// [page]最大值根据[Timeline.maxPage]。
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

  /// 一页最多19个回复。
  ///
  /// 没有饼干的话只能浏览前100页。
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

  /// 一页最多20个回复。
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

  Future<Reference> getReference(int postId, {String? cookie}) async {
    if (postId <= 0) {
      throw XdnmbApiException('串的ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().reference(postId), cookie ?? xdnmbCookie?.cookie);

    return Reference._fromJson(response.utf8Body);
  }

  Future<HtmlReference> getHtmlReference(int postId, {String? cookie}) async {
    if (postId <= 0) {
      throw XdnmbApiException('串的ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().htmlReference(postId), cookie ?? xdnmbCookie?.cookie);

    return HtmlReference._fromHtml(response.utf8Body);
  }

  /// 最多10个
  Future<List<Feed>> getFeed(String uuid,
      {int page = 1, String? cookie}) async {
    if (page <= 0) {
      throw XdnmbApiException('页数要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().feed(uuid, page: page), cookie ?? xdnmbCookie?.cookie);

    return Feed._fromJson(response.utf8Body);
  }

  Future<void> addFeed(String uuid, int mainPostId, {String? cookie}) async {
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().addFeed(uuid, mainPostId), cookie ?? xdnmbCookie?.cookie);
    final String decoded = json.decode(response.utf8Body);

    if (!decoded.contains('订阅大成功')) {
      throw XdnmbApiException(decoded);
    }
  }

  Future<void> deleteFeed(String uuid, int mainPostId, {String? cookie}) async {
    if (mainPostId <= 0) {
      throw XdnmbApiException('主串ID要大于0');
    }

    final response = await _client.xGet(
        XdnmbUrls().deleteFeed(uuid, mainPostId),
        cookie ?? xdnmbCookie?.cookie);
    final String decoded = json.decode(response.utf8Body);

    if (!decoded.contains('取消订阅成功')) {
      throw XdnmbApiException(decoded);
    }
  }

  /// [email]其实没用
  Future<void> postNewThread(
      {required int forumId,
      required String content,
      String? name,
      String? email,
      String? title,
      bool? watermark,
      Image? image,
      String? cookie}) async {
    cookie = cookie ?? xdnmbCookie?.cookie;
    if (cookie == null) {
      throw XdnmbApiException('发串需要饼干');
    }
    if (forumId <= 0) {
      throw XdnmbApiException('板块ID要大于0');
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
    if (watermark != null && watermark) {
      multipart.add('water', watermark);
    }
    if (image != null) {
      multipart.addBytes('image', image.data,
          filename: image.filename, contentType: image.imageType.mineType());
    }

    final response = await _client.xPostMultipart(multipart, cookie);
    _handleHtml(response.utf8Body);
  }

  Future<void> postNewThreadWithImage(
          {required int forumId,
          required String content,
          required String imageFile,
          String? name,
          String? email,
          String? title,
          bool? watermark,
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

  /// [email]其实没用
  Future<void> replyThread(
      {required int mainPostId,
      required String content,
      String? name,
      String? email,
      String? title,
      bool? watermark,
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
    if (watermark != null && watermark) {
      multipart.add('water', watermark);
    }
    if (image != null) {
      multipart.addBytes('image', image.data,
          contentType: image.imageType.mineType(), filename: image.filename);
    }

    final response = await _client.xPostMultipart(multipart, cookie);
    _handleHtml(response.utf8Body);
  }

  Future<void> replyThreadWithImage(
          {required int mainPostId,
          required String content,
          required String imageFile,
          String? name,
          String? email,
          String? title,
          bool? watermark,
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

  void close() {
    _client.close();
  }

  Future<Uint8List> getVerifyImage() async =>
      (await _client.xGet(XdnmbUrls().verifyImage)).bodyBytes;

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

  Future<CookieList> getCookiesList({String? userCookie}) async {
    userCookie = userCookie ?? _userCookie;
    if (userCookie == null) {
      throw XdnmbApiException('获取饼干列表需要用户Cookie');
    }
    final response = await _client.xGet(XdnmbUrls().cookiesList, userCookie);
    final document = parse(response.utf8Body);
    _handleDocument(document);

    var element = document.querySelector('b.am-text-success');
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
    final cookiesList = <XdnmbCookie>[];
    for (final id in idList) {
      cookiesList.add(await getCookie(id, userCookie: userCookie));
    }

    return CookieList._internal(
        canGetCookie: canGetCookie,
        currentCookiesNum: currentCookiesNum,
        totalCookiesNum: totalCookiesNum,
        cookiesList: cookiesList);
  }

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

void _handleJsonError(dynamic decoded) {
  if (decoded is String) {
    throw XdnmbApiException(decoded);
  }
  if (decoded is Map<String, dynamic> && decoded['error'] != null) {
    throw XdnmbApiException(decoded['error'].toString());
  }
}

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

String? _handleHtml(String data) => _handleDocument(parse(data));

DateTime _parseTimeString(String timeString) {
  final time = timeString.replaceFirst(_RegExp._parseDay, 'T');

  return DateTime.parse('$time+0800');
}

abstract class _RegExp {
  static final RegExp _parseDay = RegExp(r'\(.*\)');

  static final RegExp _cookieNum = RegExp(r'([0-9])/([0-9])');

  static final RegExp _parseNum = RegExp(r'[0-9]+');

  static final RegExp _parseMainPostId = RegExp(r't/([0-9]+)');

  static final RegExp _parseThumbImage = RegExp(r'thumb/([^\.]+)(\..*)?');

  static final RegExp _parseUserHash = RegExp(r'ID:(.+)');
}
