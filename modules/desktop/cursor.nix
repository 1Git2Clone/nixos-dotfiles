# Named once; stylix, the greeter and weston each read it back.
#
# Switching pointers is the one line below. A theme is any directory in the
# third-party-assets input -- or under assets/, for one that is ours -- with a
# cursors/ in it: Windows pack or XCursor, pkgs/cursors.nix finds it and names
# it after its own folder, so adding one is dropping a folder in and changing
# this string.
{ pkgs, inputs, ... }:
let
  name = "Hutao-Cursor";

  package =
    (pkgs.callPackage ../../pkgs/cursors.nix {
      thirdParty = inputs.third-party-assets;
    }).${name};
in
{
  _module.args.cursor = {
    inherit package name;
    size = 24;
  };
}
