-- Run this entire file in Supabase Dashboard > SQL Editor as postgres.
-- Repairs missing profiles without changing existing profiles or admin roles.
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data->>'display_name'), ''),
      nullif(split_part(new.email, '@', 1), ''),
      'ISM бүтээгч'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- This function is only used by the Auth trigger, never as a client RPC.
revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Covers accounts created before the profile trigger was installed.
insert into public.profiles (id, display_name)
select
  u.id,
  coalesce(
    nullif(btrim(u.raw_user_meta_data->>'display_name'), ''),
    nullif(split_part(u.email, '@', 1), ''),
    'ISM бүтээгч'
  )
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;

commit;

-- Expected result: users_missing_profiles = 0, profile_trigger_enabled = true.
select
  (select count(*) from auth.users u
   where not exists (select 1 from public.profiles p where p.id = u.id)
  ) as users_missing_profiles,
  exists (
    select 1 from pg_trigger
    where tgrelid = 'auth.users'::regclass
      and tgname = 'on_auth_user_created'
      and tgenabled in ('O', 'A')
      and not tgisinternal
  ) as profile_trigger_enabled;
