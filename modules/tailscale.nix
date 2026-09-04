# In hosts/common, not the desktop layer: hutao-vm has no sops to decrypt
# authKeyFile with.
{ config, pkgs, ... }:
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

  # https://tailscale.com/s/ethtool-config-udp-gro — throughput when this node
  # routes for others, which useRoutingFeatures above allows. The nixpkgs
  # module does not do it, so this carries over the dotfiles repo's
  # networkd-dispatcher script; NetworkManager's dispatcher is the equivalent
  # hook, and re-runs it whenever a link comes up rather than only at boot.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "tailscale-udp-gro" ''
        # $2 is the dispatcher action; "basic" fires for every one of them.
        [ "$2" = "up" ] || exit 0
        dev=$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '{print $5; exit}')
        [ -n "$dev" ] && ${pkgs.ethtool}/bin/ethtool -K "$dev" \
          rx-udp-gro-forwarding on rx-gro-list off
      '';
    }
  ];
}
