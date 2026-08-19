/**
 * Cầu nối JS gửi nhận lệnh với Android Native Bridge.
 */
window.GameSpaceBridge = (function() {
    const listeners = {};

    function registerListener(event, callback) {
        if (!listeners[event]) {
            listeners[event] = [];
        }
        listeners[event].push(callback);
    }

    function executeAction(action, payload = {}) {
        const jsonPayload = JSON.stringify(payload);
        if (window.AndroidNativeBridge && typeof window.AndroidNativeBridge.executeAction === 'function') {
            window.AndroidNativeBridge.executeAction(action, jsonPayload);
        } else {
            console.warn("[Bridge Web] AndroidNativeBridge không tồn tại, giả lập Web mode:", action);
            setTimeout(() => {
                onNativeEvent("ON_ERROR", { message: "Đang chạy chế độ trình duyệt thử nghiệm (No Native)" });
            }, 300);
        }
    }

    function onNativeEvent(event, data) {
        if (listeners[event]) {
            listeners[event].forEach(cb => cb(data));
        }
    }

    return {
        registerListener: registerListener,
        executeAction: executeAction,
        onNativeEvent: onNativeEvent
    };
})();
