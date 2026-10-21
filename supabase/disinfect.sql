-- [AI 생성 초안 - 검토 전] 농부마을 방역 소독 체크 — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run.
-- 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 소독 기록 표 (표는 하나, 종류는 3가지)
--    차량 = 차량 소독기 통과 / 사람 = 대인소독실 통과 / 주위 = 농장 주위 소독(주 1회)
-- ─────────────────────────────────────────────
create table if not exists public.disinfect_logs (
  id          bigint generated always as identity primary key,
  kind        text not null check (kind in ('차량', '사람', '주위')),
  log_date    date not null,
  log_time    time,
  target      text not null default '' check (length(target) <= 60),    -- 차량번호 / 이름 / 소독한 곳
  purpose     text not null default '' check (length(purpose) <= 60),   -- 무슨 일로 / 소속
  chemical    text not null default '' check (length(chemical) <= 60),  -- 소독약 (선택)
  memo        text not null default '' check (length(memo) <= 300),
  written_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists disinfect_logs_date_idx on public.disinfect_logs(log_date desc);

-- 적은 사람·시각은 서버가 채움
create or replace function public.disinfect_logs_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  -- 적은 사람은 처음 적은 사람으로 고정 (고쳐도 바뀌지 않음) → 「자기가 적은 기록」 판정에 씀
  if tg_op = 'INSERT' then new.written_by := auth.uid(); new.created_at := now();
  else new.written_by := old.written_by; new.created_at := old.created_at; end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists disinfect_logs_stamp on public.disinfect_logs;
create trigger disinfect_logs_stamp before insert or update on public.disinfect_logs
  for each row execute function public.disinfect_logs_stamp();

-- ─────────────────────────────────────────────
-- 2. 권한 (RLS) — 산란 기록과 같은 규칙
--    승인된 직원: 읽기·적기·고치기 / 지우기: 적은 사람 본인 또는 대표 / 로그인 안 한 사람: 아무것도 못 함
-- ─────────────────────────────────────────────
alter table public.disinfect_logs enable row level security;

drop policy if exists "disinfect_read"   on public.disinfect_logs;
drop policy if exists "disinfect_insert" on public.disinfect_logs;
drop policy if exists "disinfect_update" on public.disinfect_logs;
drop policy if exists "disinfect_delete" on public.disinfect_logs;
create policy "disinfect_read"   on public.disinfect_logs for select to authenticated using (public.is_active_member());
create policy "disinfect_insert" on public.disinfect_logs for insert to authenticated with check (public.is_active_member());
create policy "disinfect_update" on public.disinfect_logs for update to authenticated using (public.is_active_member()) with check (public.is_active_member());
create policy "disinfect_delete" on public.disinfect_logs for delete to authenticated using (public.is_ceo() or (public.is_active_member() and written_by = auth.uid()));

revoke all on public.disinfect_logs from anon, authenticated;
grant select, insert, update, delete on public.disinfect_logs to authenticated;
revoke all on function public.disinfect_logs_stamp() from public, anon, authenticated;
