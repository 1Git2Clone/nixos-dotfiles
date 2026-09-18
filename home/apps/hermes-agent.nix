{ lib, osConfig, ... }:
{
  # `programs.` is the CLI, `services.` owns ~/.hermes. gateway.enable stays
  # at its default false: this is a command, not a daemon.
  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;

    # The only free openrouter model that calls tools and has the context an
    # agent needs.
    settings.model = {
      default = "minimax/minimax-m3:free";
      provider = "openrouter";
    };

    # A `str`, never a path literal: a literal would copy the plaintext into
    # /nix/store. Guarded because hutao-vm has no sops module, and hutao-vm is
    # what CI evaluates.
    #
    # The same file dot-profile.d/environment.sh sources, rendered by
    # modules/sops.nix out of the `llm:` section — one place holds the keys,
    # and hermes picks up a new provider without a line here.
    environmentFiles = lib.optional (osConfig ? sops) osConfig.sops.templates."llm.env".path;
  };
}
