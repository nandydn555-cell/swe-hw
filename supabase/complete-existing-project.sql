-- Existing ISM project: run as postgres. Preserves accounts and editorial content.
-- repair-missing-profiles.sql
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


-- migrations/20261106_category_relation.sql
-- Run once in Supabase SQL Editor for an existing installation.
-- Keeps the existing category text for app compatibility and adds its FK relation.
begin;

alter table public.profiles add column if not exists bio text;

insert into public.exhibition_categories (name)
select distinct category from public.exhibits
where category is not null and btrim(category) <> ''
on conflict (name) do nothing;

insert into public.exhibition_categories (name, description) values
  ('Технологи','Технологид суурилсан шийдэл'),
  ('Веб хөгжүүлэлт','Веб сайт болон аппликейшн'),
  ('Дижитал урлаг','Дижитал медиа, дизайн, интерактив бүтээл'),
  ('Судалгаа','Судалгаа, дата өгүүлэмж'),
  ('Дурсамж','Түүх, дурсамж, аман өв')
on conflict (name) do nothing;

alter table public.exhibits
  add column if not exists category_id uuid references public.exhibition_categories(id) on delete restrict;

update public.exhibits e
set category_id = c.id
from public.exhibition_categories c
where e.category_id is null and c.name = e.category;

create or replace function public.sync_exhibit_category_reference()
returns trigger language plpgsql set search_path = public
as $$
begin
  select id into new.category_id
  from public.exhibition_categories
  where name = new.category;
  if new.category_id is null then
    raise exception 'Unknown exhibition category: %', new.category;
  end if;
  return new;
end;
$$;

drop trigger if exists exhibits_sync_category_reference on public.exhibits;
create trigger exhibits_sync_category_reference
before insert or update of category on public.exhibits
for each row execute function public.sync_exhibit_category_reference();

alter table public.exhibits alter column category_id set not null;
create index if not exists exhibits_category_id_idx on public.exhibits(category_id);
commit;


-- admin-migration.sql
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


-- finalize-schema.sql
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


-- setup-storage.sql
-- Run in the Supabase SQL Editor to enable museum image uploads.
-- Safe to re-run. Images are publicly readable; authenticated users can
-- upload/update files in their own UUID folder, and admins can delete files.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'museum-media',
  'museum-media',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'Museum media is publicly readable'
  ) then
    execute $policy$
      create policy "Museum media is publicly readable"
        on storage.objects for select
        using (bucket_id = 'museum-media')
    $policy$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'Creators upload to their own folder'
  ) then
    execute $policy$
      create policy "Creators upload to their own folder"
        on storage.objects for insert to authenticated
        with check (
          bucket_id = 'museum-media'
          and (storage.foldername(name))[1] = auth.uid()::text
        )
    $policy$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'Creators update own files'
  ) then
    execute $policy$
      create policy "Creators update own files"
        on storage.objects for update to authenticated
        using (
          bucket_id = 'museum-media'
          and (storage.foldername(name))[1] = auth.uid()::text
        )
        with check (
          bucket_id = 'museum-media'
          and (storage.foldername(name))[1] = auth.uid()::text
        )
    $policy$;
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'Creators delete own files'
  ) then
    execute $policy$
      create policy "Creators delete own files"
        on storage.objects for delete to authenticated
        using (
          bucket_id = 'museum-media'
          and (
            (storage.foldername(name))[1] = auth.uid()::text
            or public.is_admin()
          )
        )
    $policy$;
  end if;
end
$$;


