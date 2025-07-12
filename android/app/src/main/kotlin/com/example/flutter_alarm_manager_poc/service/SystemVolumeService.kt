package com.example.flutter_alarm_manager_poc.service

import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class SystemVolumeService : Service(), SensorEventListener {
    private val TAG = "SystemVolumeService"
    
    private lateinit var audioManager: AudioManager
    private lateinit var sensorManager: SensorManager
    private var proximitySensor: Sensor? = null
    private lateinit var powerManager: PowerManager
    private lateinit var wakeLock: PowerManager.WakeLock
    
    private var originalVolume: Int = 0
    private var maxVolume: Int = 0
    private var isProximityNear = false
    private val keepMaxVolume = AtomicBoolean(false)
    private var volumeThread: Thread? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "SystemVolumeService created")
        
        // Initialize audio manager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        
        Log.d(TAG, "Audio settings - Max volume: $maxVolume, Original volume: $originalVolume")
        
        // Initialize proximity sensor
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        proximitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        
        if (proximitySensor != null) {
            Log.d(TAG, "Proximity sensor found - Max range: ${proximitySensor!!.maximumRange}")
        } else {
            Log.w(TAG, "Proximity sensor not available")
        }
        
        // Initialize power manager and wake lock
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SystemVolumeService::WakeLock"
        )
        
        // Acquire wake lock to keep service running
        wakeLock.acquire()
        Log.d(TAG, "Wake lock acquired")
        
        // Start proximity sensor
        proximitySensor?.let { sensor ->
            val success = sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            if (success) {
                Log.d(TAG, "Proximity sensor registered successfully")
            } else {
                Log.e(TAG, "Failed to register proximity sensor")
            }
        } ?: run {
            Log.w(TAG, "Proximity sensor not available")
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "SystemVolumeService started with startId: $startId")
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "SystemVolumeService destroyed")
        
        // Stop volume thread
        keepMaxVolume.set(false)
        volumeThread?.interrupt()
        volumeThread = null
        
        // Release wake lock
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
        
        // Unregister sensor listener
        sensorManager.unregisterListener(this)
        
        // Restore original volume
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, originalVolume, 0)
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_PROXIMITY) {
            val distance = event.values[0]
            val isNear = distance < (proximitySensor?.maximumRange ?: 0f)
            
            Log.d(TAG, "Proximity sensor - Distance: $distance, Max range: ${proximitySensor?.maximumRange}, Is near: $isNear, Was near: $isProximityNear")
            
            if (isNear != isProximityNear) {
                isProximityNear = isNear
                Log.d(TAG, "Proximity state changed to: $isNear")
                
                if (isNear) {
                    // Phone is pressed/covered - start volume loop to maximum
                    keepMaxVolume.set(true)
                    startVolumeLoop()
                    Log.d(TAG, "Started volume loop to maximum")
                } else {
                    // Phone is uncovered - stop volume loop and restore original volume
                    keepMaxVolume.set(false)
                    stopVolumeLoop()
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    Log.d(TAG, "Phone released - Current volume: $currentVolume, Restoring to original: $originalVolume")
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, originalVolume, 0)
                    Log.d(TAG, "Volume restored to original: $originalVolume")
                }
            }
        }
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not needed for proximity sensor
    }
    
    private fun startVolumeLoop() {
        // Stop existing thread if running
        stopVolumeLoop()
        
        volumeThread = Thread {
            Log.d(TAG, "Volume loop thread started")
            while (keepMaxVolume.get()) {
                try {
                    val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    if (currentVolume < maxVolume) {
                        Log.d(TAG, "Forcing system volume to maximum: $maxVolume (was: $currentVolume)")
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVolume, 0)
                    }
                    Thread.sleep(1000) // Check every second
                } catch (e: InterruptedException) {
                    Log.d(TAG, "Volume loop thread interrupted")
                    break
                } catch (e: Exception) {
                    Log.e(TAG, "Error in volume loop: ${e.message}")
                }
            }
            Log.d(TAG, "Volume loop thread stopped")
        }.apply {
            name = "SystemVolumeLoop"
            start()
        }
    }
    
    private fun stopVolumeLoop() {
        volumeThread?.let { thread ->
            if (thread.isAlive) {
                thread.interrupt()
                try {
                    thread.join(1000) // Wait up to 1 second for thread to stop
                } catch (e: InterruptedException) {
                    Log.w(TAG, "Interrupted while waiting for volume thread to stop")
                }
            }
        }
        volumeThread = null
    }
    
    companion object {
        fun startService(context: Context) {
            val intent = Intent(context, SystemVolumeService::class.java)
            context.startService(intent)
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, SystemVolumeService::class.java)
            context.stopService(intent)
        }
    }
} 