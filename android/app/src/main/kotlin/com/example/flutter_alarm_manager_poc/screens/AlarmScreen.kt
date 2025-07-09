package com.example.flutter_alarm_manager_poc.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.flutter_alarm_manager_poc.utils.convertMillisToTime

@Composable
fun AlarmScreen(
    onPlay: () -> Unit,
    onSnooze: () -> Unit,
    alarmTime: Long
) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "It's ${convertMillisToTime(alarmTime)}",
                style = MaterialTheme.typography.headlineMedium
            )
            Spacer(modifier = Modifier.height(32.dp))
            Button(onClick = onSnooze) {
                Text(text = "Snooze (1 minute)")
            }
            Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = onPlay) {
                Text(text = "Play")
            }
        }
    }
}
