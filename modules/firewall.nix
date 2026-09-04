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
# policy drop, lo and tailscale0 accepted, established/related, then the
# explicit ports. No output chain, which on a desktop would mean a drop policy
# over every port a browser, game or update ever picks.
{ config, ... }:
{
  networking.nftables.enable = true;

  networking.firewall = {
    # Tailscale's own transport, so peers can find a direct path instead of
    # falling back to a DERP relay. Nothing opens it by default.
    allowedUDPPorts = [ config.services.tailscale.port ];

    # The VPS ruleset's `log prefix "DROP_in: "`. Defaults to false here.
    logRefusedConnections = true;
  };

  # sshd keeps listening, but only trustedInterfaces reaches it: over the
  # tailnet, or from the keyboard. Losing tailscale means losing remote SSH.
  services.openssh.openFirewall = false;
}
