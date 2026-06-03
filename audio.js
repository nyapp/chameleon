/**
 * NEO CHAMELEON - 8-Bit Web Audio Synthesizer
 * Generates custom retro square, triangle, and noise sound effects dynamically.
 */

class RetroAudio {
  constructor() {
    this.ctx = null;
    this.bgmInterval = null;
    this.bgmNode = null;
    this.masterBgmGain = null;
    this.masterSfxGain = null;
    this.isBgmPlaying = false;
    this.tempo = 120; // BPM
    
    // Track indicators
    this.musicEnabled = true;
    this.sfxEnabled = true;
  }

  init() {
    if (this.ctx) return;
    
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AudioContextClass();
    
    // Master gains
    this.masterBgmGain = this.ctx.createGain();
    this.masterSfxGain = this.ctx.createGain();
    
    this.masterBgmGain.connect(this.ctx.destination);
    this.masterSfxGain.connect(this.ctx.destination);
    
    this.masterBgmGain.gain.value = 0.15; // lower BGM volume
    this.masterSfxGain.gain.value = 0.3; // higher SFX volume
    
    // Start BGM loop if allowed
    if (this.musicEnabled) {
      this.startBGM();
    }
  }

  resume() {
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  setMusicEnabled(enabled) {
    this.musicEnabled = enabled;
    if (enabled) {
      this.init();
      this.resume();
      this.startBGM();
    } else {
      this.stopBGM();
    }
  }

  setSfxEnabled(enabled) {
    this.sfxEnabled = enabled;
    if (enabled) {
      this.init();
      this.resume();
    }
  }

  // --- Sound Effects Generators ---

  // Tongue Shoot sound: rapid pitch slide upwards
  playShoot() {
    if (!this.sfxEnabled) return;
    this.init();
    this.resume();
    
    const now = this.ctx.currentTime;
    
    const osc = this.ctx.createOscillator();
    const gainNode = this.ctx.createGain();
    
    osc.connect(gainNode);
    gainNode.connect(this.masterSfxGain);
    
    osc.type = 'triangle'; // triangle wave gives a nice retro springy feel
    osc.frequency.setValueAtTime(220, now);
    osc.frequency.exponentialRampToValueAtTime(1200, now + 0.12);
    
    gainNode.gain.setValueAtTime(1.0, now);
    gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.12);
    
    osc.start(now);
    osc.stop(now + 0.13);
  }

  // Eat Bug sound: a retro 8-bit crunch (square wave + quick noise burst)
  playEat() {
    if (!this.sfxEnabled) return;
    this.init();
    this.resume();

    const now = this.ctx.currentTime;
    
    // Part 1: Square wave drop
    const osc = this.ctx.createOscillator();
    const gainNode = this.ctx.createGain();
    osc.connect(gainNode);
    gainNode.connect(this.masterSfxGain);
    
    osc.type = 'square';
    osc.frequency.setValueAtTime(600, now);
    osc.frequency.setValueAtTime(300, now + 0.04);
    osc.frequency.setValueAtTime(150, now + 0.08);
    
    gainNode.gain.setValueAtTime(0.8, now);
    gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.12);
    
    osc.start(now);
    osc.stop(now + 0.13);
    
