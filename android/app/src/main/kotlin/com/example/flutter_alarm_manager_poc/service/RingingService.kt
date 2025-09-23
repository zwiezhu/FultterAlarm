package com.example.flutter_alarm_manager_poc.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.flutter_alarm_manager_poc.R
import com.example.flutter_alarm_manager_poc.activity.AlarmActivity

class RingingService : Service() {
    companion object {
        const val ACTION_START_RING = "com.example.flutter_alarm_manager_poc.action.START_RING"
        const val ACTION_PAUSE_RING = "com.example.flutter_alarm_manager_poc.action.PAUSE_RING"
        const val ACTION_RESUME_RING = "com.example.flutter_alarm_manager_poc.action.RESUME_RING"
        const val ACTION_STOP_SERVICE = "com.example.flutter_alarm_manager_poc.action.STOP_SERVICE"

        const val EXTRA_ALARM_ID = "ALARM_ID"
        const val EXTRA_ALARM_MESSAGE = "ALARM_MESSAGE"
        const val EXTRA_ALARM_GAME_TYPE = "ALARM_GAME_TYPE"
        const val EXTRA_ALARM_DURATION_MIN = "ALARM_DURATION_MINUTES"

        private const val CHANNEL_ID = "alarm_channel"
        private const val NOTIF_ID = 10001
    }

    private val TAG = "RingingService"

    private var mediaPlayer: MediaPlayer? = null
    private lateinit var audioManager: AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var volumeRunnable: Runnable? = null
    private var volumeGuardActive: Boolean = false

    private var originalVolume: Int = -1
    private var maxVolume: Int = 0
    private var targetVolume: Int = 0
    private var isRinging: Boolean = false

