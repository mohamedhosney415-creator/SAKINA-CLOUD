-- Track the app version last reported by each signed-in installation.
-- A user can write only their own row; owners can read all rows for the dashboard.
create table if not exists public.app_installs (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  app_version text not null,
  build_number integer not null default 0 check (build_number >= 0),
  platform text not null default 'android',
  last_seen_at timestamptz not null default now()
);

alter table public.app_installs enable row level security;

drop policy if exists app_installs_read_self_or_owner on public.app_installs;
create policy app_installs_read_self_or_owner
on public.app_installs
for select to authenticated
using (user_id = (select auth.uid()) or public.is_owner());

drop policy if exists app_installs_insert_self on public.app_installs;
create policy app_installs_insert_self
on public.app_installs
for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists app_installs_update_self on public.app_installs;
create policy app_installs_update_self
on public.app_installs
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

revoke all on table public.app_installs from anon;
grant select, insert, update on table public.app_installs to authenticated;
