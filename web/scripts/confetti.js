// High-performance Confetti Celebration Utility for QuizPro
// Uses canvas-confetti library with standalone canvas particle fallback

export class ConfettiCelebration {
  static firePassingCelebration() {
    if (typeof window.confetti === 'function') {
      // 3-wave multi-burst celebration
      const count = 200;
      const defaults = {
        origin: { y: 0.7 }
      };

      function fire(particleRatio, opts) {
        window.confetti({
          ...defaults,
          ...opts,
          particleCount: Math.floor(count * particleRatio)
        });
      }

      fire(0.25, {
        spread: 26,
        startVelocity: 55,
        colors: ['#4F46E5', '#10B981', '#F59E0B', '#3B82F6']
      });

      fire(0.2, {
        spread: 60,
        colors: ['#10B981', '#FBBF24', '#6366F1']
      });

      fire(0.35, {
        spread: 100,
        decay: 0.91,
        scalar: 0.8
      });

      fire(0.1, {
        spread: 120,
        startVelocity: 25,
        decay: 0.92,
        colors: ['#EC4899', '#8B5CF6', '#10B981']
      });

      fire(0.1, {
        spread: 120,
        startVelocity: 45
      });

      // Side cannons burst
      setTimeout(() => {
        window.confetti({
          particleCount: 50,
          angle: 60,
          spread: 55,
          origin: { x: 0 }
        });
        window.confetti({
          particleCount: 50,
          angle: 120,
          spread: 55,
          origin: { x: 1 }
        });
      }, 400);

    } else {
      // Fallback particle burst using vanilla DOM elements
      this.domFallbackConfetti();
    }
  }

  static fireStreakCelebration() {
    if (typeof window.confetti === 'function') {
      window.confetti({
        particleCount: 80,
        spread: 70,
        origin: { y: 0.6 },
        colors: ['#F59E0B', '#EF4444', '#F97316']
      });
    } else {
      this.domFallbackConfetti(['🔥', '⭐', '✨']);
    }
  }

  static domFallbackConfetti(emojis = ['🎉', '✨', '🏆', '⭐', '🎊']) {
    const container = document.createElement('div');
    container.style.cssText = `
      position: fixed;
      inset: 0;
      pointer-events: none;
      z-index: 9999;
      overflow: hidden;
    `;
    document.body.appendChild(container);

    for (let i = 0; i < 40; i++) {
      const el = document.createElement('div');
      const emoji = emojis[Math.floor(Math.random() * emojis.length)];
      el.textContent = emoji;
      el.style.cssText = `
        position: absolute;
        top: -10%;
        left: ${Math.random() * 100}%;
        font-size: ${Math.random() * 20 + 20}px;
        transform: rotate(${Math.random() * 360}deg);
        transition: transform ${Math.random() * 1.5 + 1.5}s ease-in, top ${Math.random() * 1.5 + 1.5}s ease-in, opacity 2s ease-out;
        opacity: 1;
      `;
      container.appendChild(el);

      requestAnimationFrame(() => {
        el.style.top = '110%';
        el.style.opacity = '0';
        el.style.transform = `rotate(${Math.random() * 720}deg) scale(0.5)`;
      });
    }

    setTimeout(() => {
      container.remove();
    }, 3000);
  }
}
