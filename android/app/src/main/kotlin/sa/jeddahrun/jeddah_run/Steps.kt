package sa.jeddahrun.jeddah_run

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Daily steps from the phone's hardware step counter.
 * The sensor counts since boot; we read it every ~15 min (and whenever the app
 * asks) and add the difference to today's total, so steps are counted even
 * while Laffa is closed.
 */
object Steps {
    private const val PREFS = "laffa_steps"
    private const val CHANNEL = "laffa_steps"

    fun available(ctx: Context): Boolean =
        (ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager).getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null

    fun granted(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < 29 ||
            ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Blocks up to [timeoutMs] for one reading of the cumulative counter. Call off the main thread. */
    fun readCounter(ctx: Context, timeoutMs: Long = 6000): Float? {
        if (!granted(ctx)) return null
        val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return null
        val latch = CountDownLatch(1)
        var value: Float? = null
        val l = object : SensorEventListener {
            override fun onSensorChanged(e: SensorEvent) {
                value = e.values[0]
                latch.countDown()
            }
            override fun onAccuracyChanged(s: Sensor?, a: Int) {}
        }
        val thread = android.os.HandlerThread("laffa-steps").apply { start() }
        sm.registerListener(l, sensor, SensorManager.SENSOR_DELAY_NORMAL, 0, android.os.Handler(thread.looper))
        latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        sm.unregisterListener(l)
        thread.quitSafely()
        return value
    }

    /** Adds the steps since the last reading to today. Returns the days map as JSON. */
    @Synchronized
    fun record(ctx: Context, counter: Float?): String {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val days = JSONObject(p.getString("days", "{}") ?: "{}")
        if (counter != null) {
            val last = p.getFloat("last", -1f)
            val delta = when {
                last < 0 -> 0f // first reading is the baseline
                counter < last -> counter // phone restarted, counter began again from 0
                else -> counter - last
            }
            val day = today()
            val total = days.optInt(day) + delta.toInt()
            days.put(day, total)
            // Keep about two months.
            val keys = days.keys().asSequence().toList().sorted()
            if (keys.size > 62) keys.take(keys.size - 62).forEach { days.remove(it) }
            p.edit().putFloat("last", counter).putString("days", days.toString()).apply()
            maybeNotify(ctx, total)
        }
        return days.toString()
    }

    fun setGoal(ctx: Context, goal: Int) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt("goal", goal).apply()

    private fun maybeNotify(ctx: Context, total: Int) {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val goal = p.getInt("goal", 8000)
        val day = today()
        if (total < goal || p.getString("notified", "") == day) return
        p.edit().putString("notified", day).apply()
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "مهمة الخطوات", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(
            ctx, 7, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setContentTitle("خلّصت مهمة الخطوات! 👟")
            .setContentText("${"%,d".format(total)} خطوة اليوم. افتح لفّة واستلم نقاطك")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        nm.notify(77, n)
    }

    fun schedule(ctx: Context) {
        val req = PeriodicWorkRequestBuilder<StepWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(ctx).enqueueUniquePeriodicWork("laffa_steps", ExistingPeriodicWorkPolicy.KEEP, req)
    }
}

class StepWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        Steps.record(applicationContext, Steps.readCounter(applicationContext))
        return Result.success()
    }
}
