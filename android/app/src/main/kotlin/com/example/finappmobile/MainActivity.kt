package com.example.finappmobile

import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.example.finappmobile.widget.WatchlistWidgetProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val channelName = "watchlist_widget"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		handleWidgetIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleWidgetIntent(intent)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"setWatchlistData" -> {
						val raw = call.arguments as? String ?: "[]"
						val prefs = getSharedPreferences(
							WatchlistWidgetProvider.PREFS_NAME,
							Context.MODE_PRIVATE
						)
						prefs.edit().putString(WatchlistWidgetProvider.PREFS_KEY_DATA, raw).apply()
						WatchlistWidgetProvider.updateAll(this)
						result.success(true)
					}
					"consumeOpenTarget" -> {
						val prefs = getSharedPreferences(
							WatchlistWidgetProvider.PREFS_NAME,
							Context.MODE_PRIVATE
						)
						val target = prefs.getString(WatchlistWidgetProvider.PREFS_KEY_OPEN_TARGET, null)
						prefs.edit().remove(WatchlistWidgetProvider.PREFS_KEY_OPEN_TARGET).apply()
						result.success(target)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun handleWidgetIntent(intent: Intent?) {
		val target = intent?.getStringExtra(WatchlistWidgetProvider.EXTRA_OPEN_TARGET)
		if (target.isNullOrEmpty()) return
		val prefs = getSharedPreferences(
			WatchlistWidgetProvider.PREFS_NAME,
			Context.MODE_PRIVATE
		)
		prefs.edit().putString(WatchlistWidgetProvider.PREFS_KEY_OPEN_TARGET, target).apply()
	}
}
