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
    
    this.initEventListeners();
    this.spawnInitialBugs();
    
    // Start game loop
    this.lastTime = 0;
    requestAnimationFrame((t) => this.loop(t));
    
    // Boot sequence: show retro screen static, then title
    this.triggerBootSequence();
  }

  initEventListeners() {
    // Keyboard inputs
    window.addEventListener('keydown', (e) => {
      this.keys[e.code] = true;
      
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
      
      // Update D-pad visual state
      this.updateDpadCSS();
    });

    window.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
      this.updateDpadCSS();
    });

    // Mouse/Touch controls inside Canvas
    this.canvas.addEventListener('mousemove', (e) => {
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
      } else {
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
      } else {
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

    Object.entries(dpadButtons).forEach(([id, key]) => {
      const btn = document.getElementById(id);
      if (btn) {
        const handleStart = (e) => {
          e.preventDefault();
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
        
        btn.addEventListener('mouseup', handleEnd);
        btn.addEventListener('mouseleave', handleEnd);
        btn.addEventListener('touchend', handleEnd, { passive: false });
      }
    });

    // Game Boy Action buttons (A & B)
    const actionBtns = ['gb-btn-a', 'gb-btn-b'];
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
          } else {
            this.triggerShoot();
          }
          
          setTimeout(() => btn.classList.remove('active'), 100);
        };
        
        btn.addEventListener('mousedown', handleAction);
        btn.addEventListener('touchstart', handleAction, { passive: false });
      }
    });

    // Game Boy SELECT & START buttons
    const selectBtn = document.getElementById('gb-select-btn');
    const startBtn = document.getElementById('gb-start-btn');
    const settingsModal = document.getElementById('settings-modal');
    const instructionsModal = document.getElementById('instructions-modal');
    const settingsCloseBtn = document.getElementById('settings-close-btn');
    const infoCloseBtn = document.getElementById('info-close-btn');

    if (selectBtn && settingsModal) {
      const toggleSettings = (e) => {
        e.preventDefault();
        e.stopPropagation();
        settingsModal.classList.toggle('show');
        selectBtn.classList.add('active');
        setTimeout(() => selectBtn.classList.remove('active'), 120);
        audio.init();
        audio.resume();
      };
      selectBtn.addEventListener('click', toggleSettings);
      selectBtn.addEventListener('touchstart', toggleSettings, { passive: false });
    }

    if (settingsCloseBtn && settingsModal) {
      const closeSettings = (e) => {
        e.preventDefault();
        settingsModal.classList.remove('show');
      };
      settingsCloseBtn.addEventListener('click', closeSettings);
      settingsCloseBtn.addEventListener('touchstart', closeSettings, { passive: false });
    }

    if (startBtn && instructionsModal) {
      const toggleInstructions = (e) => {
        e.preventDefault();
        e.stopPropagation();
        instructionsModal.classList.toggle('show');
        startBtn.classList.add('active');
        setTimeout(() => startBtn.classList.remove('active'), 120);
        audio.init();
        audio.resume();
      };
      startBtn.addEventListener('click', toggleInstructions);
      startBtn.addEventListener('touchstart', toggleInstructions, { passive: false });
    }

    if (infoCloseBtn && instructionsModal) {
      const closeInstructions = (e) => {
        e.preventDefault();
        instructionsModal.classList.remove('show');
      };
      infoCloseBtn.addEventListener('click', closeInstructions);
      infoCloseBtn.addEventListener('touchstart', closeInstructions, { passive: false });
    }

    // Close modals on window click/touchstart if clicking outside
    window.addEventListener('click', (e) => {
      if (instructionsModal && instructionsModal.classList.contains('show') && !instructionsModal.contains(e.target) && e.target !== startBtn) {
        instructionsModal.classList.remove('show');
      }
      if (settingsModal && settingsModal.classList.contains('show') && !settingsModal.contains(e.target) && e.target !== selectBtn) {
        settingsModal.classList.remove('show');
      }
    });

    window.addEventListener('touchstart', (e) => {
      if (instructionsModal && instructionsModal.classList.contains('show') && !instructionsModal.contains(e.target) && e.target !== startBtn) {
        instructionsModal.classList.remove('show');
      }
      if (settingsModal && settingsModal.classList.contains('show') && !settingsModal.contains(e.target) && e.target !== selectBtn) {
        settingsModal.classList.remove('show');
      }
    }, { passive: true });
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
      // Game Boy button feedback
      const btnA = document.getElementById('gb-btn-a');
      if (btnA) {
        btnA.classList.add('active');
        setTimeout(() => btnA.classList.remove('active'), 100);
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
    this.state = 'PLAYING';
    this.score = 0;
    this.fliesEaten = 0;
    this.level = 1;
    this.energy = 100;
    this.combo = 0;
    this.chameleon.deactivatePowerUp();
    this.powerUpType = null;
    this.powerUpTimeLeft = 0;
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

  // --- CORE GAME LOOP ---

  loop(timestamp) {
    this.update();
    this.draw();
    requestAnimationFrame((t) => this.loop(t));
  }

  update() {
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
        this.chameleon.triggerHurt();
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
    if (this.screenShake > 0) this.screenShake -= 0.8;
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
    
    // Save high score
    if (this.score > this.highScore) {
      this.highScore = this.score;
      localStorage.setItem('neo_chameleon_highscore', this.highScore);
    }
  }

  // --- RENDERING / DRAWING ---

  draw() {
    this.ctx.save();
    
    // Apply screen shake
    if (this.screenShake > 0) {
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
    
    // 4. Draw Overlays (Title, Game Over, Paused)
    if (this.state === 'TITLE') {
      this.drawTitleScreen();
    } else if (this.state === 'GAMEOVER') {
      this.drawGameOverScreen();
    }
    
    this.ctx.restore();
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
    
    // Draw a beautiful retro neon-pink target crosshair
    this.ctx.save();
    
    // Set neon pink glow
    this.ctx.shadowColor = '#ff007f';
    this.ctx.shadowBlur = 4;
    
    this.ctx.strokeStyle = '#ff007f';
    this.ctx.lineWidth = 1.5;
    
    // Draw a small target circle
    this.ctx.beginPath();
    this.ctx.arc(tx, ty, 5, 0, Math.PI * 2);
    this.ctx.stroke();
    
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

  drawBackground() {
    // Cyberpunk Grid Background
    // Dark deep blue background
    this.ctx.fillStyle = '#08080f';
    this.ctx.fillRect(0, 0, this.width, this.height);
    
    // Draw neon pink horizon line
    this.ctx.strokeStyle = '#9d00ff';
    this.ctx.lineWidth = 1;
    this.ctx.beginPath();
    this.ctx.moveTo(0, 185);
    this.ctx.lineTo(this.width, 185);
    this.ctx.stroke();

    // Floor neon grid lines (perspective simulation)
    this.ctx.strokeStyle = 'rgba(255, 0, 127, 0.15)';
    this.ctx.lineWidth = 1;
    
    // Horizontal lines
    for (let y = 185; y < this.height; y += 8) {
      this.ctx.beginPath();
      this.ctx.moveTo(0, y);
      this.ctx.lineTo(this.width, y);
      this.ctx.stroke();
    }
    // Vertical perspective lines radiating outward
    const vp = this.width / 2; // vanishing point X
    const vpy = 180; // vanishing point Y
    for (let x = -100; x <= this.width + 100; x += 30) {
      this.ctx.beginPath();
      this.ctx.moveTo(vp + (x - vp) * 0.1, vpy);
      this.ctx.lineTo(x, this.height);
      this.ctx.stroke();
    }
    
    // Glowing synth sun in distance
    this.ctx.fillStyle = 'rgba(255, 0, 127, 0.04)';
    this.ctx.beginPath();
    this.ctx.arc(this.width / 2, 180, 50, Math.PI, 0);
    this.ctx.fill();
    
    // Draw little pixelated clouds or neon star sparks in sky
    ctxFlicker(this.ctx);
  }

  drawHUD() {
    const isPlaying = this.state === 'PLAYING';
    
    // Top Score Bar (Monospace alignment)
    this.ctx.font = '7px "Press Start 2P", monospace';
    this.ctx.fillStyle = '#ffffff';
    
    // Score
    this.ctx.fillText(`SCORE:${String(this.score).padStart(6, '0')}`, 8, 12);
    // High Score
    this.ctx.fillText(`HI-SCORE:${String(this.highScore).padStart(6, '0')}`, 138, 12);

    if (isPlaying) {
      // Second-row stats (hunger moved to bottom)
      this.ctx.font = '6px "Press Start 2P", monospace';
      this.ctx.fillStyle = '#39ff14';
      this.ctx.fillText(`ハエ:${String(this.fliesEaten).padStart(3, '0')}`, 8, 22);

      this.ctx.fillStyle = '#ff007f';
      this.ctx.fillText(`LVL:${this.level}`, 100, 22);

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
      if (this.energy < 30) {
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
    this.ctx.fillText("© 2026 DEEPMIND RETRO CORP", this.width / 2, 225);
    
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
    this.ctx.fillText(`EATEN FLIES: ${this.fliesEaten}`, this.width / 2, 130);
    
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
  window.game = new GameEngine();
});
