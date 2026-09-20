package com.koma.koma

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class ContinueWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.continue_widget).apply {
                val title = widgetData.getString("continue_title", null)
                    ?: "Continue reading"
                val progress = widgetData.getString("continue_progress", null).orEmpty()
                setTextViewText(R.id.continue_widget_title, title)
                if (progress.isNotEmpty()) {
                    setViewVisibility(R.id.continue_widget_progress, View.VISIBLE)
                    setTextViewText(R.id.continue_widget_progress, progress)
                } else {
                    setViewVisibility(R.id.continue_widget_progress, View.GONE)
                }

                val coverPath = widgetData.getString("continue_cover_path", null)
                val coverFile = coverPath?.let { File(it) }
                if (coverFile != null && coverFile.exists()) {
                    val bitmap = BitmapFactory.decodeFile(coverFile.absolutePath)
                    if (bitmap != null) {
                        setViewVisibility(R.id.continue_widget_cover, View.VISIBLE)
                        setImageViewBitmap(R.id.continue_widget_cover, bitmap)
                    } else {
                        setViewVisibility(R.id.continue_widget_cover, View.GONE)
                    }
                } else {
                    setViewVisibility(R.id.continue_widget_cover, View.GONE)
                }

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("koma://continue"),
                )
                setOnClickPendingIntent(R.id.continue_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
