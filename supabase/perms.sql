-- [AI 생성 초안 - 검토 전] 농부마을 화면별 허락(권한) — Supabase 설정
-- 대표가 허락한 직원만 볼 수 있는 화면을 만들 때 씁니다. (지금은 거래처 지도)
-- 먼저 approvals.sql · clients.sql 을 실행한 뒤, 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 허락 표 — 「누가 · 어떤 화면을」 볼 수 있는지 한 줄씩
--    대표는 이 표와 상관없이 모든 화면을 봅니다.
-- ─────────────────────────────────────────────
create table if not exists public.member_perms (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  perm        text not null check (perm in ('clients')),     -- 화면이 늘면 여기에 이름을 더함
  granted_by  uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now(),
  primary key (user_id, perm)
);

-- 허락받았는지 판정 (대표는 항상 허락)
create or replace function public.has_perm(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_active_member()
     and (public.is_ceo() or exists (select 1 from member_perms where user_id = auth.uid() and perm = p));
$$;
revoke all on function public.has_perm(text) from public, anon;
grant execute on function public.has_perm(text) to authenticated;

-- 허락 표 권한: 자기 줄은 읽을 수 있고, 주고 뺏는 건 대표만
alter table public.member_perms enable row level security;
drop policy if exists "perms_read"  on public.member_perms;
drop policy if exists "perms_write" on public.member_perms;
create policy "perms_read"  on public.member_perms for select to authenticated using (user_id = auth.uid() or public.is_ceo());
create policy "perms_write" on public.member_perms for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.member_perms from anon, authenticated;
grant select, insert, delete on public.member_perms to authenticated;

-- ─────────────────────────────────────────────
-- 2. 거래처 표는 허락받은 사람만
--    읽기·등록·고치기: 허락받은 사람 / 지우기: 대표 또는 (허락받은 사람 중) 등록한 본인
-- ─────────────────────────────────────────────
drop policy if exists "clients_read"   on public.clients;
drop policy if exists "clients_insert" on public.clients;
drop policy if exists "clients_update" on public.clients;
drop policy if exists "clients_delete" on public.clients;
create policy "clients_read"   on public.clients for select to authenticated using (public.has_perm('clients'));
create policy "clients_insert" on public.clients for insert to authenticated with check (public.has_perm('clients'));
create policy "clients_update" on public.clients for update to authenticated using (public.has_perm('clients')) with check (public.has_perm('clients'));
create policy "clients_delete" on public.clients for delete to authenticated using (public.is_ceo() or (public.has_perm('clients') and written_by = auth.uid()));
