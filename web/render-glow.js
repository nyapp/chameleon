/**
 * NEO CHAMELEON - Lightweight neon draw helpers (no shadowBlur)
 */
const RenderGlow = {
  strokeNeonPath(ctx, opts = {}) {
    const {
      color,
      width = 1,
      glowWidth = 2,
      glowAlpha = 0.35,
      lineCap
    } = opts;

    ctx.save();
    if (lineCap) ctx.lineCap = lineCap;
    ctx.strokeStyle = color;
    ctx.globalAlpha = glowAlpha;
    ctx.lineWidth = width + glowWidth * 2;
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.lineWidth = width;
    ctx.stroke();
    ctx.restore();
  },

  strokeNeonArc(ctx, x, y, radius, opts = {}) {
    const {
      color,
      width = 1,
      glowWidth = 2,
      glowAlpha = 0.35
    } = opts;

    ctx.save();
    ctx.strokeStyle = color;
    ctx.globalAlpha = glowAlpha;
    ctx.lineWidth = width + glowWidth * 2;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.lineWidth = width;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  },

  fillNeonHalo(ctx, x, y, w, h, color, alpha = 0.35, pad = 2) {
    ctx.save();
    ctx.fillStyle = color;
    ctx.globalAlpha = alpha;
    ctx.fillRect(x - pad, y - pad, w + pad * 2, h + pad * 2);
    ctx.restore();
  }
};
