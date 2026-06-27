package com.vidra.vidra_app;

import android.app.Notification;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class NotificationForwarderService extends NotificationListenerService {
    private static final String TAG = "VidRA_PUSH";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String STORAGE_PREFS = "vidra_native_storage";

    private static final String KEY_PUSH_FORWARDING = "pushForwarding";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";

    private static final String PUSH_LIST_KEY = "push_messages";

    private static final int MAX_MESSAGES = 100;
    private static final int MAX_RECENT_PUSHES = 80;
    private static final long DUPLICATE_WINDOW_MS = 5 * 60 * 1000L;

    private final Map<String, Long> recentPushFingerprints = new HashMap<>();

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

            if (shouldIgnoreNotification(sbn, packageName)) {
                return;
            }

            String appName = getAppName(packageName);
            String title = clean(extractNotificationTitle(sbn));
            String text = clean(extractNotificationText(sbn));

            if (title.isEmpty() && text.isEmpty()) {
                return;
            }

            long receivedAt = System.currentTimeMillis();
            String fingerprint = buildNotificationFingerprint(sbn, packageName, title, text);

            if (isDuplicatePush(fingerprint, receivedAt)) {
                Log.d(TAG, "Duplicate PUSH skipped");
                return;
            }

            JSONObject payload = buildPayload(
                    sbn,
                    packageName,
                    appName,
                    title,
                    text,
                    fingerprint,
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

    private boolean shouldIgnoreNotification(StatusBarNotification sbn, String packageName) {
        if (packageName == null || packageName.equals(getPackageName())) {
            return true;
        }

        Notification notification = sbn.getNotification();

        if (notification == null) {
            return true;
        }

        if ((notification.flags & Notification.FLAG_GROUP_SUMMARY) != 0) {
            return true;
        }

        if ((notification.flags & Notification.FLAG_ONGOING_EVENT) != 0) {
            return true;
        }

        if ((notification.flags & Notification.FLAG_LOCAL_ONLY) != 0) {
            return true;
        }

        return false;
    }

    private boolean isDuplicatePush(String fingerprint, long now) {
        synchronized (recentPushFingerprints) {
            removeOldFingerprints(now);

            Long lastSeenAt = recentPushFingerprints.get(fingerprint);

            if (lastSeenAt != null && now - lastSeenAt < DUPLICATE_WINDOW_MS) {
                return true;
            }

            recentPushFingerprints.put(fingerprint, now);
            trimRecentFingerprints();

            return false;
        }
    }

    private void removeOldFingerprints(long now) {
        Iterator<Map.Entry<String, Long>> iterator = recentPushFingerprints.entrySet().iterator();

        while (iterator.hasNext()) {
            Map.Entry<String, Long> entry = iterator.next();

            if (now - entry.getValue() > DUPLICATE_WINDOW_MS) {
                iterator.remove();
            }
        }
    }

    private void trimRecentFingerprints() {
        if (recentPushFingerprints.size() <= MAX_RECENT_PUSHES) {
            return;
        }

        Iterator<String> iterator = recentPushFingerprints.keySet().iterator();

        while (recentPushFingerprints.size() > MAX_RECENT_PUSHES && iterator.hasNext()) {
            iterator.next();
            iterator.remove();
        }
    }

    private String buildNotificationFingerprint(
            StatusBarNotification sbn,
            String packageName,
            String title,
            String text
    ) {
        String tag = clean(sbn.getTag());
        int id = sbn.getId();

        return packageName + "|" + tag + "|" + id + "|" + title + "|" + text;
    }

    private String buildStablePayloadId(StatusBarNotification sbn, String fingerprint) {
        long postTime = sbn.getPostTime();
        String source = fingerprint + "|" + postTime;

        return "push_" + Integer.toHexString(source.hashCode());
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
                    .getCharSequence(Notification.EXTRA_TITLE);

            return title == null ? "" : title.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private String extractNotificationText(StatusBarNotification sbn) {
        try {
            CharSequence bigText = sbn.getNotification()
                    .extras
                    .getCharSequence(Notification.EXTRA_BIG_TEXT);

            if (bigText != null) {
                return bigText.toString();
            }

            CharSequence text = sbn.getNotification()
                    .extras
                    .getCharSequence(Notification.EXTRA_TEXT);

            return text == null ? "" : text.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private JSONObject buildPayload(
            StatusBarNotification sbn,
            String packageName,
            String appName,
            String title,
            String text,
            String fingerprint,
            long receivedAt
    ) {
        JSONObject payload = new JSONObject();

        try {
            payload.put("id", buildStablePayloadId(sbn, fingerprint));
            payload.put("type", "push");
            payload.put("sender", appName);
            payload.put("app", appName);
            payload.put("packageName", packageName);
            payload.put("title", title);
            payload.put("text", text);
            payload.put("deviceName", getDeviceName());
            payload.put("deviceId", getSavedVidraDeviceId());
            payload.put("deviceBrand", clean(Build.MANUFACTURER));
            payload.put("deviceModel", clean(Build.MODEL));
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

    private String clean(String value) {
        return value == null ? "" : value.trim();
    }
}