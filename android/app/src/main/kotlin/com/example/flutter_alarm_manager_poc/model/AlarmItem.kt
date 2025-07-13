package com.example.flutter_alarm_manager_poc.model

data class AlarmItem(
    val id: Int,
    val message: String,
    val gameType: String = "piano_tiles"
)