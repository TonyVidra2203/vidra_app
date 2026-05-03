package com.vidra.vidra_app;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.service.notification.NotificationListenerService;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "VidRA_BOOT";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null || intent.getAction() == null) {
            return;
        }

        String action = intent.getAction();

        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
            Log.d(TAG, "Boot/package event received: " + action);

            requestNotificationListenerRebind(context);
            MainActivity.notifyMessagesUpdated(context);
        }
    }

    private void requestNotificationListenerRebind(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return;
        }

        try {
            ComponentName componentName = new ComponentName(
                    context,
                    NotificationForwarderService.class
            );

            NotificationListenerService.requestRebind(componentName);

            Log.d(TAG, "Notification listener rebind requested");
        } catch (Exception e) {
            Log.e(TAG, "Failed to request notification listener rebind", e);
        }
    }
}