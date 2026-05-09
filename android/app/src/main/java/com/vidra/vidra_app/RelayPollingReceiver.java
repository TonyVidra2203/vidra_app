package com.vidra.vidra_app;

import android.Manifest;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;

public class RelayPollingReceiver extends BroadcastReceiver {
    private static final String TAG = "VidRA_RELAY_POLL";

    private static final String ACTION_POLL_RELAY = "com.vidra.vidra_app.POLL_RELAY";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String STORAGE_PREFS = "vidra_native_storage";

    private static final String KEY_RELAY_URL = "relayUrl";
    private static final String KEY_DEVICE_ID = "deviceId";

    private static final String SMS_LIST_KEY = "sms_messages";
    private static final String PUSH_LIST_KEY = "push_messages";
    private static final String NOTIFIED_IDS_KEY = "relay_notified_ids";

    private static final String CHANNEL_ID = "vidra_relay_events";
    private static final int MAX_MESSAGES = 100;
    private static final int MAX_NOTIFIED_IDS = 200;

    public static void schedule(Context context) {
        if (context == null) {
            return;
        }

        try {
            AlarmManager alarmManager =
                    (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);

            if (alarmManager == null) {
                return;
            }

            PendingIntent pendingIntent = buildPendingIntent(context);

            long firstRunAt = System.currentTimeMillis() + 15_000L;
            long interval = 60_000L;

            alarmManager.setInexactRepeating(
                    AlarmManager.RTC_WAKEUP,
                    firstRunAt,
                    interval,
                    pendingIntent
            );

            Log.d(TAG, "Relay polling scheduled");
        } catch (Exception e) {
            Log.e(TAG, "Failed to schedule relay polling", e);
        }
    }

    public static void cancel(Context context) {
        if (context == null) {
            return;
        }

        try {
            AlarmManager alarmManager =
                    (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);

            if (alarmManager == null) {
                return;
            }

            alarmManager.cancel(buildPendingIntent(context));
            Log.d(TAG, "Relay polling cancelled");
        } catch (Exception e) {
            Log.e(TAG, "Failed to cancel relay polling", e);
        }
    }

    private static PendingIntent buildPendingIntent(Context context) {
        Intent intent = new Intent(context, RelayPollingReceiver.class);
        intent.setAction(ACTION_POLL_RELAY);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        return PendingIntent.getBroadcast(context, 22030, intent, flags);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) {
            return;
        }

        if (!ACTION_POLL_RELAY.equals(intent.getAction())) {
            return;
        }

