-- Run in Supabase SQL Editor after schema.sql. Safe to re-run.

-- Do not let regular users promote themselves by updating their own profile.
create or replace function public.prevent_profile_role_escalation()
returns trigger language plpgsql set search_path = public
as $$ begin
  if new.role is distinct from old.role
     and not public.is_admin()
     and current_user not in ('postgres','supabase_admin') then
    raise exception 'Only an administrator can change profile roles';
  end if;
  return new;
end $$;
drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role before update on public.profiles
for each row execute procedure public.prevent_profile_role_escalation();

-- Admins can create, publish, update, and delete museum exhibits.
drop policy if exists "Admins manage exhibits" on public.exhibits;
create policy "Admins manage exhibits" on public.exhibits for all
  using (public.is_admin()) with check (public.is_admin());
