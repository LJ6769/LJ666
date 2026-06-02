import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hilmi/config/config.dart';
import 'package:hilmi/core/app_bootstrap.dart';
import 'package:hilmi/core/auth_service.dart';
import 'package:hilmi/core/feed_data_cache.dart';
import 'package:hilmi/data/home_placeholder_data.dart';
import 'package:hilmi/models/home_models.dart';
import 'package:hilmi/services/storage_media_url_resolver.dart';
import 'package:hilmi/utils/tipsy_bar_display_slots.dart';
import 'package:hilmi/utils/supabase_auth_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeRepository {
  const HomeRepository();

  static const _chatRoomSelect = '''
          id,
          room_index,
          title,
          description,
          cover_path,
          image_on_right,
          show_on_home,
          sort_order,
          ChatRoomMember (
            sort_order,
            User (
              avatar_path
            )
          )
        ''';

  Future<HomeFeedData> fetchHomeFeed({
    Set<String> blockedHostIds = const {},
  }) async {
    return _loadHomeFeed(blockedHostIds: blockedHostIds);
  }

  /// 下拉刷新：Discover / Live / Tipsy Bar 均重新随机。
  Future<HomeFeedData> refreshHomeFeed({
    Set<String> blockedHostIds = const {},
  }) {
    FeedDataCache.clearHomeFeed();
    return _loadHomeFeed(
      forceRefresh: true,
      blockedHostIds: blockedHostIds,
    );
  }

  Future<HomeFeedData> _loadHomeFeed({
    bool forceRefresh = false,
    Set<String> blockedHostIds = const {},
  }) async {
    if (!forceRefresh) {
      final cached = FeedDataCache.homeFeed;
      if (cached != null) return cached;
    }

    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      debugPrint('[HomeRepository] Supabase not ready, using placeholder data');
      return _homePlaceholderFeed();
    }

    try {
      final feed = await _fetchFromSupabase(
        client,
        blockedHostIds: blockedHostIds,
      ).timeout(
        AppConfig.supabaseHomeRequestTimeout,
        onTimeout: () {
          debugPrint('[HomeRepository] Request timed out, using placeholder data');
          return _homePlaceholderFeed();
        },
      );
      FeedDataCache.setHomeFeed(feed);
      return feed;
    } on PostgrestException catch (error, stack) {
      if (isJwtClockSkewError(error)) {
        debugPrint('[HomeRepository] JWT clock skew; some auth APIs may fail');
      } else if (error.code == 'PGRST205') {
        debugPrint(
          '[HomeRepository] Table missing. Run deploy_six_tables.sql and migrations/20260603000003_chat_room.sql in SQL Editor',
        );
      } else {
        debugPrint('[HomeRepository] Load failed: $error');
      }
      debugPrint('$stack');
      return _homePlaceholderFeed();
    } catch (error, stack) {
      debugPrint('[HomeRepository] Load failed: $error');
      debugPrint('$stack');
      return _homePlaceholderFeed();
    }
  }

  Future<HomeFeedData> _fetchFromSupabase(
    SupabaseClient client, {
    Set<String> blockedHostIds = const {},
  }) async {
    final results = await Future.wait([
      _fetchProfileStories(client),
      _fetchLiveRooms(client),
      _fetchTipsyBarRooms(client),
    ]);

    final stories = results[0] as List<ProfileStory>;
    final liveRooms = results[1] as List<LiveRoom>;
    final tipsyRooms = results[2] as List<TipsyBarRoom>;

    debugPrint(
      '[HomeRepository] Stories=${stories.length} '
      'Live=${liveRooms.length} Tipsy=${tipsyRooms.length}',
    );

    return _assembleHomeFeed(
      storyPool: stories,
      liveRooms: liveRooms,
      tipsyRooms: tipsyRooms,
      blockedHostIds: blockedHostIds,
    );
  }

  /// 拉黑/取消拉黑后本地过滤，避免整页重拉与媒体重签。
  static HomeFeedData filterByBlockedHosts(
    HomeFeedData feed,
    Set<String> blockedHostIds,
  ) {
    if (blockedHostIds.isEmpty) return feed;
    return HomeFeedData(
      coinBalance: feed.coinBalance,
      profileStories: feed.profileStories
          .where((s) => !blockedHostIds.contains(s.id))
          .toList(growable: false),
      liveRooms: feed.liveRooms
          .where(
            (r) =>
                r.hostId == null ||
                r.hostId!.isEmpty ||
                !blockedHostIds.contains(r.hostId),
          )
          .toList(growable: false),
      tipsyBarRooms: feed.tipsyBarRooms,
    );
  }

  HomeFeedData _assembleHomeFeed({
    required List<ProfileStory> storyPool,
    required List<LiveRoom> liveRooms,
    required List<TipsyBarRoom> tipsyRooms,
    Set<String> blockedHostIds = const {},
  }) {
    final discoverPool = storyPool.isNotEmpty
        ? storyPool
        : kHomePlaceholderData.profileStories;

    final usePlaceholderMedia = !AppBootstrap.isReady;

    return HomeFeedData(
      coinBalance: AuthService.cachedProfile?.coins ?? UserConfig.guestBalance,
      profileStories: _pickRandomDiscoverStories(discoverPool),
      liveRooms: _pickRandomLiveRooms(
        _eligibleLiveRooms(
          liveRooms.isNotEmpty
              ? liveRooms
              : (usePlaceholderMedia ? kHomePlaceholderData.liveRooms : []),
          blockedHostIds,
        ),
      ),
      tipsyBarRooms: _pickRandomTipsyBarRooms(
        tipsyRooms.isNotEmpty
            ? tipsyRooms
            : (usePlaceholderMedia ? kHomePlaceholderData.tipsyBarRooms : []),
      ),
    );
  }

  Future<List<ProfileStory>> _fetchProfileStories(
    SupabaseClient client,
  ) async {
    final myId = AuthService.cachedProfile?.id.trim();

    var query = client
        .from(SupabaseTables.user)
        .select('id, display_name, email, avatar_path');

    if (myId != null && myId.isNotEmpty) {
      query = query.neq('id', myId);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(FeedConfig.discoverPoolLimit) as List<dynamic>;

    if (rows.isEmpty) return const [];

    final paths = <String?>[
      for (final row in rows) (row as Map<String, dynamic>)['avatar_path'] as String?,
    ];
    final signed = await StorageMediaUrlResolver.resolveMany(
      paths,
      client: client,
    );

    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      final avatarPath = map['avatar_path'] as String?;
      return ProfileStory(
        id: map['id'] as String,
        name: map['display_name'] as String?,
        email: map['email'] as String?,
        imageUrl: StorageMediaUrlResolver.pickNullable(signed, avatarPath),
      );
    }).toList();
  }

  List<ProfileStory> _pickRandomDiscoverStories(List<ProfileStory> pool) {
    if (pool.isEmpty) return pool;
    final shuffled = List<ProfileStory>.from(pool)..shuffle(Random());
    return shuffled.take(FeedConfig.discoverPreviewCount).toList();
  }

  HomeFeedData _homePlaceholderFeed() {
    final offline = !AppBootstrap.isReady;
    return _assembleHomeFeed(
      storyPool: kHomePlaceholderData.profileStories,
      liveRooms: offline ? kHomePlaceholderData.liveRooms : [],
      tipsyRooms: offline ? kHomePlaceholderData.tipsyBarRooms : [],
    );
  }

  static const _liveRoomSelect = '''
          id,
          streamer_id,
          description,
          cover_path,
          video_path,
          is_live,
          sort_order,
          viewer_count,
          User!streamer_id (
            display_name,
            email,
            avatar_path
          )
        ''';

  /// See All → Popular 随机展示数量；Tutorials / Other 显示该分类全部。
  /// Bartending Live 列表（See All）：Popular 随机 4 条，其余按分类筛选。
  Future<List<LiveRoom>> fetchBartendingLiveList({
    String? categorySlug,
    Set<String> blockedHostIds = const {},
  }) async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      return _bartendingListResult(
        kBartendingLiveListPlaceholder,
        categorySlug,
        blockedHostIds,
      );
    }

    try {
      var query = client
          .from(SupabaseTables.live)
          .select(_liveRoomSelect)
          .eq('is_live', true);

      if (categorySlug != null) {
        query = query.eq('category_slug', categorySlug);
      }

      final rows =
          await query.order('sort_order', ascending: true) as List<dynamic>;
      final rooms = await _mapLiveRows(rows, client);
      final pool = rooms.isNotEmpty
          ? rooms
          : <LiveRoom>[];
      return _bartendingListResult(pool, categorySlug, blockedHostIds);
    } catch (error, stack) {
      debugPrint('[HomeRepository] fetchBartendingLiveList: $error');
      debugPrint('$stack');
      return _bartendingListResult(<LiveRoom>[], categorySlug, blockedHostIds);
    }
  }

  List<LiveRoom> _bartendingListResult(
    List<LiveRoom> pool,
    String? categorySlug,
    Set<String> blockedHostIds,
  ) {
    final eligible = _eligibleLiveRooms(pool, blockedHostIds);
    if (categorySlug == null) {
      return _pickRandomLiveRooms(eligible, count: FeedConfig.livePopularListCount);
    }
    return eligible;
  }

  List<LiveRoom> _eligibleLiveRooms(
    List<LiveRoom> pool,
    Set<String> blockedHostIds,
  ) {
    if (blockedHostIds.isEmpty) return pool;
    return pool
        .where((room) => !blockedHostIds.contains(room.hostId))
        .toList(growable: false);
  }

  /// 首页 Bartending Live 每次随机展示数量。
  Future<List<LiveRoom>> _fetchLiveRooms(SupabaseClient client) async {
    final rows = await client
        .from(SupabaseTables.live)
        .select(_liveRoomSelect)
        .eq('is_live', true)
        .order('sort_order', ascending: true) as List<dynamic>;

    return _mapLiveRows(rows, client);
  }

  List<LiveRoom> _pickRandomLiveRooms(
    List<LiveRoom> pool, {
    int? count,
  }) {
    if (pool.isEmpty) return pool;
    final limit = count ?? FeedConfig.liveHomePreviewCount;
    final shuffled = List<LiveRoom>.from(pool)..shuffle(Random());
    return shuffled.take(limit).toList();
  }

  Future<List<LiveRoom>> _mapLiveRows(
    List<dynamic> rows,
    SupabaseClient client,
  ) async {
    final mediaPaths = <String?>[];
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final profile = _readEmbeddedProfile(map['User']);
      // 列表只签封面与头像；视频进房时再签（见 LiveRepository.resolveVideoUrl）。
      mediaPaths.addAll([
        map['cover_path'] as String?,
        profile?['avatar_path'] as String?,
      ]);
    }
    final signed = await StorageMediaUrlResolver.resolveMany(
      mediaPaths,
      client: client,
    );

    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      final profile = _readEmbeddedProfile(map['User']);
      final avatarPath = profile?['avatar_path'] as String?;
      final coverPath = map['cover_path'] as String?;

      final streamerId = map['streamer_id'] as String?;
      final hostEmail = profile?['email'] as String?;

      return LiveRoom(
        id: map['id'] as String,
        coverUrl: StorageMediaUrlResolver.pick(signed, coverPath),
        videoUrl: null,
        hostName: profile?['display_name'] as String?,
        hostId: streamerId,
        hostEmail: hostEmail,
        hostAvatarUrl: StorageMediaUrlResolver.pick(signed, avatarPath),
        title: _liveCardTitle(map['description'] as String?),
        isLive: map['is_live'] as bool? ?? true,
      );
    }).toList();
  }

  /// Tipsy Bar 列表页（See All）。
  Future<List<TipsyBarRoom>> fetchTipsyBarList() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      return kHomePlaceholderData.tipsyBarRooms;
    }

    try {
      return await _fetchTipsyBarRooms(client);
    } catch (error, stack) {
      debugPrint('[HomeRepository] fetchTipsyBarList: $error');
      debugPrint('$stack');
      return const [];
    }
  }

  Future<List<TipsyBarRoom>> _fetchTipsyBarRooms(SupabaseClient client) async {
    final rows = await client
        .from(SupabaseTables.chatRoom)
        .select(_chatRoomSelect)
        .order('sort_order', ascending: true) as List<dynamic>;

    return _mapChatRoomRows(rows, client);
  }

  List<TipsyBarRoom> _pickRandomTipsyBarRooms(List<TipsyBarRoom> pool) {
    if (pool.isEmpty) return pool;
    final shuffled = List<TipsyBarRoom>.from(pool)..shuffle(Random());
    return shuffled
        .take(FeedConfig.tipsyBarHomePreviewCount)
        .toList()
        .asMap()
        .entries
        .map((entry) => _tipsyRoomWithPhotoSide(entry.value, entry.key))
        .toList();
  }

  /// 首页随机卡片：第 0 张图在左，第 1 张在右，依次交替。
  TipsyBarRoom _tipsyRoomWithPhotoSide(TipsyBarRoom room, int index) {
    return TipsyBarRoom(
      id: room.id,
      coverUrl: room.coverUrl,
      title: room.title,
      description: room.description,
      participantAvatarUrls: room.participantAvatarUrls,
      imageOnRight: index.isOdd,
    );
  }

  Future<List<TipsyBarRoom>> _mapChatRoomRows(
    List<dynamic> rows,
    SupabaseClient client,
  ) async {
    final mediaPaths = <String?>[];
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      mediaPaths.add(map['cover_path'] as String?);
      for (final member in _readEmbeddedMembers(map['ChatRoomMember'])) {
        final profile = _readEmbeddedProfile(member['User']);
        mediaPaths.add(profile?['avatar_path'] as String?);
      }
    }

    final signed = await StorageMediaUrlResolver.resolveMany(
      mediaPaths,
      client: client,
    );

    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      final coverPath = map['cover_path'] as String?;
      final participantUrls = _participantAvatarUrls(map, signed);

      return TipsyBarRoom(
        id: map['id'] as String,
        coverUrl: StorageMediaUrlResolver.pick(signed, coverPath),
        title: map['title'] as String?,
        description: map['description'] as String?,
        participantAvatarUrls: participantUrls,
        imageOnRight: map['image_on_right'] as bool? ?? false,
      );
    }).toList();
  }

  List<Map<String, dynamic>> _readEmbeddedMembers(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map<String, dynamic>) item,
      ];
    }
    if (raw is Map<String, dynamic>) return [raw];
    return const [];
  }

  List<String?> _participantAvatarUrls(
    Map<String, dynamic> roomMap,
    Map<String, String> signed,
  ) {
    final members = _readEmbeddedMembers(roomMap['ChatRoomMember'])
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
          b['sort_order'] as int? ?? 0,
        ),
      );

    final urls = [
      for (final member in members.take(5))
        StorageMediaUrlResolver.pickNullable(
          signed,
          _readEmbeddedProfile(member['User'])?['avatar_path'] as String?,
        ),
    ];
    return tipsyBarCardParticipantAvatars(urls);
  }

  Map<String, dynamic>? _readEmbeddedProfile(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  /// 仅规范化空白；行数与省略号由首页 Live 卡片 UI 控制。
  String? _liveCardTitle(String? description) {
    if (description == null || description.isEmpty) return null;
    return description.replaceAll('\n', ' ').trim();
  }
}
