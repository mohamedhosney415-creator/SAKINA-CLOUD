-- App version reporting and owner-controlled update settings.
-- The owner-only policies rely on public.is_owner() from the base schema.

create table if not exists public.app_installs (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  app_version text not null,
  build_number integer not null default 0 check (build_number >= 0),
  platform text not null default 'android',
  last_seen_at timestamptz not null default now()
);

alter table public.app_installs enable row level security;

drop policy if exists app_installs_insert_self on public.app_installs;
create policy app_installs_insert_self
on public.app_installs for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists app_installs_read_self_or_owner on public.app_installs;
create policy app_installs_read_self_or_owner
on public.app_installs for select
to authenticated
using (user_id = auth.uid() or public.is_owner());

drop policy if exists app_installs_update_self on public.app_installs;
create policy app_installs_update_self
on public.app_installs for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

revoke all on public.app_installs from anon;
grant select, insert, update on public.app_installs to authenticated;

create table if not exists public.app_update_settings (
  id smallint primary key default 1 check (id = 1),
  latest_version text not null default '4.9.2',
  latest_build integer not null default 19 check (latest_build >= 0),
  apk_url text not null default 'https://github.com/mohamedhosney415-creator/SAKINA-CLOUD/releases/latest/download/app-release.apk',
  notes text not null default '',
  show_update boolean not null default false,
  auto_check boolean not null default true,
  mandatory boolean not null default false,
  minimum_version text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table public.app_update_settings enable row level security;

drop policy if exists app_update_settings_read_authenticated on public.app_update_settings;
create policy app_update_settings_read_authenticated
on public.app_update_settings for select
to authenticated
using (true);

drop policy if exists app_update_settings_insert_owner on public.app_update_settings;
create policy app_update_settings_insert_owner
on public.app_update_settings for insert
to authenticated
with check (public.is_owner());

drop policy if exists app_update_settings_update_owner on public.app_update_settings;
create policy app_update_settings_update_owner
on public.app_update_settings for update
to authenticated
using (public.is_owner())
with check (public.is_owner());

revoke all on public.app_update_settings from anon;
grant select, insert, update on public.app_update_settings to authenticated;

insert into public.app_update_settings (
  id, latest_version, latest_build, apk_url, notes,
  show_update, auto_check, mandatory, minimum_version
)
values (
  1, '4.9.2', 19,
  'https://github.com/mohamedhosney415-creator/SAKINA-CLOUD/releases/latest/download/app-release.apk',
  'تنبيه قبل التثبيت: افتح المزيد ثم حساب سَكِينَة واضغط مزامنة بياناتي إلى السحابة. بعد نجاح المزامنة احذف النسخة القديمة إذا رفض أندرويد التحديث، ثم ثبت الجديدة وسجل الدخول لاسترجاع بياناتك.',
  false, true, false, null
)
on conflict (id) do nothing;
