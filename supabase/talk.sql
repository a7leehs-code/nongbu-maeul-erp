-- [AI 생성 초안 - 검토 전] 농부마을 사내메신저(마을톡) — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·로그인 공유), 이 파일을 SQL Editor 에 붙여넣고 Run.
-- 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 표 3개 — 방 · 방 멤버 · 메시지
-- ─────────────────────────────────────────────
create table if not exists public.talk_rooms (
  id                 bigint generated always as identity primary key,
  kind               text not null check (kind in ('all', 'group', 'direct')),
  name               text not null default '' check (length(name) <= 40),
  direct_key         text unique,
  created_by         uuid references public.profiles(id),
  pinned_message_id  bigint,
  created_at         timestamptz not null default now()
);
create unique index if not exists talk_rooms_one_all on public.talk_rooms (kind) where kind = 'all';

create table if not exists public.talk_members (
  room_id       bigint not null references public.talk_rooms(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  joined_at     timestamptz not null default now(),
  last_read_at  timestamptz not null default now(),
  primary key (room_id, user_id)
);
create index if not exists talk_members_user_idx on public.talk_members(user_id);

create table if not exists public.talk_messages (
  id          bigint generated always as identity primary key,
  room_id     bigint not null references public.talk_rooms(id) on delete cascade,
  sender      uuid references public.profiles(id),
  kind        text not null default 'text' check (kind in ('text', 'system')),
  body        text not null check (length(body) between 1 and 2000),
  created_at  timestamptz not null default now()
);
create index if not exists talk_messages_room_idx on public.talk_messages(room_id, created_at desc);

-- 보낸 시각은 서버가 찍는다 (보내는 사람이 시각을 바꿔 넣을 수 없게)
create or replace function public.talk_messages_server_time() returns trigger
language plpgsql set search_path = public as $$
begin
  new.created_at := now();
  return new;
end;
$$;
revoke execute on function public.talk_messages_server_time() from public, anon, authenticated;
drop trigger if exists talk_messages_server_time on public.talk_messages;
create trigger talk_messages_server_time
  before insert on public.talk_messages
  for each row execute function public.talk_messages_server_time();

do $$ begin
  alter table public.talk_rooms
    add constraint talk_rooms_pinned_fk foreign key (pinned_message_id) references public.talk_messages(id) on delete set null;
exception when duplicate_object then null; end $$;

-- ─────────────────────────────────────────────
-- 2. 판정 도우미 — 「이 방 멤버인가」는 여기서만
-- ─────────────────────────────────────────────
create or replace function public.is_room_member(p_room bigint) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_member()
     and exists (select 1 from talk_members where room_id = p_room and user_id = auth.uid());
$$;

-- ─────────────────────────────────────────────
-- 3. 읽기 규칙 (RLS) — 방 멤버만 읽고, 수정·삭제는 아무도 못 함(기록 보존)
-- ─────────────────────────────────────────────
alter table public.talk_rooms enable row level security;
alter table public.talk_members enable row level security;
alter table public.talk_messages enable row level security;

drop policy if exists "talk_rooms_read" on public.talk_rooms;
create policy "talk_rooms_read" on public.talk_rooms
  for select to authenticated using (public.is_room_member(id));

drop policy if exists "talk_members_read" on public.talk_members;
create policy "talk_members_read" on public.talk_members
  for select to authenticated using (public.is_room_member(room_id));

drop policy if exists "talk_messages_read" on public.talk_messages;
create policy "talk_messages_read" on public.talk_messages
  for select to authenticated using (public.is_room_member(room_id));

drop policy if exists "talk_messages_send" on public.talk_messages;
create policy "talk_messages_send" on public.talk_messages
  for insert to authenticated
  with check (sender = auth.uid() and kind = 'text' and public.is_room_member(room_id));

revoke insert, update, delete on public.talk_rooms from anon, authenticated;
revoke insert, update, delete on public.talk_members from anon, authenticated;
revoke update, delete on public.talk_messages from anon, authenticated;
revoke insert on public.talk_messages from anon;

-- ─────────────────────────────────────────────
-- 4. 전체방 — 사용 허용된 직원은 자동으로 들어감
-- ─────────────────────────────────────────────
insert into public.talk_rooms (kind, name) values ('all', '농부마을 전체')
on conflict do nothing;

create or replace function public.talk_join_all_room() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_room bigint;
begin
  if new.active then
    select id into v_room from talk_rooms where kind = 'all';
    if v_room is not null then
      insert into talk_members (room_id, user_id) values (v_room, new.id) on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists talk_join_all_room on public.profiles;
create trigger talk_join_all_room
  after insert or update of active on public.profiles
  for each row execute function public.talk_join_all_room();

insert into public.talk_members (room_id, user_id)
select r.id, p.id from public.talk_rooms r cross join public.profiles p
where r.kind = 'all' and p.active
on conflict do nothing;

-- ─────────────────────────────────────────────
-- 5. 동작 함수
-- ─────────────────────────────────────────────

-- 내 채팅 목록: 방 정보 + 마지막 메시지 + 안 읽은 수
create or replace function public.my_rooms()
returns table (id bigint, kind text, name text, created_by uuid, pinned_message_id bigint,
               last_body text, last_at timestamptz, last_sender uuid, unread bigint, member_ids uuid[])
language sql stable security definer set search_path = public as $$
  select r.id, r.kind, r.name, r.created_by, r.pinned_message_id,
         lm.body, lm.created_at, lm.sender,
         (select count(*) from talk_messages m
            where m.room_id = r.id and m.created_at > me.last_read_at and m.sender is distinct from auth.uid()),
         (select array_agg(tm.user_id order by tm.joined_at) from talk_members tm where tm.room_id = r.id)
    from talk_rooms r
    join talk_members me on me.room_id = r.id and me.user_id = auth.uid()
    left join lateral (
      select body, created_at, sender from talk_messages m where m.room_id = r.id order by created_at desc, id desc limit 1
    ) lm on true
   where public.is_active_member()
   order by coalesce(lm.created_at, r.created_at) desc;
$$;

create or replace function public.talk_mark_read(p_room bigint) returns void
language sql security definer set search_path = public as $$
  update talk_members set last_read_at = now()
   where room_id = p_room and user_id = auth.uid() and public.is_active_member();
$$;

-- 1:1 방 열기 (없으면 만들고, 있으면 그 방)
create or replace function public.talk_open_direct(p_other uuid) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_key text; v_room bigint;
begin
  if not public.is_active_member() then raise exception '사용 승인이 안 된 계정입니다.'; end if;
  if p_other = auth.uid() then raise exception '나와의 대화는 만들 수 없습니다.'; end if;
  if not exists (select 1 from profiles where id = p_other and active) then raise exception '사용 중인 직원이 아닙니다.'; end if;
  v_key := least(auth.uid()::text, p_other::text) || ':' || greatest(auth.uid()::text, p_other::text);
  select id into v_room from talk_rooms where direct_key = v_key;
  if v_room is null then
    insert into talk_rooms (kind, name, direct_key, created_by) values ('direct', '', v_key, auth.uid())
    on conflict (direct_key) do nothing
    returning id into v_room;
    if v_room is null then select id into v_room from talk_rooms where direct_key = v_key; end if;
  end if;
  insert into talk_members (room_id, user_id) values (v_room, auth.uid()), (v_room, p_other) on conflict do nothing;
  return v_room;
end;
$$;

-- 그룹방 만들기
create or replace function public.talk_create_group(p_name text, p_members uuid[]) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_room bigint; v_name text := trim(coalesce(p_name, ''));
begin
  if not public.is_active_member() then raise exception '사용 승인이 안 된 계정입니다.'; end if;
  if v_name = '' then raise exception '방 이름을 적어주세요.'; end if;
  if length(v_name) > 40 then raise exception '방 이름은 40자까지입니다.'; end if;
  if coalesce(array_length(p_members, 1), 0) < 1 then raise exception '함께할 직원을 한 명 이상 골라주세요.'; end if;
  insert into talk_rooms (kind, name, created_by) values ('group', v_name, auth.uid()) returning id into v_room;
  insert into talk_members (room_id, user_id)
  select v_room, p.id from profiles p where p.active and (p.id = auth.uid() or p.id = any(p_members))
  on conflict do nothing;
  insert into talk_messages (room_id, sender, kind, body)
  values (v_room, null, 'system', (select name from profiles where id = auth.uid()) || '님이 「' || v_name || '」 방을 만들었습니다.');
  return v_room;
end;
$$;

-- 그룹방 나가기 (전체방·1:1은 나갈 수 없음)
create or replace function public.talk_leave(p_room bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_room_member(p_room) then raise exception '이 방의 멤버가 아닙니다.'; end if;
  if (select kind from talk_rooms where id = p_room) <> 'group' then raise exception '전체방과 1:1 대화는 나갈 수 없습니다.'; end if;
  insert into talk_messages (room_id, sender, kind, body)
  values (p_room, null, 'system', (select name from profiles where id = auth.uid()) || '님이 나갔습니다.');
  delete from talk_members where room_id = p_room and user_id = auth.uid();
end;
$$;

-- 공지 고정/해제 — 대표 또는 방을 만든 사람만
create or replace function public.talk_pin(p_room bigint, p_message bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_room_member(p_room) then raise exception '이 방의 멤버가 아닙니다.'; end if;
  if not (public.is_ceo() or coalesce((select created_by from talk_rooms where id = p_room) = auth.uid(), false)) then
    raise exception '공지는 대표나 방을 만든 사람만 고정할 수 있습니다.';
  end if;
  if p_message is not null and not exists (select 1 from talk_messages where id = p_message and room_id = p_room and kind = 'text') then
    raise exception '이 방의 메시지가 아닙니다.';
  end if;
  update talk_rooms set pinned_message_id = p_message where id = p_room;
end;
$$;

revoke execute on function public.my_rooms() from public, anon;
revoke execute on function public.talk_mark_read(bigint) from public, anon;
revoke execute on function public.talk_open_direct(uuid) from public, anon;
revoke execute on function public.talk_create_group(text, uuid[]) from public, anon;
revoke execute on function public.talk_leave(bigint) from public, anon;
revoke execute on function public.talk_pin(bigint, bigint) from public, anon;
grant execute on function public.my_rooms() to authenticated;
grant execute on function public.talk_mark_read(bigint) to authenticated;
grant execute on function public.talk_open_direct(uuid) to authenticated;
grant execute on function public.talk_create_group(text, uuid[]) to authenticated;
grant execute on function public.talk_leave(bigint) to authenticated;
grant execute on function public.talk_pin(bigint, bigint) to authenticated;
revoke execute on function public.talk_join_all_room() from public, anon, authenticated;
revoke execute on function public.is_room_member(bigint) from public, anon;
grant execute on function public.is_room_member(bigint) to authenticated;

-- ─────────────────────────────────────────────
-- 6. 실시간 — 새 메시지·읽음 표시가 바로 뜨도록
-- ─────────────────────────────────────────────
do $$ begin
  alter publication supabase_realtime add table public.talk_messages;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.talk_members;
exception when duplicate_object then null; end $$;
