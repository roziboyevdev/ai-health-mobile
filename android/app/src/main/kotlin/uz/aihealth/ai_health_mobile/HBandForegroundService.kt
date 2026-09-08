package uz.aihealth.ai_health_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.veepoo.protocol.VPOperateManager

class HBandForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        VPOperateManager.getInstance().init(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel()
        val name = intent?.getStringExtra(EXTRA_DEVICE_NAME) ?: "smart band"
        startForeground(
            NOTIFICATION_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("AI Health is collecting bracelet data")
                .setContentText("Connected to $name")
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build(),
        )
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Bracelet sync",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    companion object {
        const val EXTRA_DEVICE_NAME = "device_name"
        private const val CHANNEL_ID = "ai_health_bracelet_sync"
        private const val NOTIFICATION_ID = 8101
    }
}
