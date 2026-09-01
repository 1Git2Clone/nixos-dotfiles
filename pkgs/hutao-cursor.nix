# Hutao-Cursor, packaged.
#
# The theme is a hand-made set of X11 cursors that is not in nixpkgs, so on
# Arch it was simply a directory in ~/.local/share/icons placed there by stow.
# That works, but it makes the cursor a *user* artifact: SDDM, the greeter and
# anything running before the home directory is stowed cannot see it, and
# Stylix has nothing to point at.
#
# Wrapping it in a derivation puts it in /run/current-system/sw/share/icons,
# where XCURSOR_PATH already looks, so it is available to the display manager
# and to every user from first boot — before ~/dotfiles has even been cloned.
#
# The 77 hex-named entries in cursors/ are symlinks to the 17 real files: X11
# addresses cursors by an MD5-ish name hash rather than a human one, and
# dropping them breaks the pointer in GTK apps specifically. `cp -r` below
# preserves them; do not "tidy" it into an install of *.png.
{
  lib,
  runCommandLocal,
}:
runCommandLocal "hutao-cursor"
  {
    meta = {
      description = "Genshin Impact Hu Tao X11 cursor theme";
      # No `license` on purpose. This is fan art vendored out of the dotfiles
      # repo with no stated terms, and nixpkgs treats an absent license as
      # unrestricted rather than blocked. Marking it `unfree` instead would be
      # no more accurate and would make `nix build .#hutao-cursor` fail outside
      # a config that sets allowUnfree — which is friction for no gain, since
      # nothing here is redistributed.
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p "$out/share/icons"
    cp -r ${../assets/Hutao-Cursor} "$out/share/icons/Hutao-Cursor"
    chmod -R u+w "$out/share/icons/Hutao-Cursor"

    # A theme with no index.theme is silently ignored by every cursor loader,
    # so fail loudly here rather than shipping an invisible package.
    test -f "$out/share/icons/Hutao-Cursor/index.theme"
  ''
