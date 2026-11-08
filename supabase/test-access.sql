-- Run as postgres in SQL Editor after setup. Every test account and row is
-- created inside this transaction and removed by ROLLBACK, including on failure.
begin;
select set_config('museum.test.alice',gen_random_uuid()::text,true),
       set_config('museum.test.bob',gen_random_uuid()::text,true),
       set_config('museum.test.admin',gen_random_uuid()::text,true),
       set_config('museum.test.exhibit',gen_random_uuid()::text,true);
insert into auth.users(id,email,raw_user_meta_data)
select current_setting('museum.test.'||name)::uuid,
       'museum-test-'||current_setting('museum.test.'||name)||'@example.invalid','{}'::jsonb
from unnest(array['alice','bob','admin']) as fixture(name);
update public.profiles set role='admin' where id=current_setting('museum.test.admin')::uuid;

-- The Auth trigger must have created all three profiles.
do $$ begin
  if (select count(*) from public.profiles where id in
    (current_setting('museum.test.alice')::uuid,current_setting('museum.test.bob')::uuid,current_setting('museum.test.admin')::uuid)) <> 3
  then raise exception 'FAIL: Auth/profile trigger'; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('museum.test.alice'),true);
insert into public.exhibits(id,title,description,category,year_created,creator_id,status)
values(current_setting('museum.test.exhibit')::uuid,'RLS transaction test','Temporary test','Технологи',2026,current_setting('museum.test.alice')::uuid,'pending');

do $$ begin
  begin
    update public.exhibits set status='published' where id=current_setting('museum.test.exhibit')::uuid;
    raise exception 'FAIL: student published directly';
  exception when insufficient_privilege then null; end;
  begin
    update public.exhibits set creator_id=current_setting('museum.test.bob')::uuid where id=current_setting('museum.test.exhibit')::uuid;
    raise exception 'FAIL: student reassigned ownership';
  exception when insufficient_privilege then null; end;
  begin
    update public.profiles set role='admin' where id=current_setting('museum.test.alice')::uuid;
    raise exception 'FAIL: student escalated role';
  exception when raise_exception then
    if sqlerrm not like 'Only an administrator%' then raise; end if;
  end;
  begin
    insert into public.teachers(name) values('Unauthorized teacher');
    raise exception 'FAIL: student inserted teacher';
  exception when insufficient_privilege then null; end;
  begin
    insert into storage.objects(bucket_id,name) values('museum-media',current_setting('museum.test.bob')||'/denied.jpg');
    raise exception 'FAIL: student uploaded into another folder';
  exception when insufficient_privilege then null; end;
end $$;
insert into storage.objects(bucket_id,name)
values('museum-media',current_setting('museum.test.alice')||'/transaction-test.jpg');

-- A second student must neither see the private draft nor change/delete it.
select set_config('request.jwt.claim.sub',current_setting('museum.test.bob'),true);
do $$ declare affected integer; begin
  if exists(select 1 from public.exhibits where id=current_setting('museum.test.exhibit')::uuid)
    then raise exception 'FAIL: another student sees private draft'; end if;
  update public.exhibits set description='unauthorized' where id=current_setting('museum.test.exhibit')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'FAIL: cross-user update'; end if;
  delete from public.exhibits where id=current_setting('museum.test.exhibit')::uuid;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'FAIL: cross-user delete'; end if;
end $$;

-- Administrator publishes; the owner revises it and sends it back to moderation.
select set_config('request.jwt.claim.sub',current_setting('museum.test.admin'),true);
do $$ declare affected integer; begin
  if not public.is_admin() then raise exception 'FAIL: admin lookup'; end if;
  update public.exhibits set status='published' where id=current_setting('museum.test.exhibit')::uuid;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'FAIL: admin publish'; end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('museum.test.alice'),true);
do $$ declare affected integer; begin
  update public.exhibits set description='Owner revision',status='pending' where id=current_setting('museum.test.exhibit')::uuid;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'FAIL: owner cannot revise published work'; end if;
end $$;

set local role anon;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
  if exists(select 1 from public.exhibits where id=current_setting('museum.test.exhibit')::uuid)
    then raise exception 'FAIL: anonymous visitor sees draft'; end if;
  begin
    insert into public.exhibits(title,description,category,year_created,creator_id,status)
    values('Unauthorized','Denied','Технологи',2026,current_setting('museum.test.alice')::uuid,'pending');
    raise exception 'FAIL: anonymous insert';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: Auth trigger, ownership, student revisions, admin publishing, role protection, private drafts, cross-user writes and Storage folders' as result;
rollback;
