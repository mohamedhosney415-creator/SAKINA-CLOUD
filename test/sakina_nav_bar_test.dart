import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/widgets.dart';

void main() {
  testWidgets('game navigation item is centered and selectable',
      (tester) async {
    var selected = -1;
    const items = <SakinaNavItem>[
      SakinaNavItem('الرئيسية', Icons.home_outlined, Icons.home),
      SakinaNavItem('الصلاة', Icons.access_time, Icons.access_time_filled),
      SakinaNavItem('اللعبة', Icons.sports_esports_outlined,
          Icons.sports_esports_rounded),
      SakinaNavItem('القرآن', Icons.menu_book_outlined, Icons.menu_book),
      SakinaNavItem('الأذكار', Icons.auto_awesome_outlined, Icons.auto_awesome),
      SakinaNavItem('المزيد', Icons.grid_view_outlined, Icons.grid_view),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: SakinaNavBar(
          index: 0,
          centerIndex: 2,
          items: items,
          onTap: (index) => selected = index,
        ),
      ),
    ));

    expect(items[2].label, 'اللعبة');
    final gameCenter = tester.getCenter(find.text('اللعبة'));
    final screenCenter =
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
    expect(gameCenter.dx, closeTo(screenCenter, 1));
    await tester.tap(find.text('اللعبة'));
    expect(selected, 2);
  });
}
