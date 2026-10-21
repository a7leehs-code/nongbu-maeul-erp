-- [AI 생성 초안 - 검토 전] 농부마을 사료 재고 — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 사료통 표 — 농장 사료통 2개 (사료 종류는 통마다 적음, 대표만 추가·수정)
--    warn_days: 며칠치 남으면 「발주하세요」로 알릴지 (하루 전 발주 → 다음 날 도착, 하루 여유 = 2일)
-- ─────────────────────────────────────────────
create table if not exists public.feed_bins (
  id          bigint generated always as identity primary key,
  name        text not null unique check (length(name) between 1 and 30),
  feed_type   text not null default '' check (length(feed_type) <= 30),
  capacity    numeric(8,2) check (capacity > 0),                    -- 통 크기(톤), 선택
  vendor_tel  text not null default '' check (length(vendor_tel) <= 40),  -- 사료 주문 전화
  warn_days   smallint not null default 2 check (warn_days between 1 and 30),
  active      boolean not null default true,
  sort        integer not null default 0,
  created_at  timestamptz not null default now()
);

insert into public.feed_bins (name, sort)
select v.name, v.sort from (values ('1번 사료통',1),('2번 사료통',2)) as v(name, sort)
where not exists (select 1 from public.feed_bins);

alter table public.feed_bins enable row level security;
drop policy if exists "feed_bins_read"  on public.feed_bins;
drop policy if exists "feed_bins_write" on public.feed_bins;
create policy "feed_bins_read"  on public.feed_bins for select to authenticated using (public.is_active_member());
create policy "feed_bins_write" on public.feed_bins for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.feed_bins from anon, authenticated;
grant select, insert, update, delete on public.feed_bins to authenticated;

-- ─────────────────────────────────────────────
-- 2. 사료 기록 표 — 잔량(통에 남은 양) / 입고(들어온 양) / 발주(주문한 양)
-- ─────────────────────────────────────────────
create table if not exists public.feed_logs (
  id          bigint generated always as identity primary key,
  log_date    date not null,
  bin_id      bigint not null references public.feed_bins(id) on delete restrict,
  kind        text not null check (kind in ('잔량', '입고', '발주')),
  amount      numeric(8,2) not null check (amount >= 0),              -- 톤
  memo        text not null default '' check (length(memo) <= 300),
  written_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists feed_logs_bin_date_idx on public.feed_logs(bin_id, log_date desc);

-- 적은 사람은 처음 적은 사람으로 고정
create or replace function public.feed_logs_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'INSERT' then new.written_by := auth.uid(); new.created_at := now();
  else new.written_by := old.written_by; new.created_at := old.created_at; end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists feed_logs_stamp on public.feed_logs;
create trigger feed_logs_stamp before insert or update on public.feed_logs
  for each row execute function public.feed_logs_stamp();

-- 권한: 승인된 직원은 읽기·적기·고치기 / 지우기는 적은 사람 본인 또는 대표 / 로그인 안 한 사람은 아무것도 못 함
alter table public.feed_logs enable row level security;
drop policy if exists "feed_logs_read"   on public.feed_logs;
drop policy if exists "feed_logs_insert" on public.feed_logs;
drop policy if exists "feed_logs_update" on public.feed_logs;
drop policy if exists "feed_logs_delete" on public.feed_logs;
create policy "feed_logs_read"   on public.feed_logs for select to authenticated using (public.is_active_member());
create policy "feed_logs_insert" on public.feed_logs for insert to authenticated with check (public.is_active_member());
create policy "feed_logs_update" on public.feed_logs for update to authenticated using (public.is_active_member()) with check (public.is_active_member());
create policy "feed_logs_delete" on public.feed_logs for delete to authenticated using (public.is_ceo() or (public.is_active_member() and written_by = auth.uid()));
revoke all on public.feed_logs from anon, authenticated;
grant select, insert, update, delete on public.feed_logs to authenticated;
revoke all on function public.feed_logs_stamp() from public, anon, authenticated;
