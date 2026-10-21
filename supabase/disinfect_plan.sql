-- [AI 생성 초안 - 검토 전] 농부마을 방역 소독 스케줄표 — Supabase 설정
-- 먼저 approvals.sql · disinfect.sql 을 실행한 뒤, 이 파일을 SQL Editor 에 붙여넣고 Run. 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 소독 일정 표 — 「무엇을 · 얼마나 자주 · 누가」 한 줄씩 (대표만 추가·수정)
--    주기는 둘 중 하나: 매주 ○요일(weekday 0=일 … 6=토) 또는 ○일마다(every_days)
-- ─────────────────────────────────────────────
create table if not exists public.disinfect_tasks (
  id          bigint generated always as identity primary key,
  name        text not null check (length(name) between 1 and 40),
  weekday     smallint check (weekday between 0 and 6),
  every_days  smallint check (every_days between 1 and 90),
  log_kind    text not null default '일정' check (log_kind in ('주위', '일정')),  -- 했어요 → 장부에 어떤 종류로 남길지
  assignee    text not null default '' check (length(assignee) <= 30),
  active      boolean not null default true,
  sort        integer not null default 0,
  created_at  timestamptz not null default now(),
  check ((weekday is null) <> (every_days is null))
);

insert into public.disinfect_tasks (name, every_days, log_kind, sort)
select '농장 주위 소독', 7, '주위', 1
where not exists (select 1 from public.disinfect_tasks);

alter table public.disinfect_tasks enable row level security;
drop policy if exists "dtasks_read"  on public.disinfect_tasks;
drop policy if exists "dtasks_write" on public.disinfect_tasks;
create policy "dtasks_read"  on public.disinfect_tasks for select to authenticated using (public.is_active_member());
create policy "dtasks_write" on public.disinfect_tasks for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());
revoke all on public.disinfect_tasks from anon, authenticated;
grant select, insert, update, delete on public.disinfect_tasks to authenticated;

-- ─────────────────────────────────────────────
-- 2. 방역 소독 장부(disinfect_logs)에 「일정」 종류와 어떤 일정인지(task_id)를 더함
--    스케줄표에서 「했어요」를 누르면 장부에 한 줄이 생깁니다.
-- ─────────────────────────────────────────────
alter table public.disinfect_logs add column if not exists task_id bigint references public.disinfect_tasks(id) on delete set null;
alter table public.disinfect_logs drop constraint if exists disinfect_logs_kind_check;
alter table public.disinfect_logs add constraint disinfect_logs_kind_check check (kind in ('차량', '사람', '주위', '일정'));
create index if not exists disinfect_logs_task_idx on public.disinfect_logs(task_id, log_date desc);
