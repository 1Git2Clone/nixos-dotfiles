// The few Spotify settings Nix owns. This one lives in Spotify's own local
// storage rather than a prefs file, so it is re-set on every launch; the rest
// of Settings stays the GUI's.
(async function hutaoSettings() {
  while (!Spicetify?.Platform?.LocalStorageAPI) await new Promise((r) => setTimeout(r, 100));
  // "Show the now-playing panel on click of play"
  Spicetify.Platform.LocalStorageAPI.setItem("toggleNowPlayingView", false);
})();
