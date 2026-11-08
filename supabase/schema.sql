-- SAKINA 3.2.1 Cloud: safe migration for the database already created.
-- Preserves existing tables and user data. Do NOT drop the public schema.

-- 1) Bring the existing profiles table up to the columns expected by Flutter.
alter table public.profiles
  add column if not exists email text,
  add column if not exists role text not null default 'user'
    check (role in ('user', 'owner')),
  add column if not exists last_seen_at timestamptz;

-- 2) Cloud sync stores each account's app data as one JSON document.
create table if not exists public.user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- 3) Owner check used by the read-only admin user list.
create or replace function public.is_owner()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'owner'
  );
$$;

grant execute on function public.is_owner() to authenticated;

-- 4) Remove earlier policies that would let a user change their own role.
drop policy if exists profiles_own_data on public.profiles;
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_insert on public.profiles;
drop policy if exists profiles_update on public.profiles;
drop policy if exists profiles_self on public.profiles;
drop policy if exists profiles_owner_all on public.profiles;
drop policy if exists profiles_read_self_or_owner on public.profiles;
drop policy if exists profiles_update_self on public.profiles;

alter table public.profiles enable row level security;

-- A user sees only their own profile; the owner can see the user directory.
create policy profiles_read_self_or_owner
on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_owner());

-- The app may update last_seen_at/email only (column grants below prevent role edits).
create policy profiles_update_self
on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

revoke all on table public.profiles from anon;
revoke insert, delete, update on table public.profiles from authenticated;
grant select on table public.profiles to authenticated;
grant update (email, last_seen_at) on table public.profiles to authenticated;

-- 5) Each signed-in user can access only their own cloud sync document.
alter table public.user_data enable row level security;
drop policy if exists user_data_self on public.user_data;
drop policy if exists user_data_own on public.user_data;
create policy user_data_self
on public.user_data
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

revoke all on table public.user_data from anon;
grant select, insert, update, delete on table public.user_data to authenticated;

-- 6) Keep the existing profile-creation trigger, but make it fill the new fields.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'display_name', '')
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- 7) Backfill profiles for accounts that existed before this migration.
insert into public.profiles (id, email, display_name)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data ->> 'display_name', '')
from auth.users u
on conflict (id) do update
  set email = excluded.email;

-- OWNER SETUP (run separately AFTER you create your account in the app):
-- update public.profiles set role = 'owner' where email = 'YOUR_EMAIL@example.com';
