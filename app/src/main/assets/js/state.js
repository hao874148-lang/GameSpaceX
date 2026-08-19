const AppState = {
  mode: 'BALANCED',
  shizukuStatus: 'SẴN SÀNG',
  memoryStatus: 'OPTIMIZED',
  temperature: 36.5,
  isHighPerformance: false,

  updateFromNative: function (data) {
    if (data.mode) this.mode = data.mode;
    if (data.currentMode) this.mode = data.currentMode;
    if (data.shizukuStatus) this.shizukuStatus = data.shizukuStatus;
    if (data.memoryStatus) this.memoryStatus = data.memoryStatus;
    if (data.temperature) this.temperature = data.temperature;

    this.isHighPerformance = (this.mode === 'HIGH_PERFORMANCE' || this.mode === 'PERFORMANCE');
  }
};
