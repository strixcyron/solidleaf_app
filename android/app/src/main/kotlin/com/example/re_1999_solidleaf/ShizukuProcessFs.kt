package com.example.re_1999_solidleaf

import android.util.Log
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Запасной FS через [Shizuku.newProcess], когда [Shizuku.bindUserService]
 * на HyperOS / Android 15 не подключается (binder жив, permission есть,
 * но UserService timeout).
 *
 * Не заменяет UserService на устройствах, где он работает — только fallback.
 */
object ShizukuProcessFs {
    private const val TAG = "SolidLeafProcessFs"

    fun shellQuote(path: String): String =
        "'" + path.replace("'", "'\\''") + "'"

    /**
     * @return exitCode to stdout+stderr
     */
    @Suppress("DEPRECATION")
    fun run(command: String, stdin: ByteArray? = null): Pair<Int, String> {
        Log.i(TAG, "exec: ${command.take(180)}")
        val process = try {
            Shizuku.newProcess(arrayOf("sh", "-c", command), null, null)
        } catch (e: Throwable) {
            Log.e(TAG, "newProcess unavailable", e)
            throw IllegalStateException(
                "Shizuku.newProcess недоступен: ${e.message}",
                e,
            )
        }

        val writer = Thread({
            try {
                if (stdin != null && stdin.isNotEmpty()) {
                    process.outputStream.write(stdin)
                }
            } catch (e: Exception) {
                Log.w(TAG, "stdin write failed", e)
            } finally {
                try {
                    process.outputStream.close()
                } catch (_: Exception) {
                }
            }
        }, "SolidLeaf-stdin")
        writer.start()

        val stdout = StringBuilder()
        val stderr = StringBuilder()
        val outReader = Thread({
            try {
                BufferedReader(InputStreamReader(process.inputStream)).use { r ->
                    var line: String?
                    while (r.readLine().also { line = it } != null) {
                        stdout.append(line).append('\n')
                    }
                }
            } catch (_: Exception) {
            }
        }, "SolidLeaf-stdout")
        val errReader = Thread({
            try {
                BufferedReader(InputStreamReader(process.errorStream)).use { r ->
                    var line: String?
                    while (r.readLine().also { line = it } != null) {
                        stderr.append(line).append('\n')
                    }
                }
            } catch (_: Exception) {
            }
        }, "SolidLeaf-stderr")
        outReader.start()
        errReader.start()

        writer.join()
        outReader.join()
        errReader.join()
        val code = try {
            process.waitFor()
        } catch (e: Exception) {
            -1
        }
        val combined = buildString {
            append(stdout)
            if (stderr.isNotEmpty()) {
                if (isNotEmpty()) append('\n')
                append(stderr)
            }
        }.trim()
        if (code != 0) {
            Log.w(TAG, "exit=$code cmd=${command.take(120)} err=$combined")
        }
        return code to combined
    }

    fun probeAlive(): Boolean {
        return try {
            val (code, out) = run("echo solidleaf_ok")
            code == 0 && out.contains("solidleaf_ok")
        } catch (e: Exception) {
            Log.e(TAG, "probeAlive failed", e)
            false
        }
    }

    fun mkdirs(path: String): Boolean {
        val (code, _) = run("mkdir -p ${shellQuote(path)}")
        return code == 0 || exists(path)
    }

    fun exists(path: String): Boolean {
        val (code, _) = run("test -e ${shellQuote(path)}")
        return code == 0
    }

    fun isDirectory(path: String): Boolean {
        val (code, _) = run("test -d ${shellQuote(path)}")
        return code == 0
    }

    fun deleteRecursive(path: String): Boolean {
        if (!exists(path)) return true
        val (code, _) = run("rm -rf ${shellQuote(path)}")
        return code == 0 || !exists(path)
    }

    fun fileSize(path: String): Long {
        val (code, out) = run("wc -c < ${shellQuote(path)}")
        if (code != 0) return -1L
        return out.trim().substringBefore(' ').toLongOrNull() ?: -1L
    }

    fun writeChunk(path: String, data: ByteArray, append: Boolean): Boolean {
        val parent = path.substringBeforeLast('/', missingDelimiterValue = "")
        if (parent.isNotEmpty()) {
            mkdirs(parent)
        }
        if (!append && exists(path)) {
            deleteRecursive(path)
        }
        // cat > / cat >> принимают stdin — надёжнее, чем echo для бинарных данных.
        val redir = if (append) ">>" else ">"
        val (code, err) = run("cat $redir ${shellQuote(path)}", stdin = data)
        if (code != 0) {
            throw IllegalStateException("process writeChunk exit=$code: $err @ $path")
        }
        return true
    }

    fun copyFile(src: String, dst: String): Boolean {
        val parent = dst.substringBeforeLast('/', missingDelimiterValue = "")
        if (parent.isNotEmpty()) mkdirs(parent)
        if (exists(dst)) deleteRecursive(dst)
        // cp, затем fallback через cat.
        var (code, err) = run("cp -f ${shellQuote(src)} ${shellQuote(dst)}")
        if (code != 0) {
            val r2 = run("cat ${shellQuote(src)} > ${shellQuote(dst)}")
            code = r2.first
            err = r2.second
        }
        if (code != 0) {
            throw IllegalStateException("process copyFile exit=$code: $err ($src -> $dst)")
        }
        val srcSize = fileSize(src)
        val dstSize = fileSize(dst)
        if (srcSize >= 0 && dstSize >= 0 && srcSize != dstSize) {
            throw IllegalStateException(
                "process copyFile size mismatch src=$srcSize dst=$dstSize",
            )
        }
        return true
    }

    fun listRelativeFiles(rootDir: String): String {
        if (!isDirectory(rootDir)) return ""
        val (code, out) = run("find ${shellQuote(rootDir)} -type f 2>/dev/null")
        if (code != 0) return ""
        val prefix = rootDir.trimEnd('/') + "/"
        return out.lineSequence()
            .map { it.trim() }
            .filter { it.startsWith(prefix) }
            .map { it.removePrefix(prefix) }
            .filter { it.isNotEmpty() }
            .joinToString("\n")
    }

    fun readChunk(path: String, offset: Long, length: Int): ByteArray? {
        if (length <= 0) return ByteArray(0)
        // Читаем через base64, чтобы бинарные данные прошли текстовый stdout.
        val (code, out) = run(
            "dd if=${shellQuote(path)} bs=1 skip=$offset count=$length 2>/dev/null | base64",
        )
        if (code != 0 || out.isEmpty()) return null
        return try {
            android.util.Base64.decode(out.trim(), android.util.Base64.DEFAULT)
        } catch (e: Exception) {
            Log.w(TAG, "base64 decode failed", e)
            null
        }
    }
}
