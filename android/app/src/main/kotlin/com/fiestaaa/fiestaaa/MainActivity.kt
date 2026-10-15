package com.fiestaaa.fiestaaa

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fiestaaa/calendar")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "openEditor" -> {
                        val title = call.argument<String>("title")
                        val start = call.argument<Number>("startMillis")?.toLong()
                        val end = call.argument<Number>("endMillis")?.toLong()
                        val zone = call.argument<String>("timeZone")
                        if (title == null || start == null || end == null ||
                            end <= start || zone == null) {
                            result.error("invalid_event", "Invalid calendar event", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_INSERT).apply {
                            data = CalendarContract.Events.CONTENT_URI
                            putExtra(CalendarContract.Events.TITLE, title)
                            putExtra(CalendarContract.Events.DESCRIPTION, call.argument<String>("description"))
                            putExtra(CalendarContract.Events.EVENT_LOCATION, call.argument<String>("location"))
                            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
                            putExtra(CalendarContract.Events.EVENT_TIMEZONE, zone)
                        }
                        try {
                            // The calendar app handles save/cancel. This only confirms handoff.
                            startActivity(intent)
                            result.success("opened")
                        } catch (_: ActivityNotFoundException) {
                            result.success("unavailable")
                        } catch (_: SecurityException) {
                            result.success("unavailable")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
