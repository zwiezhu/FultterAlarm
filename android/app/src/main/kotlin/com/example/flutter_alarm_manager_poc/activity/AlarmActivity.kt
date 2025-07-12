package com.example.flutter_alarm_manager_poc.activity

import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import com.example.flutter_alarm_manager_poc.alarmNotificationService.AlarmNotificationService
import com.example.flutter_alarm_manager_poc.alarmNotificationService.AlarmNotificationServiceImpl
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmScheduler
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmSchedulerImpl
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import com.example.flutter_alarm_manager_poc.screens.AlarmScreen

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel


class AlarmActivity : ComponentActivity() {
    private val ENGINE_ID = "alarm_manager_engine"
    private val CHANNEL = "com.example/alarm_manager"
    private val TAG = "AlarmActivity"
    private var flutterEngine: FlutterEngine? = null
    private var isNewEngineCreated = false // create new engine when app is closed and use existing when app is resumed state
    private lateinit var alarmNotificationService: AlarmNotificationService
    private lateinit var alarmScheduler: AlarmScheduler
    private lateinit var alarmSoundService: AlarmSoundService
    
    // Volume control
    private lateinit var audioManager: AudioManager
    private var originalVolume: Int = 0
    private var maxVolume: Int = 0
    private var targetVolume: Int = 0
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var volumeCheckRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        actionBar?.hide()

        val alarmId = intent.getIntExtra("ALARM_ID", -1)
        val alarmTime = intent.getLongExtra("ALARM_TIME", System.currentTimeMillis())

        // Initialize volume control
        initializeVolumeControl()

        alarmNotificationService = AlarmNotificationServiceImpl(this)
        alarmScheduler = AlarmSchedulerImpl(this)
        alarmSoundService = AlarmSoundServiceImpl(this)
        
        // Start alarm sound immediately when activity opens
        Log.d(TAG, "Starting alarm sound on activity creation")
        alarmSoundService.startAlarmSound()

