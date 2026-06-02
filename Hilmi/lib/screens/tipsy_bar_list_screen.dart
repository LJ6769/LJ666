import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/home_repository.dart';
import '../models/home_models.dart';
import '../splash_page.dart';
import '../utils/open_tipsy_bar_chat_room.dart';
import '../utils/open_tipsy_create_room.dart';
import '../widgets/home_feed_cards.dart';
import '../widgets/tipsy/tipsy_create_banner.dart';

class TipsyBarListScreen extends StatefulWidget {
  const TipsyBarListScreen({super.key});

  @override
  State<TipsyBarListScreen> createState() => _TipsyBarListScreenState();
}

class _TipsyBarListScreenState extends State<TipsyBarListScreen> {
  final _repository = const HomeRepository();
  late Future<List<TipsyBarRoom>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    _roomsFuture = _repository.fetchTipsyBarList();
  }

  void _reloadRooms() {
    setState(() {
      _roomsFuture = _repository.fetchTipsyBarList();
    });
  }

  Future<void> _onCreateTap() async {
    final room = await openTipsyCreateRoom(context);
    if (!mounted || room == null) return;
    _reloadRooms();
    final deleted = await openTipsyBarChatRoom(context, room: room);
    if (!mounted) return;
    if (deleted) _reloadRooms();
  }

  Future<void> _openRoom(TipsyBarRoom room) async {
    final deleted = await openTipsyBarChatRoom(context, room: room);
    if (!mounted) return;
    if (deleted) _reloadRooms();
  }

  Future<void> _openRoomAbout(TipsyBarRoom room) async {
    final deleted = await openTipsyBarChatRoom(
      context,
      room: room,
      openAboutRoomOnEnter: true,
    );
    if (!mounted) return;
    if (deleted) _reloadRooms();
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
                        'assets/home/tipsy_btn_back.png',
                        width: 44,
                        height: 44,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Tipsy Bar',
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
              Expanded(
                child: FutureBuilder<List<TipsyBarRoom>>(
                  future: _roomsFuture,
                  builder: (context, snapshot) {
                    final rooms = snapshot.data ?? const <TipsyBarRoom>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        rooms.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        TipsyCreateBanner(onTap: _onCreateTap),
                        const SizedBox(height: 16),
                        if (rooms.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(
                              child: Text(
                                'No chat rooms',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                          )
                        else
                          for (var i = 0; i < rooms.length; i++)
                            HomeTipsyBarCard(
                              room: rooms[i],
                              photoOnRight: i.isOdd,
                              isFirst: i == 0,
                              isLast: i == rooms.length - 1,
                              onJoinTap: () => _openRoom(rooms[i]),
                              onMoreTap: () => _openRoomAbout(rooms[i]),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
