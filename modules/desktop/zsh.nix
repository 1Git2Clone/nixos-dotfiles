# oh-my-zsh already loads its plugins from home/apps/zsh.nix, and
# ZSH_CACHE_DIR defaults to $ZSH/cache, which is a store path here.
{
  environment.sessionVariables.ZSH_CACHE_DIR = "$HOME/.cache/oh-my-zsh";
}
