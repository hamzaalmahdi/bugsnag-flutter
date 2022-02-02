package com.bugsnag.flutter.test.app;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.bugsnag.android.Bugsnag;
import com.bugsnag.android.Configuration;
import com.bugsnag.android.EndpointConfiguration;
import com.bugsnag.flutter.test.app.scenario.Scenario;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MazeRunnerMethodCallHandler implements MethodChannel.MethodCallHandler {
    public static final String TAG = "MazeRunner";
    private final Handler scenarioRunner = new Handler(Looper.getMainLooper());
    private final Context context;

    MazeRunnerMethodCallHandler(@NonNull Context context) {
        this.context = context;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (call.method.equals("runScenario")) {
            runScenario(call, result);
        } else if (call.method.equals("startBugsnag")) {
            Configuration config = Configuration.load(context);
            config.setApiKey("abc12312312312312312312312312312");
            if (call.hasArgument("notifyEndpoint") && call.hasArgument("sessionEndpoint")) {
                config.setEndpoints(new EndpointConfiguration(
                        call.argument("notifyEndpoint"),
                        call.argument("sessionEndpoint")
                ));
            }
            Bugsnag.start(context, config);
            result.success(null);
        } else {
            result.notImplemented();
        }
    }

    private void runScenario(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String scenarioName = call.argument("scenarioName");
        if (scenarioName == null || scenarioName.isEmpty()) {
            Log.w(TAG, "No scenario name specified: " + scenarioName);
            result.error("NullPointerException", "scenarioName", null);
            return;
        }

        String scenarioClassName = "com.bugsnag.flutter.test.app.scenario." + scenarioName;
        Scenario scenario = initScenario(result, scenarioClassName);

        if (scenario != null) {
            // we push all scenarios to the main thread to stop Flutter catching the exceptions
            scenarioRunner.post(() -> {
                scenario.run(call.argument("extraConfig"));
                result.success(null);
            });
        }
    }

    @Nullable
    private Scenario initScenario(MethodChannel.Result result, String scenarioName) {
        Log.v(TAG, "Attempting to init scenario: " + scenarioName);
        Scenario scenario = null;
        try {
            @SuppressWarnings("unchecked")
            Class<? extends Scenario> scenarioClass = (Class<? extends Scenario>) Class.forName(scenarioName);
            scenario = scenarioClass.newInstance();
        } catch (Exception e) {
            Log.e(TAG, "Failed to init scenario: " + scenarioName, e);
            result.error(e.getClass().getSimpleName(), e.getMessage(), scenarioName);
        }

        return scenario;
    }
}
