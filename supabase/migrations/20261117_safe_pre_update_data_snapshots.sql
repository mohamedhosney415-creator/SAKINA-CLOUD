-- Safe pre-update backup: preserve both the device state and previous cloud state.
-- The RPC runs as the authenticated user and is protected by RLS on both tables.

create table if not exists public.user_data_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  data jsonb not null,
  source text not null check (source in ('pre_update_local', 'pre_update_cloud')),
  created_at timestamptz not null default now()
);

create index if not exists user_data_snapshots_user_created_idx
  on public.user_data_snapshots (user_id, created_at desc);

alter table public.user_data_snapshots enable row level security;

drop policy if exists user_data_snapshots_select_own on public.user_data_snapshots;
create policy user_data_snapshots_select_own
  on public.user_data_snapshots
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists user_data_snapshots_insert_own on public.user_data_snapshots;
create policy user_data_snapshots_insert_own
  on public.user_data_snapshots
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

revoke all on public.user_data_snapshots from anon;
grant select, insert on public.user_data_snapshots to authenticated;

create or replace function public.prepare_sakina_update_backup(p_local_data jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_remote_data jsonb;
  v_local_snapshot uuid;
  v_cloud_snapshot uuid;
  v_saved_data jsonb;
begin
  if v_user_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_local_data is null or jsonb_typeof(p_local_data) <> 'object' then
    raise exception 'INVALID_LOCAL_DATA';
  end if;

  select ud.data into v_remote_data
  from public.user_data as ud
  where ud.user_id = v_user_id
  for update;

  insert into public.user_data_snapshots (user_id, data, source)
  values (v_user_id, p_local_data, 'pre_update_local')
  returning id into v_local_snapshot;

  if v_remote_data is not null then
    insert into public.user_data_snapshots (user_id, data, source)
    values (v_user_id, v_remote_data, 'pre_update_cloud')
    returning id into v_cloud_snapshot;
  end if;

  insert into public.user_data (user_id, data, updated_at)
  values (v_user_id, p_local_data, now())
  on conflict (user_id) do update
    set data = excluded.data, updated_at = excluded.updated_at;

  select ud.data into v_saved_data
  from public.user_data as ud
  where ud.user_id = v_user_id;

  if v_saved_data is distinct from p_local_data then
    raise exception 'BACKUP_VERIFY_FAILED';
  end if;

  return jsonb_build_object(
    'ok', true,
    'local_snapshot_id', v_local_snapshot,
    'cloud_snapshot_id', v_cloud_snapshot,
    'cloud_snapshot_saved', v_cloud_snapshot is not null,
    'verified', true
  );
end;
$$;

revoke all on function public.prepare_sakina_update_backup(jsonb) from public, anon;
grant execute on function public.prepare_sakina_update_backup(jsonb) to authenticated;
