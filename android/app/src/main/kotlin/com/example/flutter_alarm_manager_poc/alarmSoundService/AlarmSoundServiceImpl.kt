package com.example.flutter_alarm_manager_poc.alarmSoundService

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.util.Log
import com.example.flutter_alarm_manager_poc.R

class AlarmSoundServiceImpl(private val context: Context) : AlarmSoundService {
    private var mediaPlayer: MediaPlayer? = null
    private val TAG = "AlarmSoundService"

    override fun startAlarmSound() {
        try {
            // Stop any existing sound first
            stopAlarmSound()
            
            // Create new MediaPlayer
            mediaPlayer = MediaPlayer().apply {
                val soundUri = Uri.parse("android.resource://" + context.packageName + "/" + R.raw.alarm)
                setDataSource(context, soundUri)
                
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setAudioAttributes(audioAttributes)
                
                isLooping = true // Loop the alarm sound
                prepare()
                start()
            }
            Log.d(TAG, "Alarm sound started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting alarm sound: ${e.message}")
        }
    }

    override fun stopAlarmSound() {
        try {
            mediaPlayer?.let { player ->
                if (player.isPlaying) {
                    player.stop()
                }
                player.release()
            }
            mediaPlayer = null
            Log.d(TAG, "Alarm sound stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm sound: ${e.message}")
        }
    }
} 