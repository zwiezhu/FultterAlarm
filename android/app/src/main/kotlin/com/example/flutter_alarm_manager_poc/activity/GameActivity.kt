package com.example.flutter_alarm_manager_poc.activity

import android.os.Bundle
import android.content.Intent
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import com.example.flutter_alarm_manager_poc.screens.GameScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache

class GameActivity : ComponentActivity() {
    private val ENGINE_ID = "alarm_manager_engine"
    private val TAG = "GameActivity"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "GameActivity created")
        
        setContent {
            MaterialTheme {
                GameScreen(
                    onBackToFlutter = {
                        // Navigate back to Flutter main app
                        val flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)
                        if (flutterEngine != null) {
                            Log.d(TAG, "Launching Flutter activity with cached engine")
                            val flutterIntent = FlutterActivity.withCachedEngine(ENGINE_ID)
                                .build(this)
                            startActivity(flutterIntent)
                        } else {
                            Log.d(TAG, "No cached engine found, launching new Flutter activity")
                            val flutterIntent = FlutterActivity.createDefaultIntent(this)
                            startActivity(flutterIntent)
                        }
                        finish()
                    }
                )
            }
        }
    }
}
