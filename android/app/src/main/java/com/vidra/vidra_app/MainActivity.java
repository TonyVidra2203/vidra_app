package com.vidra.vidra_app;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONArray;
import org.json.JSONObject;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "vidra/android_permissions";
    private static final String EVENTS_CHANNEL = "vidra/native_events";

    private static final String ACTION_MESSAGES_UPDATED = "com.vidra.vidra_app.MESSAGES_UPDATED";
    private static final String EVENT_MESSAGES_UPDATED = "messagesUpdated";

    private static final String SETTINGS_PREFS = "vidra_sender_settings";
    private static final String STORAGE_PREFS = "vidra_native_storage";
    private static final String FILTERS_PREFS = "vidra_filter_settings";

    private static final String KEY_SMS_FORWARDING = "smsForwarding";
    private static final String KEY_PUSH_FORWARDING = "pushForwarding";
    private static final String KEY_BACKGROUND_MODE = "backgroundMode";
    private static final String KEY_ONLY_WITH_INTERNET = "onlyWithInternet";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";
    private static final String KEY_RELAY_URL = "relayUrl";
    private static final String KEY_RELAY_API_KEY = "relayApiKey";

    private static final String KEY_VERIFICATION_CODES = "verificationCodes";
    private static final String KEY_BANK_MESSAGES = "bankMessages";
    private static final String KEY_AD_SMS = "adSms";
    private static final String KEY_INTERNATIONAL_NUMBERS = "internationalNumbers";
    private static final String KEY_CRYPTO_SPAM = "cryptoSpam";
    private static final String KEY_BLACKLIST = "blacklist";

    private static final String SMS_LIST_KEY = "sms_messages";
    private static final String PUSH_LIST_KEY = "push_messages";

    private static final int SMS_PERMISSION_REQUEST = 2203;
    private static final int NOTIFICATION_PERMISSION_REQUEST = 2204;

    private EventChannel.EventSink eventSink;
    private BroadcastReceiver nativeEventsReceiver;

    public static void notifyMessagesUpdated(Context context) {
        if (context == null) {
            return;
        }

        Intent intent = new Intent(ACTION_MESSAGES_UPDATED);
        intent.setPackage(context.getPackageName());
        context.sendBroadcast(intent);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "requestSmsPermissions":
                    requestSmsPermissions();
                    result.success(hasSmsPermissions());
                    break;

                case "hasSmsPermissions":
                    result.success(hasSmsPermissions());
                    break;

                case "requestPostNotificationPermission":
                    requestPostNotificationPermission();
                    result.success(hasPostNotificationPermission());
                    break;

                case "hasPostNotificationPermission":
                    result.success(hasPostNotificationPermission());
                    break;

                case "isNotificationListenerEnabled":
                    result.success(isNotificationListenerEnabled());
                    break;

                case "openNotificationListenerSettings":
                    openNotificationListenerSettings();
                    result.success(null);
                    break;

                case "isBatteryOptimizationDisabled":
                    result.success(isBatteryOptimizationDisabled());
                    break;

                case "openBatteryOptimizationSettings":
                    openBatteryOptimizationSettings();
                    result.success(null);
                    break;

                case "openAppSettings":
                    openAppSettings();
                    result.success(null);
                    break;

                case "moveAppToBackground":
                    moveTaskToBack(true);
                    result.success(null);
                    break;

                case "saveSenderSettings":
                    saveSenderSettings(
                            call.argument(KEY_SMS_FORWARDING),
                            call.argument(KEY_PUSH_FORWARDING),
                            call.argument(KEY_BACKGROUND_MODE),
                            call.argument(KEY_ONLY_WITH_INTERNET),
                            call.argument(KEY_DEVICE_NAME),
                            call.argument(KEY_DEVICE_ID),
                            call.argument(KEY_RELAY_URL),
                            call.argument(KEY_RELAY_API_KEY)
                    );
                    result.success(null);
                    break;

                case "saveFilterSettings":
                    saveFilterSettings(
                            call.argument(KEY_VERIFICATION_CODES),
                            call.argument(KEY_BANK_MESSAGES),
                            call.argument(KEY_AD_SMS),
                            call.argument(KEY_INTERNATIONAL_NUMBERS),
                            call.argument(KEY_CRYPTO_SPAM),
                            call.argument(KEY_BLACKLIST)
                    );
                    result.success(null);
                    break;

                case "getFilterSettings":
                    result.success(getFilterSettings().toString());
                    break;

                case "getMainPhoneStatus":
                    result.success(getMainPhoneStatus().toString());
                    break;

                case "getNativeMessages":
                    result.success(getNativeMessages().toString());
                    break;

                case "clearNativeMessages":
                    clearNativeMessages();
                    notifyMessagesUpdated(this);
                    result.success(null);
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });

        new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                EVENTS_CHANNEL
        ).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });

        registerNativeEventsReceiver();
        syncRelayPollingState();
        syncBackgroundKeepAliveService();
    }

    @Override
    protected void onDestroy() {
        unregisterNativeEventsReceiver();
        super.onDestroy();
    }

    private void registerNativeEventsReceiver() {
        if (nativeEventsReceiver != null) {
            return;
        }

        nativeEventsReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (intent == null) {
                    return;
                }

                if (ACTION_MESSAGES_UPDATED.equals(intent.getAction())) {
                    sendNativeEvent(EVENT_MESSAGES_UPDATED);
                }
            }
        };

        IntentFilter filter = new IntentFilter(ACTION_MESSAGES_UPDATED);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                    nativeEventsReceiver,
                    filter,
                    Context.RECEIVER_NOT_EXPORTED
            );
        } else {
            registerReceiver(nativeEventsReceiver, filter);
        }
    }

    private void unregisterNativeEventsReceiver() {
        if (nativeEventsReceiver == null) {
            return;
        }

        try {
            unregisterReceiver(nativeEventsReceiver);
        } catch (Exception ignored) {
        }

        nativeEventsReceiver = null;
    }

    private void sendNativeEvent(String event) {
        if (eventSink == null) {
            return;
        }

        runOnUiThread(() -> {
            try {
                eventSink.success(event);
            } catch (Exception ignored) {
            }
        });
    }

    private boolean hasSmsPermissions() {
        return ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
                && ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED;
    }

    private void requestSmsPermissions() {
        if (!hasSmsPermissions()) {
            ActivityCompat.requestPermissions(
                    this,
                    new String[]{
                            Manifest.permission.RECEIVE_SMS,
                            Manifest.permission.READ_SMS
                    },
                    SMS_PERMISSION_REQUEST
            );
        }
    }

    private boolean hasPostNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true;
        }

        return ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED;
    }

    private void requestPostNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasPostNotificationPermission()) {
            ActivityCompat.requestPermissions(
                    this,
                    new String[]{Manifest.permission.POST_NOTIFICATIONS},
                    NOTIFICATION_PERMISSION_REQUEST
            );
        }
    }

    private boolean isNotificationListenerEnabled() {
        try {
            String packageName = getPackageName();
            String enabledListeners = Settings.Secure.getString(
                    getContentResolver(),
                    "enabled_notification_listeners"
            );

            if (TextUtils.isEmpty(enabledListeners)) {
                return false;
            }

            return enabledListeners.toLowerCase().contains(packageName.toLowerCase());
        } catch (Exception e) {
            return false;
        }
    }

    private void openNotificationListenerSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception e) {
            openAppSettings();
        }
    }

    private boolean isBatteryOptimizationDisabled() {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                return true;
            }

            PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
            return powerManager != null && powerManager.isIgnoringBatteryOptimizations(getPackageName());
        } catch (Exception e) {
            return false;
        }
    }

    private void openBatteryOptimizationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent intent = new Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                );
                intent.setData(Uri.parse("package:" + getPackageName()));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                return;
            }

            openAppSettings();
        } catch (Exception e) {
            try {
                Intent intent = new Intent(
                        Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                );
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
            } catch (Exception ignored) {
                openAppSettings();
            }
        }
    }

    private void openAppSettings() {
        try {
            Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            intent.setData(Uri.parse("package:" + getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        } catch (Exception ignored) {
        }
    }

    private void saveSenderSettings(
            Boolean smsForwarding,
            Boolean pushForwarding,
            Boolean backgroundMode,
            Boolean onlyWithInternet,
            String deviceName,
            String deviceId,
            String relayUrl,
            String relayApiKey
    ) {
        String cleanRelayUrl = cleanOrDefault(relayUrl, "");
        String cleanDeviceId = cleanOrDefault(deviceId, "");
        boolean enabledBackgroundMode = backgroundMode != null ? backgroundMode : true;

        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        prefs.edit()
                .putBoolean(
                        KEY_SMS_FORWARDING,
                        smsForwarding != null ? smsForwarding : true
                )
                .putBoolean(
                        KEY_PUSH_FORWARDING,
                        pushForwarding != null ? pushForwarding : true
                )
                .putBoolean(
                        KEY_BACKGROUND_MODE,
                        enabledBackgroundMode
                )
                .putBoolean(
                        KEY_ONLY_WITH_INTERNET,
                        onlyWithInternet != null && onlyWithInternet
                )
                .putString(
                        KEY_DEVICE_NAME,
                        cleanOrDefault(
                                deviceName,
                                Build.MANUFACTURER + " " + Build.MODEL
                        )
                )
                .putString(KEY_DEVICE_ID, cleanDeviceId)
                .putString(KEY_RELAY_URL, cleanRelayUrl)
                .putString(KEY_RELAY_API_KEY, cleanOrDefault(relayApiKey, ""))
                .apply();

        syncRelayPollingState(cleanRelayUrl, cleanDeviceId);
        syncBackgroundKeepAliveService(enabledBackgroundMode);
    }

    private void syncRelayPollingState() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        String relayUrl = cleanOrDefault(prefs.getString(KEY_RELAY_URL, ""), "");
        String deviceId = cleanOrDefault(prefs.getString(KEY_DEVICE_ID, ""), "");

        syncRelayPollingState(relayUrl, deviceId);
    }

    private void syncRelayPollingState(String relayUrl, String deviceId) {
        if (!relayUrl.isEmpty() && deviceId.isEmpty()) {
            RelayPollingReceiver.schedule(this);
        } else {
            RelayPollingReceiver.cancel(this);
        }
    }

    private void syncBackgroundKeepAliveService() {
        SharedPreferences prefs = getSharedPreferences(
                SETTINGS_PREFS,
                Context.MODE_PRIVATE
        );

        boolean enabledBackgroundMode = prefs.getBoolean(KEY_BACKGROUND_MODE, true);
        syncBackgroundKeepAliveService(enabledBackgroundMode);
    }

    private void syncBackgroundKeepAliveService(boolean enabledBackgroundMode) {
        if (enabledBackgroundMode) {
            BackgroundKeepAliveService.start(this);
        } else {
            BackgroundKeepAliveService.stop(this);
        }
    }

    private void saveFilterSettings(
            Boolean verificationCodes,
            Boolean bankMessages,
            Boolean adSms,
            Boolean internationalNumbers,
            Boolean cryptoSpam,
            Boolean blacklist
    ) {
        SharedPreferences prefs = getSharedPreferences(
                FILTERS_PREFS,
                Context.MODE_PRIVATE
        );

        prefs.edit()
                .putBoolean(
                        KEY_VERIFICATION_CODES,
                        verificationCodes != null ? verificationCodes : true
                )
                .putBoolean(
                        KEY_BANK_MESSAGES,
                        bankMessages != null ? bankMessages : true
                )
                .putBoolean(KEY_AD_SMS, adSms != null && adSms)
                .putBoolean(
                        KEY_INTERNATIONAL_NUMBERS,
                        internationalNumbers != null ? internationalNumbers : true
                )
                .putBoolean(KEY_CRYPTO_SPAM, cryptoSpam != null && cryptoSpam)
                .putBoolean(KEY_BLACKLIST, blacklist != null ? blacklist : true)
                .apply();
    }

    private JSONObject getFilterSettings() {
        JSONObject filters = new JSONObject();

        try {
            SharedPreferences prefs = getSharedPreferences(
                    FILTERS_PREFS,
                    Context.MODE_PRIVATE
            );

            filters.put(
                    KEY_VERIFICATION_CODES,
                    prefs.getBoolean(KEY_VERIFICATION_CODES, true)
            );
            filters.put(
                    KEY_BANK_MESSAGES,
                    prefs.getBoolean(KEY_BANK_MESSAGES, true)
            );
            filters.put(KEY_AD_SMS, prefs.getBoolean(KEY_AD_SMS, false));
            filters.put(
                    KEY_INTERNATIONAL_NUMBERS,
                    prefs.getBoolean(KEY_INTERNATIONAL_NUMBERS, true)
            );
            filters.put(
                    KEY_CRYPTO_SPAM,
                    prefs.getBoolean(KEY_CRYPTO_SPAM, false)
            );
            filters.put(KEY_BLACKLIST, prefs.getBoolean(KEY_BLACKLIST, true));
        } catch (Exception ignored) {
        }

        return filters;
    }

    private JSONObject getMainPhoneStatus() {
        JSONObject status = new JSONObject();

        try {
            SharedPreferences settings = getSharedPreferences(
                    SETTINGS_PREFS,
                    Context.MODE_PRIVATE
            );
            SharedPreferences storage = getSharedPreferences(
                    STORAGE_PREFS,
                    Context.MODE_PRIVATE
            );

            JSONArray smsMessages = new JSONArray(
                    storage.getString(SMS_LIST_KEY, "[]")
            );
            JSONArray pushMessages = new JSONArray(
                    storage.getString(PUSH_LIST_KEY, "[]")
            );

            String relayUrl = cleanOrDefault(
                    settings.getString(KEY_RELAY_URL, ""),
                    ""
            );
            String deviceId = cleanOrDefault(
                    settings.getString(KEY_DEVICE_ID, ""),
                    ""
            );

            status.put("smsPermission", hasSmsPermissions());
            status.put("postNotificationPermission", hasPostNotificationPermission());
            status.put("notificationListener", isNotificationListenerEnabled());
            status.put(
                    "batteryOptimizationDisabled",
                    isBatteryOptimizationDisabled()
            );
            status.put(
                    "smsForwarding",
                    settings.getBoolean(KEY_SMS_FORWARDING, true)
            );
            status.put(
                    "pushForwarding",
                    settings.getBoolean(KEY_PUSH_FORWARDING, true)
            );
            status.put(
                    "backgroundMode",
                    settings.getBoolean(KEY_BACKGROUND_MODE, true)
            );
            status.put(
                    "onlyWithInternet",
                    settings.getBoolean(KEY_ONLY_WITH_INTERNET, false)
            );
            status.put(
                    "deviceName",
                    settings.getString(
                            KEY_DEVICE_NAME,
                            Build.MANUFACTURER + " " + Build.MODEL
                    )
            );
            status.put("deviceId", deviceId);
            status.put("relayConfigured", !relayUrl.isEmpty());
            status.put("relayPollingEnabled", !relayUrl.isEmpty() && deviceId.isEmpty());
            status.put("smsCount", smsMessages.length());
            status.put("pushCount", pushMessages.length());
        } catch (Exception ignored) {
        }

        return status;
    }

    private JSONArray getNativeMessages() {
        JSONArray messages = new JSONArray();

        try {
            SharedPreferences storage = getSharedPreferences(
                    STORAGE_PREFS,
                    Context.MODE_PRIVATE
            );

            JSONArray smsMessages = new JSONArray(
                    storage.getString(SMS_LIST_KEY, "[]")
            );
            JSONArray pushMessages = new JSONArray(
                    storage.getString(PUSH_LIST_KEY, "[]")
            );

            for (int i = 0; i < smsMessages.length(); i++) {
                messages.put(smsMessages.getJSONObject(i));
            }

            for (int i = 0; i < pushMessages.length(); i++) {
                messages.put(pushMessages.getJSONObject(i));
            }
        } catch (Exception ignored) {
        }

        return messages;
    }

    private void clearNativeMessages() {
        getSharedPreferences(STORAGE_PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(SMS_LIST_KEY, "[]")
                .putString(PUSH_LIST_KEY, "[]")
                .apply();
    }

    private String cleanOrDefault(String value, String defaultValue) {
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }

        return value.trim();
    }
}