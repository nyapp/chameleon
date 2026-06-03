/**
 * NEO CHAMELEON - Chameleon Character Logic & Pixel Art Drawing
 */

class Chameleon {
  constructor(canvasWidth, canvasHeight) {
    this.canvasWidth = canvasWidth;
    this.canvasHeight = canvasHeight;
    
    // Core positioning (sitting on a diagonal branch on the bottom-left)
    this.x = 42;
    this.y = 175;
    this.pivotX = this.x + 14; // Neck pivot center
    this.pivotY = this.y - 12;
    
    // Rotation & Aiming
    this.angle = -Math.PI / 6; // Angle in radians (default angled up-right, e.g. -30deg)
    this.targetAngle = -Math.PI / 6;
    this.rotationSpeed = 0.08;
    
    // Tongue properties
    this.tongueState = 'idle'; // 'idle', 'shooting', 'retracting', 'swallowing'
    this.tongueLen = 0;
    this.tongueMaxLen = 170; // Max reach in pixels
    this.tongueSpeed = 16;   // Pixels per frame
    this.tongueTipX = this.pivotX;
    this.tongueTipY = this.pivotY;
    this.caughtBug = null;
    
    // Animation states
    this.idleTime = 0;
    this.mouthOpen = 0; // 0 = closed, 1 = fully open
    this.eyeTargetAngle = 0;
    this.flashFrames = 0; // Flash when hit (red or poison purple)
    this.hurtPoison = false;
    this.powerUpActive = null; // 'gold', 'multi', 'slow'
    this.colorCycle = 0;
    
    // Pixel scale
    this.pixelScale = 2; // Each sprite pixel is 2 canvas pixels
  }

  update(keys, mouseTarget, currentBugs) {
    this.idleTime += 0.05;
    
    // 1. Aiming Logic
    if (mouseTarget) {
      // Aim with mouse: calculate angle from head pivot to mouse
      const dx = mouseTarget.x - this.pivotX;
      const dy = mouseTarget.y - this.pivotY;
      
      // Chameleon sits on left, looks right/up. Keep angle bounded to range:
      // Straight Up (-Math.PI/2) to Down-Right (Math.PI/8)
      let desiredAngle = Math.atan2(dy, dx);
      if (desiredAngle < -Math.PI * 0.6) desiredAngle = -Math.PI * 0.6;
      if (desiredAngle > Math.PI * 0.1) desiredAngle = Math.PI * 0.1;
      
      this.targetAngle = desiredAngle;
    } else {
      // Aim with Keyboard
      if (keys['ArrowUp'] || keys['KeyW']) {
        this.targetAngle -= 0.04;
      }
      if (keys['ArrowDown'] || keys['KeyS']) {
        this.targetAngle += 0.04;
      }
      // Clamps
      if (this.targetAngle < -Math.PI * 0.65) this.targetAngle = -Math.PI * 0.65;
      if (this.targetAngle > Math.PI * 0.15) this.targetAngle = Math.PI * 0.15;
    }

    // Smooth angle rotation
    const diff = this.targetAngle - this.angle;
    this.angle += diff * this.rotationSpeed;
    
    // Eye tracking logic: look at nearest bug, or follow target angle
    if (currentBugs && currentBugs.length > 0) {
      let nearestBug = null;
      let minDist = 9999;
      for (const bug of currentBugs) {
        const d = Math.hypot(bug.x - this.pivotX, bug.y - this.pivotY);
        if (d < minDist && bug.state === 'active') {
          minDist = d;
          nearestBug = bug;
        }
      }
      if (nearestBug) {
        this.eyeTargetAngle = Math.atan2(nearestBug.y - this.pivotY, nearestBug.x - this.pivotX);
      } else {
        this.eyeTargetAngle = this.angle;
      }
    } else {
      this.eyeTargetAngle = this.angle;
    }

    // 2. Tongue Shooting State Machine
    if (this.tongueState === 'shooting') {
      this.mouthOpen = Math.min(this.mouthOpen + 0.25, 1);
      this.tongueLen += this.tongueSpeed;
      
      // Calculate tip position
      this.tongueTipX = this.pivotX + Math.cos(this.angle) * this.tongueLen;
      this.tongueTipY = this.pivotY + Math.sin(this.angle) * this.tongueLen;
      
      // Out of bounds / Max length check
      if (this.tongueLen >= this.tongueMaxLen || 
          this.tongueTipX < 0 || this.tongueTipX > this.canvasWidth || 
          this.tongueTipY < 0 || this.tongueTipY > this.canvasHeight) {
        this.tongueState = 'retracting';
      }
    } 
    else if (this.tongueState === 'retracting') {
      this.tongueLen -= this.tongueSpeed * 0.8; // Retract slightly slower for weight
      if (this.tongueLen <= 0) {
        this.tongueLen = 0;
        this.tongueState = 'swallowing';
      }
      
      this.tongueTipX = this.pivotX + Math.cos(this.angle) * this.tongueLen;
      this.tongueTipY = this.pivotY + Math.sin(this.angle) * this.tongueLen;
      
      // Drag bug along
      if (this.caughtBug) {
        this.caughtBug.x = this.tongueTipX;
        this.caughtBug.y = this.tongueTipY;
      }
    } 
    else if (this.tongueState === 'swallowing') {
      this.mouthOpen = Math.max(this.mouthOpen - 0.15, 0);
      if (this.mouthOpen <= 0) {
        this.tongueState = 'idle';
        if (this.caughtBug) {
          // Trigger eat success hook in main game logic
          this.caughtBug.state = 'eaten';
          this.caughtBug = null;
        }
      }
    } 
    else {
      // Idle state
      this.tongueLen = 0;
      this.tongueTipX = this.pivotX;
      this.tongueTipY = this.pivotY;
      this.mouthOpen = 0;
    }

    // Flash frames countdown
    if (this.flashFrames > 0) this.flashFrames--;
    
    // Tick color cycle for synthwave rainbow powerup
    this.colorCycle += 0.05;
  }

