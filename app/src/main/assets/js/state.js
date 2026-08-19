/**
 * Lưu trữ trạng thái UI và bắn sự kiện khi state thay đổi.
 */
window.GameState = (function() {
    let state = {
        shizukuStatus: 'DISCONNECTED',
        shizukuAvailable: false,
        shizukuPermission: false,
        performanceMode: false,
        temperature: 36.5,
        memoryStatus: 'OPTIMIZED',
        logs: []
    };

    const listeners = [];

    function getState() {
        return { ...state };
    }

    function setState(newState) {
        state = { ...state, ...newState };
        listeners.forEach(cb => cb(state));
    }

    function addLog(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        const logItem = { timestamp, message, type };
        state.logs.push(logItem);
        if (state.logs.length > 30) state.logs.shift();
        setState({ logs: state.logs });
    }

    function subscribe(callback) {
        listeners.push(callback);
    }

    return {
        getState: getState,
        setState: setState,
        addLog: addLog,
        subscribe: subscribe
    };
})();
