/// 直播间观众列表项。
class LiveViewer {
  const LiveViewer({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
}
