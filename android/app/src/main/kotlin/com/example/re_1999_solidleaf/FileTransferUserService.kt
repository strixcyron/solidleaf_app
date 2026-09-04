package com.example.re_1999_solidleaf

import android.util.Log
import java.io.File
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
 * reflection in the new process).
 */
class FileTransferUserService : IFileTransferService.Stub() {

    override fun mkdirs(path: String): Boolean {
        return try {
            val dir = File(path)
            dir.exists() || dir.mkdirs()
        } catch (e: Exception) {
            Log.w(TAG, "mkdirs failed: $path", e)
            false
        }
    }

    override fun writeChunk(path: String, data: ByteArray, append: Boolean): Boolean {
        try {
            val file = File(path)
            file.parentFile?.mkdirs()

            // HyperOS / MIUI / Honor: у существующих файлов игры иногда нельзя
            // сделать O_TRUNC — удаляем или обнуляем перед первой записью.
            if (!append && file.exists()) {
                prepareForOverwrite(file)
            }

            FileOutputStream(path, append).use { it.write(data) }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "writeChunk failed: $path append=$append", e)
            // Пробрасываем текст ошибки на сторону Flutter (MainActivity → FS_ERROR).
            throw RuntimeException(
                "writeChunk: ${e.javaClass.simpleName}: ${e.message ?: "unknown"} @ $path",
                e,
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
        } catch (e: Exception) {
            Log.w(TAG, "truncate failed, will try FileOutputStream: ${file.path}", e)
        }
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
