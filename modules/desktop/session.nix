# The session-scoped daemons autostart.lua execs by Arch path. Declared as
# services so those lines fail harmlessly.
#
# polkit's authority and the keyring's PAM hook are root's; the agent that
# talks to them is the user's, and lives in home/apps/polkit-gnome.nix.
{
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.geoclue2.enable = true;
}
