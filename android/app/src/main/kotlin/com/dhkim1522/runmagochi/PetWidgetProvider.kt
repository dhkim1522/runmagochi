package com.dhkim1522.runmagochi

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * 홈 화면 위젯 (F29, 결정 0037). 앱이 그려 둔 그림(`pet_image`)을 보여 주고,
 * 누르면 앱을 연다. 그림이 아직 없으면 앱 아이콘을 보인다.
 */
class PetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val path = widgetData.getString("pet_image", null)
        val bitmap = path?.let { p ->
            File(p).takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.absolutePath) }
        }
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pet_widget).apply {
                if (bitmap != null) {
                    setImageViewBitmap(R.id.pet_widget_image, bitmap)
                } else {
                    setImageViewResource(R.id.pet_widget_image, R.mipmap.ic_launcher)
                }
                setOnClickPendingIntent(
                    R.id.pet_widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
