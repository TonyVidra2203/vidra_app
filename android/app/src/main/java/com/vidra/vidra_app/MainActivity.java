package com.vidra.vidra_app;

import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import android.content.Context;
import android.content.SharedPreferences;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "vidra/native";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {

            switch (call.method) {

                case "getSms":
                    result.success(getSmsList());
                    break;

                case "openNotificationSettings":
                    startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS));
                    result.success(null);
                    break;

                case "openBatterySettings":
                    startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS));
                    result.success(null);
                    break;

                default:
                    result.notImplemented();
                    break;
            }
        });
    }

    private String getSmsList() {
        SharedPreferences prefs = getSharedPreferences(
                "vidra_native_storage",
                Context.MODE_PRIVATE
        );

        return prefs.getString("sms_messages", "[]");
    }
}