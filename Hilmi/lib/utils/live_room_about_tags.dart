/// 直播间 About 面板标签：分类 + 数据库 hashtags。
abstract final class LiveRoomAboutTags {
  /// 首枚为分类（other → `other`，其余用 [categoryName]），其后为 [tags]（去掉 `#`）。
  static List<String> build({
    String? categorySlug,
    String? categoryName,
    List<String> tags = const [],
  }) {
    final result = <String>[];
    final slug = categorySlug?.trim().toLowerCase() ?? '';

    if (slug.isNotEmpty) {
      if (slug == 'other') {
        result.add('other');
      } else {
        final name = categoryName?.trim();
        if (name != null && name.isNotEmpty) {
          result.add(name);
        } else {
          result.add(_titleCaseSlug(slug));
        }
      }
    }

    for (final raw in tags) {
      final tag = _stripHash(raw);
      if (tag.isEmpty) continue;
      if (!result.contains(tag)) {
        result.add(tag);
      }
    }

    return result;
  }

  static String _stripHash(String raw) {
    var tag = raw.trim();
    while (tag.startsWith('#')) {
      tag = tag.substring(1).trim();
    }
    return tag;
  }

  static String _titleCaseSlug(String slug) {
    return slug
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
