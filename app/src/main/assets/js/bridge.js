const NativeBridge = {
  isAvailable: function() {
    return typeof window.AndroidBridge !== 'undefined';
  },
  
  executeAction: function(action, payload = {}) {
    console.log("[Bridge] Triggered action:", action, payload);
    if (this.isAvailable()) {
      window.AndroidBridge.postMessage(JSON.stringify({ action, payload }));
    } else {
      console.warn("[Bridge] Mock Mode: AndroidBridge native instance non-found.");
    }
  }
};