  shoot() {
    if (this.tongueState === 'idle') {
      this.tongueState = 'shooting';
      this.tongueLen = 5;
      this.caughtBug = null;
      return true;
    }
    return false;
  }

  triggerHurt(isPoison = false) {
    this.flashFrames = 15;
    this.hurtPoison = isPoison;
  }

  activatePowerUp(type) {
    this.powerUpActive = type;
    if (type === 'gold') {
      this.tongueMaxLen = 220;
      this.tongueSpeed = 22;
    } else {
      this.tongueMaxLen = 170;
      this.tongueSpeed = 16;
    }
  }

  deactivatePowerUp() {
    this.powerUpActive = null;
    this.tongueMaxLen = 170;
    this.tongueSpeed = 16;
  }

  // --- DRAWING LOGIC ---

  draw(ctx) {
    const scale = this.pixelScale;
    
    // Helper: draw a 1px sprite block scaled
    const drawPixel = (px, py, color) => {
      ctx.fillStyle = color;
      ctx.fillRect(px * scale, py * scale, scale, scale);
    };

    // 1. Draw Tree Branch (Diagonal)
    ctx.fillStyle = '#4a2c11';
    ctx.fillRect(0, 185, 90, 8);
    ctx.fillStyle = '#301c0a';
    ctx.fillRect(0, 193, 80, 6);
    
    // Little retro leaf on branch
    ctx.fillStyle = '#1b7a27';
    ctx.fillRect(70, 181, 6, 4);
    ctx.fillRect(72, 177, 2, 4);

    // Save context to apply local adjustments (flash / color cycle)
    ctx.save();
    
    // Choose chameleon color scheme
    let skinColor = '#00f0ff'; // Cyber cyan base color
    let bellyColor = '#ff007f'; // Pink highlight belly
    let darkColor = '#008ba3';
    
    if (this.powerUpActive === 'gold') {
      // Golden power-up skin
      skinColor = '#ffea00';
      bellyColor = '#ffaa00';
      darkColor = '#b38600';
    } else if (this.powerUpActive === 'multi') {
      // Flashing multi-tongue skin — all body parts cycle together
      const speed = Math.floor(this.colorCycle * 5) % 3;
      if (speed === 0) {
        skinColor = '#39ff14';
        bellyColor = '#b8ffb8';
        darkColor = '#1a9900';
      } else if (speed === 1) {
        skinColor = '#ff007f';
        bellyColor = '#ffb8dc';
        darkColor = '#99004d';
      } else {
        skinColor = '#00f0ff';
        bellyColor = '#b8ffff';
        darkColor = '#008ba3';
      }
    } else if (this.flashFrames > 0) {
      if (this.hurtPoison) {
        skinColor = '#bf5af2';
        bellyColor = '#39ff14';
        darkColor = '#5b21b6';
      } else {
        skinColor = '#ff3b30';
        bellyColor = '#ffffff';
        darkColor = '#800000';
      }
    }

    // 2. Draw Body & Legs (Stationary part)
    // Drawn via pixel matrix relative to this.x and this.y
    // We will draw it manually using rects to ensure retro-style perfect alignment.
    
    // Curved tail curled up
    ctx.fillStyle = darkColor;
    ctx.fillRect(this.x - 24, this.y - 12, 10, 4);
    ctx.fillRect(this.x - 26, this.y - 8, 4, 10);
    ctx.fillRect(this.x - 22, this.y + 2, 10, 4);
    
    ctx.fillStyle = skinColor;
    ctx.fillRect(this.x - 20, this.y - 10, 8, 4);
    ctx.fillRect(this.x - 24, this.y - 6, 4, 8);
    ctx.fillRect(this.x - 20, this.y + 2, 8, 2);

    // Main torso
    const breathing = Math.sin(this.idleTime * 2) * 1.5; // slow breathing motion
    ctx.fillStyle = skinColor;
    ctx.fillRect(this.x - 14, this.y - 14 + breathing, 22, 18 - breathing);
    
    // Belly highlights
    ctx.fillStyle = bellyColor;
    ctx.fillRect(this.x - 8, this.y - 8 + breathing, 12, 10 - breathing);

    // Legs
    ctx.fillStyle = darkColor;
    // Front foot
    ctx.fillRect(this.x + 2, this.y + 4, 4, 8);
    ctx.fillRect(this.x + 4, this.y + 10, 6, 2);
    // Back foot
    ctx.fillRect(this.x - 12, this.y + 4, 4, 8);
    ctx.fillRect(this.x - 14, this.y + 10, 6, 2);

    // Back spikes (NES dinosaur style)
    ctx.fillStyle = bellyColor;
    ctx.fillRect(this.x - 12, this.y - 18 + breathing, 4, 4);
    ctx.fillRect(this.x - 4, this.y - 18 + breathing, 4, 4);
    ctx.fillRect(this.x + 4, this.y - 16 + breathing, 3, 3);

    // 3. Draw Rotating Head & Eye & Mouth
    // Since the head turns to look at bugs, we rotate the canvas context around the pivot
    ctx.translate(this.pivotX, this.pivotY);
    ctx.rotate(this.angle);

    // Draw Tongue (behind the head, inside the local head coordinates)
    if (this.tongueState === 'shooting' || this.tongueState === 'retracting' || this.tongueState === 'swallowing') {
      this.drawTongueLocal(ctx);
    }

    // HEAD SHAPE (relative to its pivot 0,0)
    // Draw back of head, crown, jaw
    ctx.fillStyle = skinColor;
    // Main head block
    ctx.fillRect(-10, -12, 22, 20);
    // Crown crest
    ctx.fillRect(-14, -14, 12, 4);
    ctx.fillRect(-12, -18, 6, 4);

    // JAW & MOUTH (Opening animation)
    ctx.fillStyle = darkColor;
    // Inside mouth dark cavity (drawn when mouth opens)
    if (this.mouthOpen > 0.1) {
      ctx.fillStyle = '#800030'; // Dark red throat
      ctx.fillRect(4, -4, 10, 6 * this.mouthOpen);
      
      // Upper lip
      ctx.fillStyle = skinColor;
      ctx.fillRect(4, -10, 10, 6);
      // Lower jaw (moves downwards)
      ctx.fillRect(2, 2 + (6 * this.mouthOpen), 10, 4);
    } else {
      // Closed mouth line
      ctx.fillStyle = darkColor;
      ctx.fillRect(6, -2, 8, 2);
    }

    // EYE (yellow iris on head — no socket / border layer)
    ctx.fillStyle = varColor('--neon-yellow') || '#ffea00';
    ctx.fillRect(-4, -8, 7, 7);

    const eyeRelativeAngle = this.eyeTargetAngle - this.angle;
    const pupilDist = 1.2;
    const pupilX = Math.round(-1 + Math.cos(eyeRelativeAngle) * pupilDist);
    const pupilY = Math.round(-5 + Math.sin(eyeRelativeAngle) * pupilDist);
    ctx.fillStyle = '#000000';
    ctx.fillRect(pupilX, pupilY, 2, 2);

    ctx.restore(); // Restore to clean state
  }

