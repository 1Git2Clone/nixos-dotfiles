# In hosts/common, not the desktop layer: hutao-vm has no sops to decrypt
# authKeyFile with.
{ config, ... }:
{
  services.tailscale = {
    enable = true;

    # Reusable and pre-authorized, not ephemeral: the node survives reboots.
    authKeyFile = config.sops.secrets.tailscale_authkey.path;

    # Also sets the forwarding sysctls modules/system.nix used to carry.
    useRoutingFeatures = "both";

    extraUpFlags = [ "--ssh" ];

    # The tailnet name lives in Tailscale's control plane, so
    # networking.hostName alone never renames an existing node.
    extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
  };

  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    # Strict rpfilter drops tailscale's UDP replies, silently degrading direct
    # connections to relayed DERP.
    checkReversePath = "loose";
  };
}
