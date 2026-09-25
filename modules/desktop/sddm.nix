# Stylix has no sddm target, so the greeter is themed by hand.
{
  pkgs,
  palette,
  cursor,
  inputs,
  ...
}:
let
  sddm-hu-tao = pkgs.callPackage ../../pkgs/sddm-hu-tao.nix {
    inherit palette;
    thirdParty = inputs.third-party-assets;
  };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    # Must match the package directory name and its Theme-Id.
    theme = sddm-hu-tao.themeName;

    # Theme.CursorTheme only reaches the Qt greeter. On Wayland weston draws
    # the pointer and reads [shell] cursor-theme, ignoring XCURSOR_THEME — and
    # the generated ini has no [shell] section, so it draws no cursor at all.
    settings.Theme.CursorTheme = cursor.name;

    wayland.compositorCommand =
      let
        westonIni = pkgs.writeText "weston.ini" ''
          [shell]
          cursor-theme=${cursor.name}
          cursor-size=${toString cursor.size}

          [keyboard]
          keymap_layout=us
          keymap_model=pc104
          keymap_options=terminate:ctrl_alt_bksp

          [libinput]
          enable-tap=true
        '';
      in
      "${pkgs.weston}/bin/weston --shell=kiosk -c ${westonIni}";

    # Main.qml's Qt imports; systemPackages does not reach the greeter.
    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qtmultimedia
      qtvirtualkeyboard
    ];
  };

  # The greeter runs as `sddm`, so none of the per-user profile paths are set
  # for it -- the theme and the cursor it names have to be system-wide.
  environment.systemPackages = [
    sddm-hu-tao
    cursor.package
  ];
}
