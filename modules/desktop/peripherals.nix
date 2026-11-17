# The Logitech mouse and the fifine mic. The option, not the package: Solaar
# needs its udev rules for non-root access.
#
# No OpenRGB: with its root server running from boot, the G502's LEDs stayed
# dark under Solaar; stopping it was part of what brought them back.
{ pkgs, ... }:
{
  # Solaar, for the G502 X Plus's DPI, buttons, lighting and Lightspeed receiver.
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

  # The fifine mic's firmware turns its hardware monitor back on at every
  # replug, feeding the mic into the headphones plugged into it.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="sound", KERNEL=="controlC*", ATTRS{idVendor}=="3142", ATTRS{idProduct}=="a010", RUN+="${pkgs.alsa-utils}/bin/amixer -c %n -q cset name='Mic Playback Switch' off"
  '';
}
