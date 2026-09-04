package com.example.re_1999_solidleaf

import android.content.Context
import android.system.Os
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.RandomAccessFile

/**
 * Runs inside a persistent process bound via Shizuku (shell uid 2000 or root),
 * started with `Shizuku.bindUserService`. Unlike spawning "sh -c" subprocesses
 * (Shizuku.newProcess), plain java.io File operations executed here run in the
 * process's own identity/SELinux domain directly — no fork/exec of a shell or
 * "cat"/"cp" binary is involved, which is what reliably allows writing into
 * another app's protected Android/data/<pkg> folder.
 *
 * Must have a public no-argument constructor (Shizuku instantiates it via
 * reflection in the new process). Shizuku v13+ may use the Context ctor first.
 */
class FileTransferUserService : IFileTransferService.Stub {
    constructor() : super()
    constructor(@Suppress("UNUSED_PARAMETER") context: Context) : super()

    override fun mkdirs(path: String): Boolean {
        return try {
            ensureDirectory(File(path))
        } catch (e: Exception) {
            Log.w(TAG, "mkdirs failed: $path", e)
            false
        }
    }

    override fun writeChunk(path: String, data: ByteArray, append: Boolean): Boolean {
        try {
            val file = File(path)
            file.parentFile?.let { ensureDirectory(it) }

            // HyperOS / MIUI / Honor / Transsion: у существующих файлов игры
            // иногда нельзя сделать O_TRUNC — удаляем или обнуляем.
            if (!append && file.exists()) {
                prepareForOverwrite(file)
            }

            try {
                writeViaStream(file, data, append)
                return true
            } catch (primary: Exception) {
                if (append) {
                    throw primary
                }
                Log.w(TAG, "writeChunk primary failed, trying tmp+rename: $path", primary)
                writeViaTempRename(file, data)
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "writeChunk failed: $path append=$append", e)
            throw RuntimeException(
                "writeChunk: ${e.javaClass.simpleName}: ${e.message ?: "unknown"} @ $path",
                e,
            )
        }
    }

    /**
     * Копирование файл→файл целиком в процессе shell (паттерн ZArchiver/MT).
     * Источник должен быть читаем shell (например staging в Android/data нашего
     * приложения или уже лежащий в Android/data игры файл для бэкапа).
     */
    override fun copyFile(src: String, dst: String): Boolean {
        try {
            val source = File(src)
            val target = File(dst)
            if (!source.exists() || !source.isFile) {
                throw IllegalStateException("source missing or not a file: $src")
            }
            target.parentFile?.let { ensureDirectory(it) }
            if (target.exists()) {
                prepareForOverwrite(target)
            }

            try {
                streamCopy(source, target)
            } catch (primary: Exception) {
                Log.w(TAG, "copyFile direct failed, tmp+rename: $src -> $dst", primary)
                try {
                    copyViaTempFile(source, target)
                } catch (secondary: Exception) {
                    Log.w(TAG, "copyFile tmp failed, toybox cp: $src -> $dst", secondary)
                    copyViaExec(source, target)
                }
            }

            if (!target.exists()) {
                throw IllegalStateException("target missing after copy: $dst")
            }
            if (target.length() != source.length()) {
                throw IllegalStateException(
                    "size mismatch after copy: src=${source.length()} dst=${target.length()}",
                )
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "copyFile failed: $src -> $dst", e)
            throw RuntimeException(
                "copyFile: ${e.javaClass.simpleName}: ${e.message ?: "unknown"} ($src -> $dst)",
                e,
            )
        }
    }

    override fun listRelativeFiles(rootDir: String): String {
        return try {
            val root = File(rootDir)
            if (!root.exists() || !root.isDirectory) {
                return ""
            }
            val rootPath = root.canonicalPath
            val out = StringBuilder()
            root.walkTopDown().forEach { file ->
                if (!file.isFile) return@forEach
                val full = try {
                    file.canonicalPath
                } catch (_: Exception) {
                    file.absolutePath
                }
                if (!full.startsWith(rootPath)) return@forEach
                var rel = full.substring(rootPath.length)
                if (rel.startsWith("/") || rel.startsWith("\\")) {
                    rel = rel.substring(1)
                }
                if (rel.isEmpty()) return@forEach
                if (out.isNotEmpty()) out.append('\n')
                out.append(rel.replace('\\', '/'))
            }
            out.toString()
        } catch (e: Exception) {
            Log.w(TAG, "listRelativeFiles failed: $rootDir", e)
            throw RuntimeException(
                "listRelativeFiles: ${e.javaClass.simpleName}: ${e.message ?: "unknown"} @ $rootDir",
                e,
            )
        }
    }

