package com.vidra.vidra_app;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.util.Log;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public final class NetworkClient {
    private static final String TAG = "VidRA_NETWORK";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String KEY_ONLY_WITH_INTERNET = "onlyWithInternet";
    private static final String KEY_RELAY_URL = "relayUrl";
    private static final String KEY_RELAY_API_KEY = "relayApiKey";

    private static final int CONNECT_TIMEOUT_MS = 10000;
    private static final int READ_TIMEOUT_MS = 10000;

    private NetworkClient() {
    }

    public static void sendEvent(Context context, JSONObject payload) {
        if (context == null || payload == null) {
            return;
        }

        SharedPreferences prefs = context.getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        boolean onlyWithInternet = prefs.getBoolean(KEY_ONLY_WITH_INTERNET, false);

        if (onlyWithInternet && !hasInternet(context)) {
            Log.d(TAG, "Internet is required, but device is offline");
            return;
        }

        String relayUrl = prefs.getString(KEY_RELAY_URL, "");
        String apiKey = prefs.getString(KEY_RELAY_API_KEY, "");

        if (relayUrl == null || relayUrl.trim().isEmpty()) {
            Log.d(TAG, "Relay URL is empty. Event saved locally only.");
            return;
        }

        String cleanRelayUrl = relayUrl.trim();
        String cleanApiKey = apiKey == null ? "" : apiKey.trim();
        String jsonBody = payload.toString();

        new Thread(() -> postJson(cleanRelayUrl, cleanApiKey, jsonBody)).start();
    }

    private static void postJson(String relayUrl, String apiKey, String jsonBody) {
        HttpURLConnection connection = null;

        try {
            URL url = new URL(relayUrl);
            connection = (HttpURLConnection) url.openConnection();

            connection.setRequestMethod("POST");
            connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
            connection.setReadTimeout(READ_TIMEOUT_MS);
            connection.setDoOutput(true);
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");

            if (!apiKey.isEmpty()) {
                connection.setRequestProperty("Authorization", "Bearer " + apiKey);
                connection.setRequestProperty("X-Api-Key", apiKey);
            }

            byte[] bodyBytes = jsonBody.getBytes(StandardCharsets.UTF_8);

            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(bodyBytes);
            }

            int responseCode = connection.getResponseCode();
            Log.d(TAG, "Relay response code: " + responseCode);
        } catch (Exception e) {
            Log.e(TAG, "Failed to send event to relay", e);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private static boolean hasInternet(Context context) {
        try {
            ConnectivityManager manager =
                    (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);

            if (manager == null) {
                return false;
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Network network = manager.getActiveNetwork();

                if (network == null) {
                    return false;
                }

                NetworkCapabilities capabilities = manager.getNetworkCapabilities(network);

                return capabilities != null
                        && capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET);
            }

            android.net.NetworkInfo activeNetwork = manager.getActiveNetworkInfo();

            return activeNetwork != null && activeNetwork.isConnected();
        } catch (Exception e) {
            return false;
        }
    }
}