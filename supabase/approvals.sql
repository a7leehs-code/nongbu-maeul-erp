-- [AI 생성 초안 - 검토 전] 농부마을 전자결재 — Supabase 설정
-- Supabase 대시보드 → SQL Editor → 이 파일 전체를 붙여넣고 Run.
-- 여러 번 실행해도 안전하도록 만들었습니다.

-- ─────────────────────────────────────────────
-- 1. 직원 표
-- ─────────────────────────────────────────────
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  name        text not null default '',
  job         text not null default '',
  role        text not null default '직원' check (role in ('대표', '직원')),
  active      boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- 2. 결재 문서 표 (상태는 4개만 저장)
-- ─────────────────────────────────────────────
create table if not exists public.approval_docs (
  id             bigint generated always as identity primary key,
  doc_no         text not null unique,
  type           text not null check (type in ('leave','overtime','outing','purchase','expense','disinfect','mortality')),
  title          text not null check (length(title) between 1 and 200),
  drafter        uuid not null references public.profiles(id),
  status         text not null default '진행중' check (status in ('진행중','승인','반려','회수')),
  start_date     date,
  end_date       date,
  work_date      date,
  hours          numeric(4,1),
  amount         bigint,
  head_count     integer,
  reason         text,
  ceo_id         uuid references public.profiles(id),
  ceo_at         timestamptz,
  self_approved  boolean not null default false,
  created_at     timestamptz not null default now()
);
create index if not exists approval_docs_drafter_idx on public.approval_docs(drafter);
create index if not exists approval_docs_status_idx on public.approval_docs(status);

-- 부서 표는 부서가 생기면 추가합니다 (지금은 기안 → 대표 직행).

-- ─────────────────────────────────────────────
-- 3. 권한 판정 도우미
-- ─────────────────────────────────────────────
create or replace function public.is_active_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active);
$$;

create or replace function public.is_ceo() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and active and role = '대표');
$$;

-- ─────────────────────────────────────────────
-- 4. 가입하면 직원 표에 자동 등록
--    맨 처음 가입한 사람 = 대표(바로 사용 가능), 그 뒤 가입자 = 직원(대표가 켜줘야 사용 가능)
-- ─────────────────────────────────────────────
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  first_user boolean;
begin
  perform pg_advisory_xact_lock(hashtext('nongbu_profiles_first_user'));
  first_user := not exists (select 1 from profiles);
  insert into profiles (id, email, name, job, role, active)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'job', ''),
    case when first_user then '대표' else '직원' end,
    first_user
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────────
-- 5. 읽기 권한 (RLS) — 쓰기는 아래 함수로만 가능
-- ─────────────────────────────────────────────
alter table public.profiles enable row level security;
alter table public.approval_docs enable row level security;

drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_active_member());

drop policy if exists "docs_read" on public.approval_docs;
create policy "docs_read" on public.approval_docs
  for select to authenticated
  using (public.is_active_member() and (drafter = auth.uid() or public.is_ceo()));

revoke insert, update, delete on public.profiles from anon, authenticated;
revoke insert, update, delete on public.approval_docs from anon, authenticated;

-- ─────────────────────────────────────────────
-- 6. 결재 동작 — 「누구 차례인가」는 여기서만 판정합니다
-- ─────────────────────────────────────────────
create or replace function public.create_doc(
  p_type text, p_title text,
  p_start date default null, p_end date default null, p_date date default null,
  p_hours numeric default null, p_amount bigint default null, p_count integer default null
) returns public.approval_docs
language plpgsql security definer set search_path = public as $$
declare
  v_prefix text;
  v_year text := to_char(now() at time zone 'Asia/Seoul', 'YYYY');
  v_seq int;
  v_ceo boolean := public.is_ceo();
  v_row approval_docs;
