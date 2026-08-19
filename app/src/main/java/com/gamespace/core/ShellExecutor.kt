package com.gamespace.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.reflect.Method

data class ShellResult(
    val isSuccess: Boolean,
    val stdout: String,
    val stderr: String,
    val exitCode: Int
)

object ShellExecutor {
    private val executionMutex = Mutex()

    private val newProcessMethod: Method? by lazy {
        try {
            Shizuku::class.java.declaredMethods
                .firstOrNull { it.name == "newProcess" }
                ?.apply { isAccessible = true }
        } catch (t: Throwable) {
            t.printStackTrace()
            null
        }
    }

    suspend fun executeCommand(command: String): ShellResult = withContext(Dispatchers.IO) {
        executionMutex.withLock {
            if (!ShizukuManager.hasShizukuPermission()) {
                return@withContext ShellResult(false, "", "Chưa cấp quyền Shizuku", -1)
            }

            val method = newProcessMethod
            if (method == null) {
                return@withContext ShellResult(false, "", "Không tìm thấy Shizuku.newProcess", -1)
            }

            try {
                val process = method.invoke(
                    null,
                    arrayOf("sh", "-c", command),
                    null,
                    null
                ) as Process

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
            } catch (t: Throwable) {
                ShellResult(false, "", t.message ?: "Lỗi Shell", -1)
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
