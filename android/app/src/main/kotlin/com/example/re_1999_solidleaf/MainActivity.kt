package com.example.re_1999_solidleaf

import android.content.pm.PackageManager
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import android.content.Intent

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.re_1999_solidleaf/shizuku"
    private val REQUEST_SHIZUKU = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkShizukuStatus" -> {
                    result.success(isShizukuAvailable())
                }
                "checkPermission" -> {
                    result.success(checkShizukuPermission())
                }
                "requestPermission" -> {
                    requestShizukuPermission()
                    result.success(true)
                }
                "executeShellCommand" -> {
                    val command = call.arguments as? String ?: ""
                    result.success(runShellCommand(command))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isShizukuAvailable(): Boolean {
        return try {
            packageManager.getPackageInfo("moe.shizuku.privileged.api", PackageManager.GET_META_DATA)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun checkShizukuPermission(): Boolean {
        // Best-effort: try calling a harmless command through Shizuku; if it succeeds assume permission granted
        if (!isShizukuAvailable()) return false
        return try {
            val test = runShellCommand("id")
            !test.contains("Error")
        } catch (_: Exception) {
            false
        }
    }

    private fun requestShizukuPermission() {
        try {
            // Try to open Shizuku manager permission request activity
            val intent = Intent("moe.shizuku.manager.ACTION_REQUEST_PERMISSION")
            intent.setPackage("moe.shizuku.manager")
            startActivityForResult(intent, REQUEST_SHIZUKU)
        } catch (e: Exception) {
            // Fallback: try to open Shizuku app
            try {
                val launch = packageManager.getLaunchIntentForPackage("moe.shizuku.manager")
                if (launch != null) startActivity(launch)
            } catch (_: Exception) {
                // ignore
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Nothing to do here; Dart side will re-check permission state via checkPermission
    }

    private fun runShellCommand(command: String): String {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val output = StringBuilder()
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.append(line).append(System.lineSeparator())
            }
            process.waitFor()
            output.toString()
        } catch (ex: Exception) {
            ex.message ?: "Ошибка выполнения shell-команды"
        }
    }
}
