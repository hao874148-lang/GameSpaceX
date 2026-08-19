document.addEventListener("DOMContentLoaded", function() {
    const bridge = window.GameSpaceBridge;
    const gameState = window.GameState;

    const shizukuBadge = document.getElementById("shizuku-badge");
    const shizukuDetail = document.getElementById("shizuku-detail");
    const btnRequestShizuku = document.getElementById("btn-request-shizuku");
    const togglePerformance = document.getElementById("toggle-performance");
    const modeText = document.getElementById("mode-text");
    const tempValue = document.getElementById("temp-value");
    const tempBar = document.getElementById("temp-bar");
    const ramStatus = document.getElementById("ram-status");
    const btnCleanRam = document.getElementById("btn-clean-ram");
    const logConsole = document.getElementById("log-console");
    const btnClearLogs = document.getElementById("btn-clear-logs");

    bridge.registerListener("ON_STATE_UPDATED", function(data) {
        gameState.setState(data);
    });

    bridge.registerListener("ON_SHIZUKU_STATUS", function(data) {
        gameState.setState({
            shizukuStatus: data.shizukuStatus,
            shizukuAvailable: data.shizukuAvailable,
            shizukuPermission: data.shizukuPermission
        });
        if (data.message) gameState.addLog(data.message, data.shizukuPermission ? "success" : "warning");
    });

    bridge.registerListener("ON_PERFORMANCE_MODE_CHANGED", function(data) {
        gameState.setState({ performanceMode: data.enabled });
        gameState.addLog(data.message, data.success ? "success" : "error");
    });

    bridge.registerListener("ON_MEMORY_CLEANED", function(data) {
        ramStatus.innerText = "OPTIMIZED";
        gameState.addLog(data.message, "success");
    });

    bridge.registerListener("ON_SYSTEM_STATS", function(data) {
        if (data.temperature) gameState.setState({ temperature: data.temperature });
    });

    bridge.registerListener("ON_ERROR", function(data) {
        gameState.addLog("Lỗi: " + data.message, "error");
    });

    gameState.subscribe(function(state) {
        if (state.shizukuPermission) {
            shizukuBadge.className = "badge ready";
            shizukuBadge.innerText = "READY";
            shizukuDetail.innerText = "Đã kết nối và sẵn sàng thực thi ADB Shell.";
        } else if (state.shizukuAvailable) {
            shizukuBadge.className = "badge warning";
            shizukuBadge.innerText = "CHƯA CẤP QUYỀN";
            shizukuDetail.innerText = "Dịch vụ đang chạy, hãy bấm CẤP QUYỀN.";
        } else {
            shizukuBadge.className = "badge danger";
            shizukuBadge.innerText = "NGẮT KẾT NỐI";
            shizukuDetail.innerText = "Chưa bật Shizuku trên thiết bị.";
        }

        togglePerformance.checked = state.performanceMode;
        if (state.performanceMode) {
            modeText.innerText = "HIGH_PERFORMANCE";
            modeText.style.color = "var(--color-accent-red)";
        } else {
            modeText.innerText = "BALANCED";
            modeText.style.color = "var(--color-accent-cyan)";
        }

        const temp = parseFloat(state.temperature).toFixed(1);
        tempValue.innerText = temp + " °C";
        const tempPercent = Math.min(Math.max((temp - 20) * 2.5, 10), 100);
        tempBar.style.width = tempPercent + "%";

        logConsole.innerHTML = "";
        state.logs.forEach(function(item) {
            const div = document.createElement("div");
            div.className = "log-item " + item.type;
            div.innerText = "[" + item.timestamp + "] " + item.message;
            logConsole.appendChild(div);
        });
        logConsole.scrollTop = logConsole.scrollHeight;
    });

    btnRequestShizuku.addEventListener("click", function() {
        bridge.executeAction("REQUEST_SHIZUKU_PERMISSION");
    });

    togglePerformance.addEventListener("change", function(e) {
        bridge.executeAction("SET_PERFORMANCE_MODE", { enable: e.target.checked });
    });

    btnCleanRam.addEventListener("click", function() {
        ramStatus.innerText = "CLEANING...";
        bridge.executeAction("CLEAN_MEMORY");
    });

    btnClearLogs.addEventListener("click", function() {
        gameState.setState({ logs: [] });
    });

    setTimeout(function() { bridge.executeAction("INIT_STATE"); }, 200);
    setInterval(function() { bridge.executeAction("GET_SYSTEM_STATS"); }, 5000);
});
