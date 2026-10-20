/* Compass Club language switch. Pages carry both languages inline
   (data-l="en" / data-l="ar"); CSS shows one, this script picks which.
   The <head> of each page sets lang/dir before first paint. */
(function () {
  "use strict";
  var KEY = "cc-lang", root = document.documentElement;
  var RM = false;
  try { RM = matchMedia("(prefers-reduced-motion: reduce)").matches; } catch (e) {}

  function current() { return root.getAttribute("lang") === "ar" ? "ar" : "en"; }

  function apply(l) {
    root.setAttribute("lang", l);
    root.setAttribute("dir", l === "ar" ? "rtl" : "ltr");
    Array.prototype.forEach.call(document.querySelectorAll("[data-aria-" + l + "]"), function (el) {
      el.setAttribute("aria-label", el.getAttribute("data-aria-" + l));
    });
    if (window.CC_TITLES && window.CC_TITLES[l]) document.title = window.CC_TITLES[l];
    document.dispatchEvent(new CustomEvent("cc-lang", { detail: l }));
  }

  function set(l) {
    try { localStorage.setItem(KEY, l); } catch (e) {}
    apply(l);
  }

  var gate = document.getElementById("langGate");
  function closeGate() {
    if (!root.classList.contains("need-lang") || !gate) return;
    gate.classList.add("leaving");
    setTimeout(function () {
      root.classList.remove("need-lang");
      gate.classList.remove("leaving");
      document.dispatchEvent(new CustomEvent("cc-lang-chosen"));
    }, RM ? 0 : 620);
  }

  document.addEventListener("click", function (e) {
    if (!e.target.closest) return;
    var pickBtn = e.target.closest("[data-set-lang]");
    if (pickBtn) { set(pickBtn.getAttribute("data-set-lang")); closeGate(); return; }
    if (e.target.closest("[data-toggle-lang]")) set(current() === "ar" ? "en" : "ar");
  });

  apply(current());
  if (root.classList.contains("need-lang") && gate) {
    var first = gate.querySelector("button");
    if (first) first.focus({ preventScroll: true });
  }

  window.CCLang = { current: current, set: set };
})();
