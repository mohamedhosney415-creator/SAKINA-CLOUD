-- SAKINA security hardening for game/content tables.
-- Safe to re-run. Uses the existing profiles.role + is_owner() model.

alter table if exists public.game_questions enable row level security;
alter table if exists public.game_progress enable row level security;
alter table if exists public.game_events enable row level security;
alter table if exists public.game_question_history enable row level security;
alter table if exists public.game_daily_challenges enable row level security;

drop policy if exists game_questions_public_read on public.game_questions;
create policy game_questions_public_read
on public.game_questions for select
to authenticated
using (active = true or public.is_owner());

drop policy if exists game_questions_owner_write on public.game_questions;
create policy game_questions_owner_write
on public.game_questions for all
to authenticated
using (public.is_owner())
with check (public.is_owner());

drop policy if exists game_progress_self on public.game_progress;
create policy game_progress_self
on public.game_progress for all
to authenticated
using (user_id = auth.uid() or public.is_owner())
with check (user_id = auth.uid() or public.is_owner());

drop policy if exists game_events_self_insert on public.game_events;
create policy game_events_self_insert
on public.game_events for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists game_events_owner_read on public.game_events;
create policy game_events_owner_read
on public.game_events for select
to authenticated
using (user_id = auth.uid() or public.is_owner());

drop policy if exists game_question_history_self on public.game_question_history;
create policy game_question_history_self
on public.game_question_history for all
to authenticated
using (user_id = auth.uid() or public.is_owner())
with check (user_id = auth.uid() or public.is_owner());

drop policy if exists game_daily_challenges_public_read on public.game_daily_challenges;
create policy game_daily_challenges_public_read
on public.game_daily_challenges for select
to authenticated
using (active = true or public.is_owner());

drop policy if exists game_daily_challenges_owner_write on public.game_daily_challenges;
create policy game_daily_challenges_owner_write
on public.game_daily_challenges for all
to authenticated
using (public.is_owner())
with check (public.is_owner());

-- Never expose service_role_key in Flutter. The app only uses the publishable key.