begin
  if not public.is_active_member() then
    raise exception '사용 승인이 안 된 계정입니다. 대표에게 계정을 켜달라고 요청하세요.';
  end if;
  if coalesce(trim(p_title), '') = '' then raise exception '제목·내역을 적어주세요.'; end if;

  v_prefix := case p_type
    when 'leave' then 'LV' when 'overtime' then 'OT' when 'outing' then 'OUT'
    when 'purchase' then 'PR' when 'expense' then 'EX'
    when 'disinfect' then 'DS' when 'mortality' then 'MT' end;
  if v_prefix is null then raise exception '알 수 없는 문서 종류입니다.'; end if;

  if p_type = 'leave' then
    if p_start is null or p_end is null then raise exception '시작일과 종료일을 모두 골라주세요.'; end if;
    if p_end < p_start then raise exception '종료일이 시작일보다 빠릅니다.'; end if;
  elsif p_type in ('overtime', 'outing') then
    if p_date is null then raise exception '날짜를 골라주세요.'; end if;
    if p_hours is null or p_hours <= 0 or p_hours > 24 then raise exception '시간은 0보다 크고 24 이하로 적어주세요.'; end if;
  elsif p_type in ('purchase', 'expense') then
    if p_amount is null or p_amount <= 0 then raise exception '금액을 적어주세요.'; end if;
  elsif p_type = 'disinfect' then
    if p_date is null then raise exception '날짜를 골라주세요.'; end if;
  elsif p_type = 'mortality' then
    if p_date is null then raise exception '날짜를 골라주세요.'; end if;
    if p_count is null or p_count <= 0 then raise exception '폐사 수를 1 이상으로 적어주세요.'; end if;
  end if;

  perform pg_advisory_xact_lock(hashtext('nongbu_doc_no_' || v_prefix || v_year));
  select coalesce(max(split_part(doc_no, '-', 3)::int), 0) + 1 into v_seq
    from approval_docs where doc_no like v_prefix || '-' || v_year || '-%';

  insert into approval_docs (doc_no, type, title, drafter, status,
      start_date, end_date, work_date, hours, amount, head_count,
      ceo_id, ceo_at, self_approved)
  values (v_prefix || '-' || v_year || '-' || lpad(v_seq::text, 3, '0'), p_type, trim(p_title), auth.uid(),
      case when v_ceo then '승인' else '진행중' end,
      case when p_type = 'leave' then p_start end,
      case when p_type = 'leave' then p_end end,
      case when p_type in ('overtime','outing','disinfect','mortality') then p_date end,
      case when p_type in ('overtime','outing') then p_hours end,
      case when p_type in ('purchase','expense') then p_amount end,
      case when p_type = 'mortality' then p_count end,
      case when v_ceo then auth.uid() end,
      case when v_ceo then now() end,
      v_ceo)
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function public.approve_doc(p_id bigint) returns public.approval_docs
language plpgsql security definer set search_path = public as $$
declare v_row approval_docs;
begin
  if not public.is_ceo() then raise exception '대표만 승인할 수 있습니다.'; end if;
  update approval_docs
     set status = '승인', ceo_id = auth.uid(), ceo_at = now()
   where id = p_id and status = '진행중' and drafter <> auth.uid()
  returning * into v_row;
  if v_row.id is null then raise exception '이미 처리됐거나 승인할 수 없는 문서입니다.'; end if;
  return v_row;
end;
$$;

create or replace function public.reject_doc(p_id bigint, p_reason text) returns public.approval_docs
language plpgsql security definer set search_path = public as $$
declare v_row approval_docs;
begin
  if not public.is_ceo() then raise exception '대표만 반려할 수 있습니다.'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception '반려 사유를 적어주세요.'; end if;
  update approval_docs
     set status = '반려', ceo_id = auth.uid(), ceo_at = now(), reason = trim(p_reason)
   where id = p_id and status = '진행중' and drafter <> auth.uid()
  returning * into v_row;
  if v_row.id is null then raise exception '이미 처리됐거나 반려할 수 없는 문서입니다.'; end if;
  return v_row;
end;
$$;

create or replace function public.withdraw_doc(p_id bigint) returns public.approval_docs
language plpgsql security definer set search_path = public as $$
declare v_row approval_docs;
begin
  if not public.is_active_member() then raise exception '사용 승인이 안 된 계정입니다.'; end if;
  update approval_docs set status = '회수'
   where id = p_id and status = '진행중' and drafter = auth.uid()
  returning * into v_row;
  if v_row.id is null then raise exception '내가 올린 대기 중 문서만 회수할 수 있습니다.'; end if;
  return v_row;
end;
$$;

-- 대표가 직원 계정을 켜고 끄기 (자기 자신은 못 바꿈)
create or replace function public.set_member(p_id uuid, p_active boolean, p_job text default null) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare v_row profiles;
begin
  if not public.is_ceo() then raise exception '대표만 직원 계정을 바꿀 수 있습니다.'; end if;
  if p_id = auth.uid() then raise exception '대표 자신의 계정은 여기서 바꿀 수 없습니다.'; end if;
  update profiles set active = p_active, job = coalesce(nullif(trim(p_job), ''), job)
   where id = p_id
  returning * into v_row;
  if v_row.id is null then raise exception '직원을 찾을 수 없습니다.'; end if;
  return v_row;
end;
$$;

-- 결재 동작은 로그인한 사람만 부를 수 있게
revoke execute on function public.create_doc(text, text, date, date, date, numeric, bigint, integer) from public, anon;
revoke execute on function public.approve_doc(bigint) from public, anon;
revoke execute on function public.reject_doc(bigint, text) from public, anon;
revoke execute on function public.withdraw_doc(bigint) from public, anon;
revoke execute on function public.set_member(uuid, boolean, text) from public, anon;
grant execute on function public.create_doc(text, text, date, date, date, numeric, bigint, integer) to authenticated;
grant execute on function public.approve_doc(bigint) to authenticated;
grant execute on function public.reject_doc(bigint, text) to authenticated;
grant execute on function public.withdraw_doc(bigint) to authenticated;
grant execute on function public.set_member(uuid, boolean, text) to authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.is_active_member() from public, anon;
revoke execute on function public.is_ceo() from public, anon;
grant execute on function public.is_active_member() to authenticated;
grant execute on function public.is_ceo() to authenticated;
