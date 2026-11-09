package com.playerszwz.app

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.text.format.DateFormat
import android.view.ContextThemeWrapper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "playerszwz/native-pickers")
            .setMethodCallHandler { call, result -> showNativePicker(call, result) }
    }

    private fun showNativePicker(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: run {
            result.error("INVALID_ARGUMENTS", "Picker arguments are required.", null)
            return
        }
        val context = ContextThemeWrapper(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)

        when (call.method) {
            "date" -> {
                val year = (args["year"] as? Number)?.toInt()
                val month = (args["month"] as? Number)?.toInt()
                val day = (args["day"] as? Number)?.toInt()
                val minimum = (args["minimumMillis"] as? Number)?.toLong()
                val maximum = (args["maximumMillis"] as? Number)?.toLong()
                if (year == null || month == null || day == null || minimum == null || maximum == null) {
                    result.error("INVALID_ARGUMENTS", "Date values are incomplete.", null)
                    return
                }
                val dialog = DatePickerDialog(context, { _, selectedYear, selectedMonth, selectedDay ->
                    result.success(mapOf(
                        "year" to selectedYear,
                        "month" to selectedMonth + 1,
                        "day" to selectedDay,
                    ))
                }, year, month - 1, day)
                dialog.datePicker.minDate = minimum
                dialog.datePicker.maxDate = maximum
                dialog.setOnCancelListener { result.success(null) }
                dialog.show()
            }

            "time" -> {
                val hour = (args["hour"] as? Number)?.toInt()
                val minute = (args["minute"] as? Number)?.toInt()
                if (hour == null || minute == null) {
                    result.error("INVALID_ARGUMENTS", "Time values are incomplete.", null)
                    return
                }
                val dialog = TimePickerDialog(
                    context,
                    { _, selectedHour, selectedMinute ->
                        result.success(mapOf("hour" to selectedHour, "minute" to selectedMinute))
                    },
                    hour,
                    minute,
                    DateFormat.is24HourFormat(this),
                )
                dialog.setOnCancelListener { result.success(null) }
                dialog.show()
            }

            else -> result.notImplemented()
        }
    }
}
