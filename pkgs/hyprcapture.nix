{ inputs, pkgs }:
inputs.hyprcapture.packages.${pkgs.stdenv.hostPlatform.system}.hyprcapture.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./hyprcapture-focused-window.patch ];
})
