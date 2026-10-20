/* Compass Club shared motion: drifting background particles and the
   compass "iris" transition between pages. Respects reduced motion. */
(function () {
  "use strict";
  var RM = false;
  try { RM = matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) {}

  var style = document.createElement("style");
  style.textContent =
    ".cc-wipe{position:fixed;inset:0;z-index:9999;pointer-events:none;display:flex;align-items:center;justify-content:center;" +
    "background:radial-gradient(circle at var(--x) var(--y),#16514C,#0A2B29 72%);" +
    "clip-path:circle(0px at var(--x) var(--y));transition:clip-path .78s cubic-bezier(.7,0,.2,1)}" +
    ".cc-wipe.full{clip-path:circle(150vmax at var(--x) var(--y))}" +
    ".cc-wipe svg{width:min(30vw,150px);height:auto;opacity:0;transform:scale(.55) rotate(-140deg);" +
    "transition:opacity .4s ease .12s,transform .85s cubic-bezier(.2,.8,.2,1)}" +
    ".cc-wipe.full svg{opacity:1;transform:none}" +
    ".cc-wipe .ndl{transform-origin:50px 50px;animation:ccNdl 1.6s cubic-bezier(.45,0,.2,1) infinite}" +
    "@keyframes ccNdl{0%{transform:rotate(-60deg)}55%{transform:rotate(380deg)}100%{transform:rotate(360deg)}}";
  document.head.appendChild(style);

  var ICON =
    '<svg viewBox="0 0 100 100" aria-hidden="true">' +
    '<circle cx="50" cy="50" r="44" fill="#F6F2E9" stroke="#D9A441" stroke-width="5"/>' +
    '<circle cx="50" cy="50" r="35" fill="none" stroke="#B9DCD0" stroke-width="1.5"/>' +
    '<g class="ndl"><path d="M50 16 57 50 43 50Z" fill="#D9A441"/><path d="M50 84 57 50 43 50Z" fill="#103E3B"/></g>' +
    '<circle cx="50" cy="50" r="4.5" fill="#0A2B29"/></svg>';

  function makeWipe(x, y) {
    var w = document.createElement("div");
    w.className = "cc-wipe";
    w.setAttribute("aria-hidden", "true");
    w.style.setProperty("--x", x);
    w.style.setProperty("--y", y);
    w.innerHTML = ICON;
    document.body.appendChild(w);
    return w;
  }

  // Leave this page: the compass expands from the click point, then we navigate.
  function leave(url, x, y) {
    if (RM) { location.href = url; return; }
    try { sessionStorage.setItem("cc-arrive", "1"); } catch (e) {}
    var w = makeWipe(x + "px", y + "px");
    void w.offsetWidth;
    w.classList.add("full");
    setTimeout(function () { location.href = url; }, 820);
  }

  // Arrive on a page: the cover (set before first paint) irises open from the centre.
  function arrive() {
    var root = document.documentElement;
    if (!root.classList.contains("cc-arriving")) return;
    try { sessionStorage.removeItem("cc-arrive"); } catch (e) {}
    if (RM) { root.classList.remove("cc-arriving"); return; }
    var w = makeWipe("50%", "50%");
    w.style.transition = "none";
    w.classList.add("full");
    void w.offsetWidth;
    root.classList.remove("cc-arriving");
    w.style.transition = "";
    requestAnimationFrame(function () { requestAnimationFrame(function () { w.classList.remove("full"); }); });
    setTimeout(function () { w.remove(); }, 1100);
  }

  // Coming back via the browser's back button restores the old page from cache, wipe and all.
  window.addEventListener("pageshow", function (e) {
    if (!e.persisted) return;
    document.documentElement.classList.remove("cc-arriving");
    Array.prototype.forEach.call(document.querySelectorAll(".cc-wipe"), function (w) { w.remove(); });
  });

  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a[data-transition]");
    if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    e.preventDefault();
    var x = e.clientX, y = e.clientY;
    if (!x && !y) { var r = a.getBoundingClientRect(); x = r.left + r.width / 2; y = r.top + r.height / 2; }
    leave(a.href, x, y);
  });

  // Slow drifting particles on a fixed canvas. isDark(x, y) lets the page tint
  // each particle for the section beneath it.
  function ambient(canvas, opts) {
    opts = opts || {};
    if (RM || !canvas || !canvas.getContext) return;
    var ctx = canvas.getContext("2d");
    if (!ctx) return;
    var dpr = Math.min(2, window.devicePixelRatio || 1), W = 0, H = 0, parts = [], lastY = window.scrollY, raf = 0;
    var isDark = opts.isDark || function () { return !!opts.dark; };
    function rnd(a, b) { return a + Math.random() * (b - a); }
    function make() {
      var spark = Math.random() < (opts.sparkRatio || 0.3);
      return {
        x: rnd(0, W), y: rnd(0, H), z: rnd(0.35, 1), spark: spark,
        s: spark ? rnd(2.4, 4.6) : rnd(0.8, 2.1),
        vy: -rnd(0.05, 0.22), vx: rnd(-0.06, 0.06), ph: rnd(0, 6.283),
        rot: rnd(0, 6.283), vr: rnd(-0.006, 0.006), a: rnd(0.28, 0.72)
      };
    }
    function resize() {
      W = window.innerWidth; H = window.innerHeight;
      canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
      canvas.style.width = W + "px"; canvas.style.height = H + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var n = Math.min(opts.max || 60, Math.round(W * H / (opts.density || 22000)));
      while (parts.length < n) parts.push(make());
      parts.length = n;
    }
    function spark(x, y, s, rot) {
      ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.beginPath();
      ctx.moveTo(0, -s); ctx.quadraticCurveTo(0, 0, s, 0); ctx.quadraticCurveTo(0, 0, 0, s);
      ctx.quadraticCurveTo(0, 0, -s, 0); ctx.quadraticCurveTo(0, 0, 0, -s);
      ctx.fill(); ctx.restore();
    }
    function frame(t) {
      raf = requestAnimationFrame(frame);
      ctx.clearRect(0, 0, W, H);
      var sy = window.scrollY, dy = sy - lastY;
      lastY = sy;
      if (Math.abs(dy) > 400) dy = 0;
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        p.y += p.vy * p.z - dy * p.z * 0.3;
        p.x += p.vx + Math.sin(t / 2600 + p.ph) * 0.15 * p.z;
        p.rot += p.vr;
        if (p.y < -14) { p.y = H + 14; p.x = rnd(0, W); } else if (p.y > H + 14) { p.y = -14; p.x = rnd(0, W); }
        if (p.x < -14) p.x = W + 14; else if (p.x > W + 14) p.x = -14;
        var dark = isDark(p.x, p.y);
        var al = p.a * (0.72 + 0.28 * Math.sin(t / 900 + p.ph * 3));
        if (p.spark) {
          ctx.fillStyle = "rgba(217,164,65," + (al * (dark ? 1 : 0.8)).toFixed(3) + ")";
          spark(p.x, p.y, p.s * (0.75 + p.z * 0.45), p.rot);
        } else {
          ctx.fillStyle = dark ? "rgba(185,220,208," + al.toFixed(3) + ")" : "rgba(16,62,59," + (al * 0.55).toFixed(3) + ")";
          ctx.beginPath(); ctx.arc(p.x, p.y, p.s * p.z, 0, 6.283); ctx.fill();
        }
      }
    }
    resize();
    window.addEventListener("resize", resize, { passive: true });
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) { cancelAnimationFrame(raf); raf = 0; }
      else if (!raf) { lastY = window.scrollY; raf = requestAnimationFrame(frame); }
    });
    raf = requestAnimationFrame(frame);
  }

  window.CCMotion = { ambient: ambient, leave: leave, reducedMotion: RM };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", arrive);
  else arrive();
})();
