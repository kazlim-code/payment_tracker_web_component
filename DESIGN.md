---
name: Technical Precision Tracker
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#e0c0b1'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#a78b7d'
  outline-variant: '#584237'
  surface-tint: '#ffb690'
  primary: '#ffb690'
  on-primary: '#552100'
  primary-container: '#f97316'
  on-primary-container: '#582200'
  inverse-primary: '#9d4300'
  secondary: '#b9c8de'
  on-secondary: '#233143'
  secondary-container: '#39485a'
  on-secondary-container: '#a7b6cc'
  tertiary: '#93ccff'
  on-tertiary: '#003351'
  tertiary-container: '#00a2f4'
  on-tertiary-container: '#003554'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbca'
  primary-fixed-dim: '#ffb690'
  on-primary-fixed: '#341100'
  on-primary-fixed-variant: '#783200'
  secondary-fixed: '#d4e4fa'
  secondary-fixed-dim: '#b9c8de'
  on-secondary-fixed: '#0d1c2d'
  on-secondary-fixed-variant: '#39485a'
  tertiary-fixed: '#cde5ff'
  tertiary-fixed-dim: '#93ccff'
  on-tertiary-fixed: '#001d32'
  on-tertiary-fixed-variant: '#004b74'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  h1:
    fontFamily: Space Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  h2:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  h3:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.2'
  body-base:
    fontFamily: Space Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  body-sm:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: '1.5'
  label-caps:
    fontFamily: Space Grotesk
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  mono-data:
    fontFamily: Space Grotesk
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1'
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  gutter: 16px
  margin: 24px
---

## Brand & Style

This design system is engineered for high-performance environments where clarity and utility are paramount. It adopts a **Pro-Tool Minimalism** aesthetic, drawing inspiration from aerospace instrumentation and laboratory equipment. The focus is on dense information display, rigorous alignment, and a sophisticated dark environment.

The brand personality is authoritative, precise, and uncompromising. By stripping away decorative brand flourishes in favor of neutral structural elements, the UI recedes to let data take center stage. The safety orange accent is used sparingly as a functional signifier for action and status, ensuring it remains impactful against the disciplined, monochromatic foundation.

## Colors

The palette is anchored by a deep "Ink" background to minimize eye strain during extended use. The primary accent, **Safety Orange (#f97316)**, is reserved exclusively for high-priority interactive states, critical alerts, and primary call-to-actions.

Structural elements—specifically borders, dividers, and container edges—are strictly limited to a range of neutral slates and greys. This removes visual noise and reinforces the "pro-tool" aesthetic.
- **Surface:** Used for cards and elevated panels.
- **Border Neutral:** The standard stroke for input fields, buttons, and card containers.
- **Border Subtle:** Used for internal dividers and secondary grouping within modules.

## Typography

This design system utilizes **Space Grotesk** across all levels to maintain a technical, geometric rhythm. The typeface's distinctive glyphs lend a futuristic, precise character to the interface.

To enhance the "pro-tool" feel, use `tabular-nums` for all data displays, tables, and counters to ensure vertical alignment. Section headers should utilize the `label-caps` style with increased letter spacing to act as clear navigational anchors without requiring heavy visual weight.

## Layout & Spacing

The layout is built on a strict **4px baseline grid**. A 12-column fluid grid system is used for page-level architecture, while internal component spacing follows a mathematical progression (4, 8, 16, 24, 40). 

Information density is high. Use the `md` (16px) gutter as the standard for card internal padding, but reduce to `sm` (8px) for data-heavy tables or sidebars. The goal is a compact, efficient use of screen real estate that mimics engineering software.

## Elevation & Depth

Depth is conveyed through **Tonal Layering** rather than traditional shadows. In this dark mode environment, elevation is signaled by slightly lightening the surface color of the container.

- **Level 0 (Background):** #020617 (Deepest)
- **Level 1 (Cards/Panels):** #0f172a
- **Level 2 (Modals/Popovers):** #1e293b

Borders are the primary tool for defining boundaries. All borders must use neutral tones (#1e293b or #334155). Even when an element is focused, the border remains neutral or white; use the safety orange accent for internal indicators (like a cursor or a small tab-bar) rather than coloring the entire perimeter of the container.

## Shapes

To reinforce the technical and precise nature of the system, a **Sharp (0px)** corner radius is applied to all UI elements. This includes buttons, input fields, cards, and dropdowns. The lack of rounding evokes a sense of industrial reliability and architectural structuralism. 

Visual separation is achieved through 1px neutral borders and contrasting tonal backgrounds rather than rounded containment.

## Components

### Buttons
- **Primary:** Solid safety orange (#f97316) with black text. Sharp corners.
- **Secondary:** Transparent background, 1px neutral border (#334155), white text.
- **Ghost:** No border, grey text, becomes white on hover.

### Input Fields
- **Default:** 1px neutral border (#1e293b), dark background (#020617).
- **Focus:** 1px white border. Do not use orange for the border; use a 2px orange vertical "active" indicator line on the far left of the input instead.

### Cards
- **Container:** Level 1 surface color, 1px neutral border (#1e293b).
- **Header:** Separated from body by a 1px internal divider (#1e293b).

### Chips & Tags
- **Technical Tags:** Small caps text, 1px neutral border, no fill. 
- **Status Indicators:** A small 8px solid circle of color (e.g., orange for 'Active', grey for 'Idle') placed next to the label.

### Lists & Data Tables
- Use 1px neutral horizontal dividers only. No vertical lines.
- Row hover state: lighten the background color slightly (#1e293b).
- Data cells: Use `mono-data` typography for perfect alignment.

### Checkboxes & Radios
- Sharp squares (checkboxes) and sharp diamonds (radios).
- Unselected: 1px neutral border.
- Selected: Solid safety orange fill with a white check/dot.
