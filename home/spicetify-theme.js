// Spotify reads colors.css once, on load. caelestia-theme-hook rewrites it
// through `spicetify refresh` on every scheme switch, so re-link it when it
// changes rather than wait for a restart.
(() => {
  const link = document.querySelector("link.userCSS[href^='colors.css']");
  if (!link) return;
  let last;
  setInterval(async () => {
    const css = await fetch("colors.css", { cache: "no-store" }).then((r) => r.text());
    if (last !== undefined && css !== last) link.href = `colors.css?${Date.now()}`;
    last = css;
  }, 2000);
})();
