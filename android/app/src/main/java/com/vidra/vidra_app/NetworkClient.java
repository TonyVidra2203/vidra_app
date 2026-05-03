package com.vidra.vidra_app;

import android.content.Context;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.util.Log;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.OutputStream;
import java.io.InputStreamReader;
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

        String relayUrl = clean(prefs.getString(KEY_RELAY_URL, ""));
        String apiKey = clean(prefs.getString(KEY_RELAY_API_KEY, ""));

        if (relayUrl.isEmpty()) {
            Log.d(TAG, "Relay URL is empty. Event saved locally only.");
            return;
        }

        JSONObject event = enrichPayload(payload);

        new Thread(() -> postJson(relayUrl, apiKey, event.toString())).start();
    }

    private static JSONObject enrichPayload(JSONObject payload) {
        try {
            if (!payload.has("sentAt")) {
                payload.put("sentAt", System.currentTimeMillis());
            }

            if (!payload.has("source")) {
                payload.put("source", "android");
            }

            if (!payload.has("client")) {
                payload.put("client", "vidra");
            }
        } catch (Exception ignored) {
        }

        return payload;
    }

    private static void postJson(String relayUrl, String apiKey, String jsonBody) {
        HttpURLConnection connection = null;

        try {
            URL url = new URL(relayUrl);
            connection = (HttpURLConnection) url.openConnection();

            connection.setRequestMethod("POST");
            connection.setConnectTimeout(CONNECT_TIMEOUT_MS);
            connection.setReadTimeout(READ_TIMEOUT_MS);
            connection.setDoInput(true);
            connection.setDoOutput(true);
            connection.setUseCaches(false);

            connection.setRequestProperty(
                    "Content-Type",
                    "application/json; charset=utf-8"
            );
            connection.setRequestProperty("Accept", "application/json");
            connection.setRequestProperty("User-Agent", "VidRA-Android");

            if (!apiKey.isEmpty()) {
                connection.setRequestProperty("Authorization", "Bearer " + apiKey);
                connection.setRequestProperty("X-Api-Key", apiKey);
            }

            byte[] bodyBytes = jsonBody.getBytes(StandardCharsets.UTF_8);
            connection.setFixedLengthStreamingMode(bodyBytes.length);

            try (OutputStream outputStream = connection.getOutputStream()) {
                outputStream.write(bodyBytes);
                outputStream.flush();
            }

            int responseCode = connection.getResponseCode();
            String responseBody = readResponse(connection, responseCode);

            if (responseCode >= 200 && responseCode < 300) {
                Log.d(TAG, "Event sent to relay. Code: " + responseCode);
                return;
            }

            Log.e(
                    TAG,
                    "Relay rejected event. Code: "
                            + responseCode
                            + ", body: "
                            + responseBody
            );
        } catch (Exception e) {
            Log.e(TAG, "Failed to send event to relay", e);
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private static String readResponse(
            HttpURLConnection connection,
            int responseCode
    ) {
        try {
            BufferedReader reader;

            if (responseCode >= 200 && responseCode < 400) {
                reader = new BufferedReader(
                        new InputStreamReader(
                                connection.getInputStream(),
                                StandardCharsets.UTF_8
                        )
                );
            } else {
                if (connection.getErrorStream() == null) {
                    return "";
                }

                reader = new BufferedReader(
                        new InputStreamReader(
                                connection.getErrorStream(),
                                StandardCharsets.UTF_8
                        )
                );
            }

            StringBuilder builder = new StringBuilder();
            String line;

            while ((line = reader.readLine()) != null) {
                builder.append(line);
            }

            reader.close();
            return builder.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private static boolean hasInternet(Context context) {
        try {
            ConnectivityManager manager =
                    (ConnectivityManager) context.getSystemService(
                            Context.CONNECTIVITY_SERVICE
                    );

            if (manager == null) {
                return false;
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Network network = manager.getActiveNetwork();

                if (network == null) {
                    return false;
                }

                NetworkCapabilities capabilities =
                        manager.getNetworkCapabilities(network);

                return capabilities != null
                        && capabilities.hasCapability(
                        NetworkCapabilities.NET_CAPABILITY_INTERNET
                );
            }

            android.net.NetworkInfo activeNetwork = manager.getActiveNetworkInfo();
            return activeNetwork != null && activeNetwork.isConnected();
        } catch (Exception e) {
            return false;
        }
    }

    private static String clean(String value) {
        if (value == null) {
            return "";
        }

        return value.trim();
    }
}