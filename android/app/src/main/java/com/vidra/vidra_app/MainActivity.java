package com.vidra.vidra_app;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.PowerManager;
import android.provider.Settings;
import android.text.TextUtils;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_NAME = "vidra/android_permissions";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL_NAME
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "openNotificationListenerSettings":
                    openNotificationListenerSettings();
                    result.success(true);
                    break;

                case "isNotificationListenerEnabled":
                    result.success(isNotificationListenerEnabled());
                    break;

                case "openBatteryOptimizationSettings":
                    openBatteryOptimizationSettings();
                    result.success(true);
                    break;

                case "isBatteryOptimizationDisabled":
                    result.success(isBatteryOptimizationDisabled());
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private void openNotificationListenerSettings() {
        Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
        startActivity(intent);
    }

    private boolean isNotificationListenerEnabled() {
        String enabledListeners = Settings.Secure.getString(
                getContentResolver(),
                "enabled_notification_listeners"
        );

        if (enabledListeners == null || enabledListeners.isEmpty()) {
            return false;
        }

        String[] names = enabledListeners.split(":");

        for (String name : names) {
            ComponentName componentName = ComponentName.unflattenFromString(name);

            if (
                    componentName != null &&
                            TextUtils.equals(getPackageName(), componentName.getPackageName())
            ) {
                return true;
            }
        }

        return false;
    }

    private void openBatteryOptimizationSettings() {
        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);

        if (!powerManager.isIgnoringBatteryOptimizations(getPackageName())) {
            Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + getPackageName()));
            startActivity(intent);
            return;
        }

        Intent intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
        startActivity(intent);
    }

    private boolean isBatteryOptimizationDisabled() {
        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
        return powerManager.isIgnoringBatteryOptimizations(getPackageName());
    }
}