# Chrome DevTools' MCP server, prebuilt and dependency-free on npm, so the
# tarball only needs node wrapped around it. mcp.nix runs it once for every
# agent; the Claude plugin of the same name started its own through npx.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:
stdenvNoCC.mkDerivation rec {
  pname = "chrome-devtools-mcp";
  version = "1.13.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-kVjEtKh5LLUirkb3buqpSRzgRhajrpcimhYnfgKkrqQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/${pname}
    cp -r out package.json $out/lib/${pname}/
    makeWrapper ${lib.getExe nodejs} $out/bin/${pname} \
      --add-flags $out/lib/${pname}/out/Default/gen/src/bin/${pname}.js
    runHook postInstall
  '';

  meta = {
    description = "Chrome DevTools MCP server";
    mainProgram = pname;
    platforms = lib.platforms.all;
  };
}
