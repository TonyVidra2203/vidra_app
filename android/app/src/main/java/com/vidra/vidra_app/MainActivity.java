package com.vidra.vidra_app;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.TextUtils;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "vidra/android_permissions";

    private static final String PREFS_NAME = "vidra_sender_settings";

    private static final String KEY_SMS_FORWARDING = "smsForwarding";
    private static final String KEY_PUSH_FORWARDING = "pushForwarding";
    private static final String KEY_BACKGROUND_MODE = "backgroundMode";
    private static final String KEY_ONLY_WITH_INTERNET = "onlyWithInternet";
    private static final String KEY_DEVICE_NAME = "deviceName";
    private static final String KEY_DEVICE_ID = "deviceId";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
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

                case "saveSenderSettings":
                    saveSenderSettings(
                            call.argument(KEY_SMS_FORWARDING),
                            call.argument(KEY_PUSH_FORWARDING),
                            call.argument(KEY_BACKGROUND_MODE),
                            call.argument(KEY_ONLY_WITH_INTERNET),
                            call.argument(KEY_DEVICE_NAME),
                            call.argument(KEY_DEVICE_ID)
                    );
                    result.success(null);
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });
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
            if (powerManager == null) {
                return false;
            }

            return powerManager.isIgnoringBatteryOptimizations(getPackageName());
        } catch (Exception e) {
            return false;
        }
    }

    private void openBatteryOptimizationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                intent.setData(Uri.parse("package:" + getPackageName()));
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                return;
            }

            openAppSettings();
        } catch (Exception e) {
            try {
                Intent intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
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
            String deviceId
    ) {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);

        prefs.edit()
                .putBoolean(KEY_SMS_FORWARDING, smsForwarding != null ? smsForwarding : true)
                .putBoolean(KEY_PUSH_FORWARDING, pushForwarding != null ? pushForwarding : true)
                .putBoolean(KEY_BACKGROUND_MODE, backgroundMode != null ? backgroundMode : true)
                .putBoolean(KEY_ONLY_WITH_INTERNET, onlyWithInternet != null && onlyWithInternet)
                .putString(KEY_DEVICE_NAME, cleanOrDefault(deviceName, "Рабочий телефон"))
                .putString(KEY_DEVICE_ID, cleanOrDefault(deviceId, ""))
                .apply();
    }

    private String cleanOrDefault(String value, String defaultValue) {
        if (value == null || value.trim().isEmpty()) {
            return defaultValue;
        }

        return value.trim();
    }
}