package com.gamespace.core

/**
 * Danh mục lưu trữ các câu lệnh ADB Shell tối ưu hệ thống.
 */
object CommandRegistry {
    // Danh sách lệnh Bật chế độ Hiệu năng cao
    val PERFORMANCE_MODE_ON = listOf(
        "cmd power set-mode 0",
        "settings put global thermal_limit_level 0",
        "settings put global power_saving_mode 0",
        "dumpsys deviceidle disable"
    )

    // Danh sách lệnh Tắt chế độ Hiệu năng cao (Khôi phục mặc định)
    val PERFORMANCE_MODE_OFF = listOf(
        "dumpsys deviceidle enable",
        "settings put global power_saving_mode 0"
    )

    // Danh sách lệnh Dọn dẹp RAM & Ứng dụng chạy ngầm
    val CLEAN_RAM = listOf(
        "am kill-all",
        "echo 3 > /proc/sys/vm/drop_caches"
    )

    // Lệnh đọc nhiệt độ thiết bị
    const val GET_CPU_TEMP = "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 1"
}
