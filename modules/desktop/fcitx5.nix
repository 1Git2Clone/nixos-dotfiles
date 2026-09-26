# Japanese input — from fcitx5-mozc in the Arch package list.
{ lib, pkgs, ... }:
{
  # fcitx5-with-addons bundles the Qt 5 frontend unconditionally, and it is
  # the one thing on the system that pulls in Qt 5; the Qt 6 and GTK frontends
  # stay. An overlay rather than i18n.inputMethod.package: the module also
  # puts its own copy of the package on QT_PLUGIN_PATH, which no option
  # reaches.
  nixpkgs.overlays = [
    (_: prev: {
      qt6Packages = prev.qt6Packages.overrideScope (
        _: qprev: {
          fcitx5-with-addons = qprev.fcitx5-with-addons.overrideAttrs (old: {
            # Store-path strings by now, so matched by name, not by package.
            paths = lib.filter (p: builtins.match ".*-fcitx5-qt5-.*" (toString p) == null) old.paths;
          });
        }
      );
    })
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    # Otherwise the module exports GTK_IM_MODULE/QT_IM_MODULE and fcitx5
    # warns; the text-input protocol Hyprland speaks is enough.
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };
}
