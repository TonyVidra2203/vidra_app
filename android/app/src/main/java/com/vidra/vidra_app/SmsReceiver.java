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

    private static final String PREFS_NAME = "vidra_native_storage";
    private static final String SMS_LIST_KEY = "sms_messages";
    private static final int MAX_MESSAGES = 100;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null || intent.getExtras() == null) {
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

        Log.d(TAG, "SMS from: " + sender);
        Log.d(TAG, "SMS body: " + messageBody);

        saveSms(context, sender, messageBody.toString(), receivedAt);
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

    private void saveSms(Context context, String sender, String body, long receivedAt) {
        try {
            SharedPreferences prefs = context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
            );

            String currentJson = prefs.getString(SMS_LIST_KEY, "[]");
            JSONArray oldMessages = new JSONArray(currentJson);
            JSONArray newMessages = new JSONArray();

            JSONObject message = new JSONObject();
            message.put("id", String.valueOf(receivedAt));
            message.put("type", "sms");
            message.put("sender", sender);
            message.put("text", body);
            message.put("deviceName", Build.MODEL);
            message.put("status", "received");
            message.put("receivedAt", receivedAt);

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