-- seed-complete-archive.sql
-- Generated from the reviewed archive in src/data.js and src/exhibits.js.
-- Run AFTER finalize-schema.sql as postgres. Inserts missing rows only.
-- Existing names/titles and editorial changes are preserved. Re-runnable.
begin;
do $$ declare owner_id uuid; event_uuid uuid; begin
select id into owner_id from public.profiles where role='admin' order by created_at limit 1;
if owner_id is null then raise exception 'Create an administrator first (README: Эхний админ)'; end if;
insert into public.teachers(name,position,courses,bio,photo_url) select 'Н.Саранчимэг','Тэнхимийн эрхлэгч',array['Бизнес процесс загварчлал','Бизнес процессын менежмент']::text[],'2012 оноос Мэдээллийн системийн менежментийн тэнхимд багш, ахлах багш, эрхлэгчээр ажилласан. Бакалавр, магистрын түвшинд бизнес процессын хичээл зааж, олон улсын хамтарсан болон BTEC хөтөлбөр, оюутны дадлага, төгсөгчдийн хамтын ажиллагааг хөгжүүлдэг.','/teachers/saranchimeg.jpg' where not exists(select 1 from public.teachers where name='Н.Саранчимэг');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then '2012 оноос Мэдээллийн системийн менежментийн тэнхимд багш, ахлах багш, эрхлэгчээр ажилласан. Бакалавр, магистрын түвшинд бизнес процессын хичээл зааж, олон улсын хамтарсан болон BTEC хөтөлбөр, оюутны дадлага, төгсөгчдийн хамтын ажиллагааг хөгжүүлдэг.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Бизнес процесс загварчлал','Бизнес процессын менежмент']::text[] else courses end where name='Н.Саранчимэг';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Ш.Ганболд','Зөвлөх багш',array['Алгоритм, програмчлалын үндэс']::text[],'2002 оноос СЭЗИС-д багшилж буй зөвлөх багш. Компьютерийн шинжлэх ухааны магистр бөгөөд алгоритм, програмчлалын үндсийг заадаг. Тестийн болон санхүүгийн бүртгэлийн программ хөгжүүлэлт, байгууллагын зөвлөх үйлчилгээний туршлагатай.','/teachers/ganbold.jpg' where not exists(select 1 from public.teachers where name='Ш.Ганболд');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then '2002 оноос СЭЗИС-д багшилж буй зөвлөх багш. Компьютерийн шинжлэх ухааны магистр бөгөөд алгоритм, програмчлалын үндсийг заадаг. Тестийн болон санхүүгийн бүртгэлийн программ хөгжүүлэлт, байгууллагын зөвлөх үйлчилгээний туршлагатай.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Алгоритм, програмчлалын үндэс']::text[] else courses end where name='Ш.Ганболд';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Д.Анхтуяа','Дэд профессор',array['Мэдээллийн системийн үндэс']::text[],'Боловсролын салбарт 30 гаруй жил ажилласан. СЭЗИС-ийн сургалт, судалгаа, платформ түншлэлийн удирдлагад ажиллаж, 2025 оноос Мэдээллийн системийн менежментийн тэнхимийн дэд профессороор ажиллаж байна. Бакалаврын түвшинд мэдээллийн системийн үндэс хичээл заадаг.','/teachers/ankhtuya.jpg' where not exists(select 1 from public.teachers where name='Д.Анхтуяа');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then 'Боловсролын салбарт 30 гаруй жил ажилласан. СЭЗИС-ийн сургалт, судалгаа, платформ түншлэлийн удирдлагад ажиллаж, 2025 оноос Мэдээллийн системийн менежментийн тэнхимийн дэд профессороор ажиллаж байна. Бакалаврын түвшинд мэдээллийн системийн үндэс хичээл заадаг.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Мэдээллийн системийн үндэс']::text[] else courses end where name='Д.Анхтуяа';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Ц.Гүндэгмаа','Ахлах багш',array['Өгөгдлийн сангийн үндэс','Өгөгдлийн сангийн удирдлага','Өгөгдлийн агуулах, олборлолт','Системийн объект хандалтат зохиомж','Финтек','Их өгөгдлийн үндэс']::text[],'Өгөгдлийн сан, өгөгдөл боловсруулах технологийн чиглэлээр багшилж, судалгаа хийдэг ахлах багш. Бакалавр, магистр болон BTEC хөтөлбөрт өгөгдлийн сан, өгөгдөл бэлтгэл, бизнес интелиженсийн хичээлүүдийг боловсруулж заадаг. Олон улсын мэдээллийн системийн шалгалтаар мэргэшсэн инженерийн зэрэг авсан.','/teachers/gundegmaa.jpg' where not exists(select 1 from public.teachers where name='Ц.Гүндэгмаа');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then 'Өгөгдлийн сан, өгөгдөл боловсруулах технологийн чиглэлээр багшилж, судалгаа хийдэг ахлах багш. Бакалавр, магистр болон BTEC хөтөлбөрт өгөгдлийн сан, өгөгдөл бэлтгэл, бизнес интелиженсийн хичээлүүдийг боловсруулж заадаг. Олон улсын мэдээллийн системийн шалгалтаар мэргэшсэн инженерийн зэрэг авсан.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Өгөгдлийн сангийн үндэс','Өгөгдлийн сангийн удирдлага','Өгөгдлийн агуулах, олборлолт','Системийн объект хандалтат зохиомж','Финтек','Их өгөгдлийн үндэс']::text[] else courses end where name='Ц.Гүндэгмаа';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Л.Эрдэнэсайхан','Ахлах багш',array['Объект хандалтат програмчлал','Хүн ба компьютерын харилцаа','Мэдээллийн системийн үндэс','Бизнес ба хиймэл оюун']::text[],'2016 оноос СЭЗИС-ийн Мэдээллийн системийн менежментийн тэнхимд ахлах багшаар ажиллаж байгаа доктор. Өмнө нь МУБИС-д багшилсан. Бакалавр, магистр болон BTEC хөтөлбөрт програмчлал, хүн-компьютерын харилцаа, хиймэл оюуны хичээлүүдийг заадаг.','/teachers/erdenesaikhan.jpg' where not exists(select 1 from public.teachers where name='Л.Эрдэнэсайхан');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then '2016 оноос СЭЗИС-ийн Мэдээллийн системийн менежментийн тэнхимд ахлах багшаар ажиллаж байгаа доктор. Өмнө нь МУБИС-д багшилсан. Бакалавр, магистр болон BTEC хөтөлбөрт програмчлал, хүн-компьютерын харилцаа, хиймэл оюуны хичээлүүдийг заадаг.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Объект хандалтат програмчлал','Хүн ба компьютерын харилцаа','Мэдээллийн системийн үндэс','Бизнес ба хиймэл оюун']::text[] else courses end where name='Л.Эрдэнэсайхан';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Г.Эрдэнэцэцэг','Ахлах багш',array['Өгөгдлийн сангийн үндэс','Python ба өгөгдлийн шинжилгээ','Мэдээллийн системийн үндэс','Технологийн хөгжлийн хандлага']::text[],'2017 оноос Мэдээллийн системийн менежментийн тэнхимд ажиллаж байна. Өгөгдлийн сан, програмчлал, өгөгдлийн шинжилгээ болон дижитал шилжилтийн сургалтуудыг боловсруулж заадаг.','/teachers/erdenetsetseg.jpg' where not exists(select 1 from public.teachers where name='Г.Эрдэнэцэцэг');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then '2017 оноос Мэдээллийн системийн менежментийн тэнхимд ажиллаж байна. Өгөгдлийн сан, програмчлал, өгөгдлийн шинжилгээ болон дижитал шилжилтийн сургалтуудыг боловсруулж заадаг.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Өгөгдлийн сангийн үндэс','Python ба өгөгдлийн шинжилгээ','Мэдээллийн системийн үндэс','Технологийн хөгжлийн хандлага']::text[] else courses end where name='Г.Эрдэнэцэцэг';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Б.Бат-Оргил','Ахлах багш',array['Алгоритм, програмчлалын хэл (2022 оны магадлан итгэмжлэлийн тайлан)']::text[],'Мэдээллийн системийн менежментийн тэнхимийн ахлах багш. 2022 онд Улсын програмчлалын олимпиадад гуравдугаар байр эзэлсэн багийг удирдсан. Хичээлийн мэдээллийг 2022 оны магадлан итгэмжлэлийн тайлангаас авсан; тухайн үеийн мэдээлэл болно.','/teachers/bat-orgil.jpg' where not exists(select 1 from public.teachers where name='Б.Бат-Оргил');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then 'Мэдээллийн системийн менежментийн тэнхимийн ахлах багш. 2022 онд Улсын програмчлалын олимпиадад гуравдугаар байр эзэлсэн багийг удирдсан. Хичээлийн мэдээллийг 2022 оны магадлан итгэмжлэлийн тайлангаас авсан; тухайн үеийн мэдээлэл болно.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Алгоритм, програмчлалын хэл (2022 оны магадлан итгэмжлэлийн тайлан)']::text[] else courses end where name='Б.Бат-Оргил';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Д.Хулан','Ахлах багш',array['Мэдээллийн системийн төслийн менежмент','Өгөгдлийн шинжилгээний үндэс / Python','Системийн шинжилгээ ба зохиомж']::text[],'2016 оноос Мэдээллийн системийн менежментийн тэнхимд ажиллаж байна. Бакалаврын хөтөлбөрт төслийн менежмент, Python өгөгдлийн шинжилгээ, системийн шинжилгээ ба зохиомжийн хичээлүүдийг боловсруулж заадаг.','/teachers/khulan-official.png' where not exists(select 1 from public.teachers where name='Д.Хулан');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then '2016 оноос Мэдээллийн системийн менежментийн тэнхимд ажиллаж байна. Бакалаврын хөтөлбөрт төслийн менежмент, Python өгөгдлийн шинжилгээ, системийн шинжилгээ ба зохиомжийн хичээлүүдийг боловсруулж заадаг.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Мэдээллийн системийн төслийн менежмент','Өгөгдлийн шинжилгээний үндэс / Python','Системийн шинжилгээ ба зохиомж']::text[] else courses end where name='Д.Хулан';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Н.Хөгжилт','Багш',array['Мэдээллийн технологийн дэд бүтэц','Хиймэл оюун ухааны үндэс','Алгоритм, програмчлалын үндэс','Үүлэн технологи ба сүлжээ']::text[],'Холбооны жижиг суурь станцын бүтээгдэхүүний төлөвлөлт, судалгаа болон C хэлээр IP сүлжээний чиглүүлэлт хөгжүүлсэн туршлагатай. Бакалаврын түвшинд дэд бүтэц, хиймэл оюун, програмчлал, BTEC хөтөлбөрт үүлэн технологи ба сүлжээний хичээл заадаг.','/teachers/khugjilt.jpg' where not exists(select 1 from public.teachers where name='Н.Хөгжилт');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then 'Холбооны жижиг суурь станцын бүтээгдэхүүний төлөвлөлт, судалгаа болон C хэлээр IP сүлжээний чиглүүлэлт хөгжүүлсэн туршлагатай. Бакалаврын түвшинд дэд бүтэц, хиймэл оюун, програмчлал, BTEC хөтөлбөрт үүлэн технологи ба сүлжээний хичээл заадаг.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Мэдээллийн технологийн дэд бүтэц','Хиймэл оюун ухааны үндэс','Алгоритм, програмчлалын үндэс','Үүлэн технологи ба сүлжээ']::text[] else courses end where name='Н.Хөгжилт';
insert into public.teachers(name,position,courses,bio,photo_url) select 'Б.Гэрэлтцолмон','Багш',array['Бизнес шинжилгээ','Системийн шинжилгээ','Өгөгдлийн шинжилгээ','Их өгөгдөл ба дүрслэл']::text[],'Мэдээллийн систем, бизнес болон өгөгдлийн шинжилгээний чиглэлээр ажилладаг. BPMN, UML, Agile Scrum, өгөгдлийн агуулах, төслийн менежментийн туршлагатай.','/teachers/gerelttsolmon-official.png' where not exists(select 1 from public.teachers where name='Б.Гэрэлтцолмон');
update public.teachers set bio=case when nullif(btrim(bio),'') is null then 'Мэдээллийн систем, бизнес болон өгөгдлийн шинжилгээний чиглэлээр ажилладаг. BPMN, UML, Agile Scrum, өгөгдлийн агуулах, төслийн менежментийн туршлагатай.' else bio end, courses=case when coalesce(cardinality(courses),0)=0 then array['Бизнес шинжилгээ','Системийн шинжилгээ','Өгөгдлийн шинжилгээ','Их өгөгдөл ба дүрслэл']::text[] else courses end where name='Б.Гэрэлтцолмон';
insert into public.events(title,event_date,description,cover_image_url,event_type,article) select 'Оюутны “Бүтээлийн уралдаан” — 2026','2026-03-26'::date,'МСМТ-ээс 2026 оны 3 сарын 26-нд 4С танхимд зохион байгуулсан бүтээлийн уралдаанд 1–4-р курсийн 50 оюутан, 13 баг оролцож, шилдгүүдээ тодрууллаа. Ерөнхий ивээн тэтгэгч: М банк.','/events/projects-2026-cover.jpg','Бүтээлийн уралдаан','{"paragraphs":["Мэдээллийн системийн менежментийн тэнхимээс нийт оюутнуудын дунд “Бүтээлийн уралдаан”-ыг 2026 оны 03 дугаар сарын 26-ны өдөр 4С танхимд амжилттай зохион байгууллаа. Ерөнхий ивээн тэтгэгчээр М банк хамтран ажиллалаа.","Уралдаанд 1–4-р курсийн нийт 50 оюутан 13 баг болон оролцож бүтээлээ танилцуулав. Сэдэв чөлөөтэй байсан бөгөөд оюутнууд веб, мобайл аппликэйшн, хиймэл оюун ухаан, VR технологи ашиглан хөгжүүлсэн бүтээлүүдээрээ өрсөлдлөө."],"heading":"Шалгарсан бүтээлүүд","updates":[{"title":"🥇 1-р байр — Waffle баг · “Пирамид”","text":"Багийн гишүүд: МСМТ-ийн 4-р курсын оюутан Б.Тамир, 3-р курсын оюутан Б.Энхжин, Г.Энхмэнд."},{"title":"🥈 2-р байр — BIT баг · “Just a bit?”","text":"IO институтын 2-р курсын оюутан Н.Мөнхпүрэв."},{"title":"🥉 3-р байр — Mongol mind баг · “Mongol mind”","text":"Багийн гишүүд: 2-р курсын оюутан А.Угтах-Эрин, Б.Цогт, Ч.Тамир."}],"closing":["Шалгарсан багуудыг ивээн тэтгэгчийн гарын бэлэг болон мөнгөн шагналаар шагналаа.","Амжилттай оролцсон нийт оюутнууд болон ивээн тэтгэгч М банкны хамт олонд талархал илэрхийлье."],"photos":[{"image_url":"/events/projects-2026-gallery.jpg","caption":"2026 оны бүтээлийн уралдааны дурсамж"}],"source":"МСМТ-ийн зохион байгуулах комисс","source_url":"https://ufe.edu.mn/widgetDetail/1850"}'::jsonb where not exists(select 1 from public.events where title='Оюутны “Бүтээлийн уралдаан” — 2026');
select id into event_uuid from public.events where title='Оюутны “Бүтээлийн уралдаан” — 2026' order by created_at limit 1;
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/projects-2026-cover.jpg','Оюутны “Бүтээлийн уралдаан” — 2026' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='Оюутны “Бүтээлийн уралдаан” — 2026');
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/projects-2026-gallery.jpg','2026 оны бүтээлийн уралдааны дурсамж' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='2026 оны бүтээлийн уралдааны дурсамж');
insert into public.events(title,event_date,description,cover_image_url,event_type,article) select 'Оюутны “Програмчлалын олимпиад” — 2026','2026-03-20'::date,'МСМТ-ийн компьютерийн лабораторит болсон олимпиадад оюутнууд HackerRank платформ дээр 1200 онооны зургаан бодлогыг 4 цагийн хугацаанд бодож өрсөлдлөө. Ерөнхий ивээн тэтгэгч: М банк.','/events/olympiad-2026-cover.jpg','Програмчлалын олимпиад','{"paragraphs":["Мэдээллийн системийн менежментийн тэнхимээс нийт оюутнуудын дунд “Програмчлалын олимпиад”-ыг 2026 оны 03 дугаар сарын 20-ны өдөр МСМТ-ийн компьютерийн лабораторит амжилттай зохион байгууллаа. Ерөнхий ивээн тэтгэгчээр М банк хамтран ажиллалаа.","Оюутнууд урьдчилан бэлдсэн HackerRank платформ ашиглан 1200 онооны зургаан бодлогыг (Easy ×2, Medium ×2, Hard ×2) 4 цагийн хугацаанд бодлоо. Програмчлалын хэлний сонголт: C, C++, Java, Python3."],"heading":"Байр эзэлсэн оюутнууд","updates":[{"title":"🥇 1-р байр — А.Угтах-Эрин · 900 оноо","text":"Мэдээллийн систем, 2-р курс."},{"title":"🥈 2-р байр — О.Баянхангай · 625 оноо","text":"Мэдээллийн системийн хамтарсан хөтөлбөр, 1-р курс."},{"title":"🥉 3-р байр — А.Бямбабаяр · 356.36 оноо","text":"Мэдээллийн систем, 3-р курс."},{"title":"🥉 3-р байр — Н.Ялалт · 356.36 оноо","text":"Мэдээллийн системийн хамтарсан хөтөлбөр, 1-р курс."}],"closing":["Эдгээр оюутнууд СЭЗИС-ийг төлөөлөн улсын болон үндэсний програмчлалын олимпиадад оролцох эрх авлаа.","Амжилттай оролцсон нийт оюутнууд болон ивээн тэтгэгч М банкны хамт олонд талархал илэрхийлье."],"photos":[{"image_url":"/events/olympiad-2026-gallery.jpg","caption":"2026 оны програмчлалын олимпиадын дурсамж"}],"source":"МСМТ-ийн зохион байгуулах комисс"}'::jsonb where not exists(select 1 from public.events where title='Оюутны “Програмчлалын олимпиад” — 2026');
select id into event_uuid from public.events where title='Оюутны “Програмчлалын олимпиад” — 2026' order by created_at limit 1;
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/olympiad-2026-cover.jpg','Оюутны “Програмчлалын олимпиад” — 2026' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='Оюутны “Програмчлалын олимпиад” — 2026');
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/olympiad-2026-gallery.jpg','2026 оны програмчлалын олимпиадын дурсамж' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='2026 оны програмчлалын олимпиадын дурсамж');
insert into public.events(title,event_date,description,cover_image_url,event_type,article) select 'СЭЗИС-ийн “Мэдээллийн систем” бакалаврын хөтөлбөр амжилттай магадлан итгэмжлэгдлээ.','2022-06-29'::date,'“Мэдээллийн систем” бакалаврын хөтөлбөр Монгол Улсын Боловсролын магадлан итгэмжлэлийг амжилттай хийлгэн, 2022 оны 6 сарын 29-нд 5 жилийн хугацаатай магадлан итгэмжлэлийн гэрчилгээгээ гардан авлаа.','/events/accreditation-2022.jpg','Магадлан итгэмжлэл','{"paragraphs":["Ажлын хэсгийг ахалж ажилласан Мэдээллийн системийн тэнхимийн эрхлэгч Н.Саранчимэг болон тэнхимийн баг хамт олон, магадлан итгэмжлэлийн комиссын бусад гишүүддээ баяр хүргэж, талархал илэрхийлье.","СЭЗИС-ийн мэдээллийн системийн хөтөлбөр нь 2005 оноос “Мэдээллийн системийн менежмент”-ээр мэргэшсэн Бизнесийн удирдлагын бакалаврын зэрэг олгох хөтөлбөрийг хэрэгжүүлж ирсэн түүхтэй. Бакалавр 2.0 хөтөлбөрийн шинэчлэлийн хүрээнд мэдээллийн системийн үндсэн болон олон улсын хамтарсан хөтөлбөрт дараах өөрчлөлт, шинэчлэлүүд хийгдсэн."],"updates":[{"title":"Мэдээллийн системийн шинжлэх ухааны бакалаврын зэрэг олгох хөтөлбөр","text":"Бизнесийн удирдлагын бакалавраас шинжлэх ухааны бакалаврын зэрэг олгох хөтөлбөрт шилжин, хөтөлбөрийн зорилго, суралцахуйн үр дүнг шинэчлэн тодорхойлсон."},{"title":"Хөтөлбөрийн зорилго","text":"Бизнесийн болон технологийн мэргэжилтнүүдийн үр дүнтэй хамтын ажиллагааг хангаж бизнесийн үйл ажиллагаа, процессуудыг үр дүнтэй, үр өгөөжтэй зохион байгуулах мэдээллийн технологийн оновчтой шийдлийг тодорхойлох мэдлэг чадвартай мэргэжилтэн бэлдэх."},{"title":"Дата аналист мэргэжлийн хөтөлбөр","text":"Тайваний Азийн их сургуультай хамтран мэдээллийн системийн суурь мэдлэгтэй, дата аналистын 2+2 хөтөлбөрийг хэрэгжүүлж эхэлсэн."},{"title":"Хос, хавсарга мэргэжил","text":"Мэдээллийн системийн хөтөлбөрийн оюутнууд СЭЗИС-ийн бусад бакалаврын хөтөлбөрт хос, хавсарга мэргэжлээр суралцах боломжтой. Бусад мэргэжлийн оюутнууд ч Мэдээллийн системийн хөтөлбөрт суралцан хөрвөх чадвараа нэмэгдүүлэх боломжтой."},{"title":"Олон улсын хамтарсан 2+2 хөтөлбөр","text":"ОХУ-ын Дорнод Сибирийн технологийн удирдлагын их сургууль, Эрхүүгийн Үндэсний Судалгааны Техникийн Их сургуульд суралцах боломжтой."}],"source":"СЭЗИС-ийн Бакалаврын сургалт, судалгааны алба"}'::jsonb where not exists(select 1 from public.events where title='СЭЗИС-ийн “Мэдээллийн систем” бакалаврын хөтөлбөр амжилттай магадлан итгэмжлэгдлээ.');
select id into event_uuid from public.events where title='СЭЗИС-ийн “Мэдээллийн систем” бакалаврын хөтөлбөр амжилттай магадлан итгэмжлэгдлээ.' order by created_at limit 1;
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/accreditation-2022.jpg','СЭЗИС-ийн “Мэдээллийн систем” бакалаврын хөтөлбөр амжилттай магадлан итгэмжлэгдлээ.' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='СЭЗИС-ийн “Мэдээллийн систем” бакалаврын хөтөлбөр амжилттай магадлан итгэмжлэгдлээ.');
insert into public.events(title,event_date,description,cover_image_url,event_type,article) select 'ИРНИТУ-ийн зочин профессорын хиймэл оюуны семинар','2022-11-08'::date,'2022 оны 11 сарын 8–11-нд зочин профессор Александр Афанасьев болон Жанна Афанасьева нар СЭЗИС-д ажиллаж, Мэдээллийн системийн хөтөлбөрийн 80 гаруй оюутанд хиймэл оюуны хэрэглээ, чиг хандлагын семинар зохион байгуулсан.','/events/irnitu-ai-2022.jpg','Семинар','{"paragraphs":["2022 оны 11 сарын 8–11-нд ИРНИТУ-ийн зочин багш нар СЭЗИС-д айлчилж, хамтарсан хөтөлбөр болон судалгааны чиглэлээр туршлага солилцов. Мэдээллийн систем болон IO хөтөлбөрийн 80 гаруй оюутанд хиймэл оюуны технологи, хэрэглээ, чиг хандлагын семинар явуулсан."],"source":"СЭЗИС · ИРНИТУ-ийн зочин багш нарын айлчлал","source_url":"https://ufe.edu.mn/widgetDetail/433"}'::jsonb where not exists(select 1 from public.events where title='ИРНИТУ-ийн зочин профессорын хиймэл оюуны семинар');
select id into event_uuid from public.events where title='ИРНИТУ-ийн зочин профессорын хиймэл оюуны семинар' order by created_at limit 1;
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/irnitu-ai-2022.jpg','ИРНИТУ-ийн зочин профессорын хиймэл оюуны семинар' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='ИРНИТУ-ийн зочин профессорын хиймэл оюуны семинар');
insert into public.events(title,event_date,description,cover_image_url,event_type,article) select 'Фулбрайтын мэргэжилтний хөтөлбөр','2024-12-09'::date,'Профессор Yasin Ozcelik 2024.12.09–2025.01.16-нд Мэдээллийн системийн менежментийн тэнхимтэй хамтран сургалтын хөтөлбөр хөгжүүлэлт, өгөгдлийн сангийн дадлага, өгөгдөл олборлолт болон хиймэл оюуны сургалт, семинар явуулсан.','/events/fulbright-2024.jpg','Хөтөлбөр','{"paragraphs":["Фэйрфилд их сургуулийн профессор Yasin Ozcelik 2024 оны 12 сарын 9-нөөс 2025 оны 1 сарын 16 хүртэл тэнхимтэй хамтран ажилласан. Хөтөлбөрийн хүрээнд судалгааны арга зүй, өгөгдлийн сангийн удирдлага, өгөгдөл бэлтгэх, өгөгдөл олборлолт, хиймэл оюуны сургалт, хэлэлцүүлэг зохион байгуулсан."],"source":"СЭЗИС · Фулбрайтын мэргэжилтэн хөтөлбөрийн тайлан","source_url":"https://ufe.edu.mn/widgetDetail/1552"}'::jsonb where not exists(select 1 from public.events where title='Фулбрайтын мэргэжилтний хөтөлбөр');
select id into event_uuid from public.events where title='Фулбрайтын мэргэжилтний хөтөлбөр' order by created_at limit 1;
insert into public.event_photos(event_id,image_url,caption) select event_uuid,'/events/fulbright-2024.jpg','Фулбрайтын мэргэжилтний хөтөлбөр' where not exists(select 1 from public.event_photos where event_id=event_uuid and caption='Фулбрайтын мэргэжилтний хөтөлбөр');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'Пирамид','2026 оны 3 сарын 26-нд болсон оюутны бүтээлийн уралдаанд 13 багаас тэргүүн байр эзэлсэн Waffle багийн бүтээл.','Технологи',array[]::text[],2026,owner_id,'Waffle баг','Уралдааны бүтээл','{"contributors":["Б.Тамир · 4-р курс","Б.Энхжин · 3-р курс","Г.Энхмэнд · 3-р курс"],"award":"🥇 1-р байр","featured":true,"highlights":["МСМТ-ийн 3 оюутны баг","Бүтээлийн уралдаан · 4С танхим","Ерөнхий ивээн тэтгэгч · М банк"],"topics":["Оюутны төсөл","Багийн бүтээл"],"source_url":"https://www.ufe.edu.mn/widgetDetail/1850","source_label":"СЭЗИС · Уралдааны тайлан","image_caption":"2026 оны бүтээлийн уралдааны зураг"}'::jsonb,'published','/events/projects-2026-cover.jpg',null,null where not exists(select 1 from public.exhibits where title='Пирамид' and status='published');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'Just a bit?','Оюутны 2026 оны бүтээлийн уралдааны дэд байрт шалгарсан BIT багийн бүтээл. Бүтээгч нь IO институтын 2-р курсын оюутан Н.Мөнхпүрэв.','Технологи',array[]::text[],2026,owner_id,'BIT баг','Уралдааны бүтээл','{"contributors":["Н.Мөнхпүрэв · IO институт · 2-р курс"],"award":"🥈 2-р байр","highlights":["2026.03.26 · Бүтээлийн уралдаан","50 оюутан, 13 баг оролцсон"],"topics":["Оюутны төсөл"],"source_url":"https://www.ufe.edu.mn/widgetDetail/1850","source_label":"СЭЗИС · Уралдааны тайлан","image_caption":"2026 оны бүтээлийн уралдааны зураг"}'::jsonb,'published','/events/projects-2026-cover.jpg',null,null where not exists(select 1 from public.exhibits where title='Just a bit?' and status='published');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'Mongol mind','МСМТ-ийн 2-р курсын оюутнуудын хамтарсан бүтээл. 2026 оны бүтээлийн уралдаанд гуравдугаар байр эзэлж, ивээн тэтгэгчийн шагнал хүртсэн.','Технологи',array[]::text[],2026,owner_id,'Mongol mind баг','Уралдааны бүтээл','{"contributors":["А.Угтах-Эрин · 2-р курс","Б.Цогт · 2-р курс","Ч.Тамир · 2-р курс"],"award":"🥉 3-р байр","highlights":["2-р курсын 3 оюутны баг","2026.03.26 · Бүтээлийн уралдаан"],"topics":["Оюутны төсөл","Багийн бүтээл"],"source_url":"https://www.ufe.edu.mn/widgetDetail/1850","source_label":"СЭЗИС · Уралдааны тайлан","image_caption":"2026 оны бүтээлийн уралдааны зураг"}'::jsonb,'published','/events/projects-2026-gallery.jpg',null,null where not exists(select 1 from public.exhibits where title='Mongol mind' and status='published');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'Хиймэл оюунд суурилсан онлайн шалгалтын хяналтын систем','Онлайн шалгалтын явцад зөрчилтэй байж болзошгүй үйлдлийг илрүүлж, багшийн нягтлалд шилжүүлэх туршилтын систем. Компьютерын хараа, аудио шинжилгээ, хөтчийн үйлдлийг нэгтгэн судалсан.','Судалгаа',array['Next.js','FastAPI','SQLite','WebSocket','MediaPipe','YOLOv8']::text[],2026,owner_id,'Гандүүрэн, Билгээ','Дипломын ажил','{"cover_style":"ai","highlights":["8 төрлийн зөрчил илрүүлэх загвар","Эцсийн шийдвэрийг багш гаргана","Дипломын төслийн туршилтын хэрэгжүүлэлт"],"topics":["Хиймэл оюун","Цахим сургалт"],"source_url":"https://www.repository.ufe.edu.mn/xmlui/handle/8524/4870","source_label":"СЭЗИС · Бүтээлийн сан"}'::jsonb,'published',null,null,null where not exists(select 1 from public.exhibits where title='Хиймэл оюунд суурилсан онлайн шалгалтын хяналтын систем' and status='published');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'Хиймэл оюун ухаанд суурилан UML диаграмм боловсруулах нь','Текстээр бичсэн шаардлагаас UML диаграмм үүсгэх боломжийг судалсан дипломын ажил. Диаграмм үүсгэгч хэрэгслүүдийг харьцуулж, системийн шаардлага болон туршилтын загварын чиглэлийг боловсруулсан.','Судалгаа',array[]::text[],2026,owner_id,'Долгорням, Ану','Дипломын ажил','{"cover_style":"systems","highlights":["Class, sequence, use case зэрэг диаграммын төрөл","Design Science Research Methodology","Шаардлагаас диаграмм үүсгэх шийдэл"],"topics":["UML","Хиймэл оюун","Системийн шинжилгээ"],"source_url":"https://www.repository.ufe.edu.mn/xmlui/handle/8524/4691","source_label":"СЭЗИС · Бүтээлийн сан"}'::jsonb,'published',null,null,null where not exists(select 1 from public.exhibits where title='Хиймэл оюун ухаанд суурилан UML диаграмм боловсруулах нь' and status='published');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'СӨХ-ийн нэгдсэн платформ','Сууц өмчлөгчдийн холбооны өдөр тутмын үйл ажиллагааг цахимжуулах нэгдсэн платформын системийн шинжилгээ, зохиомжийг боловсруулахад чиглэсэн дипломын төсөл.','Судалгаа',array[]::text[],2026,owner_id,'Батсүмбэрэл, Энэрэлт','Дипломын ажил','{"cover_style":"platform","highlights":["СӨХ-ийн үйл ажиллагааны цахимжилт","Нэгдсэн платформын шинжилгээ, зохиомж"],"topics":["Системийн шинжилгээ","Дижитал шилжилт"],"source_url":"https://repository.ufe.edu.mn/xmlui/handle/8524/4674","source_label":"СЭЗИС · Бүтээлийн сан"}'::jsonb,'published',null,null,null where not exists(select 1 from public.exhibits where title='СӨХ-ийн нэгдсэн платформ' and status='published');
insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select 'Цахим худалдааны UX/UI ба худалдан авах зан төлөв','Монголын цахим худалдааны платформын интерфейс, хэрэглэхэд хялбар байдал нь худалдан авалтын шийдвэрт хэрхэн нөлөөлөхийг судалсан ажил. Санал асуулга болон өрсөлдөөнт шинжилгээг хослуулсан.','Судалгаа',array[]::text[],2025,owner_id,'Төмөрбаатар, Алтанзул','Дипломын ажил','{"original_title":"Монголын цахим худалдааны платформуудын UX/UI дизайн нь хэрэглэгчийн худалдан авах зан төлөвт хэрхэн нөлөөлж буй судалгаа","cover_style":"design","highlights":["Чанарын болон тоон судалгаа","Навигаци, хурд, төлбөрийн урсгал","Хэрэглэгч төвтэй сайжруулалтын санал"],"topics":["UX/UI","Цахим худалдаа","Хэрэглэгчийн судалгаа"],"source_url":"https://repository.ufe.edu.mn/xmlui/handle/8524/4451","source_label":"СЭЗИС · Бүтээлийн сан"}'::jsonb,'published',null,null,null where not exists(select 1 from public.exhibits where title='Цахим худалдааны UX/UI ба худалдан авах зан төлөв' and status='published');
end $$;
commit;
select 'teachers' as content,count(*) from public.teachers union all select 'events',count(*) from public.events union all select 'exhibits',count(*) from public.exhibits union all select 'event_photos',count(*) from public.event_photos;
