/**
 * NEO CHAMELEON - Bug/Insect Classes & AI Movement Patterns
 */

class Bug {
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
    switch (this.type) {
      case 'gnat':
        this.scoreValue = 300;
        this.energyValue = 25; // Good energy boost
        this.color = '#ffea00'; // Gold
        this.size = 3; // Tiny and fast
        break;
      case 'firefly':
        this.scoreValue = 200;
        this.energyValue = 15;
        this.color = '#00f0ff'; // Glowing cyan
        this.size = 4;
        break;
      case 'wasp':
        this.scoreValue = -200;
        this.energyValue = -25; // Poisonous, drops energy
        this.color = '#ff3b30'; // Red wasp
        this.size = 5;
        break;
      case 'common':
      default:
        this.type = 'common';
        this.scoreValue = 100;
        this.energyValue = 15;
        this.color = '#a0a0a0'; // Grey/white wings, dark body
        this.size = 4;
        break;
    }
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
    
    // Translate to center of bug
    ctx.translate(Math.round(this.x), Math.round(this.y));

    // Choose drawing style based on bug type
    if (this.type === 'common') {
      // 8-bit Common Fly
      // Body (black grid)
      ctx.fillStyle = '#1c1c1c';
      ctx.fillRect(-2, -2, 4, 4);
      // Head
      ctx.fillStyle = '#ff3b30'; // Little red fly eyes
      ctx.fillRect(2, -2, 2, 2);
      
      // Flapping Wings (grey pixel bars)
      ctx.fillStyle = '#dcdcdc';
      if (this.wingFrame === 0) {
        ctx.fillRect(-4, -6, 2, 4); // wing up-left
        ctx.fillRect(-2, -6, 2, 4); // wing up-right
      } else {
        ctx.fillRect(-6, -4, 4, 2); // wing down-left
        ctx.fillRect(-4, -4, 4, 2); // wing down-right
      }
    } 
    else if (this.type === 'gnat') {
      // Golden Speedy Gnat
      // Glow shadow
      ctx.shadowColor = '#ffea00';
      ctx.shadowBlur = 8;
      
      ctx.fillStyle = '#b38600'; // body
      ctx.fillRect(-2, -2, 4, 2);
      
      ctx.fillStyle = '#ffea00'; // wings/eyes
      if (this.wingFrame === 0) {
        ctx.fillRect(-4, -4, 2, 2);
        ctx.fillRect(0, -4, 2, 2);
      } else {
        ctx.fillRect(-6, -2, 2, 2);
        ctx.fillRect(2, -2, 2, 2);
      }
    } 
    else if (this.type === 'firefly') {
      // Glowing neon Firefly
      // Dynamic glowing aura
      const glowAmt = Math.sin(this.glowCycle) * 6 + 10;
      ctx.shadowColor = '#00f0ff';
      ctx.shadowBlur = glowAmt;
      
      // Body (electric cyan)
      ctx.fillStyle = '#00c8ff';
      ctx.fillRect(-2, -2, 4, 4);
      
      // Wing flicker
      ctx.fillStyle = '#ffffff';
      if (this.wingFrame === 0) {
        ctx.fillRect(-4, -4, 2, 2);
        ctx.fillRect(2, -4, 2, 2);
      } else {
        ctx.fillRect(-5, -2, 2, 2);
        ctx.fillRect(3, -2, 2, 2);
      }
      
      // Tail glow indicator
      ctx.fillStyle = '#39ff14'; // Green butt glow
      ctx.fillRect(-4, 0, 2, 2);
    } 
    else if (this.type === 'wasp') {
      // Red striped toxic wasp
      ctx.shadowColor = '#ff3b30';
      ctx.shadowBlur = 6;

      // Striped body: yellow/red
      ctx.fillStyle = '#ff3b30'; // Red wasp body
      ctx.fillRect(-4, -2, 8, 4);
      ctx.fillStyle = '#0a0a14'; // Dark stripes
      ctx.fillRect(-2, -2, 2, 4);
      ctx.fillRect(2, -2, 2, 4);
      
      // Danger stinger
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(-6, 0, 2, 1);
      
      // Wing flaps
      ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
      if (this.wingFrame === 0) {
        ctx.fillRect(-2, -6, 2, 4);
        ctx.fillRect(0, -6, 2, 4);
      } else {
        ctx.fillRect(-4, -4, 2, 2);
        ctx.fillRect(2, -4, 2, 2);
      }
    }

    ctx.restore();
  }
}
