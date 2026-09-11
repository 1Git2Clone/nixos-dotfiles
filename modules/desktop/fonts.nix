{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    # caelestia's icon names are Material Symbols glyphs.
    material-symbols
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    dejavu_fonts
    liberation_ttf
  ];
}
