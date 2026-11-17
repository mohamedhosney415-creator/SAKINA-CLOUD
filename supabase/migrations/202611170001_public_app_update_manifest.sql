create or replace function public.get_public_app_update()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select jsonb_build_object(
    'latestVersion',
      case
        when mandatory or (show_update and auto_check) then latest_version || '+' || latest_build::text
        else ''
      end,
    'latestBuild', latest_build,
    'apkUrl', apk_url,
    'minimumVersion',
      case
        when mandatory then coalesce(nullif(minimum_version, ''), latest_version || '+' || latest_build::text)
        else ''
      end,
    'notes', notes,
    'showUpdate', show_update,
    'autoCheck', auto_check,
    'mandatory', mandatory
  )
  from public.app_update_settings
  where id = 1;
$function$;

revoke all on function public.get_public_app_update() from public;
grant usage on schema public to anon, authenticated;
revoke execute on function public.get_public_app_update() from authenticated;
grant execute on function public.get_public_app_update() to anon;
