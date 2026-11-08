-- Read-only diagnostics. Run as postgres in Supabase SQL Editor AFTER setup.
-- This does not create users, grant roles, or change data.
begin transaction read only;

-- Required columns and all seven tables must exist; RLS must be enabled.
select c.table_name, c.column_name, c.data_type, c.is_nullable
from information_schema.columns c
where c.table_schema = 'public'
  and (c.table_name, c.column_name) in
    (('profiles','role'), ('profiles','bio'), ('exhibits','category_id'))
order by c.table_name, c.column_name;

select required.table_name, cls.oid is not null as table_exists,
       cls.relrowsecurity as rls_enabled
from unnest(array['profiles','exhibition_categories','exhibits','teachers',
                  'events','event_photos','time_capsules']) as required(table_name)
left join pg_class cls on cls.oid = to_regclass('public.' || required.table_name)
order by required.table_name;

-- Each trigger must exist and be enabled (O = enabled for normal writes).
select required.trigger_name, t.oid is not null as trigger_exists, t.tgenabled
from (values
  ('auth.users', 'on_auth_user_created'),
  ('public.profiles', 'protect_profile_role'),
  ('public.exhibits', 'exhibits_sync_category_reference')
) as required(table_name, trigger_name)
left join pg_trigger t on t.tgrelid = to_regclass(required.table_name)
  and t.tgname = required.trigger_name and not t.tgisinternal;

select n.nspname as schema_name, p.proname, p.prosecdef as security_definer,
       p.proconfig, pg_get_functiondef(p.oid) as definition
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in
  ('is_admin','handle_new_user','prevent_profile_role_escalation',
   'sync_exhibit_category_reference');

-- Inspect USING/WITH CHECK and table privileges together: both are needed.
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in
  ('profiles','exhibition_categories','exhibits','teachers','events','event_photos','time_capsules'))
  or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon','authenticated')
  and table_name in ('profiles','exhibition_categories','exhibits','teachers',
                     'events','event_photos','time_capsules')
order by table_name, grantee, privilege_type;

-- SQL Editor can see Auth users; a publishable key cannot verify this.
select count(*) as auth_users,
       count(*) filter (where u.email_confirmed_at is not null) as confirmed_email_users,
       count(*) filter (where p.id is null) as users_missing_profiles,
       count(*) filter (where p.role = 'admin') as admin_profiles,
       count(*) filter (where p.role = 'admin' and u.email_confirmed_at is not null)
         as confirmed_email_admins
from auth.users u left join public.profiles p on p.id = u.id;

-- Each expected seed row must have matches = 1 (0 = absent, >1 = duplicates).
select expected.name, count(t.id) as matches
from (values ('Д.Хулан'), ('Г.Эрдэнэцэцэг'), ('Б.Гэрэлтцолмон')) as expected(name)
left join public.teachers t on t.name = expected.name
group by expected.name;

select expected.title, expected.event_date, count(e.id) as matches
from (values
  ('ИРНИТУ-ийн зочин профессорын хиймэл оюуны семинар', date '2022-11-08'),
  ('Фулбрайтын мэргэжилтний хөтөлбөр', date '2024-12-09')
) as expected(title, event_date)
left join public.events e on e.title = expected.title and e.event_date = expected.event_date
group by expected.title, expected.event_date;

select count(*) as invalid_category_references
from public.exhibits e
left join public.exhibition_categories c on c.id = e.category_id
where c.id is null or c.name is distinct from e.category;

select id, public, file_size_limit, allowed_mime_types
from storage.buckets where id = 'museum-media';

-- These scripts use SQL Editor, not Supabase CLI migration history.
-- A missing history table does NOT imply that schema.sql was never applied.
select to_regclass('supabase_migrations.schema_migrations') as cli_migration_history;
commit;
