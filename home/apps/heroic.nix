# Heroic's custom themes are CSS files in one folder, each named as the body
# class it styles: caelestia.css is picked as "caelestia" and styles
# body.caelestia. A caelestia template, so it follows a scheme switch the next
# time Heroic starts. Point Settings > General > Custom Themes Path at
# ~/.config/heroic/themes once and pick it.
{ pkgs, palette, ... }:
let
  inherit (palette.template) hex rgba;
in
{
  hutao.caelestiaTemplates."heroic-caelestia.css" = {
    target = ".config/heroic/themes/caelestia.css";
    source = pkgs.writeText "heroic-caelestia.css" ''
      body.caelestia {
        /* 2.22's base palette (styles/_colors.scss), which no built-in theme
           overrides, so the tour and the brand-coloured widgets stay cyan
           under every one of them. Upstream main derives these from the
           accent instead. */
        --brand-primary: ${hex.primary};
        --brand-primary-hover: ${hex.primaryFixedDim};
        --brand-secondary: ${hex.secondary};
        --brand-secondary-hover: ${hex.secondaryFixed};
        --brand-text-01: ${hex.primaryFixed};
        --brand-text-02: ${hex.primaryFixedDim};
        --brand-text-03: ${hex.primary};
        --brand-text-04: ${hex.tertiaryFixed};
        --brand-text-05: ${hex.tertiary};
        --neutral-01: ${hex.crust};
        --neutral-02: ${hex.mantle};
        --neutral-03: ${hex.surface0};
        --neutral-04: ${hex.overlay0};
        --neutral-05: ${hex.subtext0};
        --neutral-06: ${hex.subtext1};
        --neutral-07: ${hex.text};
        --neutral-08: ${hex.onSurface};
        --status-default: ${hex.subtext1};
        --status-default-hover: ${hex.subtext0};
        --status-success: ${hex.success};
        --status-success-hover: ${hex.green};
        --status-warning: ${hex.yellow};
        --status-warning-hover: ${hex.peach};
        --status-danger: ${hex.error};
        --status-danger-hover: ${hex.red};
        --status-info: ${hex.sky};
        --status-info-hover: ${hex.sapphire};
        --primary-active: ${hex.primaryFixed};
        --secondary-hover: ${hex.secondaryFixedDim};
        --secondary-active: ${hex.secondaryContainer};
        --base-06: ${hex.overlay2};
        --accent-02: ${rgba "primaryContainer" "0.36"};
        --gradient-01: linear-gradient(270.36deg, ${hex.tertiary} 1.57%, ${hex.primary} 96.46%);
        --gradient-02: linear-gradient(270.36deg, ${hex.primary} 1.57%, ${hex.tertiary} 96.46%);

        --on-panel: ${hex.text};
        --on-panel-muted: ${hex.subtext1};
        --ink-on-accent: ${hex.onPrimary};

        --accent: ${hex.primary};
        --accent-overlay: ${hex.primaryFixed};
        --navbar-accent: ${hex.tertiary};
        --background: ${hex.base};
        --body-background: ${hex.base};
        --background-darker: ${hex.mantle};
        --current-background: ${hex.base};
        --navbar-background: ${hex.mantle};
        --navbar-active-background: ${hex.surface1};
        --gradient-body-background: linear-gradient(
          90deg,
          var(--background-darker) -32px,
          var(--body-background) 64px,
          var(--body-background) 100%
        );
        --input-background: ${hex.surface0};
        --modal-background: var(--body-background);
        --modal-border: ${hex.outlineVariant};
        --success: ${hex.success};
        --success-hover: ${hex.green};
        --primary: ${hex.primary};
        --primary-hover: ${hex.primaryFixedDim};
        --danger: ${hex.error};
        --text-log: ${hex.subtext0};
        --text-title: var(--on-panel);
        --text-default: var(--on-panel);
        --text-secondary: var(--on-panel-muted);
        --text-tertiary: var(--ink-on-accent);
        --osk-background: var(--body-background);
        --osk-button-background: var(--input-background);
        --osk-button-border: var(--navbar-background);
        --action-icon: ${hex.overlay2};
        --action-icon-hover: var(--accent-overlay);
        --action-icon-active: var(--text-default);
        --success-button: ${hex.success};
        --secondary-button: ${hex.secondary};
        --icons-background: ${hex.surface0};
      }

      /* A literal cyan in 2.22's Tour.scss, !important, so only a more
         specific !important reaches it. */
      body.caelestia .heroic-tour-highlight {
        background: ${rgba "primary" "0.1"} !important;
      }
    '';
  };
}
