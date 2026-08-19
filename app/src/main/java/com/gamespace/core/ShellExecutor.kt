package com.gamespace.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

data class ShellResult(
    val isSuccess: Boolean,
    val stdout: String,
    val stderr: String,
    val exitCode: Int
)

/**
 * Bộ thực thi lệnh Shell ADB tuần tự (xếp hàng chờ) để tránh xung đột lệnh.
 */
object ShellExecutor {
    private val executionMutex = Mutex()

    suspend fun executeCommand(command: String): ShellResult = withContext(Dispatchers.IO) {
        executionMutex.withLock {
            if (!ShizukuManager.hasShizukuPermission()) {
                return@withContext ShellResult(
                    isSuccess = false,
                    stdout = "",
                    stderr = "Chưa cấp quyền Shizuku hoặc dịch vụ bị ngắt",
                    exitCode = -1
                )
            }

            try {
                val process = Shizuku.newProcess(arrayOf("sh", "-c", command), null, null)
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val errorReader = BufferedReader(InputStreamReader(process.errorStream))

                val stdoutBuilder = StringBuilder()
                val stderrBuilder = StringBuilder()

                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    stdoutBuilder.append(line).append("\n")
                }
                while (errorReader.readLine().also { line = it } != null) {
                    stderrBuilder.append(line).append("\n")
                }

                val exitCode = process.waitFor()
                process.destroy()

                ShellResult(
                    isSuccess = (exitCode == 0),
                    stdout = stdoutBuilder.toString().trim(),
                    stderr = stderrBuilder.toString().trim(),
                    exitCode = exitCode
                )
            } catch (e: Exception) {
                ShellResult(
                    isSuccess = false,
                    stdout = "",
                    stderr = e.message ?: "Lỗi không xác định khi thực thi Shell",
                    exitCode = -1
                )
            }
        }
    }

    suspend fun executeCommands(commands: List<String>): List<ShellResult> {
        val results = mutableListOf<ShellResult>()
        for (cmd in commands) {
            results.add(executeCommand(cmd))
        }
        return results
    }
}
