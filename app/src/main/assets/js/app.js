document.addEventListener('DOMContentLoaded', () => {
  const boostBtn = document.getElementById('boostBtn');
  const modeStatus = document.getElementById('modeStatus');
  
  if (boostBtn) {
    boostBtn.addEventListener('click', () => {
      UIState.setPerformanceMode('BEAST_MODE');
      if (modeStatus) {
        modeStatus.innerText = 'BEAST MODE';
        modeStatus.style.color = '#ff0055';
      }
      NativeBridge.executeAction('SET_PERFORMANCE_MODE', { mode: 'BEAST_MODE' });
    });
  }
});
