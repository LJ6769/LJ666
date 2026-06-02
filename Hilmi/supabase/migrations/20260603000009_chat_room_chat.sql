-- Tipsy Bar 房间公屏聊天（与 LiveChat 类似，按 chat_room_id 隔离）

create table if not exists public."ChatRoomChat" (
  id uuid primary key default gen_random_uuid(),
  chat_room_id uuid not null references public."ChatRoom" (id) on delete cascade,
  sender_id uuid references public."User" (id) on delete set null,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists chat_room_chat_room_idx
  on public."ChatRoomChat" (chat_room_id, created_at);

alter table public."ChatRoomChat" enable row level security;

drop policy if exists "chat_room_chat_select" on public."ChatRoomChat";
create policy "chat_room_chat_select" on public."ChatRoomChat"
  for select using (true);

drop policy if exists "chat_room_chat_insert" on public."ChatRoomChat";
create policy "chat_room_chat_insert" on public."ChatRoomChat"
  for insert to authenticated with check (true);

drop policy if exists "chat_room_chat_insert_anon" on public."ChatRoomChat";
create policy "chat_room_chat_insert_anon" on public."ChatRoomChat"
  for insert to anon with check (true);

do $$
begin
  alter publication supabase_realtime add table public."ChatRoomChat";
exception
  when duplicate_object then null;
end $$;
