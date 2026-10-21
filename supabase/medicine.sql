-- [AI 생성 초안 - 검토 전] 농부마을 약품 구입 내역 — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run.
-- 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 약품 구입 표 — 한 번 산 것 = 한 줄
-- ─────────────────────────────────────────────
create table if not exists public.medicine_purchases (
  id          bigint generated always as identity primary key,
  buy_date    date not null,
  category    text not null check (category in ('소독약', '백신', '치료제·항생제', '영양제·비타민', '기타')),
  name        text not null check (length(name) between 1 and 60),
  qty         numeric(10,2) check (qty >= 0),
  unit        text not null default '' check (length(unit) <= 10),      -- 병·포·kg·L·도즈 등
  amount      bigint check (amount >= 0),                                 -- 금액 (원)
  vendor      text not null default '' check (length(vendor) <= 60),     -- 구입처
  expiry      date,                                                       -- 유효기간 (선택)
  memo        text not null default '' check (length(memo) <= 300),
  written_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists medicine_purchases_date_idx on public.medicine_purchases(buy_date desc);

-- 적은 사람·시각은 서버가 채움
create or replace function public.medicine_purchases_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  new.written_by := auth.uid();
  new.updated_at := now();
  if tg_op = 'INSERT' then new.created_at := now(); end if;
  return new;
end;
$$;
drop trigger if exists medicine_purchases_stamp on public.medicine_purchases;
create trigger medicine_purchases_stamp before insert or update on public.medicine_purchases
  for each row execute function public.medicine_purchases_stamp();

-- ─────────────────────────────────────────────
-- 2. 권한 (RLS) — 산란 기록·방역 소독과 같은 규칙
--    승인된 직원: 읽기·적기·고치기 / 대표만: 지우기 / 로그인 안 한 사람: 아무것도 못 함
-- ─────────────────────────────────────────────
alter table public.medicine_purchases enable row level security;

drop policy if exists "medicine_read"   on public.medicine_purchases;
drop policy if exists "medicine_insert" on public.medicine_purchases;
drop policy if exists "medicine_update" on public.medicine_purchases;
drop policy if exists "medicine_delete" on public.medicine_purchases;
create policy "medicine_read"   on public.medicine_purchases for select to authenticated using (public.is_active_member());
create policy "medicine_insert" on public.medicine_purchases for insert to authenticated with check (public.is_active_member());
create policy "medicine_update" on public.medicine_purchases for update to authenticated using (public.is_active_member()) with check (public.is_active_member());
create policy "medicine_delete" on public.medicine_purchases for delete to authenticated using (public.is_ceo());

revoke all on public.medicine_purchases from anon, authenticated;
grant select, insert, update, delete on public.medicine_purchases to authenticated;
revoke all on function public.medicine_purchases_stamp() from public, anon, authenticated;
