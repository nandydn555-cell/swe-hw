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
