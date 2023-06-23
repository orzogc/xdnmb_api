import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:xdnmb_api/src/xdnmb.dart';

const bool _useHttps = false;

const bool _useBackupApi = true;

void main() async {
  group('XdnmbApi', () {
    final userHash = Platform.environment['XdnmbUserHash'];
    final xdnmb = XdnmbApi(userHash: userHash);
    final image = Platform.environment['XdnmbImage'];

    test('updateUrls() updates URLs', () async {
      await xdnmb.updateUrls(_useHttps);
      xdnmb.useHttps(_useHttps);
      xdnmb.useBackupApi(_useBackupApi);
    });

    test('getNotice() gets the notice', () async {
      final notice = await xdnmb.getNotice();

      expect(notice.content, isNotEmpty);
      expect(notice.index, isPositive);
      expect(notice.isValid, isTrue);
    });

    test('getCdnList() gets the CDN list', () async {
      final cdnList = await xdnmb.getCdnList();

      expect(cdnList[0].url, equals('https://image.nmb.best/'));
    });

    test('getForumList() gets the forum list', () async {
      final forumList = await xdnmb.getForumList();

      for (final forumGroup in forumList.forumGroupList) {
        expect(forumGroup.id, isPositive);
        expect(forumGroup.sort, isNonNegative);
        expect(forumGroup.name, isNotEmpty);
        expect(forumGroup.status, equals('n'));
      }

      if (forumList.timelineList != null) {
        final timeline = forumList.timelineList![0];
        expect(timeline.id, equals(-1));
        expect(timeline.name, equals('时间线'));
        expect(timeline.message, isNotEmpty);
      }

      for (final forum in forumList.forumList) {
        expect(forum.id, isPositive);
        expect(forum.forumGroupId, isPositive);
        expect(forum.sort, isNonNegative);
        expect(forum.name, isNotEmpty);
        expect(forum.message, isNotEmpty);
        expect(forum.interval, isPositive);
        expect(forum.autoDelete, greaterThanOrEqualTo(0));
        expect(forum.threadCount, isPositive);
        expect(forum.permissionLevel, greaterThanOrEqualTo(0));
        expect(forum.forumFuseId, greaterThanOrEqualTo(0));
        expect(forum.createTime, isNotEmpty);
        expect(forum.updateTime, isNotEmpty);
        expect(forum.status, equals('n'));
      }
    });

    test('getTimelineList() gets the timeline list', () async {
      final timelineList = await xdnmb.getTimelineList();

      for (final timeline in timelineList) {
        expect(timeline.id, isPositive);
        expect(timeline.name, isNotEmpty);
        expect(timeline.displayName, isNotEmpty);
        expect(timeline.message, isNotEmpty);
        expect(timeline.maxPage, isPositive);
      }
    });

    test('getHtmlForumInfo() gets the html forum information', () async {
      final forum = await xdnmb.getHtmlForumInfo(4);

      expect(forum.id, equals(4));
      expect(forum.name, isNotEmpty);
      expect(forum.message, isNotEmpty);

      await expectLater(() async => await xdnmb.getHtmlForumInfo(0),
          throwsA(isA<XdnmbApiException>()));
    });

    test('getForum() gets forum threads', () async {
      final forumList = await xdnmb.getForumList();

      for (final forum in forumList.forumList) {
        if (xdnmb.xdnmbCookie != null || forum.permissionLevel == 0) {
          final forumThreads = await xdnmb.getForum(forum.id);

          testForumThreads(forumThreads, equals(forum.id));
        } else {
          await expectLater(() async => await xdnmb.getForum(forum.id),
              throwsA(isA<XdnmbApiException>()));
        }
      }

      await expectLater(() async => await xdnmb.getForum(0),
          throwsA(isA<XdnmbApiException>()));
    }, timeout: Timeout(Duration(minutes: 1)));

    test('getTimeline() gets timeline threads', () async {
      final timelineList = await xdnmb.getTimelineList();

      for (final timeline in timelineList) {
        if (xdnmb.xdnmbCookie != null || timeline.id != 2) {
          final timelineThreads = await xdnmb.getTimeline(timeline.id);

          testForumThreads(timelineThreads, isPositive);
        } else {
          await expectLater(() async => await xdnmb.getTimeline(timeline.id),
              throwsA(isA<XdnmbApiException>()));
        }
      }
    });

    test('getThread() gets the thread', () async {
      final forumThreads = await xdnmb.getForum(4);

      for (final forumThread in forumThreads) {
        final thread = await xdnmb.getThread(forumThread.mainPost.id);

        testPost(thread.mainPost, equals(4), greaterThanOrEqualTo(0), true);
        for (final reply in thread.replies) {
          testPost(reply, isPositive, isZero, true);
        }
        final tip = thread.tip;
        if (tip != null) {
          testTip(tip);
        }
      }

      await expectLater(() async => await xdnmb.getThread(1),
          throwsA(isA<XdnmbApiException>()));
    });

    test("getOnlyPoThread() gets the thread witch only has po's reply",
        () async {
      final forumThreads = await xdnmb.getForum(4);

      for (final forumThread in forumThreads) {
        final thread = await xdnmb.getOnlyPoThread(forumThread.mainPost.id);

        testPost(thread.mainPost, equals(4), greaterThanOrEqualTo(0), true);
        for (final reply in thread.replies) {
          testPost(reply, isPositive, isZero, true);
        }
        final tip = thread.tip;
        if (tip != null) {
          testTip(tip);
        }
      }

      await expectLater(() async => await xdnmb.getThread(1),
          throwsA(isA<XdnmbApiException>()));
    });

    test('getReference() gets the reference of a post', () async {
      final forumThreads = await xdnmb.getForum(4);

      for (final forumThread in forumThreads) {
        final reference = await xdnmb.getReference(forumThread.mainPost.id);

        testReference(reference);
        expect(reference.status, equals('n'));
      }

      final thread = await xdnmb.getThread(forumThreads[1].mainPost.id);
      for (final reply in thread.replies) {
        final reference = await xdnmb.getReference(reply.id);

        testReference(reference);
        expect(reference.status, equals('n'));
      }

      await expectLater(() async => await xdnmb.getReference(1),
          throwsA(isA<XdnmbApiException>()));
    });

    test('getHtmlReference() gets the html reference of a post', () async {
      final forumThreads = await xdnmb.getForum(4);

      for (final forumThread in forumThreads) {
        final reference = await xdnmb.getHtmlReference(forumThread.mainPost.id);

        testReference(reference);
        expect(reference.mainPostId, isNotNull);
      }

      final thread = await xdnmb.getThread(forumThreads[1].mainPost.id);
      for (final reply in thread.replies) {
        final reference = await xdnmb.getHtmlReference(reply.id);

        testReference(reference);
        expect(reference.mainPostId, isNull);
      }

      await expectLater(() async => await xdnmb.getHtmlReference(1),
          throwsA(isA<XdnmbApiException>()));
    });

    const String feedId = '4aabbf60-d9be-475a-8276-c0b11d2535d2';

    test('getFeed() gets the feed', () async {
      final feed = await xdnmb.getFeed(feedId);

      for (final feedPost in feed) {
        expect(feedPost.id, isPositive);
        expect(feedPost.userId, isPositive);
        expect(feedPost.forumId, isPositive);
        expect(feedPost.replyCount, greaterThanOrEqualTo(0));
        for (final replyId in feedPost.recentReplies) {
          expect(replyId, isPositive);
        }
        expect(feedPost.category, isEmpty);
        expect(feedPost.fileId, greaterThanOrEqualTo(0));
        if (feedPost.image.isEmpty) {
          expect(feedPost.imageExtension, isEmpty);
        } else {
          expect(feedPost.imageExtension, isNotEmpty);
          expect(feedPost.thumbImageUrl, isNotEmpty);
          expect(feedPost.imageUrl, isNotEmpty);
        }
        expect(feedPost.postTime.toString(), isNotEmpty);
        expect(feedPost.userHash, isNotEmpty);
        expect(feedPost.content, isNotEmpty);
        expect(feedPost.status, equals('n'));
        expect(feedPost.po, isEmpty);
      }
    });

    test('getHtmlFeed() gets the feed from HTML', () async {
      final (feedList, maxPage) = await xdnmb.getHtmlFeed();

      for (final feed in feedList) {
        testPost(feed, isNull, isNull, false);
      }

      expect(maxPage, isPositive);
    },
        skip: xdnmb.xdnmbCookie == null
            ? 'the environment variable XdnmbUserHash is not set'
            : null);

    const int feedMainPostId = 50000002;

    test('addFeed() adds the main post to the feed', () async {
      await xdnmb.addFeed(feedId, feedMainPostId);

      await expectLater(() async => await xdnmb.addFeed(feedId, 1),
          throwsA(isA<XdnmbApiException>()));
    });

    test('addHtmlFeed() adds the main post to the feed from HTML', () async {
      await xdnmb.addHtmlFeed(feedMainPostId);

      await expectLater(() async => await xdnmb.addHtmlFeed(1),
          throwsA(isA<XdnmbApiException>()));
    },
        skip: xdnmb.xdnmbCookie == null
            ? 'the environment variable XdnmbUserHash is not set'
            : null);

    test('deleteFeed() deletes the main post from the feed', () async {
      await xdnmb.deleteFeed(feedId, feedMainPostId);
    });

    test('deleteHtmlFeed() deletes the main post from the feed from HTML',
        () async {
      await xdnmb.deleteHtmlFeed(feedMainPostId);
    },
        skip: xdnmb.xdnmbCookie == null
            ? 'the environment variable XdnmbUserHash is not set'
            : null);

    test(
        'postNewThread() posts a new thread and replyThread() replies a thread',
        () async {
      final threadContent = getRandomString(20);
      await xdnmb.postNewThreadWithImage(
        forumId: 122,
        content: threadContent,
        imageFile: image!,
        name: 'foo',
        email: 'bar',
        title: 'baz',
        watermark: true,
      );
      final forumThreads = await xdnmb.getForum(122);
      expect(forumThreads, isNotEmpty);
      final mainPost = forumThreads[0].mainPost;

      testNewPost(mainPost, threadContent, 'foo', 'baz');

      LastPost? lastPost = await xdnmb.getLastPost();
      testLastPost(lastPost!, null, threadContent, 'foo', 'bar', 'baz');

      await Future.delayed(Duration(seconds: 20));
      final postContent = getRandomString(20);
      await xdnmb.replyThreadWithImage(
        mainPostId: mainPost.id,
        content: postContent,
        imageFile: image,
        name: 'foo',
        email: 'bar',
        title: 'baz',
        watermark: false,
      );
      final thread = await xdnmb.getThread(mainPost.id);
      expect(thread.replies, isNotEmpty);
      final post = thread.replies[0];

      testNewPost(post, postContent, 'foo', 'baz');
      expect(mainPost.image, isNot(equals(post.image)));
      expect(mainPost.imageExtension, equals(post.imageExtension));
      expect(mainPost.thumbImageUrl, isNotEmpty);
      expect(mainPost.imageUrl, isNotEmpty);
      expect(post.thumbImageUrl, isNotEmpty);
      expect(post.imageUrl, isNotEmpty);

      lastPost = await xdnmb.getLastPost();
      testLastPost(lastPost!, mainPost.id, postContent, 'foo', 'bar', 'baz');
    },
        skip: (xdnmb.xdnmbCookie == null || image == null)
            ? 'the environment variable XdnmbUserHash or XdnmbImage is not set'
            : null);
  });
}

