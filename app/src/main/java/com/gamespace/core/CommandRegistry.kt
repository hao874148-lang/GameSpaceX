package com.gamespace.core

object CommandRegistry {
    val PERFORMANCE_MODE_ON = listOf(
        "cmd power set-mode 0",
        "settings put global thermal_limit_level 0",
        "settings put global power_saving_mode 0",
        "dumpsys deviceidle disable"
    )

    val PERFORMANCE_MODE_OFF = listOf(
        "dumpsys deviceidle enable",
        "settings put global power_saving_mode 0"
    )

    val CLEAN_RAM = listOf(
        "am kill-all",
        "echo 3 > /proc/sys/vm/drop_caches"
    )

    const val GET_CPU_TEMP = "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 1"
}
