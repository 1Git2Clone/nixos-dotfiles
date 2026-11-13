# RGB and the Logitech mouse. The options, not the packages: both need udev
# rules for non-root access, and OpenRGB its i2c modules and server.
{
  services.hardware.openrgb.enable = true;

  # Solaar, for the G502 X Plus's DPI, buttons and Lightspeed receiver.
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };
}
