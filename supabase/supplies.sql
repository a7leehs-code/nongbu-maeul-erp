-- [AI 생성 초안 - 검토 전] 농부마을 부자재 관리 — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 부자재 목록 — 계란판·박스 같은 품목 (대표만 추가·수정)
--    min_qty: 이 개수 이하로 남으면 「주문하세요」로 알림
-- ─────────────────────────────────────────────
create table if not exists public.supplies (
  id          bigint generated always as identity primary key,
  name        text not null unique check (length(name) between 1 and 30),
  unit        text not null default '개' check (length(unit) between 1 and 10),
  min_qty     numeric(10,1) not null default 0 check (min_qty >= 0),
  vendor_tel  text not null default '' check (length(vendor_tel) <= 40),
  active      boolean not null default true,
  sort        integer not null default 0,
  created_at  timestamptz not null default now()
);

insert into public.supplies (name, unit, sort)
select v.name, v.unit, v.sort from (values ('계란판(난좌)','장',1),('계란 박스','개',2),('포장 비닐·랩','롤',3),('라벨 스티커','장',4),('테이프','개',5)) as v(name, unit, sort)
where not exists (select 1 from public.supplies);

alter table public.supplies enable row level security;
drop policy if exists "supplies_read"  on public.supplies;
drop policy if exists "supplies_write" on public.supplies;
create policy "supplies_read"  on public.supplies for select to authenticated using (public.is_active_member());
create policy "supplies_write" on public.supplies for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.supplies from anon, authenticated;
grant select, insert, update, delete on public.supplies to authenticated;

-- ─────────────────────────────────────────────
-- 2. 부자재 기록 — 입고(들어옴) / 사용(씀) / 실사(직접 세어 본 실제 개수)
-- ─────────────────────────────────────────────
create table if not exists public.supply_logs (
  id          bigint generated always as identity primary key,
  log_date    date not null,
  supply_id   bigint not null references public.supplies(id) on delete restrict,
  kind        text not null check (kind in ('입고', '사용', '실사')),
  qty         numeric(10,1) not null check (qty >= 0),
  memo        text not null default '' check (length(memo) <= 300),
  written_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists supply_logs_item_date_idx on public.supply_logs(supply_id, log_date desc);

-- 적은 사람은 처음 적은 사람으로 고정
create or replace function public.supply_logs_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then new.written_by := auth.uid(); new.created_at := now();
  else new.written_by := old.written_by; new.created_at := old.created_at; end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists supply_logs_stamp on public.supply_logs;
create trigger supply_logs_stamp before insert or update on public.supply_logs
  for each row execute function public.supply_logs_stamp();

-- 권한: 승인된 직원은 읽기·적기·고치기 / 지우기는 적은 본인 또는 대표 / 로그인 안 한 사람은 아무것도 못 함
alter table public.supply_logs enable row level security;
drop policy if exists "supply_logs_read"   on public.supply_logs;
drop policy if exists "supply_logs_insert" on public.supply_logs;
drop policy if exists "supply_logs_update" on public.supply_logs;
drop policy if exists "supply_logs_delete" on public.supply_logs;
create policy "supply_logs_read"   on public.supply_logs for select to authenticated using (public.is_active_member());
create policy "supply_logs_insert" on public.supply_logs for insert to authenticated with check (public.is_active_member());
create policy "supply_logs_update" on public.supply_logs for update to authenticated using (public.is_active_member()) with check (public.is_active_member());
create policy "supply_logs_delete" on public.supply_logs for delete to authenticated using (public.is_ceo() or (public.is_active_member() and written_by = auth.uid()));
revoke all on public.supply_logs from anon, authenticated;
grant select, insert, update, delete on public.supply_logs to authenticated;
revoke all on function public.supply_logs_stamp() from public, anon, authenticated;
