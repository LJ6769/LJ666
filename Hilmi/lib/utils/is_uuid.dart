final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Supabase 主键是否为合法 UUID（占位 id 如 `live-1` 为 false）。
bool isUuid(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isNotEmpty && _uuidPattern.hasMatch(trimmed);
}
