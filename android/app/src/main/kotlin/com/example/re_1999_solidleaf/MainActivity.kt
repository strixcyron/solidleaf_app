package com.example.re_1999_solidleaf

import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.re_1999_solidleaf/shizuku"
    private val REQUEST_SHIZUKU = 1001
    private val SERVICE_BIND_TIMEOUT_MS = 10000L

    private val mainHandler = Handler(Looper.getMainLooper())

    // The persistent Shizuku UserService connection used for direct Java file
    // I/O in the shell/root identity (see FileTransferUserService for why this
    // is required instead of spawning "sh -c" subprocesses).
    private var fileService: IFileTransferService? = null
    private var pendingServiceResult: MethodChannel.Result? = null
    private var pendingServiceTimeout: Runnable? = null

    private val userServiceArgs: Shizuku.UserServiceArgs by lazy {
        Shizuku.UserServiceArgs(ComponentName(packageName, FileTransferUserService::class.java.name))
            .daemon(false)
            .processNameSuffix("filesvc")
            .debuggable(false)
            .version(1)
    }

    private val fileServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            fileService = if (binder != null && binder.pingBinder()) {
                IFileTransferService.Stub.asInterface(binder)
            } else {
                null
            }
            completePendingServiceResult(fileService != null, null)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            fileService = null
        }
    }

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
                    val args = call.arguments
                    val command: String
                    val stdinBytes: ByteArray?
                    if (args is Map<*, *>) {
                        command = args["command"] as? String ?: ""
                        stdinBytes = args["stdin"] as? ByteArray
                    } else {
                        command = args as? String ?: ""
                        stdinBytes = null
                    }
                    try {
                        val res = runShellCommand(command, stdinBytes)
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
                "ensureFileService" -> ensureFileService(result)
                "fsMkdirs" -> {
                    val path = call.arguments as? String ?: ""
                    try {
                        result.success(requireFileService().mkdirs(path))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                "fsWriteChunk" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String ?: ""
                    val data = args?.get("data") as? ByteArray ?: ByteArray(0)
                    val append = args?.get("append") as? Boolean ?: false
                    try {
                        result.success(requireFileService().writeChunk(path, data, append))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                "fsReadChunk" -> {
                    val args = call.arguments as? Map<*, *>
                    val path = args?.get("path") as? String ?: ""
                    val offset = (args?.get("offset") as? Number)?.toLong() ?: 0L
                    val length = (args?.get("length") as? Number)?.toInt() ?: 0
                    try {
                        result.success(requireFileService().readChunk(path, offset, length))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                "fsFileSize" -> {
                    val path = call.arguments as? String ?: ""
                    try {
                        result.success(requireFileService().fileSize(path))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                "fsDeleteRecursive" -> {
                    val path = call.arguments as? String ?: ""
                    try {
                        result.success(requireFileService().deleteRecursive(path))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                "fsExists" -> {
                    val path = call.arguments as? String ?: ""
                    try {
                        result.success(requireFileService().exists(path))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                "fsIsDirectory" -> {
                    val path = call.arguments as? String ?: ""
                    try {
                        result.success(requireFileService().isDirectory(path))
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requireFileService(): IFileTransferService {
        return fileService ?: throw IllegalStateException("Shizuku file service is not bound. Call ensureFileService first.")
    }

    private fun completePendingServiceResult(success: Boolean, error: String?) {
        pendingServiceTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingServiceTimeout = null
        val pending = pendingServiceResult ?: return
        pendingServiceResult = null
        if (error != null) {
            pending.error("SERVICE_BIND_FAILED", error, null)
        } else {
            pending.success(success)
        }
    }

    private fun ensureFileService(result: MethodChannel.Result) {
        val current = fileService
        if (current != null && current.asBinder().pingBinder()) {
            result.success(true)
            return
        }

        if (!isShizukuAvailable()) {
            result.error("SHIZUKU_NOT_AVAILABLE", "Shizuku app is not installed or not running", null)
            return
        }
        if (!checkShizukuPermission()) {
            result.error("SHIZUKU_PERMISSION_DENIED", "Shizuku permission is not granted", null)
            return
        }

        pendingServiceResult = result
        val timeout = Runnable {
            if (pendingServiceResult === result) {
                pendingServiceResult = null
                result.error("SERVICE_TIMEOUT", "Shizuku user service did not connect in time", null)
            }
        }
        pendingServiceTimeout = timeout
        mainHandler.postDelayed(timeout, SERVICE_BIND_TIMEOUT_MS)

        try {
            Shizuku.bindUserService(userServiceArgs, fileServiceConnection)
        } catch (e: Exception) {
            completePendingServiceResult(false, e.message ?: "bindUserService failed")
        }
    }

    private fun isShizukuAvailable(): Boolean {
        return try {
            packageManager.getPackageInfo("moe.shizuku.privileged.api", PackageManager.GET_META_DATA)
            Shizuku.pingBinder()
        } catch (_: Exception) {
            false
        }
    }

    private fun checkShizukuPermission(): Boolean {
        return try {
            if (!Shizuku.pingBinder()) return false
            if (Shizuku.isPreV11()) return false
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) {
            false
        }
    }

    private fun requestShizukuPermission() {
        try {
            if (Shizuku.pingBinder() && !Shizuku.isPreV11()) {
                Shizuku.requestPermission(REQUEST_SHIZUKU)
                return
            }
        } catch (_: Exception) {
            // Fall through to opening the Shizuku manager app below.
        }
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

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (fileService != null) {
                Shizuku.unbindUserService(userServiceArgs, fileServiceConnection, true)
            }
        } catch (_: Exception) {
        }
    }

    /**
     * Legacy shell-command execution, kept for operations still expressed as
     * shell one-liners. Writes into another app's protected Android/data/&lt;pkg&gt;
     * folder must go through the fs-prefixed methods (ensureFileService, fsMkdirs, ...)
     * instead — see FileTransferUserService for why a spawned "sh -c" subprocess
     * cannot reliably do this even when Shizuku permission is granted.
     */
    private fun runShellCommand(command: String, stdinBytes: ByteArray? = null): Map<String, Any?> {
        try {
            val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
            return readProcessResult(process, stdinBytes)
        } catch (ex: Exception) {
            val map: MutableMap<String, Any?> = HashMap()
            map["exitCode"] = -1
            map["stdout"] = ""
            map["stderr"] = ex.message ?: "Ошибка выполнения shell-команды"
            return map
        }
    }

    /**
     * Writes optional stdin bytes on a background thread (to avoid pipe deadlocks with
     * large payloads) while concurrently draining stdout/stderr, then waits for exit.
     */
    private fun readProcessResult(process: Process, stdinBytes: ByteArray?): Map<String, Any?> {
        val writerThread = Thread {
            try {
                if (stdinBytes != null && stdinBytes.isNotEmpty()) {
                    process.outputStream.write(stdinBytes)
                }
            } catch (_: Exception) {
                // Ignore broken pipe if the process already exited/failed.
            } finally {
                try {
                    process.outputStream.close()
                } catch (_: Exception) {
                }
            }
        }
        writerThread.start()

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

        writerThread.join()
        val exitCode = process.waitFor()
        val map: MutableMap<String, Any?> = HashMap()
        map["exitCode"] = exitCode
        map["stdout"] = stdout.toString()
        map["stderr"] = stderr.toString()
        return map
    }
}
