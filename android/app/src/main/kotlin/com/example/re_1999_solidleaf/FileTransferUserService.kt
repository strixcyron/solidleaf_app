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
                // Запасной путь: tmp + rename — обходит блокировки truncate/open.
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
            // renameTo может вернуть false на FUSE/exFAT — копируем вручную.
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
