-- Existing projects: run after schema.sql / category migration, as postgres.
-- Re-runnable; keeps all existing users and content. No service-role key needed.
begin;

alter table public.exhibits add column if not exists creator_name text;
alter table public.exhibits add column if not exists collection text not null default 'Оюутны бүтээл';
alter table public.exhibits add column if not exists archive_details jsonb not null default '{}'::jsonb;
alter table public.events add column if not exists event_type text;
alter table public.events add column if not exists article jsonb;

-- Reading one's own role requires no privilege escalation: profiles have a
-- public SELECT policy. Keep this helper invoker-only rather than bypassing RLS.
create or replace function public.is_admin()
returns boolean language sql stable security invoker set search_path = ''
as $$ select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin') $$;

drop policy if exists "Owners update own pending exhibits" on public.exhibits;
drop policy if exists "Owners revise own exhibits" on public.exhibits;
create policy "Owners revise own exhibits" on public.exhibits for update to authenticated
  using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()) and status = 'pending');
-- Admins retain the separate all-operations policy. Students cannot publish
-- directly; editing a previously published/rejected exhibit returns it to review.

create index if not exists exhibits_creator_id_idx on public.exhibits(creator_id);
create index if not exists event_photos_event_id_idx on public.event_photos(event_id);
create index if not exists time_capsules_user_id_idx on public.time_capsules(user_id);

grant select on public.profiles, public.exhibition_categories, public.exhibits,
  public.teachers, public.events, public.event_photos, public.time_capsules to anon, authenticated;
grant insert, update, delete on public.exhibits, public.teachers, public.events,
  public.event_photos, public.exhibition_categories to authenticated;
grant update on public.profiles to authenticated;
grant insert on public.time_capsules to anon, authenticated;
grant update, delete on public.time_capsules to authenticated;

commit;
