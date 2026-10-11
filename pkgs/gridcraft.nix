# GridCraft, a Rust Excel-style spreadsheet, from the same upstream
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
  pname = "gridcraft";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/storytold/gridcraft/releases/download/v${finalAttrs.version}/gridcraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-5lBcL5KfmFTDUKDfJhicTlbIrfh8xhYl+A1qjuwrYo0=";
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
    wrapProgram $out/bin/gridcraft --prefix PATH : ${lib.makeBinPath [ zenity ]}
    runHook postInstall
  '';

  meta = {
    description = "Open-source clean-room spreadsheet (Excel-style) in Rust";
    homepage = "https://github.com/storytold/gridcraft";
    license = with lib.licenses; [
      asl20
      mit
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "gridcraft";
  };
})
