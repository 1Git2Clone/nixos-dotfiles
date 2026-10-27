# CADCraft, a Rust AutoCAD-style CAD app, from the same upstream
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
  pname = "cadcraft";
  version = "0.13.0";

  src = fetchurl {
    url = "https://github.com/storytold/cadcraft/releases/download/v${finalAttrs.version}/cadcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-04dVvrYYiXVr69k430kebuDeeMLzX9NRBaR5kJ/RypI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
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
    wrapProgram $out/bin/cadcraft --prefix PATH : ${lib.makeBinPath [ zenity ]}
    runHook postInstall
  '';

  meta = {
    description = "Open-source clean-room AutoCAD-style CAD app in Rust";
    homepage = "https://github.com/storytold/cadcraft";
    license = with lib.licenses; [
      asl20
      mit
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "cadcraft";
  };
})
