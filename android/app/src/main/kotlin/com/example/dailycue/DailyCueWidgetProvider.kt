package com.example.dailycue

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class DailyCueWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.daily_cue_widget).apply {
                // Get data from SharedPreferences
                val widgetData = HomeWidgetPlugin.getData(context)
                val hasActivity = widgetData.getBoolean("has_activity", false)

                if (hasActivity) {
                    val activityTitle = widgetData.getString("activity_title", "No Activity")
                    val activityTime = widgetData.getString("activity_time", "--:--")
                    val activityDescription = widgetData.getString("activity_description", "")
                    val countdown = widgetData.getString("activity_countdown", "")

                    setTextViewText(R.id.widget_activity_title, activityTitle)
                    setTextViewText(R.id.widget_activity_time, activityTime)
                    setTextViewText(R.id.widget_countdown, countdown)

                    if (activityDescription.isNotEmpty()) {
                        setTextViewText(R.id.widget_activity_description, activityDescription)
                        setViewVisibility(R.id.widget_activity_description, android.view.View.VISIBLE)
                    } else {
                        setViewVisibility(R.id.widget_activity_description, android.view.View.GONE)
                    }
                } else {
                    setTextViewText(R.id.widget_activity_title, "No Activities")
                    setTextViewText(R.id.widget_activity_time, "--:--")
                    setTextViewText(R.id.widget_countdown, "")
                    setViewVisibility(R.id.widget_activity_description, android.view.View.GONE)
                }

                // Set click intent to launch the app
                val pendingIntent = HomeWidgetPlugin.getPendingIntentForWidgetClick(
                    context,
                    widgetId,
                    Intent(context, MainActivity::class.java)
                )
                setOnClickPendingIntent(R.id.widget_activity_title, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == "android.appwidget.action.APPWIDGET_UPDATE") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
            if (appWidgetIds != null) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }
}
