package {{PKG}}

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** ويدجت الصلاة يعمل من البيانات المحلية، مع وِرد الختمة عند توافره. */
class SakinaWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val entries = (widgetData.getString("upcoming", "") ?: "")
            .split(";")
            .mapNotNull { entry ->
                val fields = entry.split(",", limit = 2)
                val timestamp = if (fields.size == 2) fields[1].toLongOrNull() else null
                if (timestamp != null && fields[0].isNotBlank()) Pair(fields[0], timestamp) else null
            }
        val now = System.currentTimeMillis()
        val nextIndex = entries.indexOfFirst { it.second > now }
        val fmt = SimpleDateFormat("h:mm a", Locale("ar", "EG")).apply {
            timeZone = TimeZone.getTimeZone("Africa/Cairo")
        }
        val nameIds = intArrayOf(R.id.w_n0, R.id.w_n1, R.id.w_n2, R.id.w_n3, R.id.w_n4)
        val timeIds = intArrayOf(R.id.w_t0, R.id.w_t1, R.id.w_t2, R.id.w_t3, R.id.w_t4)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.sakina_widget)
            views.setTextViewText(R.id.w_hijri, widgetData.getString("hijri", "") ?: "")
            views.setTextViewText(R.id.w_city, widgetData.getString("city", "") ?: "")
            if (nextIndex >= 0) {
                val next = entries[nextIndex]
                views.setTextViewText(R.id.w_next_name, "الصلاة القادمة: ${next.first}")
                val base = SystemClock.elapsedRealtime() + (next.second - now)
                views.setChronometer(R.id.w_chrono, base, null, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(R.id.w_chrono, true)
                }
                val dayStart = (nextIndex / 5) * 5
                for (k in 0 until 5) {
                    val prayer = entries.getOrNull(dayStart + k)
                    views.setTextViewText(nameIds[k], prayer?.first ?: "")
                    views.setTextViewText(timeIds[k], prayer?.let { fmt.format(Date(it.second)) } ?: "")
                }
            } else {
                views.setTextViewText(R.id.w_next_name, "افتح سكينة لتحديث المواقيت")
                views.setTextViewText(R.id.w_chrono, "")
                for (k in 0 until 5) {
                    views.setTextViewText(nameIds[k], "")
                    views.setTextViewText(timeIds[k], "")
                }
            }

            val wird = (widgetData.getString("wird_today", "") ?: "").split(",", limit = 2)
            val target = if (wird.size == 2) wird[0].toIntOrNull() else null
            val read = if (wird.size == 2) wird[1].toIntOrNull() else null
            if (target != null && read != null && target >= 0 && read >= 0) {
                views.setViewVisibility(R.id.w_wird, View.VISIBLE)
                views.setTextViewText(R.id.w_wird, "ورد اليوم: $target صفحة • قرأت $read")
            } else {
                views.setViewVisibility(R.id.w_wird, View.GONE)
            }

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.w_root, pi)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
        // تنبيه وحيد عند الصلاة القادمة؛ لا يوجد polling أو تحديث دوري كثيف.
        if (nextIndex >= 0) scheduleRefresh(context, appWidgetIds, entries[nextIndex].second + 2000)
        else cancelRefresh(context)
    }

    private fun scheduleRefresh(context: Context, ids: IntArray, at: Long) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, SakinaWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            val pending = PendingIntent.getBroadcast(
                context, 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC, at, pending)
            } else {
                am.set(AlarmManager.RTC, at, pending)
            }
        } catch (_: Exception) { }
    }

    private fun cancelRefresh(context: Context) {
        try {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, SakinaWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val pending = PendingIntent.getBroadcast(
                context, 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pending)
        } catch (_: Exception) { }
    }
}
