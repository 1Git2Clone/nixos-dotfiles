{
  services.power-profiles-daemon.enable = true; # powerprofilesctl, power-mode.sh

  # The bar's battery widget enumerates devices over org.freedesktop.UPower,
  # and nothing was serving that name -- power-profiles-daemon owns only
  # org.freedesktop.UPower.PowerProfiles, which is why the power menu could
  # report a profile and "No battery detected" in the same popup. btop reads
  # /sys/class/power_supply directly, so it always showed the charge and hid
  # this.
  services.upower.enable = true;
}
