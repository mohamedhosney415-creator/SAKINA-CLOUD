alter table public.game_progress
  add column if not exists highest_level integer not null default 1
  check (highest_level between 1 and 100);

update public.game_progress
set highest_level = greatest(highest_level, least(100, greatest(1, coalesce((data->>'qgame_level')::integer, 1))));

update public.game_progress
set data = jsonb_set(coalesce(data, '{}'::jsonb), '{qgame_highest_level}', to_jsonb(highest_level), true)
where not (coalesce(data, '{}'::jsonb) ? 'qgame_highest_level');

create table if not exists public.app_control (
  id smallint primary key default 1 check (id = 1),
  game_enabled boolean not null default true,
  maintenance_message text not null default 'اللعبة متوقفة مؤقتًا للصيانة. حاول مرة أخرى لاحقًا.',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
insert into public.app_control(id) values (1) on conflict (id) do nothing;
alter table public.app_control enable row level security;

drop policy if exists app_control_read_authenticated on public.app_control;
create policy app_control_read_authenticated on public.app_control
  for select to authenticated using (true);
drop policy if exists app_control_owner_update on public.app_control;
create policy app_control_owner_update on public.app_control
  for update to authenticated using (public.is_owner()) with check (public.is_owner());

drop policy if exists game_progress_owner_read on public.game_progress;
create policy game_progress_owner_read on public.game_progress
  for select to authenticated using (user_id = (select auth.uid()) or public.is_owner());
drop policy if exists game_progress_owner_update on public.game_progress;
create policy game_progress_owner_update on public.game_progress
  for update to authenticated using (user_id = (select auth.uid()) or public.is_owner())
  with check (user_id = (select auth.uid()) or public.is_owner());

create or replace function public.game_owner_set_player_level(target_user uuid, target_level integer)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare current_highest integer; current_data jsonb;
begin
  if not public.is_owner() then raise exception 'Owner access required'; end if;
  if target_level < 1 or target_level > 100 then raise exception 'Target level must be between 1 and 100'; end if;
  select highest_level, data into current_highest, current_data
  from public.game_progress where user_id = target_user for update;
  if current_data is null then raise exception 'Game progress not found'; end if;
  if target_level > current_highest then
    raise exception 'Cannot set a level above the highest reached level (%)', current_highest;
  end if;
  current_data := jsonb_set(current_data, '{qgame_level}', to_jsonb(target_level), true);
  current_data := jsonb_set(current_data, '{qgame_level_answered}', '0'::jsonb, true);
  current_data := jsonb_set(current_data, '{qgame_level_correct}', '0'::jsonb, true);
  current_data := jsonb_set(current_data, '{qgame_level_mistakes}', '0'::jsonb, true);
  current_data := jsonb_set(current_data, '{qgame_level_history}', '[]'::jsonb, true);
  update public.game_progress set data = current_data, version = version + 1, updated_at = now()
  where user_id = target_user;
end;
$$;
revoke all on function public.game_owner_set_player_level(uuid, integer) from public, anon;
grant execute on function public.game_owner_set_player_level(uuid, integer) to authenticated;
