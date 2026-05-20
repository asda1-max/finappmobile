package com.example.finappmobile.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.example.finappmobile.MainActivity
import com.example.finappmobile.R
import org.json.JSONArray

class WatchlistWidgetProvider : AppWidgetProvider() {
  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray
  ) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == ACTION_REFRESH) {
      updateAll(context)
    }
  }

  companion object {
    const val PREFS_NAME = "watchlist_widget"
    const val PREFS_KEY_DATA = "widget_data"
    const val PREFS_KEY_OPEN_TARGET = "open_target"
    const val ACTION_REFRESH = "com.example.finappmobile.WATCHLIST_WIDGET_REFRESH"
    const val EXTRA_OPEN_TARGET = "open_target"

    fun updateAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val component = ComponentName(context, WatchlistWidgetProvider::class.java)
      val ids = manager.getAppWidgetIds(component)
      for (id in ids) {
        updateAppWidget(context, manager, id)
      }
    }

    fun updateAppWidget(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int
    ) {
      val views = RemoteViews(context.packageName, R.layout.widget_watchlist)

      val launchIntent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        putExtra(EXTRA_OPEN_TARGET, "watchlist")
      }
      val launchPending = PendingIntent.getActivity(
        context,
        0,
        launchIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
      views.setOnClickPendingIntent(R.id.widget_root, launchPending)

      val refreshIntent = Intent(context, WatchlistWidgetProvider::class.java).apply {
        action = ACTION_REFRESH
      }
      val refreshPending = PendingIntent.getBroadcast(
        context,
        0,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
      )
      views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)

      val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
      val raw = prefs.getString(PREFS_KEY_DATA, "[]") ?: "[]"
      val items = parseItems(raw)

      bindRow(views, 1, items.getOrNull(0))
      bindRow(views, 2, items.getOrNull(1))
      bindRow(views, 3, items.getOrNull(2))

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindRow(views: RemoteViews, index: Int, item: WidgetItem?) {
      val rowId = when (index) {
        1 -> R.id.widget_row_1
        2 -> R.id.widget_row_2
        else -> R.id.widget_row_3
      }
      if (item == null) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }

      views.setViewVisibility(rowId, View.VISIBLE)
      val tickerId = when (index) {
        1 -> R.id.widget_row_1_ticker
        2 -> R.id.widget_row_2_ticker
        else -> R.id.widget_row_3_ticker
      }
      val decisionId = when (index) {
        1 -> R.id.widget_row_1_decision
        2 -> R.id.widget_row_2_decision
        else -> R.id.widget_row_3_decision
      }
      val priceId = when (index) {
        1 -> R.id.widget_row_1_price
        2 -> R.id.widget_row_2_price
        else -> R.id.widget_row_3_price
      }
      val changeId = when (index) {
        1 -> R.id.widget_row_1_change
        2 -> R.id.widget_row_2_change
        else -> R.id.widget_row_3_change
      }
      val sectorId = when (index) {
        1 -> R.id.widget_row_1_sector
        2 -> R.id.widget_row_2_sector
        else -> R.id.widget_row_3_sector
      }
      val scoreId = when (index) {
        1 -> R.id.widget_row_1_score
        2 -> R.id.widget_row_2_score
        else -> R.id.widget_row_3_score
      }
      val rangeId = when (index) {
        1 -> R.id.widget_row_1_range
        2 -> R.id.widget_row_2_range
        else -> R.id.widget_row_3_range
      }

      views.setTextViewText(tickerId, item.ticker)
      views.setTextViewText(decisionId, item.decision)
      views.setTextViewText(priceId, item.price)
      views.setTextViewText(changeId, item.change)
      views.setTextViewText(sectorId, item.sector)
      views.setTextViewText(scoreId, "Score ${item.score}")
      views.setTextViewText(rangeId, "52W: ${item.range}")

      val decisionBg = when {
        item.decision.contains("BUY") && !item.decision.contains("NO") -> R.drawable.decision_buy_bg
        item.decision.contains("HOLD") -> R.drawable.decision_hold_bg
        else -> R.drawable.decision_no_bg
      }
      views.setInt(decisionId, "setBackgroundResource", decisionBg)

      val changeColor = when {
        item.change.startsWith("+") -> 0xFF6FD08A.toInt()
        item.change.startsWith("-") -> 0xFFE0705A.toInt()
        else -> 0xFF9C9386.toInt()
      }
      views.setTextColor(changeId, changeColor)
    }

    private fun parseItems(raw: String): List<WidgetItem> {
      return try {
        val arr = JSONArray(raw)
        val items = ArrayList<WidgetItem>()
        for (i in 0 until arr.length()) {
          val obj = arr.getJSONObject(i)
          val ticker = obj.optString("ticker")
          val price = obj.optString("price")
          val score = obj.optString("score")
          val decision = obj.optString("decision")
          val change = obj.optString("change")
          val sector = obj.optString("sector")
          val range = obj.optString("range")
          if (ticker.isNotEmpty()) {
            items.add(WidgetItem(ticker, price, score, decision, change, sector, range))
          }
        }
        items
      } catch (e: Exception) {
        emptyList()
      }
    }
  }
}

data class WidgetItem(
  val ticker: String,
  val price: String,
  val score: String,
  val decision: String,
  val change: String,
  val sector: String,
  val range: String
)
