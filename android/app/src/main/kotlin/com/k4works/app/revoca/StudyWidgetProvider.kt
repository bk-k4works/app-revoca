package com.k4works.app.revoca

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Words left today and the study streak; tapping opens the app. */
class StudyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.study_widget).apply {
                setTextViewText(R.id.widget_count, widgetData.getString("count", "–"))
                setTextViewText(
                    R.id.widget_headline,
                    widgetData.getString("headline", "앱을 열면 오늘 할 단어가 보여요"),
                )
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", ""))
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
