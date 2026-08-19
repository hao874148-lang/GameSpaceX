document.addEventListener('DOMContentLoaded', () => {
  const btnTogglePerformance = document.getElementById('btn-performance');
  const txtMode = document.getElementById('txt-mode');
  const txtShizuku = document.getElementById('txt-shizuku');
  const txtMemory = document.getElementById('txt-memory');
  const txtTemp = document.getElementById('txt-temp');

  fetchSystemStatus();

  if (btnTogglePerformance) {
    btnTogglePerformance.addEventListener('click', () => {
      const nextMode = AppState.isHighPerformance ? 'BALANCED' : 'HIGH_PERFORMANCE';

      btnTogglePerformance.disabled = true;
      btnTogglePerformance.style.opacity = '0.7';

      Bridge.executeAction('SET_PERFORMANCE_MODE', { mode: nextMode }, (response) => {
        btnTogglePerformance.disabled = false;
        btnTogglePerformance.style.opacity = '1';

        if (response && response.success) {
          AppState.updateFromNative(response.data);
          updateUI();
          showNotification(response.message);
        } else {
          showNotification('Lỗi: ' + (response ? response.message : 'Kết nối thất bại'));
        }
      });
    });
  }

  function fetchSystemStatus() {
    Bridge.executeAction('GET_SYSTEM_STATUS', {}, (response) => {
      if (response && response.success) {
        AppState.updateFromNative(response.data);
        updateUI();
      }
    });
  }

  function updateUI() {
    if (txtMode) {
      txtMode.textContent = AppState.mode;
      txtMode.style.color = AppState.isHighPerformance ? '#ff0055' : '#00f2fe';
    }

    if (txtShizuku) {
      txtShizuku.textContent = AppState.shizukuStatus;
    }

    if (txtMemory) {
      txtMemory.textContent = AppState.memoryStatus;
    }

    if (txtTemp) {
      txtTemp.textContent = typeof AppState.temperature === 'number' 
        ? `${AppState.temperature.toFixed(1)} °C` 
        : AppState.temperature;
    }

    if (btnTogglePerformance) {
      if (AppState.isHighPerformance) {
        btnTogglePerformance.textContent = 'TẮT CHẾ ĐỘ HIỆU NĂNG CAO';
        btnTogglePerformance.classList.add('active');
      } else {
        btnTogglePerformance.textContent = 'BẬT CHẾ ĐỘ HIỆU NĂNG CAO';
        btnTogglePerformance.classList.remove('active');
      }
    }
  }

  function showNotification(msg) {
    let toast = document.getElementById('toast-notification');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'toast-notification';
      toast.style.position = 'fixed';
      toast.style.bottom = '20px';
      toast.style.left = '50%';
      toast.style.transform = 'translateX(-50%)';
      toast.style.background = 'rgba(0, 0, 0, 0.85)';
      toast.style.color = '#00ff88';
      toast.style.border = '1px solid #00ff88';
      toast.style.padding = '10px 20px';
      toast.style.borderRadius = '20px';
      toast.style.fontSize = '12px';
      toast.style.zIndex = '9999';
      toast.style.boxShadow = '0 0 10px rgba(0, 255, 136, 0.5)';
      toast.style.transition = 'opacity 0.3s ease';
      document.body.appendChild(toast);
    }
    toast.textContent = msg;
    toast.style.opacity = '1';
    setTimeout(() => {
      toast.style.opacity = '0';
    }, 2500);
  }
});
