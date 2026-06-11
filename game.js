/**
 * NEO CHAMELEON - Game Engine & Coordinator
 */

class GameEngine {
  constructor() {
    this.canvas = document.getElementById('game-canvas');
    this.ctx = this.canvas.getContext('2d');
    
    // Internal NES Resolution
    this.width = 256;
    this.height = 240;
    
    // Game States: 'TITLE', 'PLAYING', 'GAMEOVER', 'PAUSED'
    this.state = 'TITLE';
    this.frozenByMenu = false;
    this.bgmPausedByMenu = false;
    this.wasBgmPlayingBeforeHide = false;
    this.lastFrameTime = 0;
    
    this.score = 0;
    this.fliesEaten = 0;
    this.highScore = parseInt(localStorage.getItem('neo_chameleon_highscore')) || 5000;
    this.level = 1;
    this.energy = 100; // Hunger meter 0-100
    this.energyDepletionRate = 0.06; // Energy lost per frame
    
    // Combo multiplier system
    this.combo = 0;
    this.comboTimer = 0;
    this.maxComboTime = 150; // frames (~2.5s)
    
    // Entities
    this.chameleon = new Chameleon(this.width, this.height);
    this.bugs = [];
    this.maxBugs = 5;
    
    // Active power-up countdowns
    this.powerUpType = null;
    this.powerUpTimeLeft = 0;
    
    // UI Animations
    this.screenShake = 0;
    this.gameOverShakeFrames = 0; // GAMEOVER 時の画面揺れ（60fps で 1 秒）
    this.levelUpBannerFrames = 0;
    
    // Inputs
    this.keys = {};
    this.mouseTarget = null;
    this.dpadUIButtons = {
      ArrowUp: false,
      ArrowDown: false,
      ArrowLeft: false,
      ArrowRight: false
    };
    
    // On-screen cabinet references
    this.staticLayer = document.getElementById('power-static');
    
    this.bgCanvas = document.createElement('canvas');
    this.bgCanvas.width = this.width;
    this.bgCanvas.height = this.height;
    this.bgCtx = this.bgCanvas.getContext('2d');
    this.buildBackgroundCache();

    this.initEventListeners();
    this.spawnInitialBugs();
    
    requestAnimationFrame((t) => this.loop(t));
    
    // Boot sequence: show retro screen static, then title
    this.triggerBootSequence();
  }

