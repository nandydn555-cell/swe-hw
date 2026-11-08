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
