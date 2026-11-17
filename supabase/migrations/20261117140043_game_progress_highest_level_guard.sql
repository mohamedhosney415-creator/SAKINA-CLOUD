create or replace function public.game_progress_track_highest_level()
returns trigger
language plpgsql
set search_path = ''
as $$
declare requested_level integer;
begin
  requested_level := greatest(1, least(100, coalesce((new.data->>'qgame_level')::integer, 1)));
  if tg_op = 'INSERT' then
    new.highest_level := requested_level;
    if requested_level > 1 then
      new.data := jsonb_set(new.data, '{qgame_highest_level}', to_jsonb(requested_level), true);
    end if;
    return new;
  end if;
  if not public.is_owner() then
    if requested_level > old.highest_level + 1 then
      requested_level := old.highest_level + 1;
      new.data := jsonb_set(new.data, '{qgame_level}', to_jsonb(requested_level), true);
    end if;
    new.highest_level := greatest(old.highest_level, requested_level);
    new.data := jsonb_set(new.data, '{qgame_highest_level}', to_jsonb(new.highest_level), true);
  else
    new.highest_level := greatest(old.highest_level, coalesce(new.highest_level, old.highest_level));
  end if;
  return new;
end;
$$;
drop trigger if exists game_progress_track_highest_level on public.game_progress;
create trigger game_progress_track_highest_level
before insert or update of data on public.game_progress
for each row execute function public.game_progress_track_highest_level();
