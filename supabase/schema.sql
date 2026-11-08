-- ISM Digital Museum schema. Run in the Supabase SQL editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'ISM бүтээгч',
  avatar_url text,
  bio text,
  role text not null default 'creator' check (role in ('creator','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.exhibition_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text
);

insert into public.exhibition_categories (name, description) values
  ('Технологи','Технологид суурилсан шийдэл'),
  ('Веб хөгжүүлэлт','Веб сайт болон аппликейшн'),
  ('Дижитал урлаг','Дижитал медиа, дизайн, интерактив бүтээл'),
  ('Судалгаа','Судалгаа, дата өгүүлэмж'),
  ('Дурсамж','Түүх, дурсамж, аман өв')
on conflict (name) do nothing;

create table if not exists public.exhibits (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  image_url text,
  category text not null,
  category_id uuid not null references public.exhibition_categories(id) on delete restrict,
  technology_stack text[] not null default '{}',
  year_created integer not null check (year_created between 1900 and 2200),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  demo_url text,
  github_url text,
  status text not null default 'pending' check (status in ('pending','published','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(), name text not null,
  position text, courses text[] not null default '{}', bio text, photo_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(), title text not null,
  event_date date not null, description text, cover_image_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.event_photos (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  image_url text not null, caption text,
  created_at timestamptz not null default now()
);

create table if not exists public.time_capsules (
  id uuid primary key default gen_random_uuid(),
  message text not null check (char_length(message) between 1 and 1200),
  author_name text not null default 'Нууц нэр',
  user_id uuid references public.profiles(id) on delete set null,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

-- Keep the public profile editor from letting a regular user grant themselves admin.
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

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin
  insert into public.profiles(id, display_name) values
    (new.id, coalesce(nullif(btrim(new.raw_user_meta_data->>'display_name'), ''), nullif(split_part(new.email,'@',1), ''), 'ISM бүтээгч'))
  on conflict (id) do nothing;
  return new;
end $$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.sync_exhibit_category_reference()
returns trigger language plpgsql set search_path = public
as $$
begin
  select id into new.category_id from public.exhibition_categories where name = new.category;
  if new.category_id is null then
    raise exception 'Unknown exhibition category: %', new.category;
  end if;
  return new;
end;
$$;
drop trigger if exists exhibits_sync_category_reference on public.exhibits;
create trigger exhibits_sync_category_reference before insert or update of category on public.exhibits
for each row execute function public.sync_exhibit_category_reference();
create index if not exists exhibits_category_id_idx on public.exhibits(category_id);

alter table public.profiles enable row level security;
alter table public.exhibition_categories enable row level security;
alter table public.exhibits enable row level security;
alter table public.teachers enable row level security;
alter table public.events enable row level security;
alter table public.event_photos enable row level security;
alter table public.time_capsules enable row level security;

create policy "Profiles are public" on public.profiles for select using (true);
create policy "Users update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy "Categories are public" on public.exhibition_categories for select using (true);
create policy "Admins manage categories" on public.exhibition_categories for all using (public.is_admin()) with check (public.is_admin());
create policy "Published exhibits are public; owners and admins see all" on public.exhibits for select
  using (status = 'published' or creator_id = auth.uid() or public.is_admin());
create policy "Creators submit own exhibits" on public.exhibits for insert
  with check (creator_id = auth.uid() and status = 'pending');
create policy "Owners update own pending exhibits" on public.exhibits for update
  using ((creator_id = auth.uid() and status = 'pending') or public.is_admin())
  with check ((creator_id = auth.uid() and status = 'pending') or public.is_admin());
create policy "Owners delete own exhibits; admins manage all" on public.exhibits for delete
  using (creator_id = auth.uid() or public.is_admin());
drop policy if exists "Admins manage exhibits" on public.exhibits;
create policy "Admins manage exhibits" on public.exhibits for all
  using (public.is_admin()) with check (public.is_admin());
create policy "Teachers are public" on public.teachers for select using (true);
create policy "Admins manage teachers" on public.teachers for all using (public.is_admin()) with check (public.is_admin());
create policy "Events are public" on public.events for select using (true);
create policy "Admins manage events" on public.events for all using (public.is_admin()) with check (public.is_admin());
create policy "Event photos are public" on public.event_photos for select using (true);
create policy "Admins manage event photos" on public.event_photos for all using (public.is_admin()) with check (public.is_admin());
create policy "Approved capsules are public" on public.time_capsules for select using (approved or user_id = auth.uid() or public.is_admin());
create policy "Anyone can submit a capsule" on public.time_capsules for insert with check (approved = false and (user_id is null or user_id = auth.uid()));
create policy "Admins review capsules" on public.time_capsules for update using (public.is_admin()) with check (public.is_admin());
create policy "Admins remove capsules" on public.time_capsules for delete using (public.is_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('museum-media','museum-media',true,8388608,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "Museum media is publicly readable" on storage.objects for select using (bucket_id = 'museum-media');
create policy "Creators upload to their own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'museum-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Creators update own files" on storage.objects for update to authenticated
  using (bucket_id = 'museum-media' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'museum-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Creators delete own files" on storage.objects for delete to authenticated
  using (bucket_id = 'museum-media' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
