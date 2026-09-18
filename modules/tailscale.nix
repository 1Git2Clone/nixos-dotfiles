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

    extraSetFlags = [
      # The tailnet name lives in Tailscale's control plane, so
      # networking.hostName alone never renames an existing node.
      "--hostname=${config.networking.hostName}"

      # Already the default, and pinned here because it is a STORED pref: one
      # `tailscale set --accept-dns=false` on a bad day persists across reboots
      # and rebuilds with nothing in this repo to contradict it. Declaring it
      # puts it back on every activation.
      #
      # On its own this flag resolves nothing — see services.resolved below.
      "--accept-dns=true"

      # Without this every pref write is root-only, so `tailscale set` and the
      # GUIs on top of it fail with "checkprefs access denied" -- which is
      # every exit-node switch, the one pref changed from the desktop daily.
      "--operator=hutao"
    ];
  };

  # WHAT ACTUALLY MAKES MagicDNS RESOLVE. accept-dns only tells tailscaled to
  # *want* the tailnet's DNS config; it still needs somewhere to install it.
  # With NetworkManager owning /etc/resolv.conf and no resolved to talk to,
  # tailscaled has nowhere to put the split-DNS routes, so the config it was
  # handed goes nowhere:
  #
  #   $ tailscale dns status        # MagicDNS: enabled, suffix dikdik-cloud.ts.net
  #   $ getent hosts vps            # nothing
  #   $ cat /etc/resolv.conf        # nameserver 1.1.1.1, no search domain
  #
  # The failure is quiet in the worst way — every tailscale-side check reports
  # healthy and only name lookups are dead, so it reads as a DNS problem rather
  # than a missing resolver. It cost a deploy: deploy-rs addresses this repo's
  # VPS by its MagicDNS name and died on "Could not resolve hostname vps".
  #
  # resolved gives tailscaled the D-Bus interface it programs split DNS
  # through, and NetworkManager defers to it once it is running. nsswitch picks
  # up `resolve` from the NixOS module, so nothing else here needs changing.
  services.resolved.enable = true;

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
