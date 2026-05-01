package com.vidra.vidra_app;

import android.util.Log;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;

public class NetworkClient {
    private static final String TAG = "VidRA_NET";

    // ⚠️ ВРЕМЕННО (потом заменим на твой сервер)
    private static final String API_URL = "https://webhook.site/YOUR_TEST_URL";

    public static void sendEvent(JSONObject data) {
        new Thread(() -> {
            try {
                URL url = new URL(API_URL);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();

                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setDoOutput(true);
                conn.setConnectTimeout(5000);
                conn.setReadTimeout(5000);

                OutputStream os = conn.getOutputStream();
                os.write(data.toString().getBytes("UTF-8"));
                os.close();

                int responseCode = conn.getResponseCode();

                Log.d(TAG, "Sent event, code=" + responseCode);

                conn.disconnect();
            } catch (Exception e) {
                Log.e(TAG, "Send failed", e);
            }
        }).start();
    }
}