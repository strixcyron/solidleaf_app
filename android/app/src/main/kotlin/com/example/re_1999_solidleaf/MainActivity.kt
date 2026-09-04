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
    // HyperOS / Transsion (Infinix): UserService поднимается медленно.
    private val SERVICE_BIND_TIMEOUT_MS = 10000L
    private val SERVICE_BIND_RETRY_DELAY_MS = 1800L
    private val SERVICE_BIND_MAX_ATTEMPTS = 5

    private val gamePackageCandidates = listOf(
        "com.bluepoch.m.en.reverse1999",
        "com.bluepoch.m.cn.reverse1999",
    )

    private val mainHandler = Handler(Looper.getMainLooper())

    // The persistent Shizuku UserService connection used for direct Java file
    // I/O in the shell/root identity (see FileTransferUserService for why this
    // is required instead of spawning "sh -c" subprocesses).
    private var fileService: IFileTransferService? = null
    private var pendingServiceResult: MethodChannel.Result? = null
    private var pendingServiceTimeout: Runnable? = null
    private var pendingServiceRetry: Runnable? = null
    private var serviceBindAttempt = 0
    private var shizukuListenersRegistered = false

    private val userServiceArgs: Shizuku.UserServiceArgs by lazy {
        // tag стабилен после ProGuard; version бампим при смене логики FS-сервиса.
        Shizuku.UserServiceArgs(ComponentName(packageName, FileTransferUserService::class.java.name))
            .daemon(false)
            .processNameSuffix("filesvc")
            .tag("solidleaf_filesvc")
            .debuggable(false)
            .version(2)
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        fileService = null
    }

    private val fileServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            fileService = if (binder != null && binder.pingBinder()) {
                IFileTransferService.Stub.asInterface(binder)
            } else {
                null
            }
            if (fileService != null) {
                completePendingServiceResult(true, null)
            } else {
                handleFileServiceBindFailure(
                    "Shizuku user service returned an inactive binder " +
                        "(attempt $serviceBindAttempt/$SERVICE_BIND_MAX_ATTEMPTS)"
                )
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            fileService = null
        }

        override fun onBindingDied(name: ComponentName?) {
            fileService = null
            handleFileServiceBindFailure(
                "Shizuku user service binding died " +
                    "(attempt $serviceBindAttempt/$SERVICE_BIND_MAX_ATTEMPTS)"
            )
        }

        override fun onNullBinding(name: ComponentName?) {
            fileService = null
            handleFileServiceBindFailure(
                "Shizuku user service returned null binder " +
                    "(attempt $serviceBindAttempt/$SERVICE_BIND_MAX_ATTEMPTS)"
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureShizukuListeners()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkShizukuStatus" -> {
                    result.success(getShizukuState().isReady)
                }
                "getShizukuState" -> {
                    result.success(getShizukuState().toMap())
                }
                "checkPermission" -> {
                    result.success(getShizukuState().hasPermission)
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
                "launchGame" -> {
                    try {
                        var launchedPkg: String? = null
                        for (pkg in gamePackageCandidates) {
                            try {
                                packageManager.getPackageInfo(pkg, 0)
                            } catch (_: PackageManager.NameNotFoundException) {
                                continue
                            }
                            val launch = packageManager.getLaunchIntentForPackage(pkg)
                                ?: Intent(Intent.ACTION_MAIN).apply {
                                    addCategory(Intent.CATEGORY_LAUNCHER)
                                    setPackage(pkg)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }.takeIf {
                                    packageManager.queryIntentActivities(it, 0).isNotEmpty()
                                }
                            if (launch != null) {
                                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launch)
                                launchedPkg = pkg
                                break
                            }
                        }
                        if (launchedPkg != null) {
                            result.success(launchedPkg)
                        } else {
                            result.error(
                                "NOT_INSTALLED",
                                "Игра Reverse: 1999 не установлена "
                                    + "(пакет com.bluepoch.m.en.reverse1999).",
                                null,
                            )
                        }
                    } catch (ex: Exception) {
                        result.error("LAUNCH_ERROR", ex.message ?: "Unknown error", null)
                    }
                }
                "resolveGamePackage" -> {
                    try {
                        var found: String? = null
                        for (pkg in gamePackageCandidates) {
                            try {
                                packageManager.getPackageInfo(pkg, 0)
                                found = pkg
                                break
                            } catch (_: PackageManager.NameNotFoundException) {
                                // следующий кандидат
                            }
                        }
                        result.success(found)
                    } catch (ex: Exception) {
                        result.error("RESOLVE_ERROR", ex.message ?: "Unknown error", null)
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
                "fsProbeWrite" -> {
                    // Быстрая проверка записи в Android/data до полной установки.
                    val path = call.arguments as? String ?: ""
                    try {
                        val svc = requireFileService()
                        val probe = if (path.endsWith("/")) {
                            path + ".solidleaf_write_probe"
                        } else {
                            "$path/.solidleaf_write_probe"
                        }
                        val parentOk = svc.mkdirs(
                            probe.substringBeforeLast('/', missingDelimiterValue = path),
                        )
                        if (!parentOk && !svc.exists(
                                probe.substringBeforeLast('/', missingDelimiterValue = path),
                            )
                        ) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "stage" to "mkdirs",
                                    "path" to probe,
                                    "error" to "cannot create parent directory",
                                ),
                            )
                            return@setMethodCallHandler
                        }
                        val payload = "ok".toByteArray(Charsets.UTF_8)
                        val wrote = svc.writeChunk(probe, payload, false)
                        val size = svc.fileSize(probe)
                        svc.deleteRecursive(probe)
                        val ok = wrote && size >= payload.size
                        result.success(
                            mapOf(
                                "ok" to ok,
                                "stage" to if (ok) "write" else "verify",
                                "path" to probe,
                                "size" to size,
                                "error" to if (ok) null else "write/verify failed",
                            ),
                        )
                    } catch (e: Exception) {
                        result.error("FS_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureShizukuListeners() {
        if (shizukuListenersRegistered) return
        shizukuListenersRegistered = true
        try {
            Shizuku.addBinderDeadListener(binderDeadListener)
        } catch (_: Exception) {
        }
    }

    private fun requireFileService(): IFileTransferService {
        val current = fileService
        if (current != null && current.asBinder().pingBinder()) {
            return current
        }
        fileService = null
        throw IllegalStateException("Shizuku file service is not bound. Call ensureFileService first.")
    }

    private fun completePendingServiceResult(success: Boolean, error: String?) {
        pendingServiceTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingServiceTimeout = null
        pendingServiceRetry?.let { mainHandler.removeCallbacks(it) }
        pendingServiceRetry = null
        val pending = pendingServiceResult ?: return
        pendingServiceResult = null
        serviceBindAttempt = 0
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
        fileService = null

        if (pendingServiceResult != null) {
            result.error("SERVICE_BIND_IN_PROGRESS", "Shizuku file service is already connecting", null)
            return
        }

        val state = getShizukuState()
        if (!state.installed) {
            result.error("SHIZUKU_NOT_INSTALLED", "Shizuku не установлен", null)
            return
        }
        if (!state.binderAlive) {
            result.error("SHIZUKU_NOT_RUNNING", "Shizuku не запущен. Откройте Shizuku и нажмите Start.", null)
            return
        }
        if (!state.hasPermission) {
            result.error("SHIZUKU_PERMISSION_DENIED", "Shizuku permission is not granted", null)
            return
        }

        pendingServiceResult = result
        serviceBindAttempt = 0
        startFileServiceBindAttempt()
    }

    /**
     * Стратегия bind без «ломания» Shizuku на HyperOS / Infinix:
     * 1) первый раз — только bind (без unbind);
     * 2) мягкие ретраи — unbind(remove=false);
     * 3) последний шанс — unbind(remove=true).
     * Жёсткий remove=true на каждой попытке даёт «provider is null» и
     * таймаут UserService при живом binder + выданных правах.
     */
    private fun startFileServiceBindAttempt() {
        val pending = pendingServiceResult ?: return
        serviceBindAttempt += 1
        val attempt = serviceBindAttempt

        pendingServiceTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingServiceRetry?.let { mainHandler.removeCallbacks(it) }

        pendingServiceTimeout = Runnable {
            if (pendingServiceResult === pending && serviceBindAttempt == attempt) {
                handleFileServiceBindFailure(
                    "Shizuku user service did not connect in time " +
                        "(attempt $attempt/$SERVICE_BIND_MAX_ATTEMPTS)"
                )
            }
        }
        mainHandler.postDelayed(pendingServiceTimeout!!, SERVICE_BIND_TIMEOUT_MS)

        fileService = null

        if (attempt > 1) {
            val forceRemove = attempt >= SERVICE_BIND_MAX_ATTEMPTS
            try {
                Shizuku.unbindUserService(userServiceArgs, fileServiceConnection, forceRemove)
            } catch (_: Exception) {
            }
        }

        try {
            Shizuku.bindUserService(userServiceArgs, fileServiceConnection)
        } catch (e: Exception) {
            handleFileServiceBindFailure(
                e.message ?: "bindUserService failed (attempt $attempt/$SERVICE_BIND_MAX_ATTEMPTS)"
            )
        }
    }

    private fun handleFileServiceBindFailure(reason: String) {
        val pending = pendingServiceResult ?: return
        pendingServiceTimeout?.let { mainHandler.removeCallbacks(it) }
        pendingServiceTimeout = null

        if (serviceBindAttempt < SERVICE_BIND_MAX_ATTEMPTS) {
            val delay = SERVICE_BIND_RETRY_DELAY_MS + (serviceBindAttempt - 1) * 400L
            pendingServiceRetry = Runnable {
                if (pendingServiceResult === pending) {
                    val state = getShizukuState()
                    if (!state.isReady) {
                        completePendingServiceResult(false, "Shizuku не готов: ${state.humanStatus}")
                        return@Runnable
                    }
                    startFileServiceBindAttempt()
                }
            }
            mainHandler.postDelayed(pendingServiceRetry!!, delay)
            return
        }

        completePendingServiceResult(
            false,
            "$reason. Shizuku «активен», но file service не подключился. "
                + "На HyperOS / Redmi / Infinix: Stop→Start в Shizuku, батарея "
                + "«без ограничений» для Shizuku и SolidLeaf, снова разрешите "
                + "доступ и повторите (не сворачивайте лаунчер).",
        )
    }

    private data class ShizukuState(
        val installed: Boolean,
        val binderAlive: Boolean,
        val hasPermission: Boolean
    ) {
        val isReady: Boolean
            get() = installed && binderAlive && hasPermission

        val humanStatus: String
            get() = when {
                !installed -> "Shizuku не установлен"
                !binderAlive -> "Shizuku не запущен"
                !hasPermission -> "Нет разрешения Shizuku"
                else -> "Shizuku активен"
            }

        fun toMap(): Map<String, Any> {
            return mapOf(
                "installed" to installed,
                "binderAlive" to binderAlive,
                "hasPermission" to hasPermission,
                "active" to isReady,
                "status" to humanStatus
            )
        }
    }

    private fun getShizukuState(): ShizukuState {
        val installed = try {
            packageManager.getPackageInfo("moe.shizuku.privileged.api", PackageManager.GET_META_DATA)
            true
        } catch (_: Exception) {
            false
        }

        val binderAlive = if (installed) {
            try {
                Shizuku.pingBinder()
            } catch (_: Exception) {
                false
            }
        } else {
            false
        }

        val hasPermission = if (binderAlive) {
            try {
                !Shizuku.isPreV11() &&
                    Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            } catch (_: Exception) {
                false
            }
        } else {
            false
        }

        return ShizukuState(installed, binderAlive, hasPermission)
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
            if (shizukuListenersRegistered) {
                Shizuku.removeBinderDeadListener(binderDeadListener)
                shizukuListenersRegistered = false
            }
        } catch (_: Exception) {
        }
        try {
            // remove=false: не убиваем процесс сервиса при повороте/пересоздании Activity.
            // Иначе на HyperOS следующий bind часто зависает до полного рестарта Shizuku.
            if (fileService != null) {
                Shizuku.unbindUserService(userServiceArgs, fileServiceConnection, false)
            }
        } catch (_: Exception) {
        }
        fileService = null
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
