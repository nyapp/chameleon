/**
 * NEO CHAMELEON - Bug/Insect Classes & AI Movement Patterns
 */

class Bug {
  static TYPE_META = {
    common: {
      scoreValue: 100,
      energyValue: 15,
      color: '#a0a0a0',
      size: 4,
      labelJa: '普通のハエ',
    },
    gnat: {
      scoreValue: 300,
      energyValue: 25,
      color: '#ffea00',
      size: 3,
      labelJa: '金の羽虫',
      tag: '高速',
    },
    firefly: {
      scoreValue: 200,
      energyValue: 15,
      color: '#00f0ff',
      size: 4,
      labelJa: 'ホタル',
      tag: 'パワーアップ',
    },
    wasp: {
      scoreValue: -200,
      energyValue: -25,
      color: '#ff3b30',
      size: 5,
      labelJa: '毒ハチ',
      tag: '体力減少',
    },
  };

  static LEGEND_ORDER = ['common', 'gnat', 'firefly', 'wasp'];

  constructor(canvasWidth, canvasHeight, type) {
    this.canvasWidth = canvasWidth;
    this.canvasHeight = canvasHeight;
    this.type = type; // 'common', 'gnat', 'firefly', 'wasp'
    
    this.state = 'active'; // 'active', 'caught', 'eaten'
    this.x = 0;
    this.y = 0;
    this.vx = 0;
    this.vy = 0;
    
    // Animation variables
    this.wingFrame = 0;
    this.time = Math.random() * 100; // Offset start phase for wave motions
    this.glowCycle = 0;
    
    this.initTypeProperties();
    this.respawn();
  }

  initTypeProperties() {
    const meta = Bug.TYPE_META[this.type] || Bug.TYPE_META.common;
    if (!Bug.TYPE_META[this.type]) {
      this.type = 'common';
    }
    this.scoreValue = meta.scoreValue;
    this.energyValue = meta.energyValue;
    this.color = meta.color;
    this.size = meta.size;
  }

  static formatScoreValue(scoreValue) {
    const sign = scoreValue > 0 ? '+' : '';
    return `${sign}${scoreValue}`;
  }

  static drawSprite(ctx, type, wingFrame = 0, glowCycle = 1.2) {
    if (type === 'common') {
      ctx.fillStyle = '#1c1c1c';
      ctx.fillRect(-2, -2, 4, 4);
      ctx.fillStyle = '#ff3b30';
      ctx.fillRect(2, -2, 2, 2);
      ctx.fillStyle = '#dcdcdc';
      if (wingFrame === 0) {
        ctx.fillRect(-4, -6, 2, 4);
        ctx.fillRect(-2, -6, 2, 4);
      } else {
        ctx.fillRect(-6, -4, 4, 2);
        ctx.fillRect(-4, -4, 4, 2);
      }
    } else if (type === 'gnat') {
      RenderGlow.fillNeonHalo(ctx, -6, -6, 10, 8, '#ffea00', 0.45);
      ctx.fillStyle = '#b38600';
      ctx.fillRect(-2, -2, 4, 2);
      ctx.fillStyle = '#ffea00';
      if (wingFrame === 0) {
        ctx.fillRect(-4, -4, 2, 2);
        ctx.fillRect(0, -4, 2, 2);
      } else {
        ctx.fillRect(-6, -2, 2, 2);
        ctx.fillRect(2, -2, 2, 2);
      }
    } else if (type === 'firefly') {
      const glowAlpha = 0.28 + (Math.sin(glowCycle) + 1) * 0.18;
      RenderGlow.fillNeonHalo(ctx, -6, -6, 10, 8, '#00f0ff', glowAlpha);
      ctx.fillStyle = '#00c8ff';
      ctx.fillRect(-2, -2, 4, 4);
      ctx.fillStyle = '#ffffff';
      if (wingFrame === 0) {
        ctx.fillRect(-4, -4, 2, 2);
        ctx.fillRect(2, -4, 2, 2);
      } else {
        ctx.fillRect(-5, -2, 2, 2);
        ctx.fillRect(3, -2, 2, 2);
      }
      ctx.fillStyle = '#39ff14';
      ctx.fillRect(-4, 0, 2, 2);
    } else if (type === 'wasp') {
      RenderGlow.fillNeonHalo(ctx, -7, -7, 14, 10, '#ff3b30', 0.4);
      ctx.fillStyle = '#ff3b30';
      ctx.fillRect(-4, -2, 8, 4);
      ctx.fillStyle = '#0a0a14';
      ctx.fillRect(-2, -2, 2, 4);
      ctx.fillRect(2, -2, 2, 4);
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(-6, 0, 2, 1);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
      if (wingFrame === 0) {
        ctx.fillRect(-2, -6, 2, 4);
        ctx.fillRect(0, -6, 2, 4);
      } else {
        ctx.fillRect(-4, -4, 2, 2);
        ctx.fillRect(2, -4, 2, 2);
      }
    }
  }

