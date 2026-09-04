// AIDL interface implemented by FileTransferUserService and invoked through
// Shizuku's bindUserService(). All methods run inside a persistent process
// with shell (uid 2000) or root identity, using plain java.io File APIs —
// NOT spawned "sh -c" subprocesses — which is required to reliably write into
// another app's protected Android/data/<pkg> folder.
package com.example.re_1999_solidleaf;

interface IFileTransferService {
    boolean mkdirs(String path) = 1;
    boolean writeChunk(String path, in byte[] data, boolean append) = 2;
    byte[] readChunk(String path, long offset, int length) = 3;
    long fileSize(String path) = 4;
    boolean deleteRecursive(String path) = 5;
    boolean exists(String path) = 6;
    boolean isDirectory(String path) = 7;

    // Локальное копирование внутри shell-процесса (как ZArchiver / MT Manager).
    // Без гонки больших ByteArray через Binder — критично для HyperOS.
    boolean copyFile(String src, String dst) = 8;

    // Список относительных путей файлов под rootDir (через '\n'), для бэкапа.
    String listRelativeFiles(String rootDir) = 9;

    // Fixed transaction code required by Shizuku so unbindUserService(..., remove=true)
    // can reliably invoke cleanup even if the interface's method order changes.
    void destroy() = 16777114;
}
