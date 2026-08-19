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

    function getState() { return { ...state }; }

    function setState(newState) {
        state = { ...state, ...newState };
        listeners.forEach(cb => cb(state));
    }

    function addLog(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        state.logs.push({ timestamp, message, type });
        if (state.logs.length > 30) state.logs.shift();
        setState({ logs: state.logs });
    }

    function subscribe(callback) { listeners.push(callback); }

    return { getState, setState, addLog, subscribe };
})();
