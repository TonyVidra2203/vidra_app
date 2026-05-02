package com.vidra.vidra_app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.provider.Telephony;
import android.telephony.SmsMessage;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

public class SmsReceiver extends BroadcastReceiver {
    private static final String TAG = "VidRA_SMS";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String STORAGE_PREFS = "vidra_native_storage";
    private static final String FILTERS_PREFS = "vidra_filter_settings";

    private static final String KEY_SMS_FORWARDING = "smsForwarding";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";

    private static final String KEY_VERIFICATION_CODES = "verificationCodes";
    private static final String KEY_BANK_MESSAGES = "bankMessages";
    private static final String KEY_AD_SMS = "adSms";
    private static final String KEY_INTERNATIONAL_NUMBERS = "internationalNumbers";
    private static final String KEY_CRYPTO_SPAM = "cryptoSpam";
    private static final String KEY_BLACKLIST = "blacklist";

    private static final String SMS_LIST_KEY = "sms_messages";

    private static final int MAX_MESSAGES = 100;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) {
            return;
        }

        if (!Telephony.Sms.Intents.SMS_RECEIVED_ACTION.equals(intent.getAction())) {
            return;
        }

        if (!isSmsForwardingEnabled(context)) {
            Log.d(TAG, "SMS forwarding disabled");
            return;
        }

        try {
            SmsMessage[] messages = Telephony.Sms.Intents.getMessagesFromIntent(intent);

            if (messages == null || messages.length == 0) {
                return;
            }

            StringBuilder bodyBuilder = new StringBuilder();
            String sender = "";
            long receivedAt = System.currentTimeMillis();

            for (SmsMessage sms : messages) {
                if (sms == null) {
                    continue;
                }

                if (sender.isEmpty()) {
                    sender = safeString(sms.getDisplayOriginatingAddress());
                }

                bodyBuilder.append(safeString(sms.getMessageBody()));

                if (sms.getTimestampMillis() > 0) {
                    receivedAt = sms.getTimestampMillis();
                }
            }

            String body = bodyBuilder.toString();

            if (sender.trim().isEmpty() && body.trim().isEmpty()) {
                return;
            }

            if (!isAllowedByFilters(context, sender, body)) {
                Log.d(TAG, "SMS skipped by filters");
                return;
            }

            JSONObject payload = buildPayload(context, sender, body, receivedAt);

            saveSmsLocally(context, payload);
            MainActivity.notifyMessagesUpdated(context);

            NetworkClient.sendEvent(context, payload);

            Log.d(TAG, "Incoming SMS captured and processed");
        } catch (Exception e) {
            Log.e(TAG, "Failed to process SMS", e);
        }
    }

    private boolean isSmsForwardingEnabled(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        return prefs.getBoolean(KEY_SMS_FORWARDING, true);
    }

    private boolean isAllowedByFilters(Context context, String sender, String body) {
        SharedPreferences filters = context.getSharedPreferences(
                FILTERS_PREFS,
                Context.MODE_PRIVATE
        );

        String normalizedSender = safeString(sender).toLowerCase().trim();
        String normalizedBody = safeString(body).toLowerCase().trim();
        String combined = normalizedSender + " " + normalizedBody;

        if (!filters.getBoolean(KEY_BLACKLIST, true) && isBlacklisted(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_VERIFICATION_CODES, true) && isVerificationCode(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_BANK_MESSAGES, true) && isBankMessage(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_AD_SMS, false) && isAdSms(combined)) {
            return false;
        }

        if (!filters.getBoolean(KEY_INTERNATIONAL_NUMBERS, true)
                && isInternationalSender(normalizedSender)) {
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

    private boolean isAdSms(String text) {
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

    private boolean isInternationalSender(String sender) {
        return sender.startsWith("+") && !sender.startsWith("+7");
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

    private JSONObject buildPayload(Context context, String sender, String body, long receivedAt) {
        JSONObject payload = new JSONObject();

        try {
            SharedPreferences prefs = context.getSharedPreferences(
                    SETTINGS_PREFS,
                    Context.MODE_PRIVATE
            );

            String deviceName = prefs.getString(
                    KEY_DEVICE_NAME,
                    Build.MANUFACTURER + " " + Build.MODEL
            );

            String deviceId = prefs.getString(KEY_DEVICE_ID, "");

            payload.put("id", "sms_" + receivedAt);
            payload.put("type", "sms");
            payload.put("sender", sender);
            payload.put("text", body);
            payload.put("deviceName", deviceName == null ? "" : deviceName);
            payload.put("deviceId", deviceId == null ? "" : deviceId);
            payload.put("status", "received");
            payload.put("receivedAt", receivedAt);
        } catch (Exception e) {
            Log.e(TAG, "Failed to build SMS payload", e);
        }

        return payload;
    }

    private void saveSmsLocally(Context context, JSONObject message) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(
                    STORAGE_PREFS,
                    Context.MODE_PRIVATE
            );

            String currentJson = prefs.getString(SMS_LIST_KEY, "[]");

            JSONArray oldMessages = new JSONArray(currentJson);
            JSONArray newMessages = new JSONArray();

            newMessages.put(message);

            int limit = Math.min(oldMessages.length(), MAX_MESSAGES - 1);

            for (int i = 0; i < limit; i++) {
                newMessages.put(oldMessages.getJSONObject(i));
            }

            prefs.edit()
                    .putString(SMS_LIST_KEY, newMessages.toString())
                    .apply();
        } catch (Exception e) {
            Log.e(TAG, "Failed to save SMS locally", e);
        }
    }

    private String safeString(String value) {
        return value == null ? "" : value;
    }
}