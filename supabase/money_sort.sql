-- [AI 생성 초안 - 검토 전] 농부마을 거래 분류함 — Supabase 설정 (7회차 돈의 장부 ②)
-- 먼저 approvals.sql · perms.sql · money.sql 을 실행한 뒤, 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.
-- 규칙: 클로브 분류는 참고만, 내 분류는 내가 정한다 · 미분류는 지우지 않는다 · 귀속월은 확실할 때만 · 대표·재무만 본다

-- ─────────────────────────────────────────────
-- 1. 내 분류 목록 — 대표가 정함. pnl=false 는 「손익 아님」(보증금·카드정산처럼 손익에 넣지 않는 돈)
-- ─────────────────────────────────────────────
create table if not exists public.money_categories (
  id          bigint generated always as identity primary key,
  name        text not null unique check (length(name) between 1 and 20),
  pnl         boolean not null default true,
  sort        integer not null default 0
);

insert into public.money_categories (name, pnl, sort)
select v.name, v.pnl, v.sort from (values
  ('계란 매출', true, 1), ('사람', true, 2), ('사료·약품', true, 3), ('자리·설비', true, 4), ('파는 데 드는 돈', true, 5),
  ('보증금', false, 6), ('카드정산', false, 7), ('대출 원금', false, 8)
) as v(name, pnl, sort)
where not exists (select 1 from public.money_categories);

alter table public.money_categories enable row level security;
drop policy if exists "money_cat_read"  on public.money_categories;
drop policy if exists "money_cat_write" on public.money_categories;
create policy "money_cat_read"  on public.money_categories for select to authenticated using (public.has_perm('money'));
create policy "money_cat_write" on public.money_categories for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.money_categories from anon, authenticated;
grant select, insert, update, delete on public.money_categories to authenticated;

-- ─────────────────────────────────────────────
-- 2. 통장 거래 — 한 거래 = 한 줄 (클로브에서 읽거나 통장 파일에서 붙임)
--    who: 'AI'(클로드가 정함) / '자동'(전에 같은 적요를 정한 대로) / '나'(사람이 정함) / null(미분류)
--    ext_key: 같은 거래를 두 번 넣지 않게 하는 열쇠 (날짜·적요·금액·순번)
-- ─────────────────────────────────────────────
create table if not exists public.bank_txns (
  id              bigint generated always as identity primary key,
  txn_date        date not null,
  description     text not null check (length(description) between 1 and 80),   -- 적요
  note            text not null default '' check (length(note) <= 200),        -- 설명 한 줄 (왜 그렇게 나눴나)
  amount_in       bigint not null default 0 check (amount_in >= 0),
  amount_out      bigint not null default 0 check (amount_out >= 0),
  clobe_category  text not null default '' check (length(clobe_category) <= 30),
  my_category     text check (my_category is null or length(my_category) <= 20),
  who             text check (who in ('AI', '자동', '나')),
  belong_month    text check (belong_month ~ '^\d{4}-\d{2}$'),                 -- 귀속월 YYYY-MM (확실할 때만)
  source          text not null default '파일' check (source in ('클로브', '파일')),
  ext_key         text not null unique check (length(ext_key) <= 200),
  updated_by      uuid references public.profiles(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (amount_in > 0 or amount_out > 0)
);
create index if not exists bank_txns_date_idx on public.bank_txns(txn_date desc);

create or replace function public.bank_txns_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists bank_txns_stamp on public.bank_txns;
create trigger bank_txns_stamp before insert or update on public.bank_txns
  for each row execute function public.bank_txns_stamp();

-- 권한: 대표·재무(허락받은 사람)만 보고·붙이고·분류 / 지우기는 대표만 (미분류도 지우지 않는 것이 원칙)
alter table public.bank_txns enable row level security;
drop policy if exists "bank_txns_read"   on public.bank_txns;
drop policy if exists "bank_txns_insert" on public.bank_txns;
drop policy if exists "bank_txns_update" on public.bank_txns;
drop policy if exists "bank_txns_delete" on public.bank_txns;
create policy "bank_txns_read"   on public.bank_txns for select to authenticated using (public.has_perm('money'));
create policy "bank_txns_insert" on public.bank_txns for insert to authenticated with check (public.has_perm('money'));
create policy "bank_txns_update" on public.bank_txns for update to authenticated using (public.has_perm('money')) with check (public.has_perm('money'));
create policy "bank_txns_delete" on public.bank_txns for delete to authenticated using (public.is_ceo());
revoke all on public.bank_txns from anon, authenticated;
grant select, insert, update, delete on public.bank_txns to authenticated;
revoke all on function public.bank_txns_stamp() from public, anon, authenticated;