  static initLegendUI() {
    const legend = document.querySelector('.bug-legend');
    if (!legend) return;

    const scale = 2;
    const size = 32;

    Bug.LEGEND_ORDER.forEach((type) => {
      const meta = Bug.TYPE_META[type];
      const item = legend.querySelector(`[data-bug-type="${type}"]`);
      if (!item) return;

      const canvas = item.querySelector('.bug-legend-icon');
      if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.imageSmoothingEnabled = false;
        ctx.clearRect(0, 0, size, size);
        ctx.save();
        ctx.translate(size / 2, size / 2);
        ctx.scale(scale, scale);
        Bug.drawSprite(ctx, type, 0, 1.2);
        ctx.restore();
      }

      const scoreEl = item.querySelector('.legend-score');
      if (scoreEl) {
        scoreEl.textContent = `${Bug.formatScoreValue(meta.scoreValue)}点`;
        scoreEl.classList.toggle('legend-score--negative', meta.scoreValue < 0);
        scoreEl.classList.toggle('legend-score--positive', meta.scoreValue > 0);
      }

      const labelEl = item.querySelector('.legend-label');
      if (labelEl) {
        labelEl.textContent = meta.tag ? `${meta.labelJa} (${meta.tag})` : meta.labelJa;
      }
    });
  }

  respawn() {
    this.state = 'active';
    this.time = Math.random() * 100;
    
    // Spawn off-screen (usually on the right or top, since chameleon is at bottom-left)
    const side = Math.random() > 0.4 ? 'right' : 'top';
    
    if (side === 'right') {
      this.x = this.canvasWidth + 10;
      this.y = Math.random() * (this.canvasHeight - 90) + 20; // Keep off the bottom branch
      
      // Speed (moving leftwards)
      if (this.type === 'gnat') {
        this.vx = -(2.2 + Math.random() * 1.5);
      } else if (this.type === 'wasp') {
        this.vx = -(1.2 + Math.random() * 0.8);
      } else { // common
        this.vx = -(1.0 + Math.random() * 0.8);
      }
    } else {
      // Spawn from top
      this.x = Math.random() * (this.canvasWidth - 80) + 60;
      this.y = -10;
      
      this.vx = -(0.5 + Math.random() * 0.8);
      this.vy = (0.6 + Math.random() * 1.0);
    }
    
    // Set specific speeds and paths
    if (this.type === 'firefly') {
      // Fireflies drift in looping spiral patterns
      this.vx = -(0.6 + Math.random() * 0.6);
      this.vy = (Math.random() - 0.5) * 0.5;
    }
  }

  update() {
    if (this.state === 'caught') {
      // Position is bound to tongue tip in chameleon.js, do not update movement physics
      return;
    }
    
    this.time += 0.08;
    this.glowCycle += 0.15;
    
    // Tick wing animation (flapping)
    if (Math.floor(this.time * 5) % 2 === 0) {
      this.wingFrame = 0;
    } else {
      this.wingFrame = 1;
    }

    // Apply movement behavior depending on insect type
    switch (this.type) {
      case 'common':
        // Standard horizontal sine-wave float
        this.x += this.vx;
        this.y += Math.sin(this.time) * 0.8;
        break;
        
      case 'gnat':
        // Fast zig-zag movement
        this.x += this.vx;
        // Jagged up/down shifts
        this.y += this.vy + Math.cos(this.time * 2.5) * 2.2;
        break;
        
      case 'firefly':
        // Smooth spirals / circles
        this.x += this.vx;
        this.y += this.vy + Math.sin(this.time) * 1.2;
        break;
        
      case 'wasp':
        // Jerky, territorial hover movements
        this.x += this.vx;
        // Wasp hovers up and down sharply
        this.y += Math.sin(this.time * 1.5) * 1.5;
        
        // Randomly adjust speed to look aggressive
        if (Math.random() < 0.02) {
          this.vx = -(1.5 + Math.random() * 1.5);
        }
        break;
    }

    // Check offscreen boundaries to recycle/respawn
    if (this.x < -15 || this.y > this.canvasHeight + 15 || this.y < -15) {
      this.respawn();
    }
  }

  draw(ctx) {
    if (this.state === 'eaten') return;

    ctx.save();
    
    const scale = 2; // Pixel art multiplier
    
    ctx.translate(Math.round(this.x), Math.round(this.y));
    Bug.drawSprite(ctx, this.type, this.wingFrame, this.glowCycle);

    ctx.restore();
  }
}
