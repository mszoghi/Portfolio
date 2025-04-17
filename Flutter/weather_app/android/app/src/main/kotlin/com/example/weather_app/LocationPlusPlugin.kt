package com.example.weather_app

import android.app.Activity
import android.content.Context
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.FusedLocationProviderClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class LocationPlusPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "location_plus")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCurrentLocation" -> {
                activity?.let { activity ->
                    fusedLocationClient = LocationServices.getFusedLocationProviderClient(activity)
                    fusedLocationClient.lastLocation
                        .addOnSuccessListener { location ->
                            val locationData = HashMap<String, Any>()
                            if (location != null) {
                                locationData["latitude"] = location.latitude.toString()
                                locationData["longitude"] = location.longitude.toString()
                                locationData["accuracy"] = location.accuracy.toString()
                                locationData["locality"] = "unknown"
                                locationData["postalCode"] = "unknown"
                                locationData["administrativeArea"] = "unknown"
                                locationData["country"] = "unknown"
                                locationData["ipAddress"] = "0"
                                result.success(locationData)
                            } else {
                                result.error("LOCATION_UNAVAILABLE", "Location data is unavailable", null)
                            }
                        }
                        .addOnFailureListener { e ->
                            result.error("LOCATION_ERROR", e.message, null)
                        }
                } ?: result.error("ACTIVITY_NULL", "Activity is null", null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }
}