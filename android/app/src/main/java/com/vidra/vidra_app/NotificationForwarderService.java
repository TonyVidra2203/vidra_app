package com.vidra.vidra_app;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

public class NotificationForwarderService extends NotificationListenerService {
    private static final String TAG = "VidRA_PUSH";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String STORAGE_PREFS = "vidra_native_storage";

    private static final String KEY_PUSH_FORWARDING = "pushForwarding";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";

    private static final String PUSH_LIST_KEY = "push_messages";

    private static final int MAX_MESSAGES = 100;

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        if (sbn == null || sbn.getNotification() == null) {
            return;
        }

        if (!isPushForwardingEnabled()) {
            Log.d(TAG, "PUSH forwarding disabled");
            return;
        }

        try {
            String packageName = sbn.getPackageName();

            if (packageName == null || packageName.equals(getPackageName())) {
                return;
            }

            String appName = getAppName(packageName);
            String title = extractNotificationTitle(sbn);
            String text = extractNotificationText(sbn);

            if (title.trim().isEmpty() && text.trim().isEmpty()) {
                return;
            }

            long receivedAt = System.currentTimeMillis();

            JSONObject payload = buildPayload(
                    packageName,
                    appName,
                    title,
                    text,
                    receivedAt
            );

            savePushLocally(payload);
            NetworkClient.sendEvent(this, payload);

            Log.d(TAG, "Incoming PUSH captured and processed");
        } catch (Exception e) {
            Log.e(TAG, "Failed to process PUSH", e);
        }
    }

    private boolean isPushForwardingEnabled() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        return prefs.getBoolean(KEY_PUSH_FORWARDING, true);
    }

    private String getDeviceName() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String savedName = prefs.getString(KEY_DEVICE_NAME, null);

        if (savedName != null && !savedName.trim().isEmpty()) {
            return savedName.trim();
        }

        return Build.MANUFACTURER + " " + Build.MODEL;
    }

    private String getSavedVidraDeviceId() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String savedId = prefs.getString(KEY_DEVICE_ID, null);

        if (savedId != null && !savedId.trim().isEmpty()) {
            return savedId.trim();
        }

        return "";
    }

    private String getAppName(String packageName) {
        try {
            return getPackageManager()
                    .getApplicationLabel(
                            getPackageManager().getApplicationInfo(packageName, 0)
                    )
                    .toString();
        } catch (Exception e) {
            return packageName;
        }
    }

    private String extractNotificationTitle(StatusBarNotification sbn) {
        try {
            CharSequence title = sbn.getNotification()
                    .extras
                    .getCharSequence("android.title");

            return title == null ? "" : title.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private String extractNotificationText(StatusBarNotification sbn) {
        try {
            CharSequence bigText = sbn.getNotification()
                    .extras
                    .getCharSequence("android.bigText");

            if (bigText != null) {
                return bigText.toString();
            }

            CharSequence text = sbn.getNotification()
                    .extras
                    .getCharSequence("android.text");

            return text == null ? "" : text.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private JSONObject buildPayload(
            String packageName,
            String appName,
            String title,
            String text,
            long receivedAt
    ) {
        JSONObject payload = new JSONObject();

        try {
            payload.put("id", "push_" + receivedAt);
            payload.put("type", "push");
            payload.put("sender", appName);
            payload.put("app", appName);
            payload.put("packageName", packageName);
            payload.put("title", title);
            payload.put("text", text);
            payload.put("deviceName", getDeviceName());
            payload.put("deviceId", getSavedVidraDeviceId());
            payload.put("status", "received");
            payload.put("receivedAt", receivedAt);
        } catch (Exception e) {
            Log.e(TAG, "Failed to build PUSH payload", e);
        }

        return payload;
    }

    private void savePushLocally(JSONObject message) {
        try {
            SharedPreferences prefs = getSharedPreferences(
                    STORAGE_PREFS,
                    Context.MODE_PRIVATE
            );

            String currentJson = prefs.getString(PUSH_LIST_KEY, "[]");
            JSONArray oldMessages = new JSONArray(currentJson);
            JSONArray newMessages = new JSONArray();

            newMessages.put(message);

            int limit = Math.min(oldMessages.length(), MAX_MESSAGES - 1);

            for (int i = 0; i < limit; i++) {
                newMessages.put(oldMessages.getJSONObject(i));
            }

            prefs.edit()
                    .putString(PUSH_LIST_KEY, newMessages.toString())
                    .apply();
        } catch (Exception e) {
            Log.e(TAG, "Failed to save PUSH locally", e);
        }
    }
}