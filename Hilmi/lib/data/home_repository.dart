// 首页 Feed：Live 房、Tipsy Bar、明星故事等聚合拉取。
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

  static Future<List<LiveRoom>>? _bartendingPoolFetch;
  static Future<List<TipsyBarRoom>>? _tipsyBarPoolFetch;

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
              id,
              avatar_path
            )
          )
        ''';

  Future<HomeFeedData> fetchHomeFeed({
    Set<String> blockedHostIds = const {},
  }) async {
    return _loadHomeFeed(blockedHostIds: blockedHostIds);
  }

  /// 下拉刷新：优先从本地池重新随机；池未命中再拉 Supabase。
  Future<HomeFeedData> refreshHomeFeed({
    Set<String> blockedHostIds = const {},
  }) async {
    FeedDataCache.clearHomeFeed();

    final storyPool = FeedDataCache.discoverStoryPool;
    if (storyPool != null) {
      final liveRooms = FeedDataCache.bartendingLivePool ?? const <LiveRoom>[];
      final tipsyRooms = FeedDataCache.tipsyBarPool ?? const <TipsyBarRoom>[];
      final feed = _assembleHomeFeed(
        storyPool: List<ProfileStory>.from(storyPool),
        liveRooms: List<LiveRoom>.from(liveRooms),
        tipsyRooms: List<TipsyBarRoom>.from(tipsyRooms),
        blockedHostIds: blockedHostIds,
      );
      FeedDataCache.setHomeFeed(feed);
      return feed;
    }

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
    if (liveRooms.isNotEmpty) {
      FeedDataCache.setBartendingLivePool(liveRooms);
    }
    if (tipsyRooms.isNotEmpty) {
      FeedDataCache.setTipsyBarPool(tipsyRooms);
    }

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

  /// 拉黑后仅移除相关卡片，其余保留；不足时从本地池补位（不整批重抽）。
  static HomeFeedData filterByBlockedHosts(
    HomeFeedData feed,
    Set<String> blockedHostIds,
  ) {
    if (blockedHostIds.isEmpty) return feed;

    const repo = HomeRepository();

    return HomeFeedData(
      coinBalance: feed.coinBalance,
      profileStories: repo._refillDiscoverStoriesAfterBlock(
        feed.profileStories,
        blockedHostIds,
      ),
      liveRooms: repo._refillLivePreviewAfterBlock(
        feed.liveRooms,
        blockedHostIds,
      ),
      tipsyBarRooms: repo._refillTipsyPreviewAfterBlock(
        feed.tipsyBarRooms,
        blockedHostIds,
      ),
    );
  }

  List<ProfileStory> _refillDiscoverStoriesAfterBlock(
    List<ProfileStory> current,
    Set<String> blockedHostIds,
  ) {
    final myId = AuthService.cachedProfile?.id.trim();
    bool isEligible(ProfileStory story) {
      if (blockedHostIds.contains(story.id)) return false;
      if (myId != null && myId.isNotEmpty && story.id == myId) return false;
      return true;
    }

    final kept =
        current.where(isEligible).toList(growable: false);
    // 展示不足 6 张且本次为拉黑（有卡片被移除）时仅减不补；
    // 取消拉黑或列表已空时从本地池恢复，与 Live 卡一致。
    final removedSomeone = kept.length < current.length;
    if (removedSomeone && current.length < FeedConfig.discoverPreviewCount) {
      return kept;
    }

    final pool = FeedDataCache.discoverStoryPool ?? const <ProfileStory>[];
    return _fillPreviewFromPool<ProfileStory>(
      kept: kept,
      pool: pool.where(isEligible).toList(growable: false),
      targetCount: FeedConfig.discoverPreviewCount,
      idOf: (story) => story.id,
      mapAtIndex: (story, _) => story,
    );
  }

  List<LiveRoom> _refillLivePreviewAfterBlock(
    List<LiveRoom> current,
    Set<String> blockedHostIds,
  ) {
    final kept = current
        .where(
          (room) =>
              room.hostId == null ||
              room.hostId!.isEmpty ||
              !blockedHostIds.contains(room.hostId),
        )
        .toList(growable: false);
    final pool = FeedDataCache.bartendingLivePool ?? const <LiveRoom>[];
    return _fillPreviewFromPool<LiveRoom>(
      kept: kept,
      pool: _eligibleLiveRooms(pool, blockedHostIds),
      targetCount: FeedConfig.liveHomePreviewCount,
      idOf: (room) => room.id,
      mapAtIndex: (room, _) => room,
    );
  }

  List<TipsyBarRoom> _refillTipsyPreviewAfterBlock(
    List<TipsyBarRoom> current,
    Set<String> blockedHostIds,
  ) {
    final kept = _eligibleTipsyBarRooms(current, blockedHostIds);
    final pool = FeedDataCache.tipsyBarPool ?? const <TipsyBarRoom>[];
    return _fillPreviewFromPool<TipsyBarRoom>(
      kept: kept,
      pool: _eligibleTipsyBarRooms(pool, blockedHostIds),
      targetCount: FeedConfig.tipsyBarHomePreviewCount,
      idOf: (room) => room.id,
      mapAtIndex: _tipsyRoomWithPhotoSide,
    );
  }

  List<T> _fillPreviewFromPool<T>({
    required List<T> kept,
    required List<T> pool,
    required int targetCount,
    required String Function(T) idOf,
    required T Function(T item, int index) mapAtIndex,
  }) {
    final keptIds = kept.map(idOf).toSet();
    final result = List<T>.from(kept);
    if (result.length < targetCount) {
      final candidates = pool
          .where((item) => !keptIds.contains(idOf(item)))
          .toList(growable: false);
      final shuffled = List<T>.from(candidates)..shuffle(Random());
      for (final item in shuffled) {
        if (result.length >= targetCount) break;
        result.add(item);
        keptIds.add(idOf(item));
      }
    }
    return result
        .take(targetCount)
        .toList()
        .asMap()
        .entries
        .map((entry) => mapAtIndex(entry.value, entry.key))
        .toList();
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
    if (discoverPool.isNotEmpty) {
      FeedDataCache.setDiscoverStoryPool(discoverPool);
    }

    final usePlaceholderMedia = !AppBootstrap.isReady;

    final eligibleStories = blockedHostIds.isEmpty
        ? discoverPool
        : discoverPool
            .where((s) => !blockedHostIds.contains(s.id))
            .toList(growable: false);
    final eligibleTipsyPool = _eligibleTipsyBarRooms(
      tipsyRooms.isNotEmpty
          ? tipsyRooms
          : (usePlaceholderMedia ? kHomePlaceholderData.tipsyBarRooms : []),
      blockedHostIds,
    );

    return HomeFeedData(
      coinBalance: AuthService.cachedProfile?.coins ?? UserConfig.guestBalance,
      profileStories: _pickRandomDiscoverStories(eligibleStories),
      liveRooms: _pickRandomLiveRooms(
        _eligibleLiveRooms(
          liveRooms.isNotEmpty
              ? liveRooms
              : (usePlaceholderMedia ? kHomePlaceholderData.liveRooms : []),
          blockedHostIds,
        ),
      ),
      tipsyBarRooms: _pickRandomTipsyBarRooms(eligibleTipsyPool),
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
          category_slug,
          category_name,
          tags,
          is_live,
          sort_order,
          viewer_count,
          User!streamer_id (
            display_name,
            email,
            avatar_path
          )
        ''';

  /// See All → Popular 随机展示；Tutorials / Other 显示该分类全部。
  /// 首次进入拉取全量直播并缓存，后续各 Tab 从本地分类缓存读取。
  Future<List<LiveRoom>> ensureBartendingLivePool({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = FeedDataCache.bartendingLivePool;
      if (cached != null) return cached;
    }

    final inFlight = _bartendingPoolFetch;
    if (inFlight != null) return inFlight;

    final fetch = _fetchAndCacheBartendingPool();
    _bartendingPoolFetch = fetch;
    try {
      return await fetch;
    } finally {
      if (identical(_bartendingPoolFetch, fetch)) {
        _bartendingPoolFetch = null;
      }
    }
  }

  Future<List<LiveRoom>> fetchBartendingLiveList({
    String? categorySlug,
    Set<String> blockedHostIds = const {},
    bool forceRefresh = false,
  }) async {
    final normalizedSlug = _normalizeCategorySlug(categorySlug);
    if (!forceRefresh && normalizedSlug != null) {
      final cachedCategory = FeedDataCache.bartendingLiveCategory(normalizedSlug);
      if (cachedCategory != null) {
        return _eligibleLiveRooms(cachedCategory, blockedHostIds);
      }
    }

    final pool = await ensureBartendingLivePool(forceRefresh: forceRefresh);
    return _bartendingListResult(pool, normalizedSlug, blockedHostIds);
  }

  Future<List<LiveRoom>> _fetchAndCacheBartendingPool() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      return FeedDataCache.bartendingLivePool ?? kBartendingLiveListPlaceholder;
    }

    try {
      final rows = await client
          .from(SupabaseTables.live)
          .select(_liveRoomSelect)
          .eq('is_live', true)
          .order('sort_order', ascending: true) as List<dynamic>;
      final rooms = await _mapLiveRows(rows, client);
      final pool = rooms.isNotEmpty ? rooms : <LiveRoom>[];
      if (pool.isNotEmpty) {
        FeedDataCache.setBartendingLivePool(pool);
        return pool;
      }
      return FeedDataCache.bartendingLivePool ?? pool;
    } catch (error, stack) {
      debugPrint('[HomeRepository] fetchBartendingLiveList: $error');
      debugPrint('$stack');
      return FeedDataCache.bartendingLivePool ?? const <LiveRoom>[];
    }
  }

  String? _normalizeCategorySlug(String? categorySlug) {
    final slug = categorySlug?.trim().toLowerCase();
    if (slug == null || slug.isEmpty) return null;
    return slug;
  }

  bool _matchesCategorySlug(LiveRoom room, String categorySlug) {
    return _normalizeCategorySlug(room.categorySlug) == categorySlug;
  }

  List<LiveRoom> _bartendingListResult(
    List<LiveRoom> pool,
    String? categorySlug,
    Set<String> blockedHostIds,
  ) {
    var filtered = pool;
    if (categorySlug != null) {
      final cachedCategory = FeedDataCache.bartendingLiveCategory(categorySlug);
      filtered = cachedCategory ??
          pool
              .where((room) => _matchesCategorySlug(room, categorySlug))
              .toList(growable: false);
    }
    final eligible = _eligibleLiveRooms(filtered, blockedHostIds);
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

      final rawDescription = map['description'] as String?;

      return LiveRoom(
        id: map['id'] as String,
        coverUrl: StorageMediaUrlResolver.pick(signed, coverPath),
        videoUrl: null,
        hostName: profile?['display_name'] as String?,
        hostId: streamerId,
        hostEmail: hostEmail,
        hostAvatarUrl: StorageMediaUrlResolver.pick(signed, avatarPath),
        title: _liveCardTitle(rawDescription),
        description: rawDescription,
        tags: _readLiveTags(map['tags']),
        categorySlug: map['category_slug'] as String?,
        categoryName: map['category_name'] as String?,
        isLive: map['is_live'] as bool? ?? true,
      );
    }).toList();
  }

  static List<String> _readLiveTags(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (item != null) item.toString().trim(),
      ].where((tag) => tag.isNotEmpty).toList(growable: false);
    }
    return const [];
  }

  /// Tipsy Bar 列表页（See All）：首次拉取并缓存 30 天，后续从本地读取。
  Future<List<TipsyBarRoom>> fetchTipsyBarList({
    bool forceRefresh = false,
    Set<String> blockedUserIds = const {},
  }) async {
    final pool = await ensureTipsyBarPool(forceRefresh: forceRefresh);
    return _eligibleTipsyBarRooms(pool, blockedUserIds);
  }

  /// 首次进入拉取全量房间并缓存，后续列表页从本地读取。
  Future<List<TipsyBarRoom>> ensureTipsyBarPool({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = FeedDataCache.tipsyBarPool;
      if (cached != null) return cached;
    }

    final inFlight = _tipsyBarPoolFetch;
    if (inFlight != null) return inFlight;

    final fetch = _fetchAndCacheTipsyBarPool();
    _tipsyBarPoolFetch = fetch;
    try {
      return await fetch;
    } finally {
      if (identical(_tipsyBarPoolFetch, fetch)) {
        _tipsyBarPoolFetch = null;
      }
    }
  }

  Future<List<TipsyBarRoom>> _fetchAndCacheTipsyBarPool() async {
    final client = AppBootstrap.client;
    if (!AppBootstrap.isReady || client == null) {
      return FeedDataCache.tipsyBarPool ?? kHomePlaceholderData.tipsyBarRooms;
    }

    try {
      final rooms = await _fetchTipsyBarRooms(client);
      if (rooms.isNotEmpty) {
        FeedDataCache.setTipsyBarPool(rooms);
        return rooms;
      }
      return FeedDataCache.tipsyBarPool ?? rooms;
    } catch (error, stack) {
      debugPrint('[HomeRepository] fetchTipsyBarList: $error');
      debugPrint('$stack');
      return FeedDataCache.tipsyBarPool ?? const <TipsyBarRoom>[];
    }
  }

  Future<List<TipsyBarRoom>> _fetchTipsyBarRooms(SupabaseClient client) async {
    final rows = await client
        .from(SupabaseTables.chatRoom)
        .select(_chatRoomSelect)
        .order('sort_order', ascending: true) as List<dynamic>;

    return _mapChatRoomRows(rows, client);
  }

  List<TipsyBarRoom> _eligibleTipsyBarRooms(
    List<TipsyBarRoom> pool,
    Set<String> blockedUserIds,
  ) {
    if (blockedUserIds.isEmpty) return pool;
    return pool
        .where(
          (room) =>
              (room.hostUserId == null ||
                  room.hostUserId!.isEmpty ||
                  !blockedUserIds.contains(room.hostUserId)) &&
              !room.participantUserIds.any(blockedUserIds.contains),
        )
        .toList(growable: false);
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
      hostUserId: room.hostUserId,
      participantUserIds: room.participantUserIds,
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
        hostUserId: _hostUserIdFromRow(map),
        participantUserIds: _participantUserIdsFromRow(map),
        participantAvatarUrls: participantUrls,
        imageOnRight: map['image_on_right'] as bool? ?? false,
      );
    }).toList();
  }

  List<String> _participantUserIdsFromRow(Map<String, dynamic> roomMap) {
    final members = _readEmbeddedMembers(roomMap['ChatRoomMember'])
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
          b['sort_order'] as int? ?? 0,
        ),
      );
    final seen = <String>{};
    final ids = <String>[];
    for (final member in members) {
      final id =
          (_readEmbeddedProfile(member['User'])?['id'] as String?)?.trim() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      ids.add(id);
    }
    return ids;
  }

  String? _hostUserIdFromRow(Map<String, dynamic> roomMap) {
    final members = _readEmbeddedMembers(roomMap['ChatRoomMember'])
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
          b['sort_order'] as int? ?? 0,
        ),
      );
    if (members.isEmpty) return null;
    final profile = _readEmbeddedProfile(members.first['User']);
    final id = profile?['id'] as String?;
    final trimmed = id?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
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

    final seen = <String>{};
    final urls = <String?>[];
    for (final member in members) {
      final profile = _readEmbeddedProfile(member['User']);
      final id = (profile?['id'] as String?)?.trim() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      urls.add(
        StorageMediaUrlResolver.pickNullable(
          signed,
          profile?['avatar_path'] as String?,
        ),
      );
      if (urls.length >= 5) break;
    }
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
