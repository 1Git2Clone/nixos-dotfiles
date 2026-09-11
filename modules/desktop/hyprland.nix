{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  # No hypridle: caelestia's general.idle.timeouts owns this, and running both
  # locks the session twice.
}