        new Thread(() -> pollRelay(context.getApplicationContext())).start();
    }

    private void pollRelay(Context context) {
        SharedPreferences settings = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String relayUrl = clean(settings.getString(KEY_RELAY_URL, ""));
        String localDeviceId = clean(settings.getString(KEY_DEVICE_ID, ""));

        if (relayUrl.isEmpty()) {
            return;
        }

        if (!localDeviceId.isEmpty()) {
            return;
        }

        try {
            JSONArray events = loadEvents(relayUrl);
            if (events.length() == 0) {
                return;
            }

            SharedPreferences storage = context.getSharedPreferences(
                    STORAGE_PREFS,
                    Context.MODE_PRIVATE
            );

            Set<String> notifiedIds = new HashSet<>(
                    storage.getStringSet(NOTIFIED_IDS_KEY, new HashSet<>())
            );

            JSONObject newestEvent = null;
            boolean hasNewEvents = false;

            for (int i = 0; i < events.length(); i++) {
                JSONObject event = events.optJSONObject(i);

                if (event == null) {
                    continue;
                }

                String eventId = getEventId(event);

                if (eventId.isEmpty() || notifiedIds.contains(eventId)) {
                    continue;
                }

                notifiedIds.add(eventId);
                saveEventLocally(context, event);

                if (newestEvent == null) {
                    newestEvent = event;
                }

                hasNewEvents = true;
            }

            if (!hasNewEvents || newestEvent == null) {
                return;
            }

            trimAndSaveNotifiedIds(storage, notifiedIds);
            MainActivity.notifyMessagesUpdated(context);
            showRelayNotification(context, newestEvent);
        } catch (Exception e) {
            Log.e(TAG, "Relay polling failed", e);
        }
    }

    private JSONArray loadEvents(String relayUrl) throws Exception {
        HttpURLConnection connection = null;

        try {
            URL url = new URL(relayUrl);
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(10_000);
            connection.setReadTimeout(10_000);
            connection.setRequestProperty("Accept", "application/json");
            connection.setRequestProperty("User-Agent", "VidRA-Android");

            int responseCode = connection.getResponseCode();

            if (responseCode < 200 || responseCode >= 300) {
                return new JSONArray();
            }

            BufferedReader reader = new BufferedReader(
                    new InputStreamReader(
                            connection.getInputStream(),
                            StandardCharsets.UTF_8
                    )
            );

            StringBuilder body = new StringBuilder();
            String line;

            while ((line = reader.readLine()) != null) {
                body.append(line);
            }

            reader.close();

            return extractEvents(body.toString());
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private JSONArray extractEvents(String body) {
        try {
            Object decoded = new org.json.JSONTokener(body).nextValue();

            if (decoded instanceof JSONArray) {
                return (JSONArray) decoded;
            }

            if (decoded instanceof JSONObject) {
                JSONObject object = (JSONObject) decoded;

                JSONArray events = object.optJSONArray("events");
                if (events != null) {
                    return events;
                }

                JSONArray messages = object.optJSONArray("messages");
                if (messages != null) {
                    return messages;
                }

                JSONArray data = object.optJSONArray("data");
                if (data != null) {
                    return data;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to parse relay response", e);
        }

        return new JSONArray();
    }

    private void saveEventLocally(Context context, JSONObject event) {
        String type = clean(event.optString("type", ""));
        String storageKey = "sms".equals(type) ? SMS_LIST_KEY : PUSH_LIST_KEY;

        try {
            SharedPreferences storage = context.getSharedPreferences(
                    STORAGE_PREFS,
                    Context.MODE_PRIVATE
            );

            JSONArray oldMessages = new JSONArray(
                    storage.getString(storageKey, "[]")
            );

            JSONArray newMessages = new JSONArray();
            newMessages.put(event);

            int limit = Math.min(oldMessages.length(), MAX_MESSAGES - 1);

            for (int i = 0; i < limit; i++) {
                newMessages.put(oldMessages.getJSONObject(i));
            }

            storage.edit()
                    .putString(storageKey, newMessages.toString())
                    .apply();
        } catch (Exception e) {
            Log.e(TAG, "Failed to save relay event locally", e);
        }
    }

    private void showRelayNotification(Context context, JSONObject event) {
        if (!canShowNotifications(context)) {
            return;
        }

        createNotificationChannel(context);

        String type = clean(event.optString("type", ""));
        String deviceName = clean(event.optString("deviceName", "Другой телефон"));
        String title = clean(event.optString("title", ""));
        String text = clean(event.optString("text", ""));
        String sender = clean(event.optString("sender", ""));
        String app = clean(event.optString("app", ""));

        String notificationTitle;

        if ("sms".equals(type)) {
            notificationTitle = "VidRA: новое SMS";
        } else {
            notificationTitle = "VidRA: новое PUSH";
        }

        String source = firstNotEmpty(sender, app, title, deviceName);
        String notificationText = source;

        if (!text.isEmpty()) {
            notificationText = source + ": " + text;
        }

        Intent launchIntent = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());

        if (launchIntent == null) {
            launchIntent = new Intent(context, MainActivity.class);
        }

        launchIntent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP
        );

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }

        PendingIntent contentIntent = PendingIntent.getActivity(
                context,
                22031,
                launchIntent,
                flags
        );

        NotificationCompat.Builder builder = new NotificationCompat.Builder(
                context,
                CHANNEL_ID
        )
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(notificationTitle)
                .setContentText(notificationText)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(notificationText))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE);

        NotificationManagerCompat.from(context).notify(
                (int) (System.currentTimeMillis() % Integer.MAX_VALUE),
                builder.build()
        );
    }

    private boolean canShowNotifications(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true;
        }

        return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED;
    }

    private void createNotificationChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationManager notificationManager =
                (NotificationManager) context.getSystemService(
                        Context.NOTIFICATION_SERVICE
                );

        if (notificationManager == null) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "VidRA события",
                NotificationManager.IMPORTANCE_HIGH
        );

        channel.setDescription("Уведомления о SMS и PUSH с привязанных телефонов");
        notificationManager.createNotificationChannel(channel);
    }

    private String getEventId(JSONObject event) {
        String id = clean(event.optString("id", ""));

        if (!id.isEmpty()) {
            return id;
        }

        return String.valueOf(event.toString().hashCode());
    }

    private void trimAndSaveNotifiedIds(
            SharedPreferences storage,
            Set<String> notifiedIds
    ) {
        Set<String> result = new HashSet<>();
        int count = 0;

        for (String id : notifiedIds) {
            if (count >= MAX_NOTIFIED_IDS) {
                break;
            }

            result.add(id);
            count++;
        }

        storage.edit()
                .putStringSet(NOTIFIED_IDS_KEY, result)
                .apply();
    }

    private String firstNotEmpty(String first, String second, String third, String fourth) {
        if (!first.isEmpty()) {
            return first;
        }

        if (!second.isEmpty()) {
            return second;
        }

        if (!third.isEmpty()) {
            return third;
        }

        return fourth;
    }

    private String clean(String value) {
        return value == null ? "" : value.trim();
    }
}