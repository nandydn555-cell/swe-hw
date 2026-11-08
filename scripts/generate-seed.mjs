import { readFileSync, writeFileSync } from 'node:fs';
import { exhibits, teachers, events } from '../src/data.js';
const str = value => value == null ? 'null' : `'${String(value).replaceAll("'", "''")}'`;
const json = value => value == null ? 'null' : `${str(JSON.stringify(value))}::jsonb`;
const array = value => `array[${value.map(str).join(',')}]::text[]`;
const lines = [
  '-- Generated from the reviewed archive in src/data.js and src/exhibits.js.',
  '-- Run AFTER finalize-schema.sql as postgres. Inserts missing rows only.',
  '-- Existing names/titles and editorial changes are preserved. Re-runnable.',
  'begin;',
  'do $$ declare owner_id uuid; event_uuid uuid; begin',
  "select id into owner_id from public.profiles where role='admin' order by created_at limit 1;",
  "if owner_id is null then raise exception 'Create an administrator first (README: Эхний админ)'; end if;"
];
for (const t of teachers) {
  lines.push(`insert into public.teachers(name,position,courses,bio,photo_url) select ${str(t.name)},${str(t.position)},${array(t.courses.split(' · ').filter(Boolean))},${str(t.bio)},${str(t.photo_url)} where not exists(select 1 from public.teachers where name=${str(t.name)});`);
  lines.push(`update public.teachers set bio=case when nullif(btrim(bio),'') is null then ${str(t.bio)} else bio end, courses=case when coalesce(cardinality(courses),0)=0 then ${array(t.courses.split(' · ').filter(Boolean))} else courses end where name=${str(t.name)};`);
}
for (const e of events) {
  lines.push(`insert into public.events(title,event_date,description,cover_image_url,event_type,article) select ${str(e.title)},${str(e.date.replaceAll('.','-'))}::date,${str(e.description)},${str(e.image_url)},${str(e.type)},${json(e.article)} where not exists(select 1 from public.events where title=${str(e.title)});`);
  lines.push(`select id into event_uuid from public.events where title=${str(e.title)} order by created_at limit 1;`);
  for (const p of [{ image_url:e.image_url, caption:e.title }, ...(e.article?.photos || [])]) lines.push(`insert into public.event_photos(event_id,image_url,caption) select event_uuid,${str(p.image_url)},${str(p.caption)} where not exists(select 1 from public.event_photos where event_id=event_uuid and caption=${str(p.caption)});`);
}
for (const e of exhibits) {
  const details=Object.fromEntries(['original_title','contributors','award','featured','cover_style','highlights','topics','source_url','source_label','image_caption'].filter(key=>e[key]!==undefined).map(key=>[key,e[key]]));
  lines.push(`insert into public.exhibits(title,description,category,technology_stack,year_created,creator_id,creator_name,collection,archive_details,status,image_url,demo_url,github_url) select ${str(e.title)},${str(e.description)},${str(e.category)},${array(e.technology_stack)},${e.year_created},owner_id,${str(e.creator)},${str(e.collection)},${json(details)},'published',${str(e.image_url)},${str(e.demo_url)},${str(e.github_url)} where not exists(select 1 from public.exhibits where title=${str(e.title)} and status='published');`);
}
lines.push('end $$;', 'commit;', 'select \'teachers\' as content,count(*) from public.teachers union all select \'events\',count(*) from public.events union all select \'exhibits\',count(*) from public.exhibits union all select \'event_photos\',count(*) from public.event_photos;');
writeFileSync('supabase/seed-complete-archive.sql', lines.join('\n')+'\n');
const files = ['repair-missing-profiles.sql','migrations/20261106_category_relation.sql','admin-migration.sql','finalize-schema.sql','setup-storage.sql','seed-complete-archive.sql'];
writeFileSync('supabase/complete-existing-project.sql', '-- Existing ISM project: run as postgres. Preserves accounts and editorial content.\n' + files.map(name => `-- ${name}\n${readFileSync(`supabase/${name}`, 'utf8')}`).join('\n\n'));
writeFileSync('supabase/finish-and-verify.sql', '-- Fills missing teacher details, then tests RLS with transaction-only data.\n' + readFileSync('supabase/seed-complete-archive.sql','utf8') + '\n' + readFileSync('supabase/test-access.sql','utf8'));
console.log('Generated full archive seed.');
