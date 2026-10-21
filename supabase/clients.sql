-- [AI 생성 초안 - 검토 전] 농부마을 거래처·배송지 — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run.
-- 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 거래처·배송지 표 — 한 곳 = 한 줄 (지도 위치 포함)
-- ─────────────────────────────────────────────
create table if not exists public.clients (
  id          bigint generated always as identity primary key,
  name        text not null check (length(name) between 1 and 60),
  kind        text not null default '' check (length(kind) <= 30),     -- 분류: 거래처 / 배송지 / 소비자 등
  addr        text not null default '' check (length(addr) <= 200),
  tel         text not null default '' check (length(tel) <= 40),
  memo        text not null default '' check (length(memo) <= 500),
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  written_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists clients_name_idx on public.clients(name);

-- 적은 사람은 처음 등록한 사람으로 고정 (고쳐도 바뀌지 않음)
create or replace function public.clients_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then new.written_by := auth.uid(); new.created_at := now();
  else new.written_by := old.written_by; new.created_at := old.created_at; end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists clients_stamp on public.clients;
create trigger clients_stamp before insert or update on public.clients
  for each row execute function public.clients_stamp();

-- ─────────────────────────────────────────────
-- 2. 권한 (RLS) — 다른 기록 표와 같은 규칙
--    승인된 직원: 읽기·등록·고치기 / 지우기: 등록한 사람 본인 또는 대표 / 로그인 안 한 사람: 아무것도 못 함
-- ─────────────────────────────────────────────
alter table public.clients enable row level security;

drop policy if exists "clients_read"   on public.clients;
drop policy if exists "clients_insert" on public.clients;
drop policy if exists "clients_update" on public.clients;
drop policy if exists "clients_delete" on public.clients;
create policy "clients_read"   on public.clients for select to authenticated using (public.is_active_member());
create policy "clients_insert" on public.clients for insert to authenticated with check (public.is_active_member());
create policy "clients_update" on public.clients for update to authenticated using (public.is_active_member()) with check (public.is_active_member());
create policy "clients_delete" on public.clients for delete to authenticated using (public.is_ceo() or (public.is_active_member() and written_by = auth.uid()));

revoke all on public.clients from anon, authenticated;
grant select, insert, update, delete on public.clients to authenticated;
revoke all on function public.clients_stamp() from public, anon, authenticated;