  drawTongueLocal(ctx) {
    const scale = this.pixelScale;
    
    // Choose tongue color (standard neon pink, or gold if powered up)
    let tongueColor = '#ff007f';
    let tongueTipColor = '#ffffff';
    let lineGlowColor = 'rgba(255, 0, 127, 0.4)';
    
    if (this.powerUpActive === 'gold') {
      tongueColor = '#ffea00';
      tongueTipColor = '#ffffff';
      lineGlowColor = 'rgba(255, 234, 0, 0.4)';
    }

    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(this.tongueLen, 0);
    RenderGlow.strokeNeonPath(ctx, {
      color: tongueColor,
      width: 6,
      glowWidth: 3,
      glowAlpha: 0.4,
      lineCap: 'round'
    });

    ctx.strokeStyle = tongueTipColor;
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(this.tongueLen, 0);
    ctx.stroke();

    // Draw the sticky tongue tip (a retro bulbous pixel circle)
    ctx.fillStyle = tongueColor;
    ctx.fillRect(this.tongueLen - 4, -4, 8, 8);
    ctx.fillStyle = tongueTipColor;
    ctx.fillRect(this.tongueLen - 2, -2, 4, 4);

    // If multi-tongue power-up is active, draw two extra smaller angled ghost tongues!
    if (this.powerUpActive === 'multi') {
      const angles = [-0.25, 0.25];
      angles.forEach(ang => {
        const sideTipX = Math.cos(ang) * this.tongueLen;
        const sideTipY = Math.sin(ang) * this.tongueLen;
        
        ctx.strokeStyle = 'rgba(0, 240, 255, 0.8)';
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(sideTipX, sideTipY);
        ctx.stroke();
        
        ctx.fillStyle = '#00f0ff';
        ctx.fillRect(sideTipX - 3, sideTipY - 3, 6, 6);
      });
    }
  }
}

// Utility to read CSS root variable values
function varColor(varName) {
  return getComputedStyle(document.documentElement).getPropertyValue(varName).trim();
}
