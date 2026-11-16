-- SAKINA game question schema extension.
-- Backward compatible: existing rows remain complete_word/quran questions.
alter table public.game_questions
  add column if not exists question_type text not null default 'complete_word',
  add column if not exists category text not null default 'quran',
  add column if not exists prompt text,
  add column if not exists xp integer not null default 10;

alter table public.game_questions
  drop constraint if exists game_questions_question_type_check;
alter table public.game_questions
  add constraint game_questions_question_type_check
  check (question_type in (
    'complete_word',
    'complete_verse',
    'identify_surah',
    'previous_next',
    'true_false',
    'mcq',
    'reorder',
    'speed_challenge'
  ));

alter table public.game_questions
  drop constraint if exists game_questions_category_check;
alter table public.game_questions
  add constraint game_questions_category_check
  check (category in (
    'quran',
    'seerah',
    'prophets',
    'companions',
    'hadith',
    'prayer',
    'fasting',
    'ramadan',
    'pillars',
    'azkar',
    'islamic_knowledge'
  ));

alter table public.game_questions
  drop constraint if exists game_questions_xp_check;
alter table public.game_questions
  add constraint game_questions_xp_check
  check (xp between 1 and 500);

create index if not exists game_questions_type_active_idx
  on public.game_questions(question_type, active);
create index if not exists game_questions_category_level_idx
  on public.game_questions(category, level);

-- Keep the existing RLS/security model. No service-role key is used by the app.
