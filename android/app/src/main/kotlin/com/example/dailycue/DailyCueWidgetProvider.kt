package com.example.dailycue

import android.app.PendingIntent
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
                val allCompleted = widgetData.getBoolean("all_completed", false)
                val completedCount = widgetData.getInt("completed_count", 0)
                val remainingCount = widgetData.getInt("remaining_count", 0)
                val totalCount = widgetData.getInt("total_count", 0)

                // Set click intent to launch the app
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    action = "es.antonborri.home_widget.action.LAUNCH"
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                if (allCompleted && totalCount > 0) {
                    // Show congratulatory view with success background
                    setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background_completed)
                    setViewVisibility(R.id.widget_normal_view, android.view.View.GONE)
                    setViewVisibility(R.id.widget_congrats_view, android.view.View.VISIBLE)
                } else {
                    // Show normal activity view with primary background
                    setInt(R.id.widget_container, "setBackgroundResource", R.drawable.widget_background)
                    setViewVisibility(R.id.widget_normal_view, android.view.View.VISIBLE)
                    setViewVisibility(R.id.widget_congrats_view, android.view.View.GONE)

                    if (hasActivity) {
                        val activityTitle = widgetData.getString("activity_title", "No Activity")
                        val activityTime = widgetData.getString("activity_time", "--:--")
                        val activityDescription = widgetData.getString("activity_description", "")
                        val countdown = widgetData.getString("activity_countdown", "")

                        setTextViewText(R.id.widget_activity_title, activityTitle)
                        setTextViewText(R.id.widget_activity_time, activityTime)
                        setTextViewText(R.id.widget_countdown, countdown)

                        if (!activityDescription.isNullOrEmpty()) {
                            setTextViewText(R.id.widget_activity_description, activityDescription)
                            setViewVisibility(R.id.widget_activity_description, android.view.View.VISIBLE)
                        } else {
                            setViewVisibility(R.id.widget_activity_description, android.view.View.GONE)
                        }

                        // Show stats if there are activities in progress
                        if (totalCount > 0) {
                            setViewVisibility(R.id.widget_stats_section, android.view.View.VISIBLE)
                            setTextViewText(R.id.widget_completed_count, completedCount.toString())
                            setTextViewText(R.id.widget_remaining_count, remainingCount.toString())

                            // Calculate progress percentage
                            val progressPercentage = if (totalCount > 0) {
                                (completedCount.toFloat() / totalCount * 100).toInt()
                            } else 0
                            setTextViewText(R.id.widget_progress_percentage, "$progressPercentage%")

                            // Set motivational message based on progress
                            val motivationMessage = when {
                                progressPercentage == 0 -> "Let's get started! 🚀"
                                progressPercentage < 30 -> "Great start! Keep going! 💪"
                                progressPercentage < 50 -> "You're making progress! 🌟"
                                progressPercentage < 75 -> "More than halfway there! 🔥"
                                progressPercentage < 100 -> "Almost done! You got this! ⚡"
                                else -> "All done! 🎉"
                            }
                            setTextViewText(R.id.widget_motivation_text, motivationMessage)

                            // Update progress bar
                            setProgressBar(R.id.widget_progress_bar, 100, progressPercentage, false)

                        } else {
                            setViewVisibility(R.id.widget_stats_section, android.view.View.GONE)
                        }
                    } else {
                        setTextViewText(R.id.widget_activity_title, "No Activities")
                        setTextViewText(R.id.widget_activity_time, "--:--")
                        setTextViewText(R.id.widget_countdown, "")
                        setViewVisibility(R.id.widget_activity_description, android.view.View.GONE)
                        setViewVisibility(R.id.widget_stats_section, android.view.View.GONE)
                    }
                }
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
