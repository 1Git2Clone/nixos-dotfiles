{ pkgs, ... }:
{
  # The option, not the package: steam needs the FHS wrapper and udev rules.
  programs.steam.enable = true;

  # Shows up in the compatibility dropdown as dwproton-11.0-12. Via this
  # option and not systemPackages, which is what the package's own meta says
  # and what puts it on STEAM_EXTRA_COMPAT_TOOLS_PATHS -- so it lives in the
  # store rather than being downloaded into a library.
  programs.steam.extraCompatPackages = [ pkgs.dwproton-bin ];

  programs.gamemode.enable = true;
}
