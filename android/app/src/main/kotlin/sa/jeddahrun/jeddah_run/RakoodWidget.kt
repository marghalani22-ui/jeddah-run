package sa.jeddahrun.jeddah_run

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/**
 * Home-screen widget: Rakood's face and a Hijazi line that follow the runner's streak.
 * The app stores lastRunMs / streak / weekKm / goalKm; the mood is worked out here
 * so it keeps changing through the day even when the app is closed.
 */
class RakoodWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val lastRun = widgetData.getLong("lastRunMs", 0L)
        val streak = widgetData.getInt("streak", 0)
        val weekKm = widgetData.getString("weekKm", "0") ?: "0"
        val goalKm = widgetData.getInt("goalKm", 20)

        val now = Calendar.getInstance()
        val hour = now.get(Calendar.HOUR_OF_DAY)
        val daysSince = if (lastRun == 0L) 99 else dayIndex(now.timeInMillis) - dayIndex(lastRun)

        val (mood, line) = when {
            daysSince == 0 && streak >= 3 -> "hype" to "إنت مرّة جامد! $streak أيام ورا بعض"
            daysSince == 0 -> "happy" to "إيوه كدا! جولة اليوم تمّت"
            daysSince == 1 && hour < 18 -> "waiting" to "جولة اليوم؟ أنا جاهز"
            daysSince == 1 -> "worried" to (if (streak > 0) "فينك؟ لا تقطع سلسلة $streak أيام" else "باقي وقت، يلا جولة خفيفة")
            daysSince <= 3 -> "sad" to "وحشتني الجولات… نرجع بكرة؟"
            else -> "sleepy" to "وحشتنا! جولة وحدة ونرجع"
        }
        val face = when (mood) {
            "hype" -> R.drawable.rakood_hype
            "happy" -> R.drawable.rakood_happy
            "waiting" -> R.drawable.rakood_waiting
            "worried" -> R.drawable.rakood_worried
            "sad" -> R.drawable.rakood_sad
            else -> R.drawable.rakood_sleepy
        }
        val night = mood == "sad" || mood == "sleepy" || hour >= 19 || hour < 5

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.rakood_widget).apply {
                setImageViewResource(R.id.widget_face, face)
                setTextViewText(R.id.widget_line, line)
                setTextViewText(R.id.widget_sub, "هالأسبوع $weekKm من $goalKm كم")
                setInt(R.id.widget_root, "setBackgroundResource", if (night) R.drawable.widget_bg_night else R.drawable.widget_bg_day)
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun dayIndex(ms: Long): Int {
        val c = Calendar.getInstance().apply { timeInMillis = ms }
        return c.get(Calendar.YEAR) * 400 + c.get(Calendar.DAY_OF_YEAR)
    }
}
