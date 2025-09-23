package com.example.flutter_alarm_manager_poc.alarmSoundService

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class AlarmSoundServiceImpl(private val context: Context) : AlarmSoundService {
    private var mediaPlayer: MediaPlayer? = null
    private val TAG = "AlarmSoundService"
    private lateinit var audioManager: AudioManager
    private var originalVolume: Int = 0
    private var maxVolume: Int = 0
    private var targetVolume: Int = 0
    private var methodChannel: MethodChannel? = null
    private var volumeMonitorJob: Job? = null
    private var isAlarmActive: Boolean = false
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var volumeCheckRunnable: Runnable? = null

    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Use STREAM_ALARM for reliable alarm sound even with screen off
        maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        targetVolume = maxVolume // Always target maximum volume
        Log.d(TAG, "AlarmSoundService initialized - Max: $maxVolume, Original: $originalVolume, Target: $targetVolume")
    }

    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        Log.d(TAG, "Method channel set")
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
                AudioManager.STREAM_ALARM,
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
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            Log.d(TAG, "Volume check - Current: $currentVolume, Target: $targetVolume")
            if (currentVolume != targetVolume) {
                Log.d(TAG, "Volume enforcement: restoring volume to $targetVolume (was: $currentVolume)")
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetVolume, 0)
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

    override fun forceMaxVolume() {
        Log.d(TAG, "Force max volume called")
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetVolume, 0)
        Log.d(TAG, "Forced volume to maximum: $targetVolume")
    }

    override fun startAlarmSound() {
        Log.d(TAG, "startAlarmSound called")
        try {
            // Stop any existing sound first
            stopAlarmSound()
            
            isAlarmActive = true
            Log.d(TAG, "Alarm is now active")
            
            // Save current volume and set to maximum
            originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, targetVolume, 0)
            Log.d(TAG, "Set volume to maximum: $targetVolume (was: $originalVolume)")
            
            // Request audio focus
            requestAudioFocus()
            
            // Start volume enforcement
            startVolumeEnforcement()
            
            // Create new MediaPlayer
            Log.d(TAG, "Creating MediaPlayer...")
            mediaPlayer = MediaPlayer().apply {
                // Use system default alarm tone with fallbacks
                val primary = Settings.System.DEFAULT_ALARM_ALERT_URI
                val fallback1 = Settings.System.DEFAULT_RINGTONE_URI
                val fallback2 = Settings.System.DEFAULT_NOTIFICATION_URI
                val soundUri: Uri = primary ?: fallback1 ?: fallback2
                Log.d(TAG, "Sound URI: $soundUri")
                setDataSource(context, soundUri)
                
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setAudioAttributes(audioAttributes)
                
                isLooping = true // Loop the alarm sound
                
                setOnPreparedListener {
                    Log.d(TAG, "MediaPlayer prepared successfully")
                    start()
                    Log.d(TAG, "MediaPlayer started")
                }
                
                setOnErrorListener { mp, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    true
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "MediaPlayer completed")
                }
                
                prepare()
            }
            Log.d(TAG, "Alarm sound started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting alarm sound: ${e.message}", e)
        }
    }

    override fun stopAlarmSound() {
        Log.d(TAG, "stopAlarmSound called")
        try {
            isAlarmActive = false
            Log.d(TAG, "Alarm is now inactive")
            
            stopVolumeEnforcement()
            abandonAudioFocus()
            
            mediaPlayer?.let { player ->
                Log.d(TAG, "Stopping MediaPlayer...")
                if (player.isPlaying) {
                    player.stop()
                    Log.d(TAG, "MediaPlayer stopped")
                }
                player.release()
                Log.d(TAG, "MediaPlayer released")
            }
            mediaPlayer = null
            
            // Restore original volume
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
            Log.d(TAG, "Restored volume to original: $originalVolume")
            
            Log.d(TAG, "Alarm sound stopped successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm sound: ${e.message}", e)
        }
    }
} 
