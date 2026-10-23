package sa.jeddahrun.jeddah_run

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

// FragmentActivity is required by Health Connect's permission screen.
class MainActivity : FlutterFragmentActivity() {
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "laffa/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "batteryOk" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "openAppSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(true)
                }
                "stepsAvailable" -> result.success(Steps.available(this))
                "stepsGranted" -> result.success(Steps.granted(this))
                "stepsRequest" -> {
                    if (Steps.granted(this)) {
                        result.success(true)
                    } else {
                        pendingPermission?.success(false)
                        pendingPermission = result
                        ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.ACTIVITY_RECOGNITION), 4701)
                    }
                }
                "stepsStart" -> {
                    (call.argument<Int>("goal"))?.let { Steps.setGoal(this, it) }
                    Steps.schedule(this)
                    result.success(true)
                }
                "stepsRead" -> thread {
                    val json = Steps.record(applicationContext, Steps.readCounter(applicationContext, 3000))
                    runOnUiThread { result.success(json) }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4701) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }
}
