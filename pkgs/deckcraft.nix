# DeckCraft, a Rust PowerPoint-style presentation app, from the same upstream
# as photocraft.nix. The Linux tarball is a plain binary that links only libc;
# the windowing and GPU libraries are dlopen'd at runtime (winit, wgpu), so
# autoPatchelf can't see them and they go on the rpath through
# runtimeDependencies instead.
#
# File > Open falls back to a bare `zenity` when the portal doesn't answer, and
# on this desktop it does nothing without one, so zenity goes on PATH.
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zenity,
  alsa-lib,
  stdenv,
  wayland,
  libxkbcommon,
  libGL,
  vulkan-loader,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "deckcraft";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/storytold/deckcraft/releases/download/v${finalAttrs.version}/deckcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-wmSMYHH2MezGY5zmt9YPaO7YPd6rprFVmwfFBGhjEXw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
  ];
  runtimeDependencies = [
    wayland
    libxkbcommon
    libGL
    vulkan-loader
    libx11
    libxcursor
    libxi
    libxrandr
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin share $out/
    wrapProgram $out/bin/deckcraft --prefix PATH : ${lib.makeBinPath [ zenity ]}
    runHook postInstall
  '';

  meta = {
    description = "Open-source clean-room PowerPoint-style presentation app in Rust";
    homepage = "https://github.com/storytold/deckcraft";
    license = with lib.licenses; [
      asl20
      mit
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "deckcraft";
  };
})
