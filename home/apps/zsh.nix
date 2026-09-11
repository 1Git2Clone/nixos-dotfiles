# oh-my-zsh, assembled rather than symlinked so the custom plugins land
# inside $ZSH. The .zshrc itself comes from the dotfiles tree.
{ pkgs, lib, ... }:
let
  zshPlugins = [
    {
      name = "zsh-autosuggestions";
      src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
    }
    {
      name = "zsh-syntax-highlighting";
      src = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
    }
    {
      name = "zsh-vi-mode";
      src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
    }
  ];

  # Assembled rather than symlinked, so the custom plugins are inside $ZSH.
  ohMyZsh = pkgs.runCommandLocal "oh-my-zsh-hutao" { } ''
    cp -r ${pkgs.oh-my-zsh}/share/oh-my-zsh $out
    chmod -R u+w $out
    ${lib.concatMapStringsSep "\n" (
      { name, src }:
      ''
        # Whole tree: these resolve siblings off ''${0:h}.
        cp -rL ${src} "$out/custom/plugins/${name}"
        chmod -R u+w "$out/custom/plugins/${name}"

        # oh-my-zsh wants <name>.plugin.zsh; nixpkgs ships some as <name>.zsh.
        if [ ! -e "$out/custom/plugins/${name}/${name}.plugin.zsh" ]; then
          echo 'source "''${0:A:h}/${name}.zsh"' \
            > "$out/custom/plugins/${name}/${name}.plugin.zsh"
        fi
      ''
    ) zshPlugins}
  '';
in
{
  # oh-my-zsh's ZSH_CACHE_DIR defaults to $ZSH/cache, which is a store path.
  home.sessionVariables.ZSH_CACHE_DIR = "$HOME/.cache/oh-my-zsh";

  home.file = {
    ".oh-my-zsh".source = ohMyZsh;

    # Sourced unguarded by .zshrc, so it only has to exist.
    ".atuin/bin/env".text = "";
  };
}