  initEventListeners() {
    // Keyboard inputs
    window.addEventListener('keydown', (e) => {
      if (this.isGameFrozen()) return;

      this.keys[e.code] = true;

      // Space scrolls the page by default; keep it for gameplay only
      if (e.code === 'Space' && !e.target.closest('input, textarea, select, button')) {
        e.preventDefault();
      }
      
      // Start audio context on first interaction
      audio.init();
      audio.resume();

      // Start BGM on title screen keypress
      if (this.state === 'TITLE' && e.code === 'Space') {
        this.startGame();
      }
      else if (this.state === 'GAMEOVER' && e.code === 'Space') {
        this.resetGame();
      }
      else if (e.code === 'Space') {
        this.triggerShoot();
      }
      else if (e.code === 'Escape') {
        if (this.state === 'PLAYING' || this.state === 'PAUSED') {
          this.toggleSettingsMenu();
        }
      }
      
      // Update D-pad visual state
      this.updateDpadCSS();
    });

    window.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
      this.updateDpadCSS();
    });

    // Mouse/Touch controls inside Canvas
    this.canvas.addEventListener('mousemove', (e) => {
      if (this.state !== 'PLAYING') return;
      const rect = this.canvas.getBoundingClientRect();
      // Translate to 256x240 coordinates
      const scaleX = this.width / rect.width;
      const scaleY = this.height / rect.height;
      this.mouseTarget = {
        x: (e.clientX - rect.left) * scaleX,
        y: (e.clientY - rect.top) * scaleY
      };
    });

    this.canvas.addEventListener('mouseleave', () => {
      this.mouseTarget = null;
    });

    this.canvas.addEventListener('mousedown', (e) => {
      audio.init();
      audio.resume();
      
      if (this.state === 'TITLE') {
        this.startGame();
      } else if (this.state === 'GAMEOVER') {
        this.resetGame();
      } else if (this.state === 'PLAYING') {
        this.triggerShoot();
      }
    });

    // Control switches hooks
    const scanlineToggle = document.getElementById('scanline-toggle');
    const musicToggle = document.getElementById('music-toggle');
    const sfxToggle = document.getElementById('sfx-toggle');
    const bgmVolumeSlider = document.getElementById('bgm-volume-slider');
    const sfxVolumeSlider = document.getElementById('sfx-volume-slider');
    const bgmVolumeValue = document.getElementById('bgm-volume-value');
    const sfxVolumeValue = document.getElementById('sfx-volume-value');
    const scanlinesLayer = document.getElementById('scanlines-layer');

    const updateVolumeLabel = (el, percent) => {
      if (el) el.textContent = `${percent}%`;
    };

    if (bgmVolumeSlider) {
      bgmVolumeSlider.value = audio.bgmVolumePercent;
      updateVolumeLabel(bgmVolumeValue, audio.bgmVolumePercent);
      bgmVolumeSlider.addEventListener('input', (e) => {
        const percent = parseInt(e.target.value, 10);
        audio.setBgmVolume(percent);
        updateVolumeLabel(bgmVolumeValue, percent);
      });
    }

    if (sfxVolumeSlider) {
      sfxVolumeSlider.value = audio.sfxVolumePercent;
      updateVolumeLabel(sfxVolumeValue, audio.sfxVolumePercent);
      sfxVolumeSlider.addEventListener('input', (e) => {
        const percent = parseInt(e.target.value, 10);
        audio.setSfxVolume(percent);
        updateVolumeLabel(sfxVolumeValue, percent);
      });
    }

    scanlineToggle.addEventListener('change', (e) => {
      scanlinesLayer.style.opacity = e.target.checked ? '1' : '0';
    });

    musicToggle.addEventListener('change', (e) => {
      audio.setMusicEnabled(e.target.checked);
    });

    sfxToggle.addEventListener('change', (e) => {
      audio.setSfxEnabled(e.target.checked);
    });

    // Touch Support for Canvas
    const handleTouchAim = (e) => {
      if (e.touches.length > 0) {
        const touch = e.touches[0];
        const rect = this.canvas.getBoundingClientRect();
        const scaleX = this.width / rect.width;
        const scaleY = this.height / rect.height;
        this.mouseTarget = {
          x: (touch.clientX - rect.left) * scaleX,
          y: (touch.clientY - rect.top) * scaleY
        };
      }
    };

    this.canvas.addEventListener('touchstart', (e) => {
      // Prevent scrolling when interacting with game canvas
      e.preventDefault();
      audio.init();
      audio.resume();
      
      if (this.state === 'TITLE') {
        this.startGame();
      } else if (this.state === 'GAMEOVER') {
        this.resetGame();
      } else if (this.state === 'PLAYING') {
        handleTouchAim(e);
        this.triggerShoot();
      }
    }, { passive: false });

    this.canvas.addEventListener('touchmove', (e) => {
      e.preventDefault();
      if (this.state === 'PLAYING') {
        handleTouchAim(e);
      }
    }, { passive: false });

    this.canvas.addEventListener('touchend', (e) => {
      e.preventDefault();
      this.mouseTarget = null;
    }, { passive: false });

    // Game Boy D-Pad buttons touch/mouse interaction
    const dpadButtons = {
      'gb-dpad-up': 'ArrowUp',
      'gb-dpad-down': 'ArrowDown',
      'gb-dpad-left': 'ArrowLeft',
      'gb-dpad-right': 'ArrowRight'
    };

    const blockTouchScroll = (el) => {
      if (!el) return;
      el.addEventListener('touchmove', (e) => e.preventDefault(), { passive: false });
    };

    // touchend + click（端末差を吸収、二重発火は debounce）
    const bindTap = (el, handler) => {
      if (!el) return;
      let lastTapAt = 0;
      const run = (e) => {
        const now = Date.now();
        if (now - lastTapAt < 400) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
        lastTapAt = now;
        e.preventDefault();
        e.stopPropagation();
        handler(e);
      };
      el.addEventListener('touchend', run, { passive: false });
      el.addEventListener('click', run);
      blockTouchScroll(el);
    };

    Object.entries(dpadButtons).forEach(([id, key]) => {
      const btn = document.getElementById(id);
      if (btn) {
        const handleStart = (e) => {
          e.preventDefault();
          if (this.isGameFrozen()) return;
          this.keys[key] = true;
          this.dpadUIButtons[key] = true;
          btn.classList.add('active');
          audio.init();
          audio.resume();
        };
        const handleEnd = (e) => {
          e.preventDefault();
          this.keys[key] = false;
          this.dpadUIButtons[key] = false;
          btn.classList.remove('active');
        };

        btn.addEventListener('mousedown', handleStart);
        btn.addEventListener('touchstart', handleStart, { passive: false });
        blockTouchScroll(btn);
        
        btn.addEventListener('mouseup', handleEnd);
        btn.addEventListener('mouseleave', handleEnd);
        btn.addEventListener('touchend', handleEnd, { passive: false });
        btn.addEventListener('touchcancel', handleEnd, { passive: false });
      }
    });

    // Shoot button (on-screen pink round button)
    const actionBtns = ['gb-shoot-btn'];
    actionBtns.forEach(id => {
      const btn = document.getElementById(id);
      if (btn) {
        const handleAction = (e) => {
          e.preventDefault();
          btn.classList.add('active');
          audio.init();
          audio.resume();
          
          if (this.state === 'TITLE') {
            this.startGame();
          } else if (this.state === 'GAMEOVER') {
            this.resetGame();
          } else if (this.state === 'PLAYING') {
            this.triggerShoot();
          }
          
          setTimeout(() => btn.classList.remove('active'), 100);
        };
        
        btn.addEventListener('mousedown', handleAction);
        btn.addEventListener('touchstart', handleAction, { passive: false });
        blockTouchScroll(btn);
      }
    });

    // Game Boy MENU button
    const menuBtn = document.getElementById('gb-menu-btn');
    const settingsModal = document.getElementById('settings-modal');
    const settingsBackdrop = document.getElementById('settings-backdrop');
    const instructionsModal = document.getElementById('instructions-modal');
    const settingsCloseBtn = document.getElementById('settings-close-btn');
    const infoCloseBtn = document.getElementById('info-close-btn');

    if (menuBtn && settingsModal) {
      bindTap(menuBtn, () => {
        this.toggleSettingsMenu();
        menuBtn.classList.add('active');
        setTimeout(() => menuBtn.classList.remove('active'), 120);
        audio.init();
        audio.resume();
      });
    }

    if (settingsCloseBtn && settingsModal) {
      bindTap(settingsCloseBtn, () => {
        this.closeSettingsMenu();
      });
    }

    if (settingsBackdrop) {
      bindTap(settingsBackdrop, () => {
        this.closeSettingsMenu();
      });
    }

    if (infoCloseBtn && instructionsModal) {
      const closeInstructions = (e) => {
        e.preventDefault();
        instructionsModal.classList.remove('show');
      };
      infoCloseBtn.addEventListener('click', closeInstructions);
      infoCloseBtn.addEventListener('touchstart', closeInstructions, { passive: false });
    }

    const infoToggleBtn = document.getElementById('info-toggle-btn');
    if (infoToggleBtn && instructionsModal) {
      const toggleInstructions = (e) => {
        e.preventDefault();
        e.stopPropagation();
        instructionsModal.classList.toggle('show');
        audio.init();
        audio.resume();
      };
      infoToggleBtn.addEventListener('click', toggleInstructions);
      infoToggleBtn.addEventListener('touchstart', toggleInstructions, { passive: false });
    }
    blockTouchScroll(infoToggleBtn);

    const handleInstructionsOutside = (e) => {
      if (e.type === 'mousedown' && window.matchMedia('(hover: none)').matches) return;
      if (instructionsModal && instructionsModal.classList.contains('show') && !instructionsModal.contains(e.target) && !infoToggleBtn?.contains(e.target)) {
        instructionsModal.classList.remove('show');
      }
    };
    window.addEventListener('touchstart', handleInstructionsOutside, { passive: true });

    const gameCabinet = document.querySelector('.arcade-cabinet');
    if (gameCabinet) {
      gameCabinet.addEventListener('contextmenu', (e) => e.preventDefault());
      gameCabinet.addEventListener('selectstart', (e) => e.preventDefault());
    }

    document.addEventListener('touchmove', (e) => {
      if (e.target.closest('input[type="range"]')) return;
      if (e.target.closest('#settings-modal.show, #instructions-modal.show, #settings-backdrop:not([hidden])')) return;
      if (e.target.closest('.arcade-cabinet')) {
        e.preventDefault();
      }
    }, { passive: false });

    document.addEventListener('visibilitychange', () => this.handlePageVisibility());
  }

  handlePageVisibility() {
    if (document.hidden) {
      this.wasBgmPlayingBeforeHide = audio.isBgmPlaying;
      if (this.wasBgmPlayingBeforeHide) {
        audio.stopBGM();
      }
      return;
    }
    this.tryResumeBgmAfterVisible();
  }

  tryResumeBgmAfterVisible() {
    if (!this.wasBgmPlayingBeforeHide) return;
    this.wasBgmPlayingBeforeHide = false;

    const musicToggle = document.getElementById('music-toggle');
    if (!musicToggle?.checked) return;
    if (this.state !== 'PLAYING' || this.isGameFrozen() || this.bgmPausedByMenu) return;

    audio.startBGM();
  }

  triggerBootSequence() {
    this.staticLayer.classList.add('active');
    setTimeout(() => {
      this.staticLayer.classList.remove('active');
    }, 400);
  }

  updateDpadCSS() {
    const upBtn = document.getElementById('gb-dpad-up');
    const downBtn = document.getElementById('gb-dpad-down');
    const leftBtn = document.getElementById('gb-dpad-left');
    const rightBtn = document.getElementById('gb-dpad-right');

    if (upBtn) {
      if (this.keys['ArrowUp'] || this.keys['KeyW']) upBtn.classList.add('active');
      else upBtn.classList.remove('active');
    }
    if (downBtn) {
      if (this.keys['ArrowDown'] || this.keys['KeyS']) downBtn.classList.add('active');
      else downBtn.classList.remove('active');
    }
    if (leftBtn) {
      if (this.keys['ArrowLeft'] || this.keys['KeyA']) leftBtn.classList.add('active');
      else leftBtn.classList.remove('active');
    }
    if (rightBtn) {
      if (this.keys['ArrowRight'] || this.keys['KeyD']) rightBtn.classList.add('active');
      else rightBtn.classList.remove('active');
    }
  }

  triggerShoot() {
    if (this.state !== 'PLAYING') return;
    
    // Shoot sound and action
    if (this.chameleon.shoot()) {
      audio.playShoot();
      // Shoot button visual feedback
      const shootBtn = document.getElementById('gb-shoot-btn');
      if (shootBtn) {
        shootBtn.classList.add('active');
        setTimeout(() => shootBtn.classList.remove('active'), 100);
      }
    }
  }

  spawnInitialBugs() {
    this.bugs = [];
    const types = ['common', 'common', 'gnat', 'wasp'];
    for (let i = 0; i < this.maxBugs; i++) {
      const type = types[i % types.length];
      this.bugs.push(new Bug(this.width, this.height, type));
    }
  }

  startGame() {
    this.closeSettingsMenu();
    this.state = 'PLAYING';
    this.score = 0;
    this.fliesEaten = 0;
    this.level = 1;
    this.energy = 100;
    this.combo = 0;
    this.chameleon.deactivatePowerUp();
    this.powerUpType = null;
    this.powerUpTimeLeft = 0;
    this.screenShake = 0;
    this.gameOverShakeFrames = 0;
    this.spawnInitialBugs();
    
    audio.resume();
    const musicEnabled = document.getElementById('music-toggle').checked;
    audio.setMusicEnabled(musicEnabled);
  }

  resetGame() {
    this.triggerBootSequence();
    setTimeout(() => {
      this.startGame();
    }, 300);
  }

  isSettingsMenuVisible() {
    return document.getElementById('settings-modal')?.classList.contains('show') ?? false;
  }

  isGameFrozen() {
    return this.frozenByMenu || this.isSettingsMenuVisible();
  }

  /** 毎フレーム DOM/フラグを同期し、ポーズ中は必ずシミュレーション停止 */
  syncPauseFromDom() {
    const shouldFreeze = this.frozenByMenu || this.isSettingsMenuVisible();
    if (!shouldFreeze) {
      return false;
    }
    if (!this.frozenByMenu) {
      this.frozenByMenu = true;
    }
    this.applyPausePresentation(true);
    if (this.state === 'PLAYING') {
      this.pauseGame();
    }
    return true;
  }

  applyPausePresentation(paused) {
    document.querySelector('.arcade-cabinet')?.classList.toggle('game-paused', paused);
    if (this.canvas) {
      this.canvas.style.pointerEvents = paused ? 'none' : '';
    }
  }

  pauseGame() {
    if (this.state !== 'PLAYING') return;
    this.state = 'PAUSED';
    this.keys = {};
    this.mouseTarget = null;
    Object.keys(this.dpadUIButtons).forEach((key) => {
      this.dpadUIButtons[key] = false;
    });
    this.updateDpadCSS();

    const musicToggle = document.getElementById('music-toggle');
    if (musicToggle?.checked && audio.isBgmPlaying) {
      this.bgmPausedByMenu = true;
      audio.stopBGM();
    }
  }

  resumeGame() {
    if (this.state !== 'PAUSED') return;
    this.state = 'PLAYING';

    if (this.bgmPausedByMenu) {
      this.bgmPausedByMenu = false;
      audio.startBGM();
    }
  }

  openSettingsMenu() {
    const settingsModal = document.getElementById('settings-modal');
    const settingsBackdrop = document.getElementById('settings-backdrop');
    if (!settingsModal || this.isSettingsMenuVisible()) return;

    this.frozenByMenu = true;
    this.applyPausePresentation(true);
    if (this.state === 'PLAYING') {
      this.pauseGame();
    }
    settingsModal.classList.add('show');
    if (settingsBackdrop) settingsBackdrop.hidden = false;
  }

  closeSettingsMenu() {
    const settingsModal = document.getElementById('settings-modal');
    const settingsBackdrop = document.getElementById('settings-backdrop');
    if (!settingsModal) return;
    if (!this.frozenByMenu && !settingsModal.classList.contains('show')) return;

    const wasPaused = this.state === 'PAUSED';
    this.frozenByMenu = false;
    settingsModal.classList.remove('show');
    if (settingsBackdrop) settingsBackdrop.hidden = true;
    this.applyPausePresentation(false);

    if (wasPaused) {
      this.resumeGame();
    }
  }

  toggleSettingsMenu() {
    if (this.isSettingsMenuVisible() || this.frozenByMenu) {
      this.closeSettingsMenu();
      return;
    }
    this.openSettingsMenu();
  }

  // --- CORE GAME LOOP ---

  loop(timestamp) {
    if (document.hidden) {
      requestAnimationFrame((t) => this.loop(t));
      return;
    }

    if (this.syncPauseFromDom()) {
      this.draw();
      requestAnimationFrame((t) => this.loop(t));
      return;
    }

    const idleState = this.state !== 'PLAYING';
    const targetInterval = idleState
      ? 1000 / Perf.TARGET_FPS_IDLE
      : 1000 / Perf.TARGET_FPS_PLAYING;

    if (this.lastFrameTime && timestamp - this.lastFrameTime < targetInterval - 1) {
      requestAnimationFrame((t) => this.loop(t));
      return;
    }

    this.lastFrameTime = timestamp;
    this.update();
    this.draw();
    requestAnimationFrame((t) => this.loop(t));
  }

  tickScreenShake() {
    if (this.gameOverShakeFrames > 0) {
      this.gameOverShakeFrames--;
      if (this.screenShake > 0) {
        this.screenShake = Math.max(0, this.screenShake - 0.8);
      }
      if (this.gameOverShakeFrames <= 0) {
        this.screenShake = 0;
      }
      return;
    }
    if (this.state === 'PLAYING' && this.screenShake > 0) {
      this.screenShake = Math.max(0, this.screenShake - 0.8);
    }
  }

  update() {
    if (this.syncPauseFromDom()) {
      return;
    }

    this.tickScreenShake();

    if (this.state !== 'PLAYING') {
      // Gentle animations on Title Screen
      this.chameleon.update(this.keys, null, this.bugs);
      this.bugs.forEach(bug => bug.update());
      return;
    }

    // 1. Decrease Hunger (Energy)
    const depletion = this.energyDepletionRate + (this.level - 1) * 0.008;
    this.energy = Math.max(0, this.energy - depletion);
    if (this.energy <= 0) {
      this.triggerGameOver();
      return;
    }

    // 2. Combo Timer handling
    if (this.combo > 0) {
      this.comboTimer--;
      if (this.comboTimer <= 0) {
        this.combo = 0;
      }
    }

    // 3. Power-Up Timer
    if (this.powerUpType) {
      this.powerUpTimeLeft--;
      if (this.powerUpTimeLeft <= 0) {
        this.powerUpType = null;
        this.chameleon.deactivatePowerUp();
      }
    }

    // 4. Update Chameleon
    // In Slow power-up, bugs move at 40% speed, chameleon moves at normal speed
    const isSlow = this.powerUpType === 'slow';
    this.chameleon.update(this.keys, this.mouseTarget, this.bugs);

    // 5. Update Bugs
    this.bugs.forEach(bug => {
      // In slow motion power-up, update movement multiple times slower
      if (isSlow && bug.state === 'active') {
        if (Math.random() < 0.4) {
          bug.update();
        }
      } else {
        bug.update();
      }
    });

    // 6. Collision Detection (Tongue Tip vs Bugs)
    if (this.chameleon.tongueState === 'shooting' && !this.chameleon.caughtBug) {
      const tipX = this.chameleon.tongueTipX;
      const tipY = this.chameleon.tongueTipY;
      
      // Check collision
      for (const bug of this.bugs) {
        if (bug.state === 'active') {
          const dist = Math.hypot(bug.x - tipX, bug.y - tipY);
          // Collision threshold
          if (dist < bug.size * 2.5 + 4) {
            bug.state = 'caught';
            this.chameleon.caughtBug = bug;
            this.chameleon.tongueState = 'retracting';
            break; // Catch only one bug at a time
          }
        }
      }
    }

    // 7. Eating/Swallowing Hook (called when tongue returns to mouth in chameleon.js)
    if (this.chameleon.tongueState === 'swallowing' && this.chameleon.caughtBug) {
      const eatenBug = this.chameleon.caughtBug;
      
      // Process Score & Energy
      if (eatenBug.type === 'wasp') {
        // Toxic wasp damage
        this.combo = 0;
        this.energy = Math.max(0, this.energy + eatenBug.energyValue);
        this.score = Math.max(0, this.score + eatenBug.scoreValue);
        this.screenShake = 12;
        this.chameleon.triggerHurt(true);
        audio.playHurt();
      } else {
        // Successful fly capture
        this.fliesEaten++;
        this.combo++;
        this.comboTimer = this.maxComboTime;
        
        // Apply scores with combo multipliers
        const baseScore = eatenBug.scoreValue;
        const reward = baseScore * this.combo;
        this.score += reward;
        
        // Add energy
        this.energy = Math.min(100, this.energy + eatenBug.energyValue);
        
        // Audio
        audio.playEat();

        // Handle Firefly powerup triggers
        if (eatenBug.type === 'firefly') {
          this.triggerRandomPowerUp();
        }
      }
      
      // Recycle the eaten bug
      eatenBug.respawn();
      this.chameleon.caughtBug = null;
      
      // Check Level Up threshold (every 1200 points)
      const targetLevel = Math.floor(this.score / 1200) + 1;
      if (targetLevel > this.level) {
        this.level = targetLevel;
        this.levelUpBannerFrames = 80; // display banner for 80 frames
        audio.playPowerup();
        
        // Add extra bug dynamically at higher levels
        if (this.level <= 4 && this.bugs.length < this.maxBugs + 2) {
          const extraTypes = ['common', 'gnat', 'firefly'];
          this.bugs.push(new Bug(this.width, this.height, extraTypes[(this.level) % 3]));
        }
      }
    }

    // 8. Decay visual animations
    if (this.levelUpBannerFrames > 0) this.levelUpBannerFrames--;
  }

  triggerRandomPowerUp() {
    const powerUps = ['gold', 'multi', 'slow'];
    const chosen = powerUps[Math.floor(Math.random() * powerUps.length)];
    
    this.powerUpType = chosen;
    this.powerUpTimeLeft = 480; // 8 seconds at 60fps
    this.chameleon.activatePowerUp(chosen);
    
    audio.playPowerup();
  }

  triggerGameOver() {
    this.state = 'GAMEOVER';
    audio.stopBGM();
    audio.playGameOver();

    // 画面揺れはゲームオーバー直後の 1 秒のみ
    this.gameOverShakeFrames = 60;
    this.screenShake = Math.max(this.screenShake, 12);
    
    // Save high score
    if (this.score > this.highScore) {
      this.highScore = this.score;
      localStorage.setItem('neo_chameleon_highscore', this.highScore);
    }
  }

  // --- RENDERING / DRAWING ---

  draw() {
    this.ctx.save();
    
    // Apply screen shake (PLAYING 中、または GAMEOVER 直後 1 秒間のみ)
    const canShake = this.screenShake > 0 && (
      this.state === 'PLAYING' || this.gameOverShakeFrames > 0
    );
    if (canShake) {
      const dx = (Math.random() - 0.5) * this.screenShake;
      const dy = (Math.random() - 0.5) * this.screenShake;
      this.ctx.translate(dx, dy);
    }
    
    // 1. Draw Background
    this.drawBackground();
    
    // 2. Draw Entities
    this.chameleon.draw(this.ctx);
    this.bugs.forEach(bug => bug.draw(this.ctx));

    // Draw Targeting Cursor
    if (this.state === 'PLAYING') {
      this.drawTargetCursor();
    }
    
    // 3. Draw HUD & GUI
    this.drawHUD();
    
    // Low hunger screen-edge warning glow
    this.drawLowHungerWarning();
    
    // 4. Draw Overlays (Title, Game Over, Paused)
    if (this.state === 'TITLE') {
      this.drawTitleScreen();
    } else if (this.state === 'GAMEOVER') {
      this.drawGameOverScreen();
    } else if (this.isGameFrozen()) {
      this.drawPausedOverlay();
    }
    
    this.ctx.restore();
  }

  drawPausedOverlay() {
    this.ctx.fillStyle = 'rgba(0, 0, 0, 0.45)';
    this.ctx.fillRect(0, 0, this.width, this.height);

    this.ctx.font = '10px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#00f0ff';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('PAUSED', this.width / 2, this.height / 2);
    this.ctx.textAlign = 'left';
  }

  isDpadUIAiming() {
    return Object.values(this.dpadUIButtons).some(Boolean);
  }

  drawTargetCursor() {
    // Only draw cursor when chameleon is idle (not shooting or retracting)
    if (this.chameleon.tongueState !== 'idle') return;
    // Show targeting cursor only while using on-screen D-pad UI
    if (!this.isDpadUIAiming()) return;

    const tx = this.chameleon.pivotX + Math.cos(this.chameleon.angle) * this.chameleon.tongueMaxLen;
    const ty = this.chameleon.pivotY + Math.sin(this.chameleon.angle) * this.chameleon.tongueMaxLen;
    
    this.ctx.save();

    RenderGlow.strokeNeonArc(this.ctx, tx, ty, 5, {
      color: '#ff007f',
      width: 1.5,
      glowWidth: 2,
      glowAlpha: 0.35
    });

    this.ctx.strokeStyle = '#ff007f';
    this.ctx.lineWidth = 1.5;
    
    // Draw center dot
    this.ctx.fillStyle = '#ffffff';
    this.ctx.fillRect(Math.round(tx) - 1, Math.round(ty) - 1, 2, 2);
    
    // Draw crosshair ticks
    this.ctx.beginPath();
    // Top tick
    this.ctx.moveTo(tx, ty - 8); this.ctx.lineTo(tx, ty - 5);
    // Bottom tick
    this.ctx.moveTo(tx, ty + 5); this.ctx.lineTo(tx, ty + 8);
    // Left tick
    this.ctx.moveTo(tx - 8, ty); this.ctx.lineTo(tx - 5, ty);
    // Right tick
    this.ctx.moveTo(tx + 5, ty); this.ctx.lineTo(tx + 8, ty);
    this.ctx.stroke();
    
    // Draw a subtle dotted aiming line from chameleon's mouth to the target
    this.ctx.strokeStyle = 'rgba(255, 0, 127, 0.25)';
    this.ctx.lineWidth = 1;
    this.ctx.setLineDash([2, 4]);
    this.ctx.beginPath();
    this.ctx.moveTo(this.chameleon.pivotX, this.chameleon.pivotY);
    this.ctx.lineTo(tx, ty);
    this.ctx.stroke();
    
    this.ctx.restore();
  }

  buildBackgroundCache() {
    const ctx = this.bgCtx;
    const w = this.width;
    const h = this.height;

    ctx.fillStyle = '#08080f';
    ctx.fillRect(0, 0, w, h);

    ctx.strokeStyle = '#9d00ff';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, 185);
    ctx.lineTo(w, 185);
    ctx.stroke();

    ctx.strokeStyle = 'rgba(255, 0, 127, 0.15)';
    ctx.lineWidth = 1;

    for (let y = 185; y < h; y += 8) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    const vp = w / 2;
    const vpy = 180;
    for (let x = -100; x <= w + 100; x += 30) {
      ctx.beginPath();
      ctx.moveTo(vp + (x - vp) * 0.1, vpy);
      ctx.lineTo(x, h);
      ctx.stroke();
    }

    ctx.fillStyle = 'rgba(255, 0, 127, 0.04)';
    ctx.beginPath();
    ctx.arc(w / 2, 180, 50, Math.PI, 0);
    ctx.fill();
  }

  drawBackground() {
    this.ctx.drawImage(this.bgCanvas, 0, 0);

    if (!this.isGameFrozen()) {
      ctxFlicker(this.ctx);
    }
  }

  drawHUD() {
    const isPlaying = this.state === 'PLAYING' || this.state === 'PAUSED';
    
    // Top Score Bar (Monospace alignment)
    this.ctx.font = '7px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#ffffff';
    
    // Score
    this.ctx.fillText(`SCORE:${String(this.score).padStart(6, '0')}`, 8, 12);
    // High Score
    this.ctx.fillText(`HI-SCORE:${String(this.highScore).padStart(6, '0')}`, 138, 12);

    if (isPlaying) {
      const levelText = `LEVEL ${this.level}`;
      const levelY = 23;
      this.ctx.font = '7px "Press Start 2P", monospace';
      this.ctx.textAlign = 'center';
      this.ctx.strokeStyle = 'rgba(0, 0, 0, 0.85)';
      this.ctx.lineWidth = 2;
      this.ctx.strokeText(levelText, this.width / 2, levelY);
      this.ctx.fillStyle = '#ffea00';
      this.ctx.fillText(levelText, this.width / 2, levelY);
      this.ctx.textAlign = 'left';

      if (this.combo > 1) {
        const comboGlow = Math.sin(this.comboTimer * 0.2) > 0;
        this.ctx.fillStyle = comboGlow ? '#ffea00' : '#ffffff';
        this.ctx.fillText(`COMBO x${this.combo}`, 160, 22);
      }

      // Power Up Active Text (above hunger bar)
      if (this.powerUpType) {
        const secondsLeft = Math.ceil(this.powerUpTimeLeft / 60);
        let text = "";
        let color = "#ffffff";
        switch (this.powerUpType) {
          case 'gold':
            text = `GOLD TONGUE BUSTER : ${secondsLeft}s`;
            color = '#ffea00';
            break;
          case 'multi':
            text = `TRIPLE TONGUE BEAST : ${secondsLeft}s`;
            color = '#ff007f';
            break;
          case 'slow':
            text = `SLOW-MO FLIES ZONE : ${secondsLeft}s`;
            color = '#00f0ff';
            break;
        }
        this.ctx.fillStyle = color;
        this.ctx.textAlign = 'center';
        this.ctx.fillText(text, this.width / 2, this.height - 22);
        this.ctx.textAlign = 'left'; // reset
      }

      // Bottom Hunger Meter (full width)
      const hungerStripH = 18;
      const barX = 8;
      const barW = this.width - 16;
      const barH = 7;
      const barY = this.height - 9;
      const innerPad = 2;
      const fillMaxW = barW - innerPad * 2;

      this.ctx.fillStyle = 'rgba(5, 5, 12, 0.75)';
      this.ctx.fillRect(0, this.height - hungerStripH, this.width, hungerStripH);

      this.ctx.font = '6px "Press Start 2P", monospace';
      this.ctx.fillStyle = '#00f0ff';
      this.ctx.fillText("HUNGER", barX, this.height - 12);

      this.ctx.strokeStyle = '#2d2d44';
      this.ctx.lineWidth = 1;
      this.ctx.strokeRect(barX, barY, barW, barH);

      let fillStyle = '#39ff14';
      const isLowHunger = this.energy < 30;
      if (isLowHunger && !this.isGameFrozen()) {
        const barPulse = Math.sin(Date.now() * 0.012) > 0;
        fillStyle = barPulse ? '#ff3b30' : '#ff6b60';
      } else if (isLowHunger) {
        fillStyle = '#ff3b30';
      } else if (this.energy < 60) {
        fillStyle = '#ffea00';
      }

      this.ctx.fillStyle = fillStyle;
      this.ctx.fillRect(
        barX + innerPad,
        barY + innerPad,
        Math.round((this.energy / 100) * fillMaxW),
        barH - innerPad * 2
      );
      
      // LEVEL UP Splash Banner Banner
      if (this.levelUpBannerFrames > 0) {
        this.ctx.fillStyle = 'rgba(0,0,0,0.6)';
        this.ctx.fillRect(0, this.height / 2 - 15, this.width, 30);
        
        this.ctx.strokeStyle = '#00f0ff';
        this.ctx.lineWidth = 1;
        this.ctx.strokeRect(-1, this.height / 2 - 15, this.width + 2, 30);
        
        this.ctx.font = '10px "Press Start 2P", monospace';
        this.ctx.fillStyle = '#ffea00';
        this.ctx.textAlign = 'center';
        
        // Blink level up
        if (Math.floor(this.levelUpBannerFrames / 5) % 2 === 0) {
          this.ctx.fillText(`LEVEL UP: STAGE ${this.level}`, this.width / 2, this.height / 2 + 3);
        }
        
        this.ctx.textAlign = 'left'; // reset
      }
    }
  }

  drawLowHungerWarning() {
    if (this.isGameFrozen() || this.state !== 'PLAYING' || this.energy >= 30) return;

    const ctx = this.ctx;
    const w = this.width;
    const h = this.height;
    const urgency = 1 - this.energy / 30;
    const pulseSpeed = this.energy < 15 ? 0.014 : 0.008;
    const pulse = 0.5 + 0.5 * Math.sin(Date.now() * pulseSpeed);
    const alpha = (0.2 + urgency * 0.5) * pulse;
    const edgeW = 24 + urgency * 24;
    const edgeAlpha = alpha * 0.9;

    ctx.save();

    const cx = w / 2;
    const cy = h / 2;
    const innerR = Math.min(w, h) * 0.32;
    const outerR = Math.hypot(cx, cy);
    const vignette = ctx.createRadialGradient(cx, cy, innerR, cx, cy, outerR);
    vignette.addColorStop(0, 'rgba(255, 59, 48, 0)');
    vignette.addColorStop(0.6, 'rgba(255, 59, 48, 0)');
    vignette.addColorStop(1, `rgba(255, 59, 48, ${alpha})`);
    ctx.fillStyle = vignette;
    ctx.fillRect(0, 0, w, h);

    let grad = ctx.createLinearGradient(0, 0, 0, edgeW);
    grad.addColorStop(0, `rgba(255, 59, 48, ${edgeAlpha})`);
    grad.addColorStop(1, 'rgba(255, 59, 48, 0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, edgeW);

    grad = ctx.createLinearGradient(0, h, 0, h - edgeW);
    grad.addColorStop(0, `rgba(255, 59, 48, ${edgeAlpha})`);
    grad.addColorStop(1, 'rgba(255, 59, 48, 0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, h - edgeW, w, edgeW);

    grad = ctx.createLinearGradient(0, 0, edgeW, 0);
    grad.addColorStop(0, `rgba(255, 59, 48, ${edgeAlpha})`);
    grad.addColorStop(1, 'rgba(255, 59, 48, 0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, edgeW, h);

    grad = ctx.createLinearGradient(w, 0, w - edgeW, 0);
    grad.addColorStop(0, `rgba(255, 59, 48, ${edgeAlpha})`);
    grad.addColorStop(1, 'rgba(255, 59, 48, 0)');
    ctx.fillStyle = grad;
    ctx.fillRect(w - edgeW, 0, edgeW, h);

    ctx.restore();
  }

  drawTitleScreen() {
    // Semi-transparent wash
    this.ctx.fillStyle = 'rgba(5, 5, 12, 0.6)';
    this.ctx.fillRect(0, 0, this.width, this.height);
    
    this.ctx.textAlign = 'center';
    
    // Large Title text
    this.ctx.font = '14px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#ff007f';
    this.ctx.fillText("NEO CHAMELEON", this.width / 2, 70);
    
    this.ctx.font = '7px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#00f0ff';
    this.ctx.fillText("CYBERNETIC ARCADE ACTION", this.width / 2, 90);
    
    // Flashing Press Start
    const flash = Math.floor(Date.now() / 400) % 2 === 0;
    this.ctx.font = '8px "Press Start 2P", monospace';
    this.ctx.fillStyle = flash ? '#ffffff' : '#4e4e6d';
    this.ctx.fillText("PRESS FIRE OR SPACE", this.width / 2, 130);
    this.ctx.fillText("TO START PLAYING", this.width / 2, 144);
    
    // Copyright
    this.ctx.font = '5px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#8080a0';
    this.ctx.fillText("© 2026 AXION COGNITIONS", this.width / 2, 225);
    
    this.ctx.textAlign = 'left'; // reset
  }

  drawGameOverScreen() {
    this.ctx.fillStyle = 'rgba(15, 0, 10, 0.75)';
    this.ctx.fillRect(0, 0, this.width, this.height);
    
    this.ctx.textAlign = 'center';
    
    this.ctx.font = '14px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#ff3b30'; // Red game over
    this.ctx.fillText("GAME OVER", this.width / 2, 85);
    
    this.ctx.font = '8px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#ffffff';
    this.ctx.fillText(`YOUR SCORE: ${this.score}`, this.width / 2, 115);
    this.ctx.fillStyle = '#39ff14';
    this.ctx.fillText(`FLIES CAUGHT: ${this.fliesEaten}`, this.width / 2, 130);
    
    if (this.score >= this.highScore && this.score > 0) {
      this.ctx.fillStyle = '#ffea00';
      this.ctx.fillText("NEW HIGH SCORE! GLORIOUS!", this.width / 2, 148);
    }
    
    const flash = Math.floor(Date.now() / 400) % 2 === 0;
    this.ctx.fillStyle = flash ? '#00f0ff' : '#4e4e6d';
    this.ctx.fillText("CLICK SCREEN TO CONTINUE", this.width / 2, 168);
    
    this.ctx.textAlign = 'left'; // reset
  }
}

// Background star sparks helper
function ctxFlicker(ctx) {
  const time = Date.now() * 0.005;
  ctx.fillStyle = '#fff';
  const sparks = [
    {x: 30, y: 40}, {x: 180, y: 30}, {x: 120, y: 70}, 
    {x: 70, y: 90}, {x: 220, y: 80}, {x: 230, y: 40}
  ];
  sparks.forEach((sp, index) => {
    // blinking star
    const val = Math.sin(time + index);
    if (val > 0.5) {
      ctx.fillRect(sp.x, sp.y, 1, 1);
    }
  });
}

// Initialize on page load
window.addEventListener('load', () => {
  Bug.initLegendUI();
  window.game = new GameEngine();
});
