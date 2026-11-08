import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'calendar_page.dart';
import 'challenges_page.dart';
import 'daily_assistant_page.dart';
import 'favorites_page.dart';
import 'hadith_page.dart';
import 'khatma_page.dart';
import 'noor_page.dart';
import 'qibla_page.dart';
import 'quran_journey_page.dart';
import 'quran_page.dart';
import 'quran_search_page.dart';
import 'ramadan_page.dart';
import 'settings_page.dart';
import 'tasbeeh_page.dart';

class _MoreItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;
  const _MoreItem(this.title, this.subtitle, this.icon, this.page);
}

class _MoreGroup {
  final String title;
  final List<_MoreItem> items;
  const _MoreGroup(this.title, this.items);
}

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_MoreGroup> _groups() => [
        _MoreGroup('القرآن والمكتبة', [
          _MoreItem('القرآن الكريم', 'قراءة السور والاستماع للتلاوات',
              Icons.menu_book_rounded, const QuranPage(standalone: true)),
          _MoreItem('البحث في القرآن', 'ابحث بكلمة أو جزء من آية',
              Icons.manage_search_rounded, const QuranSearchPage()),
          _MoreItem('رحلتي مع القرآن', 'أيام القراءة والسور التي زرتها',
              Icons.auto_stories_rounded, const QuranJourneyPage()),
          _MoreItem('مساعد الختمة', 'خطة ورد يومي ومتابعة الإنجاز',
              Icons.flag_rounded, const KhatmaPage()),
          _MoreItem('المفضلة', 'الآيات والأذكار والمحتوى المحفوظ',
              Icons.favorite_rounded, const FavoritesPage()),
        ]),
        _MoreGroup('العبادة اليومية', [
          _MoreItem('مساعد سكينة اليومي', 'برنامج القرآن والأذكار والتسبيح',
              Icons.today_rounded, const DailyAssistantPage()),
          _MoreItem('تحديات سكينة', 'تحديات اختيارية للاستمرار',
              Icons.emoji_events_rounded, const ChallengesPage()),
          _MoreItem('المسبحة الإلكترونية', 'عداد وإحصائيات التسبيح',
              Icons.touch_app_rounded, const TasbeehPage()),
          _MoreItem('نور يومك', 'حديث أو حكمة ومحتوى يومي',
              Icons.wb_twilight_rounded, const NoorPage()),
          _MoreItem('الأحاديث النبوية', 'الأحاديث مع المصدر والدرجة',
              Icons.format_quote_rounded, const HadithPage()),
        ]),
        _MoreGroup('الأدوات والتقويم', [
          _MoreItem('القبلة', 'بوصلة اتجاه القبلة',
              Icons.explore_rounded, const QiblaPage()),
          _MoreItem('التقويم الإسلامي', 'المناسبات والأيام المباركة',
              Icons.calendar_month_rounded, const CalendarPage()),
          _MoreItem('رمضان والصيام', 'الإمساكية والصيام والقضاء',
              Icons.dark_mode_rounded, const RamadanPage()),
        ]),
        _MoreGroup('الحساب والتطبيق', [
          _MoreItem('حساب سكينة', 'تسجيل الدخول والمزامنة السحابية',
              Icons.account_circle_rounded, const AccountPage()),
          _MoreItem('الإعدادات', 'الأذان والمدينة والمظهر والنسخ الاحتياطي',
              Icons.settings_rounded, const SettingsPage()),
          _MoreItem('عن التطبيق', 'معلومات الإصدار والمصادر',
              Icons.info_rounded, const AboutPage()),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final groups = _groups()
        .map((group) => _MoreGroup(
              group.title,
              group.items
                  .where((item) => query.trim().isEmpty ||
                      item.title.contains(query.trim()) ||
                      item.subtitle.contains(query.trim()))
                  .toList(),
            ))
        .where((group) => group.items.isNotEmpty)
        .toList();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
      const Text('اكتشف سكينة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('كل أدواتك ومحتواك في مكان واحد',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(155))),
      const SizedBox(height: 16),
      TextField(
        controller: _search,
        onChanged: (value) => setState(() => query = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'ابحث عن أداة أو قسم',
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    _search.clear();
                    setState(() => query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: 8),
      if (groups.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: EmptyState(icon: Icons.search_off_rounded, text: 'ما لقيناش قسمًا بهذا الاسم.'),
        )
      else
        for (final group in groups) ...[
          SectionTitle(group.title),
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Panel(
                onTap: () => go(context, item.page),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  SakinaIconBadge(icon: item.icon, size: 46, iconSize: 23, semanticLabel: item.title),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(item.subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                    ]),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: goldDeep),
                ]),
              ),
            ),
        ],
      const DeveloperSignature(),
    ]);
  }
}
