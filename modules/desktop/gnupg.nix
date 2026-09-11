# dot-gitconfig sets commit.gpgSign; without this every commit fails.
{ pkgs, ... }:
{
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