void testPost(PostBase post, Matcher forumIdMatcher, Matcher replyCountMatcher,
    bool testTitle) {
  expect(post.id, isPositive);
  expect(post.forumId, forumIdMatcher);
  expect(post.replyCount, replyCountMatcher);
  if (post.image.isEmpty) {
    expect(post.imageExtension, isEmpty);
  } else {
    expect(post.imageExtension, isNotEmpty);
    expect(post.thumbImageUrl, isNotEmpty);
    expect(post.imageUrl, isNotEmpty);
  }
  expect(post.postTime.toString(), isNotEmpty);
  expect(post.userHash, isNotEmpty);
  expect(post.name, isNotEmpty);
  if (testTitle) {
    expect(post.title, isNotEmpty);
  }
  expect(post.content, isNotEmpty);
}

void testForumThreads(List<ForumThread> forumThreads, Matcher forumIdMatcher) {
  for (final forumThread in forumThreads) {
    testPost(forumThread.mainPost, forumIdMatcher,
        greaterThanOrEqualTo(forumThread.recentReplies.length), true);
    for (final reply in forumThread.recentReplies) {
      testPost(reply, isPositive, isZero, true);
    }
    if (forumThread.mainPost.replyCount > 5) {
      expect(forumThread.remainReplies,
          equals(forumThread.mainPost.replyCount - 5));
    } else {
      expect(forumThread.remainReplies, isNull);
    }
  }
}

