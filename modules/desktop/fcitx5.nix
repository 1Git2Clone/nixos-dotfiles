# Japanese input — from fcitx5-mozc in the Arch package list.
{ pkgs, ... }:
{
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
