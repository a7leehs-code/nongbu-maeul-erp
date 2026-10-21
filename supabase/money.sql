-- [AI 생성 초안 - 검토 전] 농부마을 돈 자료 수집현황 — Supabase 설정
-- 먼저 approvals.sql · perms.sql 을 실행한 뒤, 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.
-- 7회차 「돈의 장부」: 숫자를 읽기 전에 「무엇이 언제까지 들어와 있나」부터. 대표·재무(대표가 허락한 사람)만 봅니다.

-- ─────────────────────────────────────────────
-- 1. 허락 이름에 'money'(경영·자금) 추가
-- ─────────────────────────────────────────────
alter table public.member_perms drop constraint if exists member_perms_perm_check;
alter table public.member_perms add constraint member_perms_perm_check check (perm in ('clients', 'money'));

-- ─────────────────────────────────────────────
-- 2. 돈 자료 표 — 통장·세금계산서·현금영수증·카드마다 한 줄
--    last_data_date: 자료가 며칠 것까지 들어와 있나 / fetched_at: 마지막으로 가져온 때
--    connected=false 면 「연결 안 함」(예: 체크카드만 써서 통장에 이미 있음)
-- ─────────────────────────────────────────────
create table if not exists public.money_sources (
  id              bigint generated always as identity primary key,
  name            text not null check (length(name) between 1 and 40),     -- 예) 통장 — 농협 운영통장
  route           text not null default '' check (length(route) <= 40),    -- 예) 클로브 ← 은행
  connected       boolean not null default true,
  last_data_date  date,
  last_data_label text not null default '' check (length(last_data_label) <= 40),  -- 예) 16:05 거래까지 / 발행분까지
  fetched_at      timestamptz,
  todo            text not null default '' check (length(todo) <= 120),    -- 비우면 상태에 맞춰 자동 안내
  sort            integer not null default 0,
  updated_at      timestamptz not null default now()
);

insert into public.money_sources (name, route, connected, sort)
select v.name, v.route, v.connected, v.sort from (values
  ('통장 — 운영통장',      '클로브 ← 은행',  true, 1),
  ('세금계산서(매출)',     '클로브 ← 홈택스', true, 2),
  ('세금계산서(매입)',     '클로브 ← 홈택스', true, 3),
  ('현금영수증',           '클로브 ← 홈택스', true, 4),
  ('카드',                 '클로브 ← 카드사', true, 5)
) as v(name, route, connected, sort)
where not exists (select 1 from public.money_sources);

-- 읽기: 대표 또는 대표가 'money'를 허락한 직원 / 고치기: 대표만
alter table public.money_sources enable row level security;
drop policy if exists "money_sources_read"  on public.money_sources;
drop policy if exists "money_sources_write" on public.money_sources;
create policy "money_sources_read"  on public.money_sources for select to authenticated using (public.has_perm('money'));
create policy "money_sources_write" on public.money_sources for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.money_sources from anon, authenticated;
grant select, insert, update, delete on public.money_sources to authenticated;