    private var alarmId: Int = 1
    private var alarmMessage: String = "Alarm!"
    private var gameType: String = "piano_tiles"
    private var durationMinutes: Int = 1

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createChannelIfNeeded()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_RING -> {
                Log.d(TAG, "ACTION_START_RING received")
                readAlarmExtras(intent)
                startForeground(NOTIF_ID, buildNotification())
                startRinging()
                startVolumeEnforcement()
                wakeAndLaunchActivity()
            }
            ACTION_RESUME_RING -> {
                Log.d(TAG, "ACTION_RESUME_RING received")
                startRinging()
                startVolumeEnforcement()
            }
            ACTION_PAUSE_RING -> {
                Log.d(TAG, "ACTION_PAUSE_RING received")
                pauseRinging()
                stopVolumeEnforcement()
            }
            ACTION_STOP_SERVICE -> {
                Log.d(TAG, "ACTION_STOP_SERVICE received")
                stopRinging()
                stopVolumeEnforcement()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                if (!isRinging) {
                    startForeground(NOTIF_ID, buildNotification())
                }
            }
        }
        return START_STICKY
    }

    private fun readAlarmExtras(intent: Intent) {
        alarmId = intent.getIntExtra(EXTRA_ALARM_ID, 1)
        alarmMessage = intent.getStringExtra(EXTRA_ALARM_MESSAGE) ?: "Alarm!"
        gameType = intent.getStringExtra(EXTRA_ALARM_GAME_TYPE) ?: "piano_tiles"
        durationMinutes = intent.getIntExtra(EXTRA_ALARM_DURATION_MIN, 1)
    }

    private fun createFullScreenIntent(): PendingIntent {
        val fullScreenIntent = Intent(this, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_ALARM_MESSAGE, alarmMessage)
            putExtra(EXTRA_ALARM_GAME_TYPE, gameType)
            putExtra(EXTRA_ALARM_DURATION_MIN, durationMinutes)
            putExtra("ALARM_TIME", System.currentTimeMillis())
        }
        return PendingIntent.getActivity(
            this,
            alarmId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildNotification(): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_bell)
            .setContentTitle("Alarm")
            .setContentText(alarmMessage)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(createFullScreenIntent(), true)
            .setOngoing(true)
            .setAutoCancel(false)

        return builder.build().apply {
            // flags = flags or Notification.FLAG_INSISTENT or Notification.FLAG_NO_CLEAR
        }
    }

    private fun wakeAndLaunchActivity() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                pm.isInteractive
            } else {
                @Suppress("DEPRECATION")
                pm.isScreenOn
            }
            if (!isInteractive) {
                @Suppress("DEPRECATION")
                val wl = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                    "flutter_alarm_manager_poc:RingingWakelock"
                )
                wl.acquire(10_000)
                Log.d(TAG, "WakeLock acquired (10s) to show AlarmActivity")
            }
            val intent = Intent(this, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_ALARM_MESSAGE, alarmMessage)
                putExtra(EXTRA_ALARM_GAME_TYPE, gameType)
                putExtra(EXTRA_ALARM_DURATION_MIN, durationMinutes)
                putExtra("ALARM_TIME", System.currentTimeMillis())
            }
            startActivity(intent)
            Log.d(TAG, "AlarmActivity launched explicitly from RingingService")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to wake/launch activity: ${e.message}", e)
        }
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = nm.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Alarm Channel",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Channel for Alarm Notifications"
                    setBypassDnd(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    enableVibration(true)
                    // Keep channel silent; MediaPlayer handles sound
                    setSound(null, null)
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    private fun requestAudioFocus(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(audioAttributes)
                .build()
            audioManager.requestAudioFocus(focusRequest!!) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun startRinging() {
        if (isRinging) return
        if (!requestAudioFocus()) {
            Log.e(TAG, "Audio focus not granted")
        }
        try {
            // Build list of candidate URIs: system alarm, fallback to ringtone, then notification
            val candidates = listOfNotNull(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                Settings.System.DEFAULT_ALARM_ALERT_URI,
                Settings.System.DEFAULT_RINGTONE_URI,
                Settings.System.DEFAULT_NOTIFICATION_URI
            )

            mediaPlayer?.release()
            mediaPlayer = MediaPlayer()

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            mediaPlayer!!.setAudioAttributes(audioAttributes)
            mediaPlayer!!.isLooping = true

            var initialized = false
            for (uri in candidates) {
                try {
                    mediaPlayer!!.reset()
                    mediaPlayer!!.setDataSource(this@RingingService, uri)
                    mediaPlayer!!.setOnPreparedListener { mediaPlayer!!.start() }
                    mediaPlayer!!.prepare()
                    Log.d(TAG, "Using alarm sound URI: $uri")
                    initialized = true
                    break
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to init alarm sound URI $uri: ${e.message}")
                }
            }

            if (!initialized) {
                Log.e(TAG, "No valid alarm sound URI available; alarm will be silent")
                // Clean up player to avoid holding resources
                mediaPlayer?.release()
                mediaPlayer = null
                isRinging = false
                return
            }

            isRinging = true
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildNotification())
            Log.d(TAG, "Ringing started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting ringing: ${e.message}", e)
        }
    }

    private fun pauseRinging() {
        try {
            mediaPlayer?.let { mp ->
                if (mp.isPlaying) mp.pause()
            }
            isRinging = false
            Log.d(TAG, "Ringing paused")
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing ringing: ${e.message}", e)
        }
    }

    private fun stopRinging() {
        try {
            mediaPlayer?.let { mp ->
                if (mp.isPlaying) mp.stop()
                mp.release()
            }
            mediaPlayer = null
            isRinging = false
            abandonAudioFocus()
            if (originalVolume >= 0) {
                try {
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
                    Log.d(TAG, "Restored alarm volume to original: $originalVolume")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to restore volume: ${e.message}")
                }
                originalVolume = -1
            }
            Log.d(TAG, "Ringing stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping ringing: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        stopRinging()
        stopVolumeEnforcement()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startVolumeEnforcement() {
        try {
            maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            targetVolume = maxVolume
            if (originalVolume < 0) {
                originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                Log.d(TAG, "Captured original alarm volume: $originalVolume (max: $maxVolume)")
            }
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetVolume, 0)
            if (volumeGuardActive) return
            volumeGuardActive = true
            volumeRunnable = object : Runnable {
                override fun run() {
                    try {
                        val current = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                        if (current != targetVolume) {
                            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetVolume, 0)
                            Log.d(TAG, "Volume guard restored volume to max ($targetVolume), was: $current")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Volume guard error: ${e.message}")
                    }
                    if (volumeGuardActive) handler.postDelayed(this, 250L)
                }
            }
            handler.post(volumeRunnable!!)
            Log.d(TAG, "Volume enforcement started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start volume enforcement: ${e.message}")
        }
    }

    private fun stopVolumeEnforcement() {
        volumeGuardActive = false
        volumeRunnable?.let { handler.removeCallbacks(it) }
        volumeRunnable = null
        Log.d(TAG, "Volume enforcement stopped")
    }
}
