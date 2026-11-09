-- SAKINA Game Cloud v3: mixed Quran + general Islamic knowledge questions.
-- Safe additive migration: preserves the existing 1,000 Quran questions and player data.

-- Let the owner inspect all player progress through the security-invoker admin view.
drop policy if exists game_progress_owner_read on public.game_progress;
create policy game_progress_owner_read
  on public.game_progress for select to authenticated
  using (public.is_owner());

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

-- Seed a reviewed starter bank of general Islamic-knowledge questions.
-- ON CONFLICT DO NOTHING preserves any owner-edited version.
insert into public.game_questions
(id,surah_number,surah_name,ayah_number,full_ayah,hidden_word,options,correct_option,difficulty,level,recitation_audio,global_ayah_number,explanation,active,question_type,question_text,context_text,source_name,source_reference)
values
('islamic-001',0,'',0,'','','["ثلاثة","أربعة","خمسة","ستة"]'::jsonb,'خمسة','easy',1,NULL,NULL,'بُني الإسلام على خمس.',TRUE,'islamic','كم عدد أركان الإسلام؟','','صحيح البخاري وصحيح مسلم','حديث ابن عمر: بني الإسلام على خمس'),
('islamic-002',0,'',0,'','','["نوح عليه السلام","آدم عليه السلام","إبراهيم عليه السلام","إدريس عليه السلام"]'::jsonb,'آدم عليه السلام','easy',1,NULL,NULL,'آدم عليه السلام أبو البشر وأول الأنبياء.',TRUE,'islamic','من هو أول الأنبياء؟','','مصادر العقيدة والسيرة','قصة آدم عليه السلام؛ البقرة 2:31-37'),
('islamic-003',0,'',0,'','','["ميكائيل","إسرافيل","جبريل","ملك الموت"]'::jsonb,'جبريل','easy',1,NULL,NULL,'نزل جبريل عليه السلام بالقرآن على قلب النبي ﷺ.',TRUE,'islamic','ما اسم الملك الذي نزل بالوحي على النبي محمد ﷺ؟','','القرآن الكريم','البقرة 2:97؛ الشعراء 26:193-194'),
('islamic-004',0,'',0,'','','["الطائف","القدس","المدينة المنورة","خيبر"]'::jsonb,'المدينة المنورة','easy',1,NULL,NULL,'كانت الهجرة النبوية من مكة إلى يثرب التي عُرفت بالمدينة المنورة.',TRUE,'islamic','إلى أي مدينة هاجر النبي ﷺ من مكة؟','','السيرة النبوية','أحداث الهجرة النبوية'),
('islamic-005',0,'',0,'','','["يا أيها المدثر","اقرأ باسم ربك الذي خلق","الحمد لله رب العالمين","قل هو الله أحد"]'::jsonb,'اقرأ باسم ربك الذي خلق','easy',1,NULL,NULL,'بدأ نزول الوحي بأوائل سورة العلق.',TRUE,'islamic','ما أول ما نزل من القرآن على النبي ﷺ؟','','صحيح البخاري','كتاب بدء الوحي؛ العلق 96:1-5'),
('islamic-006',0,'',0,'','','["آل عمران","النساء","البقرة","المائدة"]'::jsonb,'البقرة','easy',2,NULL,NULL,'سورة البقرة هي أطول سور القرآن وعدد آياتها 286.',TRUE,'islamic','ما أطول سورة في القرآن الكريم؟','','المصحف الشريف','سورة البقرة'),
('islamic-007',0,'',0,'','','["110","112","114","116"]'::jsonb,'114','easy',2,NULL,NULL,'عدد سور القرآن الكريم 114 سورة.',TRUE,'islamic','كم عدد سور القرآن الكريم؟','','المصحف الشريف','ترتيب سور المصحف'),
('islamic-008',0,'',0,'','','["عائشة رضي الله عنها","حفصة رضي الله عنها","خديجة رضي الله عنها","زينب رضي الله عنها"]'::jsonb,'خديجة رضي الله عنها','easy',2,NULL,NULL,'خديجة بنت خويلد رضي الله عنها أول زوجات النبي ﷺ وأول من آمن به من النساء.',TRUE,'islamic','من هي أول زوجات النبي محمد ﷺ؟','','السيرة النبوية','سيرة ابن هشام؛ أحداث بدء الوحي'),
('islamic-009',0,'',0,'','','["عمر بن الخطاب","علي بن أبي طالب","أبو بكر الصديق","عثمان بن عفان"]'::jsonb,'أبو بكر الصديق','easy',2,NULL,NULL,'كان أبو بكر الصديق رضي الله عنه مع النبي ﷺ في الغار.',TRUE,'islamic','من الصحابي الذي صاحب النبي ﷺ في الغار أثناء الهجرة؟','','القرآن الكريم','التوبة 9:40؛ صحيح البخاري، كتاب فضائل أصحاب النبي'),
('islamic-010',0,'',0,'','','["شعبان","رمضان","شوال","محرم"]'::jsonb,'رمضان','easy',2,NULL,NULL,'فرض الله صيام شهر رمضان.',TRUE,'islamic','في أي شهر يصوم المسلمون صيام الفريضة؟','','القرآن الكريم','البقرة 2:183-185'),
('islamic-011',0,'',0,'','','["غار ثور","غار حراء","غار أحد","غار بدر"]'::jsonb,'غار حراء','medium',3,NULL,NULL,'كان النبي ﷺ يتعبد في غار حراء قبل نزول الوحي.',TRUE,'islamic','ما اسم الغار الذي نزل فيه أول الوحي؟','','صحيح البخاري','كتاب بدء الوحي'),
('islamic-012',0,'',0,'','','["أبو بكر الصديق","عمر بن الخطاب","عثمان بن عفان","علي بن أبي طالب"]'::jsonb,'عمر بن الخطاب','medium',3,NULL,NULL,'اشتهر عمر بن الخطاب رضي الله عنه بلقب الفاروق.',TRUE,'islamic','من الصحابي الملقب بالفاروق؟','','كتب السيرة والتراجم','ترجمة عمر بن الخطاب رضي الله عنه'),
('islamic-013',0,'',0,'','','["المسجد النبوي","المسجد الأقصى","الكعبة المشرفة","جبل عرفات"]'::jsonb,'الكعبة المشرفة','easy',3,NULL,NULL,'أُمر المسلمون بالتوجه شطر المسجد الحرام.',TRUE,'islamic','ما القبلة التي يتجه إليها المسلمون في الصلاة؟','','القرآن الكريم','البقرة 2:144'),
('islamic-014',0,'',0,'','','["الكهف","الإسراء","مريم","طه"]'::jsonb,'الإسراء','medium',3,NULL,NULL,'من أسماء سورة الإسراء: بني إسرائيل.',TRUE,'islamic','ما السورة التي تُسمى سورة بني إسرائيل؟','','علوم القرآن','أسماء سورة الإسراء في كتب التفسير'),
('islamic-015',0,'',0,'','','["يونس عليه السلام","أيوب عليه السلام","يوسف عليه السلام","هارون عليه السلام"]'::jsonb,'يونس عليه السلام','easy',3,NULL,NULL,'ذكر القرآن قصة ذي النون عليه السلام في بطن الحوت.',TRUE,'islamic','أي نبي ابتلعه الحوت؟','','القرآن الكريم','الأنبياء 21:87-88؛ الصافات 37:139-148'),
('islamic-016',0,'',0,'','','["ليلة النصف من شعبان","ليلة القدر","ليلة الإسراء","ليلة العيد"]'::jsonb,'ليلة القدر','easy',4,NULL,NULL,'ورد فضل ليلة القدر في سورة القدر.',TRUE,'islamic','ما اسم الليلة التي هي خير من ألف شهر؟','','القرآن الكريم','سورة القدر 97:1-3'),
('islamic-017',0,'',0,'','','["إسحاق عليه السلام","يعقوب عليه السلام","إبراهيم عليه السلام","لوط عليه السلام"]'::jsonb,'يعقوب عليه السلام','medium',4,NULL,NULL,'يوسف بن يعقوب بن إسحاق بن إبراهيم عليهم السلام.',TRUE,'islamic','ما اسم والد النبي يوسف عليه السلام؟','','القرآن الكريم','يوسف 12:4-6؛ الأنعام 6:84'),
('islamic-018',0,'',0,'','','["أحد","الخندق","بدر","حنين"]'::jsonb,'بدر','medium',4,NULL,NULL,'وقعت غزوة بدر الكبرى في رمضان من السنة الثانية للهجرة.',TRUE,'islamic','ما اسم المعركة التي وقعت في السنة الثانية للهجرة؟','','كتب السيرة النبوية','غزوة بدر الكبرى'),
('islamic-019',0,'',0,'','','["الأنفال","التوبة","يونس","هود"]'::jsonb,'التوبة','medium',4,NULL,NULL,'سورة التوبة هي السورة الوحيدة التي لا تبدأ بالبسملة في المصحف.',TRUE,'islamic','ما اسم السورة التي لا تبدأ بالبسملة؟','','المصحف الشريف','بداية سورة التوبة'),
('islamic-020',0,'',0,'','','["عيسى عليه السلام","موسى عليه السلام","إبراهيم عليه السلام","داود عليه السلام"]'::jsonb,'موسى عليه السلام','medium',4,NULL,NULL,'وصف القرآن موسى عليه السلام بأن الله كلمه تكليمًا.',TRUE,'islamic','من النبي الذي كلمه الله تكليمًا؟','','القرآن الكريم','النساء 4:164'),
('islamic-021',0,'',0,'','','["بلال بن رباح","علي بن أبي طالب","زيد بن حارثة","عبد الرحمن بن عوف"]'::jsonb,'علي بن أبي طالب','medium',5,NULL,NULL,'بات علي بن أبي طالب رضي الله عنه في فراش النبي ﷺ ورد الأمانات إلى أهلها.',TRUE,'islamic','ما اسم الصحابي الذي نام في فراش النبي ﷺ ليلة الهجرة؟','','كتب السيرة النبوية','أحداث الهجرة النبوية'),
('islamic-022',0,'',0,'','','["النساء","مريم","المجادلة","التحريم"]'::jsonb,'مريم','easy',5,NULL,NULL,'سورة مريم سميت باسم مريم ابنة عمران عليها السلام.',TRUE,'islamic','ما السورة التي تحمل اسم امرأة؟','','المصحف الشريف','سورة مريم'),
('islamic-023',0,'',0,'','','["التوراة","الإنجيل","الزبور","الصحف"]'::jsonb,'الزبور','medium',5,NULL,NULL,'آتَى الله داود زبورًا.',TRUE,'islamic','ما اسم الكتاب الذي أُنزل على النبي داود عليه السلام؟','','القرآن الكريم','النساء 4:163؛ الإسراء 17:55'),
('islamic-024',0,'',0,'','','["عمران","زكريا","هارون","إلياس"]'::jsonb,'عمران','medium',5,NULL,NULL,'ورد اسم مريم بنت عمران في القرآن.',TRUE,'islamic','ما اسم والد مريم عليها السلام كما ورد في القرآن؟','','القرآن الكريم','آل عمران 3:35-36'),
('islamic-025',0,'',0,'','','["الدين النصيحة","إنما الأعمال بالنيات","من حسن إسلام المرء","لا يؤمن أحدكم"]'::jsonb,'إنما الأعمال بالنيات','medium',5,NULL,NULL,'حديث مشهور في الإخلاص والنية.',TRUE,'islamic','ما العبارة التي يبدأ بها حديث «إنما الأعمال بالنيات»؟','','صحيح البخاري وصحيح مسلم','حديث عمر بن الخطاب رضي الله عنه: إنما الأعمال بالنيات')
on conflict (id) do nothing;


-- Include collected game stars in the owner-only player analytics view.
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
  coalesce((gp.data->>'qgame_streak')::int, 0) as streak,
  coalesce((gp.data->>'qgame_total_stars')::int, 0) as stars
from public.game_progress gp
left join public.profiles p on p.id = gp.user_id;

grant select on public.game_admin_player_stats to authenticated;
