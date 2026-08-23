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
                    try {
                        val res = runShellCommand(command)
                        val exitCode = (res["exitCode"] as? Int) ?: (res["exitCode"]?.toString()?.toIntOrNull() ?: -1)
                        if (exitCode != 0) {
                            val stderr = (res["stderr"] as? String) ?: ""
                            val stdout = (res["stdout"] as? String) ?: ""
                            val message = if (stderr.isNotEmpty()) stderr else stdout
                            result.error("SHIZUKU_CMD_FAILED", message, exitCode)
                        } else {
                            result.success(res)
                        }
                    } catch (ex: Exception) {
                        result.error("EXEC_ERROR", ex.message ?: "Unknown error", null)
                    }
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
        if (!isShizukuAvailable()) return false
        return try {
            // Use reflection so this file can compile even if Shizuku API classes are not present at compile time.
            val shizukuClass = try {
                Class.forName("moe.shizuku.api.Shizuku")
            } catch (e: ClassNotFoundException) {
                try {
                    Class.forName("dev.rikka.shizuku.api.Shizuku")
                } catch (e2: ClassNotFoundException) {
                    null
                }
            }
            if (shizukuClass == null) return false
            val method = shizukuClass.getMethod("checkSelfPermission")
            val res = method.invoke(null) as Int
            res == android.content.pm.PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) {
            false
        }
    }

    private fun requestShizukuPermission() {
        try {
            val intent = Intent("moe.shizuku.manager.ACTION_REQUEST_PERMISSION")
            intent.setPackage("moe.shizuku.manager")
            startActivityForResult(intent, REQUEST_SHIZUKU)
        } catch (e: Exception) {
            try {
                val launch = packageManager.getLaunchIntentForPackage("moe.shizuku.manager")
                if (launch != null) startActivity(launch)
            } catch (_: Exception) {
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun runShellCommand(command: String): Map<String, Any?> {
        try {
            // Try to use Shizuku via reflection (so compile-time dependency is not required).
            val shizukuClass = try {
                Class.forName("moe.shizuku.api.Shizuku")
            } catch (e: ClassNotFoundException) {
                try {
                    Class.forName("dev.rikka.shizuku.api.Shizuku")
                } catch (e2: ClassNotFoundException) {
                    null
                }
            }

            if (shizukuClass != null) {
                try {
                    val checkMethod = shizukuClass.getMethod("checkSelfPermission")
                    val perm = checkMethod.invoke(null) as Int
                    if (perm == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        val newProcessMethod = shizukuClass.getMethod("newProcess", Array<String>::class.java, java.io.File::class.java, java.io.File::class.java)
                        val process = newProcessMethod.invoke(null, arrayOf("sh", "-c", command), null, null) as Process

                        val stdout = StringBuilder()
                        val stderr = StringBuilder()

                        val outReader = BufferedReader(InputStreamReader(process.inputStream))
                        var line: String?
                        while (outReader.readLine().also { line = it } != null) {
                            stdout.append(line).append("\n")
                        }

                        val errReader = BufferedReader(InputStreamReader(process.errorStream))
                        while (errReader.readLine().also { line = it } != null) {
                            stderr.append(line).append("\n")
                        }

                        val exitCode = process.waitFor()
                        val map: MutableMap<String, Any?> = HashMap()
                        map["exitCode"] = exitCode
                        map["stdout"] = stdout.toString()
                        map["stderr"] = stderr.toString()
                        return map
                    }
                } catch (_: Exception) {
                    // If reflection call fails, fall through to normal exec fallback below.
                }
            }

            // Fallback to normal process execution
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            val stdout = StringBuilder()
            val stderr = StringBuilder()

            val outReader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (outReader.readLine().also { line = it } != null) {
                stdout.append(line).append("\n")
            }

            val errReader = BufferedReader(InputStreamReader(process.errorStream))
            while (errReader.readLine().also { line = it } != null) {
                stderr.append(line).append("\n")
            }

            val exitCode = process.waitFor()
            val map: MutableMap<String, Any?> = HashMap()
            map["exitCode"] = exitCode
            map["stdout"] = stdout.toString()
            map["stderr"] = stderr.toString()
            return map
        } catch (ex: Exception) {
            val map: MutableMap<String, Any?> = HashMap()
            map["exitCode"] = -1
            map["stdout"] = ""
            map["stderr"] = ex.message ?: "Ошибка выполнения shell-команды"
            return map
        }
    }
}
