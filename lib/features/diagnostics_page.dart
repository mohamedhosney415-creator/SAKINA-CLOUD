import 'package:flutter/material.dart';
import '../core/diag.dart';
import '../core/widgets.dart';

/// صفحة التشخيص: تعرض خطوات التشغيل وأي أخطاء، ويمكن نسخها وإرسالها للمطوّر.
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التشخيص')),
      body: ListenableBuilder(
        listenable: Diag.i,
        builder: (context, _) {
          final d = Diag.i;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => copyText(context, d.report()),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ التقرير كاملًا'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  d.errors.clear();
                  d.steps.clear();
                  d.ok('تم مسح السجل');
                },
                child: const Text('مسح'),
              ),
            ]),
            const SectionTitle('الأخطاء'),
            if (d.errors.isEmpty)
              const Panel(child: Text('لا توجد أخطاء مسجّلة ✅'))
            else
              for (final e in d.errors)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    color: Colors.red.withAlpha(20),
                    child: SelectableText(e, style: const TextStyle(fontSize: 12, height: 1.5)),
                  ),
                ),
            const SectionTitle('خطوات التشغيل'),
            Panel(
              child: SelectableText(d.steps.isEmpty ? '—' : d.steps.join('\n'),
                  style: const TextStyle(fontSize: 12.5, height: 1.8)),
            ),
          ]);
        },
      ),
    );
  }
}
