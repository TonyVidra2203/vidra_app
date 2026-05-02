package com.vidra.vidra_app;

import android.app.Notification;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
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
        if (sbn == null) {
            return;
        }

        if (!isPushForwardingEnabled()) {
            Log.d(TAG, "PUSH forwarding disabled");
            return;
        }

        try {
            Notification notification = sbn.getNotification();

            if (notification == null) {
                return;
            }

            Bundle extras = notification.extras;

            String packageName = safeString(sbn.getPackageName());
            String appName = getAppName(packageName);
            String title = "";
            String text = "";

            if (extras != null) {
                title = charSequenceToString(extras.getCharSequence(Notification.EXTRA_TITLE));
                text = charSequenceToString(extras.getCharSequence(Notification.EXTRA_TEXT));

                if (text.isEmpty()) {
                    text = charSequenceToString(extras.getCharSequence(Notification.EXTRA_BIG_TEXT));
                }
            }

            if (packageName.equals(getPackageName())) {
                return;
            }

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
            MainActivity.notifyMessagesUpdated(this);

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

    private JSONObject buildPayload(
            String packageName,
            String appName,
            String title,
            String text,
            long receivedAt
    ) {
        JSONObject payload = new JSONObject();

        try {
            SharedPreferences prefs = getSharedPreferences(
                    SETTINGS_PREFS,
                    Context.MODE_PRIVATE
            );

            String deviceName = prefs.getString(
                    KEY_DEVICE_NAME,
                    Build.MANUFACTURER + " " + Build.MODEL
            );

            String deviceId = prefs.getString(KEY_DEVICE_ID, "");

            payload.put("id", "push_" + receivedAt);
            payload.put("type", "push");
            payload.put("sender", appName);
            payload.put("app", appName);
            payload.put("packageName", packageName);
            payload.put("title", title);
            payload.put("text", text);
            payload.put("deviceName", deviceName == null ? "" : deviceName);
            payload.put("deviceId", deviceId == null ? "" : deviceId);
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

    private String getAppName(String packageName) {
        if (packageName == null || packageName.trim().isEmpty()) {
            return "";
        }

        try {
            CharSequence label = getPackageManager()
                    .getApplicationLabel(
                            getPackageManager().getApplicationInfo(packageName, 0)
                    );

            return label == null ? packageName : label.toString();
        } catch (Exception e) {
            return packageName;
        }
    }

    private String charSequenceToString(CharSequence value) {
        return value == null ? "" : value.toString();
    }

    private String safeString(String value) {
        return value == null ? "" : value;
    }
}