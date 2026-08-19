const Bridge = {
  callbacks: {},

  executeAction: function (action, payload = {}, callback = null) {
    const requestId = 'req_' + Date.now() + '_' + Math.floor(Math.random() * 1000);

    if (callback) {
      this.callbacks[requestId] = callback;
    }

    const requestData = {
      requestId: requestId,
      action: action,
      payload: payload
    };

    const jsonString = JSON.stringify(requestData);

    if (window.AndroidBridge && typeof window.AndroidBridge.postMessage === 'function') {
      window.AndroidBridge.postMessage(jsonString);
    } else {
      console.warn('[Bridge] AndroidBridge không khả dụng. Sử dụng chế độ Mock data.');
      setTimeout(() => {
        this.handleNativeResponse(JSON.stringify({
          requestId: requestId,
          action: action,
          success: true,
          message: 'Phản hồi giả lập (Chạy trên Trình duyệt Web)',
          data: payload
        }));
      }, 300);
    }
  },

  handleNativeResponse: function (jsonResponseString) {
    try {
      const response = typeof jsonResponseString === 'string' ? JSON.parse(jsonResponseString) : jsonResponseString;
      const requestId = response.requestId;

      if (requestId && this.callbacks[requestId]) {
        this.callbacks[requestId](response);
        delete this.callbacks[requestId];
      }

      const event = new CustomEvent('nativeResponse', { detail: response });
      window.dispatchEvent(event);

    } catch (err) {
      console.error('[Bridge] Lỗi xử lý phản hồi từ Native:', err);
    }
  }
};

window.onNativeResponse = function (jsonString) {
  Bridge.handleNativeResponse(jsonString);
};
