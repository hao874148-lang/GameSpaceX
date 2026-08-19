const UIState = {
  performanceMode: 'BALANCED',
  shizukuConnected: false,
  fpsLimit: 60,
  
  setPerformanceMode: function(mode) {
    this.performanceMode = mode;
    console.log("[State] Performance mode changed to:", mode);
  }
};
