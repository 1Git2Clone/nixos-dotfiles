# The image-generation MCP server opencode calls. Source is ours, under
# pkgs/openrouter-image-mcp -- it is TypeScript, so it has to be compiled
# before anything can run it, which is the whole reason it is a package
# rather than a path in the dotfiles.
{
  lib,
  buildNpmPackage,
  makeWrapper,
  nodejs,
}:
buildNpmPackage {
  pname = "openrouter-image-mcp";
  inherit (lib.importJSON ./openrouter-image-mcp/package.json) version;

  src = ./openrouter-image-mcp;

  # Bump with:
  #   nix run nixpkgs#prefetch-npm-deps -- pkgs/openrouter-image-mcp/package-lock.json
  npmDepsHash = "sha256-FX3zV3cVmtk3OB+2mJj7+Vt9Gk6S+z3Q6EYVyOrLMJI=";

  nativeBuildInputs = [ makeWrapper ];

  # package.json declares no `bin`, and dist/ is gitignored, so npm's own
  # install step would ship neither. Copy the tsc output and wrap node
  # around it instead.
  installPhase = ''
    runHook preInstall

    npm prune --omit=dev
    mkdir -p $out/lib/openrouter-image-mcp
    cp -r dist node_modules $out/lib/openrouter-image-mcp/

    makeWrapper ${lib.getExe nodejs} $out/bin/openrouter-image-mcp \
      --add-flags $out/lib/openrouter-image-mcp/dist/index.js

    runHook postInstall
  '';

  meta = {
    description = "MCP server for OpenRouter image generation";
    mainProgram = "openrouter-image-mcp";
    platforms = lib.platforms.all;
  };
}
