/**
 * NEO CHAMELEON - Performance settings (global, no build step)
 */
const Perf = {
  TARGET_FPS_IDLE: 30,
  TARGET_FPS_PLAYING: 60,

  init() {
    document.documentElement.classList.add('perf-lite');
  }
};

Perf.init();
