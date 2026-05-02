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
    private static final String FILTERS_PREFS = "vidra_filter_settings";

    private static final String KEY_PUSH_FORWARDING = "pushForwarding";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";

    private static final String KEY_VERIFICATION_CODES = "verificationCodes";
    private static final String KEY_BANK_MESSAGES = "bankMessages";
    private static final String KEY_AD_SMS = "adSms";
    private static final String KEY_CRYPTO_SPAM = "cryptoSpam";
    private static final String KEY_BLACKLIST = "blacklist";

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

            if (!isAllowedByFilters(appName, packageName, title, text)) {
                Log.d(TAG, "PUSH skipped by filters");
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

    private boolean isAllowedByFilters(
            String appName,
            String packageName,
            String title,
            String text
    ) {
        SharedPreferences filters = getSharedPreferences(
                FILTERS_PREFS,
                Context.MODE_PRIVATE
        );

        String combined = (
                safeString(appName) + " " +
                        safeString(packageName) + " " +
                        safeString(title) + " " +
                        safeString(text)
        ).toLowerCase().trim();

        if (!filters.getBoolean(KEY_BLACKLIST, true) && isBlacklisted(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_VERIFICATION_CODES, true) && isVerificationCode(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_BANK_MESSAGES, true) && isBankMessage(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_AD_SMS, false) && isAdPush(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_CRYPTO_SPAM, false) && isCryptoSpam(combined)) {
            return false;
        }

        return true;
    }

    private boolean isVerificationCode(String text) {
        return text.contains("код")
                || text.contains("code")
                || text.contains("otp")
                || text.contains("пароль")
                || text.contains("password")
                || text.contains("verification")
                || text.contains("подтверждения")
                || text.matches(".*\\b\\d{4,8}\\b.*");
    }

    private boolean isBankMessage(String text) {
        return text.contains("bank")
                || text.contains("банк")
                || text.contains("sber")
                || text.contains("сбер")
                || text.contains("tinkoff")
                || text.contains("тинькофф")
                || text.contains("alfabank")
                || text.contains("альфа")
                || text.contains("vtb")
                || text.contains("втб")
                || text.contains("mir")
                || text.contains("мир")
                || text.contains("card")
                || text.contains("карта")
                || text.contains("balance")
                || text.contains("баланс")
                || text.contains("покупка")
                || text.contains("списание")
                || text.contains("зачисление");
    }

    private boolean isAdPush(String text) {
        return text.contains("скидка")
                || text.contains("sale")
                || text.contains("акция")
                || text.contains("promo")
                || text.contains("промо")
                || text.contains("discount")
                || text.contains("bonus")
                || text.contains("бонус")
                || text.contains("offer")
                || text.contains("реклама")
                || text.contains("unsubscribe")
                || text.contains("отпис");
    }

    private boolean isCryptoSpam(String text) {
        return text.contains("crypto")
                || text.contains("bitcoin")
                || text.contains("btc")
                || text.contains("usdt")
                || text.contains("binance")
                || text.contains("bybit")
                || text.contains("airdrop")
                || text.contains("wallet")
                || text.contains("blockchain")
                || text.contains("крипто")
                || text.contains("биткоин");
    }

    private boolean isBlacklisted(String text) {
        return text.contains("casino")
                || text.contains("казино")
                || text.contains("1xbet")
                || text.contains("stavka")
                || text.contains("ставка")
                || text.contains("bet")
                || text.contains("loan")
                || text.contains("займ")
                || text.contains("кредит")
                || text.contains("микрозайм");
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