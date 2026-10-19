-- [AI 생성 초안 - 검토 전] 농부마을 고객관리(문의 접수) — Supabase 설정
-- 먼저 approvals.sql 을 실행한 뒤(직원 표·권한 함수를 같이 씁니다), 이 파일을 SQL Editor 에 붙여넣고 Run.
-- 여러 번 실행해도 안전합니다.

-- ─────────────────────────────────────────────
-- 1. 문의 표 (표는 하나)
--    상태는 3개만 저장: 신규 → 응대중 → 완료
-- ─────────────────────────────────────────────
create table if not exists public.inquiries (
  id          bigint generated always as identity primary key,
  name        text not null check (length(name) between 1 and 60),
  contact     text not null check (length(contact) between 1 and 120),
  message     text not null check (length(message) between 1 and 2000),
  source      text not null default '홈페이지',
  status      text not null default '신규' check (status in ('신규', '응대중', '완료')),
  memo        text not null default '' check (length(memo) <= 2000),
  handled_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists inquiries_status_created_idx on public.inquiries(status, created_at desc);

-- ─────────────────────────────────────────────
-- 2. 읽기 권한 (RLS) — 승인된 직원만 읽습니다. 쓰기는 아래 함수로만 가능.
--    홈페이지 방문자(anon)는 표를 읽을 수도, 직접 쓸 수도 없습니다.
-- ─────────────────────────────────────────────
alter table public.inquiries enable row level security;

drop policy if exists "inquiries_read" on public.inquiries;
create policy "inquiries_read" on public.inquiries
  for select to authenticated
  using (public.is_active_member());

revoke all on public.inquiries from anon, authenticated;
grant select on public.inquiries to authenticated;

-- ─────────────────────────────────────────────
-- 3. 문의 접수 — 홈페이지 방문자(로그인 안 한 사람)가 부를 수 있는 유일한 문
--    길이·빈칸을 검사하고, 짧은 시간에 너무 많이 들어오면 막습니다(도배 방지).
--    막힌 경우(429)에는 홈페이지가 「메일로 보내기」로 바꿔 안내합니다.
-- ─────────────────────────────────────────────
create or replace function public.submit_inquiry(p_name text, p_contact text, p_message text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_name    text := trim(coalesce(p_name, ''));
  v_contact text := trim(coalesce(p_contact, ''));
  v_message text := trim(coalesce(p_message, ''));
begin
  if v_name = ''    then raise exception '성함을 적어주세요.'; end if;
  if v_contact = '' then raise exception '연락처를 적어주세요.'; end if;
  if v_message = '' then raise exception '문의 내용을 적어주세요.'; end if;
  if length(v_name) > 60     then raise exception '성함은 60자 이하로 적어주세요.'; end if;
  if length(v_contact) > 120 then raise exception '연락처는 120자 이하로 적어주세요.'; end if;
  if length(v_message) > 2000 then raise exception '문의 내용은 2000자 이하로 적어주세요.'; end if;

  if (select count(*) from inquiries where created_at > now() - interval '10 minutes') >= 20 then
    raise exception '문의가 한꺼번에 몰렸습니다. 잠시 후 다시 시도해 주세요.' using errcode = 'PT429';
  end if;

  insert into inquiries (name, contact, message) values (v_name, v_contact, v_message);
end;
$$;

-- ─────────────────────────────────────────────
-- 4. 직원이 하는 일 — 상태 바꾸기 · 메모 남기기 · 지우기
-- ─────────────────────────────────────────────
create or replace function public.set_inquiry_status(p_id bigint, p_status text)
returns public.inquiries
language plpgsql security definer set search_path = public as $$
declare v_row inquiries;
begin
  if not public.is_active_member() then raise exception '사용 승인이 안 된 계정입니다.'; end if;
  if p_status is null or p_status not in ('신규', '응대중', '완료') then raise exception '알 수 없는 상태입니다.'; end if;
  update inquiries
     set status = p_status, handled_by = auth.uid(), updated_at = now()
   where id = p_id
  returning * into v_row;
  if v_row.id is null then raise exception '문의를 찾을 수 없습니다. 이미 지워졌을 수 있습니다.'; end if;
  return v_row;
end;
$$;

create or replace function public.set_inquiry_memo(p_id bigint, p_memo text)
returns public.inquiries
language plpgsql security definer set search_path = public as $$
declare v_row inquiries;
begin
  if not public.is_active_member() then raise exception '사용 승인이 안 된 계정입니다.'; end if;
  if length(coalesce(p_memo, '')) > 2000 then raise exception '메모는 2000자 이하로 적어주세요.'; end if;
  update inquiries
     set memo = trim(coalesce(p_memo, '')), handled_by = auth.uid(), updated_at = now()
   where id = p_id
  returning * into v_row;
  if v_row.id is null then raise exception '문의를 찾을 수 없습니다. 이미 지워졌을 수 있습니다.'; end if;
  return v_row;
end;
$$;

-- 지우기는 대표만 (도배·장난 문의를 치울 때 쓰고, 지우면 되돌릴 수 없습니다)
create or replace function public.delete_inquiry(p_id bigint)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_ceo() then raise exception '대표만 문의를 지울 수 있습니다.'; end if;
  delete from inquiries where id = p_id;
  if not found then raise exception '문의를 찾을 수 없습니다. 이미 지워졌을 수 있습니다.'; end if;
end;
$$;

-- 접수는 누구나, 나머지는 로그인한 사람만 부를 수 있게
revoke execute on function public.submit_inquiry(text, text, text) from public;
revoke execute on function public.set_inquiry_status(bigint, text) from public, anon;
revoke execute on function public.set_inquiry_memo(bigint, text) from public, anon;
revoke execute on function public.delete_inquiry(bigint) from public, anon;
grant execute on function public.submit_inquiry(text, text, text) to anon, authenticated;
grant execute on function public.set_inquiry_status(bigint, text) to authenticated;
grant execute on function public.set_inquiry_memo(bigint, text) to authenticated;
grant execute on function public.delete_inquiry(bigint) to authenticated;
