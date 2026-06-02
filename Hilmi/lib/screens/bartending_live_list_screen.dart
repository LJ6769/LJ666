import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/block_service.dart';
import '../data/home_repository.dart';
import '../models/home_models.dart';
import '../splash_page.dart';
import '../widgets/home_feed_cards.dart';

class BartendingLiveListScreen extends StatefulWidget {
  const BartendingLiveListScreen({super.key});

  @override
  State<BartendingLiveListScreen> createState() =>
      _BartendingLiveListScreenState();
}

class _BartendingLiveListScreenState extends State<BartendingLiveListScreen> {
  static const _tabs = <({
    String? slug,
    String offAsset,
    String onAsset,
  })>[
    (
      slug: null,
      offAsset: 'assets/home/tab_popular_off.png',
      onAsset: 'assets/home/tab_popular_on.png',
    ),
    (
      slug: 'tutorials',
      offAsset: 'assets/home/tab_tutorials_off.png',
      onAsset: 'assets/home/tab_tutorials_on.png',
    ),
    (
      slug: 'other',
      offAsset: 'assets/home/tab_other_off.png',
      onAsset: 'assets/home/tab_other_on.png',
    ),
  ];

  static const _listPhysics = AlwaysScrollableScrollPhysics(
    parent: BouncingScrollPhysics(),
  );

  final _repository = const HomeRepository();
  int _selectedTab = 0;
  List<LiveRoom> _rooms = const [];
  bool _loading = true;

  bool get _isPopularTab => _tabs[_selectedTab].slug == null;

  @override
  void initState() {
    super.initState();
    BlockService.blockedIds.addListener(_onBlockedIdsChanged);
    _loadRooms();
  }

  @override
  void dispose() {
    BlockService.blockedIds.removeListener(_onBlockedIdsChanged);
    super.dispose();
  }

  void _onBlockedIdsChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadRooms());
    });
  }

  Future<void> _loadRooms() async {
    final rooms = await _repository.fetchBartendingLiveList(
      categorySlug: _tabs[_selectedTab].slug,
      blockedHostIds: BlockService.blockedIds.value,
    );
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  void _onTabSelected(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _selectedTab = index;
      _rooms = const [];
      _loading = true;
    });
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: splashBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: splashBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Image.asset(
                        'assets/home/btn_back.png',
                        width: 44,
                        height: 44,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Bartending Live',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 27, 20, 20),
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final selected = index == _selectedTab;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 6,
                          right: index == _tabs.length - 1 ? 0 : 6,
                        ),
                        child: _CategoryTabButton(
                          offAsset: _tabs[index].offAsset,
                          onAsset: _tabs[index].onAsset,
                          selected: selected,
                          onTap: () => _onTabSelected(index),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadRooms,
                  color: Colors.black,
                  displacement: 28,
                  child: _buildRoomList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomList() {
    if (_loading && _rooms.isEmpty) {
      return ListView(
        physics: _listPhysics,
        children: const [
          SizedBox(
            height: 240,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }

    if (_rooms.isEmpty) {
      return ListView(
        physics: _listPhysics,
        children: const [
          SizedBox(
            height: 240,
            child: Center(
              child: Text(
                'No live streams',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      key: _isPopularTab
          ? ValueKey(_rooms.map((room) => room.id).join(','))
          : null,
      physics: _listPhysics,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _rooms.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return HomeLiveRoomCard(
          room: _rooms[index],
          fullWidth: true,
        );
      },
    );
  }
}

class _CategoryTabButton extends StatelessWidget {
  const _CategoryTabButton({
    required this.offAsset,
    required this.onAsset,
    required this.selected,
    required this.onTap,
  });

  final String offAsset;
  final String onAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child: Image.asset(
          selected ? onAsset : offAsset,
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