    private fun streamCopy(source: File, target: File) {
        FileInputStream(source).use { input ->
            FileOutputStream(target, false).use { output ->
                val buffer = ByteArray(256 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                }
                try {
                    output.fd.sync()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun copyViaTempFile(source: File, target: File) {
        val parent = target.parentFile
            ?: throw IllegalStateException("no parent for ${target.path}")
        ensureDirectory(parent)
        val tmp = File(parent, "${target.name}.solidleaf.tmp")
        if (tmp.exists()) {
            prepareForOverwrite(tmp)
            tmp.delete()
        }
        try {
            streamCopy(source, tmp)
            if (target.exists()) {
                prepareForOverwrite(target)
            }
            if (tmp.renameTo(target)) {
                return
            }
            streamCopy(tmp, target)
        } finally {
            if (tmp.exists()) {
                tmp.delete()
            }
        }
    }

    /** Запасной cp в том же shell-процессе — ближе к поведению ZArchiver. */
    private fun copyViaExec(source: File, target: File) {
        target.parentFile?.let { ensureDirectory(it) }
        if (target.exists()) {
            prepareForOverwrite(target)
        }
        val commands = listOf(
            arrayOf("toybox", "cp", "-f", source.absolutePath, target.absolutePath),
            arrayOf("cp", "-f", source.absolutePath, target.absolutePath),
        )
        var lastError: Exception? = null
        for (cmd in commands) {
            try {
                val proc = Runtime.getRuntime().exec(cmd)
                val code = proc.waitFor()
                if (code == 0 && target.exists() && target.length() == source.length()) {
                    return
                }
                lastError = IllegalStateException("exit=$code for ${cmd.joinToString(" ")}")
            } catch (e: Exception) {
                lastError = e
            }
        }
        throw lastError ?: IllegalStateException("exec cp failed")
    }

    private fun writeViaStream(file: File, data: ByteArray, append: Boolean) {
        FileOutputStream(file, append).use { out ->
            out.write(data)
            try {
                out.fd.sync()
            } catch (_: Exception) {
            }
        }
    }

    private fun writeViaTempRename(file: File, data: ByteArray) {
        val parent = file.parentFile ?: throw IllegalStateException("no parent for ${file.path}")
        ensureDirectory(parent)
        val tmp = File(parent, "${file.name}.solidleaf.tmp")
        if (tmp.exists() && !tmp.delete()) {
            prepareForOverwrite(tmp)
            tmp.delete()
        }
        try {
            writeViaStream(tmp, data, false)
            if (file.exists()) {
                prepareForOverwrite(file)
            }
            if (tmp.renameTo(file)) {
                return
            }
            FileInputStream(tmp).use { input ->
                FileOutputStream(file, false).use { output ->
                    input.copyTo(output)
                    try {
                        output.fd.sync()
                    } catch (_: Exception) {
                    }
                }
            }
        } finally {
            if (tmp.exists()) {
                tmp.delete()
            }
        }
        if (!file.exists() || file.length() < data.size.toLong()) {
            throw IllegalStateException(
                "tmp+rename verify failed: exists=${file.exists()} len=${file.length()} want=${data.size}",
            )
        }
    }

    /** Удаление / truncate перед перезаписью — без этого OEM-оболочки часто падают. */
    private fun prepareForOverwrite(file: File) {
        if (!file.exists()) return
        if (file.delete()) return
        if (!file.exists()) return
        try {
            RandomAccessFile(file, "rw").use { it.setLength(0) }
            return
        } catch (e: Exception) {
            Log.w(TAG, "truncate failed: ${file.path}", e)
        }
        try {
            Os.remove(file.path)
        } catch (e: Exception) {
            Log.w(TAG, "Os.remove failed: ${file.path}", e)
        }
    }

    /**
     * Пошаговое создание каталогов: на части HyperOS/Infinix [File.mkdirs]
     * молча возвращает false на глубоких путях Android/data.
     */
    private fun ensureDirectory(dir: File): Boolean {
        if (dir.exists()) return dir.isDirectory
        if (dir.mkdirs()) return true

        val missing = ArrayList<File>()
        var cur: File? = dir
        while (cur != null && !cur.exists()) {
            missing.add(cur)
            cur = cur.parentFile
        }
        for (i in missing.indices.reversed()) {
            val d = missing[i]
            if (d.exists()) {
                if (!d.isDirectory) return false
                continue
            }
            if (!d.mkdir() && !(d.exists() && d.isDirectory)) {
                Log.w(TAG, "mkdir step failed: ${d.path}")
                return false
            }
        }
        return dir.exists() && dir.isDirectory
    }

    override fun readChunk(path: String, offset: Long, length: Int): ByteArray? {
        return try {
            RandomAccessFile(path, "r").use { raf ->
                raf.seek(offset)
                val buffer = ByteArray(length)
                val read = raf.read(buffer)
                if (read <= 0) ByteArray(0) else buffer.copyOf(read)
            }
        } catch (e: Exception) {
            Log.w(TAG, "readChunk failed: $path", e)
            null
        }
    }

    override fun fileSize(path: String): Long {
        return try {
            File(path).length()
        } catch (e: Exception) {
            -1L
        }
    }

    override fun deleteRecursive(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return true
            file.deleteRecursively()
        } catch (e: Exception) {
            Log.w(TAG, "deleteRecursive failed: $path", e)
            false
        }
    }

    override fun exists(path: String): Boolean {
        return try {
            File(path).exists()
        } catch (e: Exception) {
            false
        }
    }

    override fun isDirectory(path: String): Boolean {
        return try {
            File(path).isDirectory
        } catch (e: Exception) {
            false
        }
    }

    override fun destroy() {
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    companion object {
        private const val TAG = "SolidLeafFS"
    }
}
