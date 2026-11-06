import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// سجل تشخيص: يلتقط أي خطأ أثناء التشغيل ويعرضه بدل أن يغلق التطبيق بصمت.
class Diag extends ChangeNotifier {
  static final Diag i = Diag._();
  Diag._();

  final List<String> steps = [];
  final List<String> errors = [];

  static String _t() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  void _notify() => Future.microtask(notifyListeners);

  void ok(String step) {
    steps.add('${_t()}  ✓  $step');
    _notify();
  }

  void error(String tag, Object e, [StackTrace? st]) {
    final trace = (st?.toString() ?? '').split('\n').take(8).join('\n');
    errors.add('[${_t()}] $tag\n$e${trace.isEmpty ? '' : '\n$trace'}');
    if (errors.length > 60) errors.removeAt(0);
    _notify();
  }

  String report() => 'SAKINA diagnostics\n\n'
      '--- الخطوات ---\n${steps.join('\n')}\n\n'
      '--- الأخطاء (${errors.length}) ---\n${errors.join('\n\n')}';

  /// ينفّذ خطوة تهيئة بأمان: أي خطأ يُسجَّل ولا يوقف التطبيق.
  static Future<T?> guard<T>(String tag, Future<T> Function() f) async {
    try {
      final r = await f();
      i.ok(tag);
      return r;
    } catch (e, s) {
      i.error(tag, e, s);
      return null;
    }
  }

  static void install() {
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      i.error('FlutterError', details.exceptionAsString(), details.stack);
      prev?.call(details);
    };
    PlatformDispatcher.instance.onError = (e, s) {
      i.error('Uncaught', e, s);
      return true;
    };
    ErrorWidget.builder = (details) => _ErrorBox(details);
  }
}

class _ErrorBox extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorBox(this.details);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0x33FF9800),
        child: SingleChildScrollView(
          child: Text(
            'تعذّر عرض هذا الجزء.\n${details.exceptionAsString()}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A3B00)),
          ),
        ),
      ),
    );
  }
}