    // Part 2: Noise crunch simulation
    this.playNoise(0.08, 0.5, 0.4, 'lowpass');
  }

  // Hurt / Hit wasp: Descending slide with harsh noise
  playHurt() {
    if (!this.sfxEnabled) return;
    this.init();
    this.resume();

    const now = this.ctx.currentTime;
    
    const osc = this.ctx.createOscillator();
    const gainNode = this.ctx.createGain();
    osc.connect(gainNode);
    gainNode.connect(this.masterSfxGain);
    
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(400, now);
    osc.frequency.linearRampToValueAtTime(80, now + 0.35);
    
    gainNode.gain.setValueAtTime(1.0, now);
    gainNode.gain.linearRampToValueAtTime(0.01, now + 0.35);
    
    osc.start(now);
    osc.stop(now + 0.36);

    // Noise rumble
    this.playNoise(0.3, 0.8, 0.2, 'bandpass');
  }

  // Power Up sound: Fast major arpeggio upward
  playPowerup() {
    if (!this.sfxEnabled) return;
    this.init();
    this.resume();

    const now = this.ctx.currentTime;
    const notes = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50]; // C major notes
    
    notes.forEach((freq, index) => {
      const noteTime = now + (index * 0.05);
      const osc = this.ctx.createOscillator();
      const gainNode = this.ctx.createGain();
      osc.connect(gainNode);
      gainNode.connect(this.masterSfxGain);
      
      osc.type = 'square';
      osc.frequency.setValueAtTime(freq, noteTime);
      
      gainNode.gain.setValueAtTime(0.7, noteTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, noteTime + 0.12);
      
      osc.start(noteTime);
      osc.stop(noteTime + 0.13);
    });
  }

  // Game over theme: Sad descending arpeggio
  playGameOver() {
    if (!this.sfxEnabled) return;
    this.init();
    this.resume();

    const now = this.ctx.currentTime;
    const notes = [392.00, 370.00, 349.23, 293.66, 220.00, 146.83]; // Sad progression
    
    notes.forEach((freq, index) => {
      const noteTime = now + (index * 0.15);
      const osc = this.ctx.createOscillator();
      const gainNode = this.ctx.createGain();
      osc.connect(gainNode);
      gainNode.connect(this.masterSfxGain);
      
      osc.type = 'square';
      osc.frequency.setValueAtTime(freq, noteTime);
      
      gainNode.gain.setValueAtTime(0.8, noteTime);
      gainNode.gain.linearRampToValueAtTime(0.01, noteTime + 0.25);
      
      osc.start(noteTime);
      osc.stop(noteTime + 0.28);
    });
  }

  // Noise generator helper (NES sound chips had a dedicated noise channel)
  playNoise(duration, volume, decay, filterType = 'lowpass') {
    const bufferSize = this.ctx.sampleRate * duration;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    
    const noiseNode = this.ctx.createBufferSource();
    noiseNode.buffer = buffer;
    
    const filter = this.ctx.createBiquadFilter();
    filter.type = filterType;
    filter.frequency.value = 1000;
    
    const gainNode = this.ctx.createGain();
    gainNode.gain.setValueAtTime(volume, this.ctx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, this.ctx.currentTime + decay);
    
    noiseNode.connect(filter);
    filter.connect(gainNode);
    gainNode.connect(this.masterSfxGain);
    
    noiseNode.start();
    noiseNode.stop(this.ctx.currentTime + duration);
  }

  // --- Background Music Synth ---

  startBGM() {
    if (this.isBgmPlaying || !this.musicEnabled) return;
    this.isBgmPlaying = true;
    
    // Notes mappings for simple synth BGM
    // Synthwave bassline notes in a cool retro minor key (A minor / Pentatonic)
    const bassline = [
      55, 55, 55, 55, 65.41, 65.41, 65.41, 65.41, // A1 -> C2
      73.42, 73.42, 73.42, 73.42, 58.27, 58.27, 58.27, 58.27 // D2 -> A#1
    ];
    
    const leadMelody = [
      440, 0, 493.88, 523.25, 587.33, 0, 523.25, 493.88,
      349.23, 0, 392.00, 440, 523.25, 0, 493.88, 440,
      392.00, 0, 440, 493.88, 587.33, 0, 523.25, 493.88,
      440, 0, 523.25, 587.33, 659.25, 698.46, 587.33, 440
    ];

    let step = 0;
    const stepTime = 60 / this.tempo / 2; // Eighth notes
    
    const playStep = () => {
      if (!this.isBgmPlaying || !this.ctx) return;
      const now = this.ctx.currentTime;
      
      // Play bass note every beat (index step % 16 / 2)
      if (step % 2 === 0) {
        const bassFreq = bassline[(step / 2) % bassline.length];
        this.playOsc(bassFreq, 'sawtooth', 0.15, 0.08, now, this.masterBgmGain);
      }
      
      // Play lead note (on/off based on melody)
      const leadFreq = leadMelody[step % leadMelody.length];
      if (leadFreq > 0) {
        // High square lead for classic NES chiptune feel
        this.playOsc(leadFreq, 'square', 0.18, 0.05, now, this.masterBgmGain);
      }
      
      // Retro synth hi-hat/snare noise channel beat simulation
      if (step % 4 === 2) {
        // Play simple retro snare noise
        this.playNoiseAt(0.05, 0.08, now, this.masterBgmGain);
      } else if (step % 2 === 0) {
        // Play subtle retro tick (closed hat)
        this.playNoiseAt(0.01, 0.03, now, this.masterBgmGain);
      }

      step++;
      
      // Schedule next step precisely
      const timeToNext = (now + stepTime) - this.ctx.currentTime;
      this.bgmInterval = setTimeout(playStep, Math.max(timeToNext * 1000, 10));
    };

    playStep();
  }

  stopBGM() {
    this.isBgmPlaying = false;
    if (this.bgmInterval) {
      clearTimeout(this.bgmInterval);
      this.bgmInterval = null;
    }
  }

  // BGM oscillator helper (triggered at precise BGM context timestamps)
  playOsc(frequency, type, duration, volume, time, outputGain) {
    const osc = this.ctx.createOscillator();
    const gainNode = this.ctx.createGain();
    
    osc.connect(gainNode);
    gainNode.connect(outputGain);
    
    osc.type = type;
    osc.frequency.setValueAtTime(frequency, time);
    
    gainNode.gain.setValueAtTime(volume, time);
    gainNode.gain.exponentialRampToValueAtTime(0.001, time + duration);
    
    osc.start(time);
    osc.stop(time + duration + 0.02);
  }

  playNoiseAt(duration, volume, time, outputGain) {
    const bufferSize = this.ctx.sampleRate * duration;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    
    const noiseNode = this.ctx.createBufferSource();
    noiseNode.buffer = buffer;
    
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'highpass';
    filter.frequency.value = 4000;
    
    const gainNode = this.ctx.createGain();
    gainNode.gain.setValueAtTime(volume, time);
    gainNode.gain.exponentialRampToValueAtTime(0.001, time + duration);
    
    noiseNode.connect(filter);
    filter.connect(gainNode);
    gainNode.connect(outputGain);
    
    noiseNode.start(time);
    noiseNode.stop(time + duration);
  }
}

// Global RetroAudio instance to be accessed by game.js
const audio = new RetroAudio();
