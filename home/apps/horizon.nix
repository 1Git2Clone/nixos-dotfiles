# Separate launcher/game state; Prism instances remain Prism's.
{ pkgs, ... }:
{
  home.packages = [ (pkgs.callPackage ../../pkgs/horizon { }) ];
}
