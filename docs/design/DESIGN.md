---
version: alpha
name: FerriScribe Clinical Workspace
description: A calm, action-first mobile workspace with matched light and dark clinical reading surfaces.
colors:
  primary: "#1B6B93"
  light-canvas: "#F4F7F9"
  light-surface: "#FFFFFF"
  light-surfaceVariant: "#E8EFF3"
  light-onSurface: "#162D3B"
  light-onSurfaceVariant: "#4E6573"
  light-primary: "#1B6B93"
  light-onPrimary: "#FFFFFF"
  light-primaryContainer: "#DAEBF4"
  light-onPrimaryContainer: "#174660"
  light-outline: "#768B98"
  light-outlineVariant: "#CEDAE1"
  light-error: "#AD303C"
  light-errorContainer: "#FCE8EB"
  light-onErrorContainer: "#74222D"
  light-success: "#216C50"
  light-successContainer: "#E2F2E9"
  light-onSuccessContainer: "#20553F"
  light-warning: "#865600"
  light-warningContainer: "#FFF1D4"
  light-onWarningContainer: "#684700"
  dark-canvas: "#101A23"
  dark-surface: "#192731"
  dark-surfaceVariant: "#233641"
  dark-onSurface: "#E6EEF3"
  dark-onSurfaceVariant: "#B1C2CD"
  dark-primary: "#91CEF0"
  dark-onPrimary: "#10384F"
  dark-primaryContainer: "#21495F"
  dark-onPrimaryContainer: "#D7EDF9"
  dark-outline: "#718B9B"
  dark-outlineVariant: "#3A505F"
  dark-error: "#FFAFB7"
  dark-errorContainer: "#492A33"
  dark-onErrorContainer: "#FFD9DE"
  dark-success: "#94D7B5"
  dark-successContainer: "#203F34"
  dark-onSuccessContainer: "#B8E7CE"
  dark-warning: "#EDC773"
  dark-warningContainer: "#433722"
  dark-onWarningContainer: "#F7DCA5"
typography:
  title:
    fontFamily: Roboto
    fontSize: 28px
    fontWeight: 600
    lineHeight: 1.22
  body:
    fontFamily: Roboto
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
  supporting:
    fontFamily: Roboto
    fontSize: 14px
    lineHeight: 1.43
rounded:
  control: 12px
  group: 16px
  sheet: 24px
spacing:
  xs: 4px
  sm: 8px
  related: 12px
  compact: 16px
  gutter: 20px
  section: 24px
  major: 32px
components:
  light-button-primary:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-onPrimary}"
    rounded: "{rounded.control}"
  light-document:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-onSurface}"
    rounded: "{rounded.control}"
  light-supporting:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-onSurfaceVariant}"
    rounded: "{rounded.control}"
  light-notice-error:
    backgroundColor: "{colors.light-errorContainer}"
    textColor: "{colors.light-onErrorContainer}"
    rounded: "{rounded.control}"
  light-notice-offline:
    backgroundColor: "{colors.light-warningContainer}"
    textColor: "{colors.light-onWarningContainer}"
    rounded: "{rounded.control}"
  dark-button-primary:
    backgroundColor: "{colors.dark-primary}"
    textColor: "{colors.dark-onPrimary}"
    rounded: "{rounded.control}"
  dark-document:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.dark-onSurface}"
    rounded: "{rounded.control}"
  dark-supporting:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.dark-onSurfaceVariant}"
    rounded: "{rounded.control}"
  dark-notice-error:
    backgroundColor: "{colors.dark-errorContainer}"
    textColor: "{colors.dark-onErrorContainer}"
    rounded: "{rounded.control}"
  dark-notice-offline:
    backgroundColor: "{colors.dark-warningContainer}"
    textColor: "{colors.dark-onWarningContainer}"
    rounded: "{rounded.control}"
---

## Overview

Operate surface, not a marketing dashboard. Paired tokens are normative in both themes. Material 3 Flutter controls, one primary action per focused route. See MOBILE_REDESIGN.md for screen/state contracts. All content in the prototype is synthetic.

## Colors

Keep brand seed #1B6B93. Initialize the complete ColorScheme fromSeed then map semantic role pairs from this file. Map canvas to scaffold background, surfaceVariant to grouped secondary surfaces, outline to essential control outlines and focus (primary focus preferred), outlineVariant to decorative separators only. Success/warning require a ThemeExtension. Never use subdued outlineVariant as the only essential control boundary. Do not equate green with clinically reviewed.

## Typography

Use native Flutter platform fonts (Roboto on Android, Cupertino system fallback on iOS); no downloaded fonts. Units in this interchange spec are px: implementations map typography to scalable sp and dimensions to logical dp, not physical pixels. Document 16sp/24, metadata 14sp/20. Weight 600 titles, 500 controls, 400 body. Never clamp OS text scaling. Timer uses tabular figures at 48sp/56.

## Layout

20dp phone gutters (16dp below 360dp), 24dp section separation, 8–12dp related gaps. App bar minimum 56dp, controls at least 48dp touch size, primary footer button minimum 56dp. All sizes are minima and grow with accessibility text. At 200% scaling stack actions rather than compressing text. Keyboard-safe scrolling with native insets. Wide document reading measure 720dp maximum.

## Elevation & Depth

Use surface changes and separators, not pervasive shadows. Native modal elevation/dimming only. No gradient, glass treatment, or fake waveform.

## Shapes

12dp controls, 16dp grouped panels, 24dp sheet corners. Pills describe a short state only. Avoid wrapping every document row in a separate card.

## Components

Filled primary, tonal/outlined secondary, text tertiary. Danger used for destructive actions; Stop & generate is not destructive. Status = semantic icon + words + optional color, never color alone. Selected appearance uses native radio semantics. Explicit Edit, Save changes, Export & share, Copy text actions. Disabled actions expose a reason nearby; use Material disabled-state treatment, not counterfeit live controls. Focus outline 2dp primary with contrast against adjacent surface. Native pressed/hover overlays, without suppressing semantics.

## Do’s and Don’ts

- Do preserve raw clinical document text and the edited buffer on error.
- Do distinguish server version, cached copy, unsaved edits and availability.
- Do keep all non-theme PHI out of preferences and demo artifacts.
- Do keep the existing opaque privacy mask independent of these tokens.
- Do not infer patient identity, clinical approval, connectivity or share delivery.
- Do not add unsupported pause, autosave, offline upload, or cloud storage controls.
- Do not use hard-coded grey/red/orange/green in production widgets.
