-- [AI 생성 초안 - 검토 전] 농부마을 통장관리 — Supabase 설정 (7회차 과제 ① 통장관리)
-- 먼저 approvals.sql · perms.sql · money.sql · money_sort.sql 을 실행한 뒤, 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.
-- 규칙: 통장은 계좌번호 대신 내가 지은 별명으로 부른다 · 계좌번호는 끝 4자리만 · 잔액·상품명은 넣지 않는다 · 대표·재무만 본다

-- ─────────────────────────────────────────────
-- 1. 통장 표 — 통장 하나 = 한 줄 (대표만 추가·수정)
-- ─────────────────────────────────────────────
create table if not exists public.money_accounts (
  id          bigint generated always as identity primary key,
  nickname    text not null unique check (length(nickname) between 1 and 20),  -- 예) 운영통장 · 카드결제통장
  dept        text not null default '' check (length(dept) <= 20),             -- 부서 (통장이 하나뿐이면 비워도 됨)
  bank        text not null check (length(bank) between 1 and 20),             -- 예) 농협
  last4       text not null check (last4 ~ '^[0-9]{4}$'),                      -- 계좌번호 끝 4자리만
  active      boolean not null default true,
  sort        integer not null default 0,
  created_at  timestamptz not null default now(),
  unique (bank, last4)
);

alter table public.money_accounts enable row level security;
drop policy if exists "money_accounts_read"  on public.money_accounts;
drop policy if exists "money_accounts_write" on public.money_accounts;
create policy "money_accounts_read"  on public.money_accounts for select to authenticated using (public.has_perm('money'));
create policy "money_accounts_write" on public.money_accounts for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.money_accounts from anon, authenticated;
grant select, insert, update, delete on public.money_accounts to authenticated;

-- ─────────────────────────────────────────────
-- 2. 거래마다 「어느 통장」 — 모르면 비워 둠 (통장을 지워도 거래는 남고 칸만 비워짐)
-- ─────────────────────────────────────────────
alter table public.bank_txns add column if not exists account_id bigint references public.money_accounts(id) on delete set null;
create index if not exists bank_txns_account_idx on public.bank_txns(account_id, txn_date desc);
