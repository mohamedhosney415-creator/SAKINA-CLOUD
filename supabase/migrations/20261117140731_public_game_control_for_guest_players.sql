grant select on public.app_control to anon, authenticated;
drop policy if exists app_control_read_anon on public.app_control;
create policy app_control_read_anon on public.app_control
  for select to anon using (true);
