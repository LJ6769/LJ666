/// 与 Supabase 六表 schema 一致的表名（PostgREST 需双引号表名）。
abstract final class SupabaseTables {
  static const user = 'User';
  static const live = 'Live';
  static const post = 'Post';
  static const postChat = 'PostChat';
  static const liveChat = 'LiveChat';
  static const message = 'Message';
  static const chatRoom = 'ChatRoom';
  static const chatRoomMember = 'ChatRoomMember';
  static const chatRoomChat = 'ChatRoomChat';
}
