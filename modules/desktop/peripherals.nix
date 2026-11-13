# RGB and the Logitech mouse. The options, not the packages: both need udev
# rules for non-root access, and OpenRGB its i2c modules and server.
{
  services.hardware.openrgb.enable = true;

  # Solaar, for the G502 X Plus's DPI, buttons and Lightspeed receiver.
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };

  # libinput's debouncing read slide clicks as switch bounce and dropped or
  # merged them; the mouse's firmware already debounces. Matched by name, as
  # the product ID differs between the receiver (4099) and the cable (c095).
  environment.etc."libinput/local-overrides.quirks".text = ''
    [Logitech G502 X Plus]
    MatchName=Logitech G502 X PLUS
    ModelBouncingKeys=1
  '';
}
