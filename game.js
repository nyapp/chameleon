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
    
    // On-screen cabinet references
    this.joystick = document.getElementById('cabinet-joystick');
    this.shootButton = document.getElementById('cabinet-shoot-btn');
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
      
      // Update Joystick visual state on cabinet
      this.updateJoystickCSS();
    });

    window.addEventListener('keyup', (e) => {
      this.keys[e.code] = false;
      this.updateJoystickCSS();
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
    const scanlinesLayer = document.getElementById('scanlines-layer');

    scanlineToggle.addEventListener('change', (e) => {
      scanlinesLayer.style.opacity = e.target.checked ? '1' : '0';
    });

    musicToggle.addEventListener('change', (e) => {
      audio.setMusicEnabled(e.target.checked);
    });

    sfxToggle.addEventListener('change', (e) => {
      audio.setSfxEnabled(e.target.checked);
    });

    // Virtual cabinet buttons
    this.shootButton.addEventListener('mousedown', () => {
      audio.init();
      audio.resume();
      if (this.state === 'TITLE') this.startGame();
      else if (this.state === 'GAMEOVER') this.resetGame();
      else this.triggerShoot();
    });
  }

  triggerBootSequence() {
    this.staticLayer.classList.add('active');
    setTimeout(() => {
      this.staticLayer.classList.remove('active');
    }, 400);
  }

  updateJoystickCSS() {
    this.joystick.className = 'joystick-shaft';
    if (this.keys['ArrowUp'] || this.keys['KeyW']) {
      this.joystick.classList.add('up');
    } else if (this.keys['ArrowDown'] || this.keys['KeyS']) {
      this.joystick.classList.add('down');
    }
  }

  triggerShoot() {
    if (this.state !== 'PLAYING') return;
    
    // Shoot sound and action
    if (this.chameleon.shoot()) {
      audio.playShoot();
      // Cabinet fire button animation feedback
      this.shootButton.classList.add('active');
      setTimeout(() => this.shootButton.classList.remove('active'), 100);
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
      // Hunger Meter Label
      this.ctx.font = '6px "Press Start 2P", monospace';
      this.ctx.fillStyle = '#00f0ff';
      this.ctx.fillText("HUNGER", 8, 22);
      
      // Energy Bar Outer Border
      this.ctx.strokeStyle = '#2d2d44';
      this.ctx.lineWidth = 1;
      this.ctx.strokeRect(48, 17, 104, 6);
      
      // Fill Hunger Bar
      let fillStyle = '#39ff14'; // green
      if (this.energy < 30) {
        fillStyle = '#ff3b30'; // flashing red if low energy
      } else if (this.energy < 60) {
        fillStyle = '#ffea00'; // yellow
      }
      
      this.ctx.fillStyle = fillStyle;
      this.ctx.fillRect(50, 19, Math.round(this.energy), 2);
      
      // Level Display
      this.ctx.fillStyle = '#ff007f';
      this.ctx.fillText(`LVL:${this.level}`, 160, 22);

      // Combo Display
      if (this.combo > 1) {
        const comboGlow = Math.sin(this.comboTimer * 0.2) > 0;
        this.ctx.fillStyle = comboGlow ? '#ffea00' : '#ffffff';
        this.ctx.fillText(`COMBO x${this.combo}`, 200, 22);
      }

      // Power Up Active Text (bottom center)
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
        this.ctx.fillText(text, this.width / 2, this.height - 10);
        this.ctx.textAlign = 'left'; // reset
      }
      
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
    
    if (this.score >= this.highScore && this.score > 0) {
      this.ctx.fillStyle = '#ffea00';
      this.ctx.fillText("NEW HIGH SCORE! GLORIOUS!", this.width / 2, 132);
    }
    
    const flash = Math.floor(Date.now() / 400) % 2 === 0;
    this.ctx.fillStyle = flash ? '#00f0ff' : '#4e4e6d';
    this.ctx.fillText("CLICK SCREEN TO CONTINUE", this.width / 2, 160);
    
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
