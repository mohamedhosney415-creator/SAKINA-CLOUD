-- SAKINA Game Cloud v3: mixed Quran + general Islamic knowledge questions.
-- Safe additive migration: preserves the existing 1,000 Quran questions and player data.

alter table public.game_questions
  add column if not exists question_type text not null default 'quran',
  add column if not exists question_text text not null default '',
  add column if not exists context_text text not null default '',
  add column if not exists source_name text not null default '',
  add column if not exists source_reference text not null default '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'game_questions_question_type_check'
      and conrelid = 'public.game_questions'::regclass
  ) then
    alter table public.game_questions
      add constraint game_questions_question_type_check
      check (question_type in ('quran', 'islamic'));
  end if;
end $$;

create index if not exists game_questions_type_level_active_idx
  on public.game_questions(question_type, level, active);

-- Owner-controlled question mix. Default is an even split.
create table if not exists public.game_settings (
  setting_key text primary key,
  setting_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table public.game_settings enable row level security;
drop policy if exists game_settings_read on public.game_settings;
create policy game_settings_read
  on public.game_settings for select to authenticated
  using (true);

drop policy if exists game_settings_owner_write on public.game_settings;
create policy game_settings_owner_write
  on public.game_settings for all to authenticated
  using (public.is_owner())
  with check (public.is_owner());

revoke all on public.game_settings from anon;
grant select on public.game_settings to authenticated;
grant insert, update, delete on public.game_settings to authenticated;

insert into public.game_settings(setting_key, setting_value)
values ('question_mix', '{"quran_percent":50,"islamic_percent":50}'::jsonb)
on conflict (setting_key) do nothing;

-- Existing rows remain Quran questions. The new fields are populated only
-- for new/edited knowledge questions; no old verse text is rewritten.
