# Tailscale, mirroring the vps repo's modules/services.nix.
#
# In hosts/common, not the desktop layer: hutao-vm has no sops, so an
# authKeyFile pointing at a secret it cannot decrypt would fail activation.
{ config, ... }:
{
  services.tailscale = {
    enable = true;

    # Pre-authorized and reusable, NOT ephemeral — the node has to survive
    # reboots. Without it `tailscale up` blocks on a login URL and the first
    # boot is not unattended.
    authKeyFile = config.sops.secrets.tailscale_authkey.path;

    # Replaces the net.ipv4.ip_forward / net.ipv6.conf.all.forwarding sysctls
    # that modules/system.nix used to carry by hand. "both" keeps the exit-node
    # and subnet-router paths available; "client" would turn forwarding off.
    useRoutingFeatures = "both";

    extraUpFlags = [ "--ssh" ];
  };

  # tailscale0 carries only tailnet peers, which are already authenticated by
  # WireGuard. Without this the default firewall drops them.
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    # Tailscale's UDP replies arrive on an interface the kernel would not have
    # chosen for the return route. Strict rpfilter drops them and direct
    # connections silently degrade to relayed DERP.
    checkReversePath = "loose";
  };
}
