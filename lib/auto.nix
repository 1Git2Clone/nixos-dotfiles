# Every module in a directory, as an imports list: each `.nix` file beside a
# default.nix, and each subdirectory that has one of its own.
#
# The point is that adding a service is adding a file. Nothing names the file
# a second time, so nothing can be written and then silently not imported.
{ lib }:
dir:
let
  keep =
    name: type:
    if type == "directory" then
      builtins.pathExists (dir + "/${name}/default.nix")
    else
      name != "default.nix" && lib.hasSuffix ".nix" name;
in
lib.mapAttrsToList (name: _: dir + "/${name}") (lib.filterAttrs keep (builtins.readDir dir))
