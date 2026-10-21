-- [AI 생성 초안 - 검토 전] 농부마을 산란·폐사 기록 — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run.
-- 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 계사(동) 표 — 대표만 추가·수정
-- ─────────────────────────────────────────────
create table if not exists public.egg_houses (
  id           bigint generated always as identity primary key,
  name         text not null unique check (length(name) between 1 and 30),
  start_birds  integer check (start_birds >= 0),
  sort         integer not null default 0,
  active       boolean not null default true,     -- 빼면 목록에서만 숨김 (지난 기록은 남음)
  created_at   timestamptz not null default now()
);

insert into public.egg_houses (name, sort)
select v.name, v.sort from (values ('1동',1),('2동',2),('3동',3),('4동',4)) as v(name, sort)
where not exists (select 1 from public.egg_houses);

-- ─────────────────────────────────────────────
-- 2. 매일 기록 표 — 하루·한 동에 한 줄
--    계란은 중란·특란·왕란·오란(더러운 계란)·파란(깨진 계란) 5가지로 저장
-- ─────────────────────────────────────────────
create table if not exists public.egg_records (
  id           bigint generated always as identity primary key,
  record_date  date not null,
  house_id     bigint not null references public.egg_houses(id) on delete restrict,
  birds        integer not null check (birds > 0),
  mid          integer not null default 0 check (mid >= 0),
  special      integer not null default 0 check (special >= 0),
  king         integer not null default 0 check (king >= 0),
  dirty        integer not null default 0 check (dirty >= 0),
  broken       integer not null default 0 check (broken >= 0),
  dead         integer not null default 0 check (dead >= 0),
  memo         text not null default '' check (length(memo) <= 500),
  written_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (record_date, house_id),
  check (dead <= birds)
);
create index if not exists egg_records_date_idx on public.egg_records(record_date desc);

-- 적은 사람·시각은 서버가 채움 (화면에서 남의 이름으로 적을 수 없게)
create or replace function public.egg_records_stamp() returns trigger
language plpgsql set search_path = public as $$
begin
  -- 적은 사람은 처음 적은 사람으로 고정 (고쳐도 바뀌지 않음) → 「자기가 적은 기록」 판정에 씀
  if tg_op = 'INSERT' then new.written_by := auth.uid(); new.created_at := now();
  else new.written_by := old.written_by; new.created_at := old.created_at; end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists egg_records_stamp on public.egg_records;
create trigger egg_records_stamp before insert or update on public.egg_records
  for each row execute function public.egg_records_stamp();

-- ─────────────────────────────────────────────
-- 3. 권한 (RLS)
--    승인된 직원: 계사·기록 읽기, 기록 적기·고치기
--    기록 지우기: 적은 사람 본인 또는 대표, 계사 추가·수정
--    로그인 안 한 사람(anon): 아무것도 못 함
-- ─────────────────────────────────────────────
alter table public.egg_houses  enable row level security;
alter table public.egg_records enable row level security;

drop policy if exists "egg_houses_read"  on public.egg_houses;
drop policy if exists "egg_houses_write" on public.egg_houses;
create policy "egg_houses_read"  on public.egg_houses for select to authenticated using (public.is_active_member());
create policy "egg_houses_write" on public.egg_houses for all    to authenticated using (public.is_ceo()) with check (public.is_ceo());

drop policy if exists "egg_records_read"   on public.egg_records;
drop policy if exists "egg_records_insert" on public.egg_records;
drop policy if exists "egg_records_update" on public.egg_records;
drop policy if exists "egg_records_delete" on public.egg_records;
create policy "egg_records_read"   on public.egg_records for select to authenticated using (public.is_active_member());
create policy "egg_records_insert" on public.egg_records for insert to authenticated with check (public.is_active_member());
create policy "egg_records_update" on public.egg_records for update to authenticated using (public.is_active_member()) with check (public.is_active_member());
create policy "egg_records_delete" on public.egg_records for delete to authenticated using (public.is_ceo() or (public.is_active_member() and written_by = auth.uid()));

revoke all on public.egg_houses, public.egg_records from anon, authenticated;
grant select, insert, update, delete on public.egg_houses, public.egg_records to authenticated;
revoke all on function public.egg_records_stamp() from public, anon, authenticated;