void testReference(ReferenceBase reference) {
  expect(reference.id, isPositive);
  if (reference.image.isEmpty) {
    expect(reference.imageExtension, isEmpty);
  } else {
    expect(reference.imageExtension, isNotEmpty);
    expect(reference.thumbImageUrl, isNotEmpty);
    expect(reference.imageUrl, isNotEmpty);
  }
  expect(reference.postTime.toString(), isNotEmpty);
  expect(reference.userHash, isNotEmpty);
  expect(reference.name, isNotEmpty);
  expect(reference.title, isNotEmpty);
  expect(reference.content, isNotEmpty);
}

void testNewPost(Post post, String content, String name, String title) {
  expect(post.id, isPositive);
  expect(post.forumId, equals(122));
  expect(post.replyCount, isZero);
  expect(post.image, isNotEmpty);
  expect(post.imageExtension, isNotEmpty);
  expect(post.thumbImageUrl, isNotEmpty);
  expect(post.imageUrl, isNotEmpty);
  expect(post.postTime.toString(), isNotEmpty);
  expect(post.userHash, isNotEmpty);
  expect(post.name, equals(name));
  expect(post.title, equals(title));
  expect(post.content, equals(content));
  expect(post.isSage, isFalse);
  expect(post.isAdmin, isFalse);
  expect(post.isHidden, isFalse);
}

void testLastPost(LastPost post, int? mainPostId, String content, String name,
    String email, String title) {
  expect(post.id, isPositive);
  expect(post.mainPostId, equals(mainPostId));
  expect(post.postTime.toString(), isNotEmpty);
  expect(post.userHash, isNotEmpty);
  expect(post.name, equals(name));
  expect(post.email, equals(email));
  expect(post.title, equals(title));
  expect(post.content, equals(content));
  expect(post.isSage, isFalse);
  expect(post.isAdmin, isFalse);
}

void testTip(Tip tip) {
  expect(tip.id, equals(9999999));
  expect(tip.userHash, equals('Tips'));
  expect(tip.isAdmin, isTrue);
  expect(tip.title, equals('Tips'));
  expect(tip.postTime.toString(), isNotEmpty);
  expect(tip.content, isNotEmpty);
  if (tip.image.isEmpty) {
    expect(tip.imageExtension, isEmpty);
  } else {
    expect(tip.imageExtension, isNotEmpty);
    expect(tip.thumbImageUrl, isNotEmpty);
    expect(tip.imageUrl, isNotEmpty);
  }
  expect(tip.name, equals('无名氏'));
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random.secure();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
