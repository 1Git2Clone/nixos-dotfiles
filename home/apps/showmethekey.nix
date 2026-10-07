# The package is system-wide (modules/desktop/packages.nix) for its polkit
# action; only its settings are the user's. What differs from the schema's
# defaults: the on/clickable/paused switches are runtime state, left out.
{
  dconf.settings."one/alynx/showmethekey" = {
    show-shift = false;
    mode = "compact";
    # Doubles in the schema: an int literal is written as one and ignored.
    width = 400.0;
    height = 100.0;
    margin-ratio = 0.32;
  };
}
