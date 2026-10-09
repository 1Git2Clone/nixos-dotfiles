# PhotoCraft, a Rust Photoshop clone. Upstream's Linux tarball is a plain
# binary that links only libc; the windowing and GPU libraries are dlopen'd at
# runtime (winit, wgpu), so autoPatchelf can't see them and they go on the
# rpath through runtimeDependencies instead.
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
  pname = "photocraft";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/storytold/photocraft/releases/download/v${finalAttrs.version}/photocraft-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-4EQQGy2lUiiW4dgza4EIfL7L9reLdoUxX1jdTz36TOA=";
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
    wrapProgram $out/bin/photocraft --prefix PATH : ${lib.makeBinPath [ zenity ]}
    runHook postInstall
  '';

  meta = {
    description = "Open-source clean-room Photoshop reimplementation in Rust";
    homepage = "https://github.com/storytold/photocraft";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "photocraft";
  };
})
