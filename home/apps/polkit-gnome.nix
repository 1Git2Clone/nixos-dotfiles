# autostart.lua execs the agent by its Arch path; declared here so that line
# fails harmlessly. home-manager's module writes the same unit the hand-rolled
# one did -- the agent authenticates as the user and wants no root itself.
{
  services.polkit-gnome.enable = true;
}
