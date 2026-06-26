package com.vidra.vidra_app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

public class BackgroundKeepAliveService extends Service {
    private static final String TAG = "VidRA_KEEP_ALIVE";

    private static final String CHANNEL_ID = "vidra_background_service";
    private static final int NOTIFICATION_ID = 22032;

    private static final String SETTINGS_PREFS = "vidra_sender_settings";

    private static final String KEY_BACKGROUND_MODE = "backgroundMode";
    private static final String KEY_RELAY_URL = "relayUrl";
    private static final String KEY_DEVICE_ID = "deviceId";

    public static void start(Context context) {
        if (context == null) {
            return;
        }

        try {
            Intent intent = new Intent(context, BackgroundKeepAliveService.class);

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to start background keep alive service", e);
        }
    }

    public static void stop(Context context) {
        if (context == null) {
            return;
        }

        try {
            Intent intent = new Intent(context, BackgroundKeepAliveService.class);
            context.stopService(intent);
        } catch (Exception e) {
            Log.e(TAG, "Failed to stop background keep alive service", e);
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        Log.d(TAG, "Background keep alive service created");
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        startForeground(NOTIFICATION_ID, buildNotification());

        if (!isBackgroundModeEnabled()) {
            Log.d(TAG, "Background mode disabled, stopping service");
            stopSelf();
            return START_NOT_STICKY;
        }

        syncRelayPollingState();

        Log.d(TAG, "Background keep alive service started");
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();

        if (isBackgroundModeEnabled()) {
            syncRelayPollingState();
        }

        Log.d(TAG, "Background keep alive service destroyed");
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private boolean isBackgroundModeEnabled() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        return prefs.getBoolean(KEY_BACKGROUND_MODE, true);
    }

    private void syncRelayPollingState() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String relayUrl = clean(prefs.getString(KEY_RELAY_URL, ""));
        String deviceId = clean(prefs.getString(KEY_DEVICE_ID, ""));

        if (!relayUrl.isEmpty() && deviceId.isEmpty()) {
            RelayPollingReceiver.schedule(this);
        } else {
            RelayPollingReceiver.cancel(this);
        }
    }

    private Notification buildNotification() {
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle("VidRA работает в фоне")
                .setContentText("SMS и PUSH пересылка активна")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setOngoing(true)
                .setSilent(true)
                .build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationManager notificationManager = (NotificationManager) getSystemService(
                Context.NOTIFICATION_SERVICE
        );

        if (notificationManager == null) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "VidRA фоновый режим",
                NotificationManager.IMPORTANCE_LOW
        );

        channel.setDescription("Постоянная работа VidRA в фоновом режиме");
        notificationManager.createNotificationChannel(channel);
    }

    private String clean(String value) {
        if (value == null) {
            return "";
        }

        return value.trim();
    }
}