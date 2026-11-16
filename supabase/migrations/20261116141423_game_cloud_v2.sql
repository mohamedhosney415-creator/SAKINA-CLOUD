-- SAKINA Game Cloud v2
-- Additive owner/admin tooling + safer aggregate access.
-- Run after migration_game_cloud_v1.sql.

create or replace view public.game_admin_player_stats
with (security_invoker = true)
as
select
  gp.user_id,
  p.email,
  p.display_name,
  gp.data,
  gp.updated_at,
  coalesce((gp.data->>'qgame_level')::int, 1) as level,
  coalesce((gp.data->>'qgame_score')::bigint, 0) as score,
  coalesce((gp.data->>'qgame_noor')::bigint, 0) as noor,
  coalesce((gp.data->>'qgame_total')::bigint, 0) as total_questions,
  coalesce((gp.data->>'qgame_correct')::bigint, 0) as correct_answers,
  coalesce((gp.data->>'qgame_streak')::int, 0) as streak
from public.game_progress gp
left join public.profiles p on p.id = gp.user_id;

grant select on public.game_admin_player_stats to authenticated;

create or replace function public.game_admin_overview()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not public.is_owner() then
    raise exception 'Owner access required';
  end if;

  select jsonb_build_object(
    'players', (select count(*) from public.game_progress),
    'questions', (select count(*) from public.game_questions where active = true),
    'total_questions', (select count(*) from public.game_questions),
    'daily_challenges', (select count(*) from public.game_daily_challenges where active = true),
    'events_24h', (select count(*) from public.game_events where created_at >= now() - interval '24 hours'),
    'events_7d', (select count(*) from public.game_events where created_at >= now() - interval '7 days'),
    'correct_7d', (select coalesce(sum(amount), 0) from public.game_events where event_type = 'answer_correct' and created_at >= now() - interval '7 days'),
    'level_100_players', (select count(*) from public.game_progress where coalesce((data->>'qgame_level')::int, 1) >= 100)
  ) into result;
  return result;
end;
$$;

grant execute on function public.game_admin_overview() to authenticated;

-- Owner-only atomic adjustment for legitimate admin corrections.
create or replace function public.game_owner_adjust_noor(target_user uuid, delta integer, reason text default 'admin adjustment')
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_noor bigint;
  new_noor bigint;
  d jsonb;
begin
  if not public.is_owner() then raise exception 'Owner access required'; end if;
  if delta = 0 then raise exception 'Delta must not be zero'; end if;

  select coalesce((data->>'qgame_noor')::bigint, 0), data
    into old_noor, d
  from public.game_progress
  where user_id = target_user
  for update;

  if d is null then raise exception 'Game progress not found'; end if;
  new_noor := old_noor + delta;
  if new_noor < 0 or new_noor > 10000000 then raise exception 'Invalid Noor balance'; end if;

  d := jsonb_set(d, '{qgame_noor}', to_jsonb(new_noor), true);
  update public.game_progress
     set data = d, version = version + 1, updated_at = now()
   where user_id = target_user;

  insert into public.game_events(user_id, event_type, amount, metadata, idempotency_key)
  values (target_user, 'admin_noor_adjustment', delta,
          jsonb_build_object('reason', reason, 'old_noor', old_noor, 'new_noor', new_noor),
          'admin_noor_' || target_user::text || '_' || extract(epoch from clock_timestamp())::bigint || '_' || abs(delta)::text);
  return new_noor;
end;
$$;

grant execute on function public.game_owner_adjust_noor(uuid, integer, text) to authenticated;
