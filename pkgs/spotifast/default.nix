{ spotifast, nerd-fonts, lib }:
spotifast.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/theme.rs --replace-fail \
      '    text_rendering().apply_to(&mut fonts);' \
      ${lib.escapeShellArg ''
        // Keep the application's weight families, with our primary face.
        for (name, bytes) in [
          ("inter", include_bytes!("${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf").as_slice()),
          ("inter-medium", include_bytes!("${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Medium.ttf").as_slice()),
          ("inter-semibold", include_bytes!("${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-SemiBold.ttf").as_slice()),
          ("inter-bold", include_bytes!("${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Bold.ttf").as_slice()),
        ] {
            fonts.font_data.insert(name.into(), std::sync::Arc::new(egui::FontData::from_static(bytes)));
        }
        text_rendering().apply_to(&mut fonts);
      ''}
  '';
})
