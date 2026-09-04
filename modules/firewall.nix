# nftables, but through the NixOS firewall module rather than a hand-written
# ruleset like ../../vps/modules/firewall.nix.
#
# That ruleset has to `delete table inet nixos-fw` to install its own, and
# nixos-fw is the name the firewall module's own table uses -- so writing one
# here would silently void trustedInterfaces, checkReversePath and every
# module's openFirewall. The VPS pays that price because docker leaves it no
# choice. Nothing here runs containers.
#
# The generated chains are the same shape either way: input and forward at
# policy drop, lo and tailscale0 accepted, established and related, then the
# explicit ports.
#
# Egress is deliberately unfiltered, so `git clone git@...` and everything
# else needs no rule. A drop policy there would have to enumerate every port a
# browser, game or updater picks, and each miss looks like a network fault
# rather than a firewall.
{ config, ... }:
{
  networking.nftables.enable = true;

  networking.firewall = {
    # The only inbound port on a physical interface, and the one that has to
    # be: it is the tailnet's own underlay, so closing it forces every peer
    # onto a DERP relay. WireGuard drops anything not from a known node key.
    allowedUDPPorts = [ config.services.tailscale.port ];

    # IPv4 only: the module's ICMPv6 accept is unconditional, since dropping
    # it breaks path MTU discovery and neighbour discovery. So v6 pings are
    # still answered, and that is correct.
    allowPing = false;

    # Off by default, and the only way to tell a firewall drop from a broken
    # service: `journalctl -k | grep refused`.
    logRefusedConnections = true;
  };

  # Inbound ssh is the tailnet's job -- tailscaled serves it itself on the
  # tailnet address and never touches sshd. So tcp 22 leaves the ruleset
  # entirely; sshd keeps listening for tailscale0 and the keyboard.
  services.openssh.openFirewall = false;
}