        // Check if a cached engine is available
        flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)

        if (flutterEngine == null) {
            // If no cached engine is found (app was killed), create a new one
            Log.d(TAG, "Creating new Flutter engine")
            flutterEngine = FlutterEngine(this).apply {
                dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
            }
            // Optionally, cache this new engine if needed later
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
            isNewEngineCreated = true;
        } else {
            Log.d(TAG, "Using cached Flutter engine")
        }

        // Set up the MethodChannel
        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        
        // Set up method call handler for alarm sound control
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarmSound" -> {
                    Log.d(TAG, "Starting alarm sound from AlarmActivity")
                    alarmSoundService.startAlarmSound()
                    result.success(null)
                }
                "stopAlarmSound" -> {
                    Log.d(TAG, "Stopping alarm sound from AlarmActivity")
                    alarmSoundService.stopAlarmSound()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Set the content of the AlarmActivity using Jetpack Compose
        setContent {
            MaterialTheme {
                Surface(color = MaterialTheme.colorScheme.onSurface) {
                    AlarmScreen(
                        onPlay = {
                            Log.d(TAG, "Play button clicked")
                            // Stop alarm sound when user starts playing
                            alarmSoundService.stopAlarmSound()
                            channel.invokeMethod("alarmAccepted", null)
                            alarmNotificationService.cancelNotification(alarmId)
                            
                            // Pass alarm time and gameType through method channel and navigate
                            val alarmArgs = mapOf(
                                "alarmTime" to alarmTime,
                                "gameType" to "piano_tiles" // docelowo dynamicznie
                            )
                            channel.invokeMethod("navigateToAlarmGame", alarmArgs)
                            
                            // Create new Flutter engine with MethodChannel
                            val newEngine = FlutterEngine(this)
                            newEngine.navigationChannel.setInitialRoute("/alarm_game")
                            newEngine.dartExecutor.executeDartEntrypoint(
                                DartExecutor.DartEntrypoint.createDefault()
                            )
                            
                            // Register MethodChannel for alarm sound
                            MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL)
                                .setMethodCallHandler { call, result ->
                                    when (call.method) {
                                        "startAlarmSound" -> {
                                            Log.d(TAG, "Starting alarm sound from new engine")
                                            alarmSoundService.startAlarmSound()
                                            result.success(null)
                                        }
                                        "stopAlarmSound" -> {
                                            Log.d(TAG, "Stopping alarm sound from new engine")
                                            alarmSoundService.stopAlarmSound()
                                            result.success(null)
                                        }
                                        else -> result.notImplemented()
                                    }
                                }
                            
                            // Cache the engine FIRST
                            FlutterEngineCache.getInstance().put("alarm_game_engine", newEngine)
                            
                            // Then create the intent with cached engine
                            val intent = io.flutter.embedding.android.FlutterActivity
                                .withCachedEngine("alarm_game_engine")
                                .build(this)
                            
                            startActivity(intent)
                            // finish() // <- zakomentowane na czas testu
                        },
                        onSnooze = {
                            Log.d(TAG, "Snooze button clicked")
                            // Stop alarm sound when user snoozes
                            alarmSoundService.stopAlarmSound()
                            channel.invokeMethod("alarmSnoozed", null)
                            snoozeAlarm()
                            alarmNotificationService.cancelNotification(alarmId)
                            finish()
                        },
                        alarmTime = alarmTime
                    )
                }
            }
        }
    }

    private fun initializeVolumeControl() {
        Log.d(TAG, "Initializing volume control")
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        
        // Use STREAM_MUSIC for higher volume but with USAGE_ALARM attributes
        maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        targetVolume = maxVolume // Always target maximum volume
        
        Log.d(TAG, "Volume settings - Max: $maxVolume, Original: $originalVolume, Target: $targetVolume")
        
        // Request audio focus
        requestAudioFocus()
        
        // Start volume enforcement
        startVolumeEnforcement()
    }

    private fun requestAudioFocus() {
        Log.d(TAG, "Requesting audio focus...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(audioAttributes)
                .build()

            val result = audioManager.requestAudioFocus(focusRequest!!)
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "Audio focus request failed")
            } else {
                Log.d(TAG, "Audio focus granted")
            }
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "Audio focus request failed")
            } else {
                Log.d(TAG, "Audio focus granted")
            }
        }
    }

    private fun abandonAudioFocus() {
        Log.d(TAG, "Abandoning audio focus...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
                Log.d(TAG, "Audio focus abandoned")
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
            Log.d(TAG, "Audio focus abandoned")
        }
    }

    private fun startVolumeEnforcement() {
        Log.d(TAG, "Starting volume enforcement...")
        // Stop any existing enforcement
        stopVolumeEnforcement()
        
        // Define the Runnable that checks and enforces the volume level
        volumeCheckRunnable = Runnable {
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            Log.d(TAG, "Volume check - Current: $currentVolume, Target: $targetVolume")
            if (currentVolume != targetVolume) {
                Log.d(TAG, "Volume enforcement: restoring volume to $targetVolume (was: $currentVolume)")
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
            }
            // Schedule the next check after 1000ms
            handler.postDelayed(volumeCheckRunnable!!, 1000)
        }
        // Start the first run
        handler.post(volumeCheckRunnable!!)
        Log.d(TAG, "Volume enforcement started")
    }

    private fun stopVolumeEnforcement() {
        Log.d(TAG, "Stopping volume enforcement...")
        // Remove callbacks to stop enforcing volume
        volumeCheckRunnable?.let { handler.removeCallbacks(it) }
        volumeCheckRunnable = null
        Log.d(TAG, "Volume enforcement stopped")
    }

    private fun snoozeAlarm() {
        val alarmItem = AlarmItem(
            id = 1,
            message = "Alarm has been ringing"
        )
        alarmScheduler.schedule(alarmItem, 60)
    }

    override fun onDestroy() {
        super.onDestroy()

        // Stop volume enforcement and abandon audio focus
        stopVolumeEnforcement()
        abandonAudioFocus()
        
        // Restore original volume
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, originalVolume, 0)
        Log.d(TAG, "Restored volume to original: $originalVolume")

        // Only destroy the engine when the notification activity is launched from killed state
        // Do not kill the engine when the app is in running state otherwise it will lead to multiple flutter main-call stacks.
        if (isNewEngineCreated) {
            Log.d(TAG, "Destroying Flutter engine")
            flutterEngine?.destroy()
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
        }
    }
}
