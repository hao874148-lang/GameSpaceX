window.GameSpaceBridge = (function() {
    const listeners = {};

    function registerListener(event, callback) {
        if (!listeners[event]) listeners[event] = [];
        listeners[event].push(callback);
    }

    function executeAction(action, payload = {}) {
        const jsonPayload = JSON.stringify(payload);
        if (window.AndroidNativeBridge && typeof window.AndroidNativeBridge.executeAction === 'function') {
            window.AndroidNativeBridge.executeAction(action, jsonPayload);
        }
    }

    function onNativeEvent(event, data) {
        if (listeners[event]) {
            listeners[event].forEach(cb => cb(data));
        }
    }

    return { registerListener, executeAction, onNativeEvent };
})();
