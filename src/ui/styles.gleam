//// This module defines the base CSS styles for the payment tracker component.
////

import lustre/element.{type Element}
import lustre/element/html

/// Returns a style element containing the base CSS for the application.
///
pub fn base() -> Element(msg) {
  html.style(
    [],
    "
    :host {
      --primary: #f97316;
      --on-primary: #000000;
      --primary-container: #f97316;
      --on-primary-container: #000000;

      --background: #0b1326;
      --on-background: #dae2fd;

      --surface: #0b1326;
      --on-surface: #dae2fd;
      --on-surface-level-1: color-mix(in srgb, var(--on-surface), black 30%);
      --surface-variant: #2d3449;
      --surface-variant-dark: #131b2e;
      --on-surface-variant-dark: color-mix(in srgb, var(--on-surface), black 20%);
      --surface-container-high: #222a3d;
      --surface-container-low: #131b2e;
      --surface-container-lowest: #060e20;
      --on-surface-variant: #e0c0b1;

      --level-0: #020617;
      --level-1: #0f172a;
      --level-2: #1e293b;

      --border-neutral: #1e293b;
      --border-subtle: #334155;

      --status-paid: #81c995;
      --status-owed: #f28b82;

      --font-family: 'Space Grotesk', sans-serif;
      --font-light: 300;
      --font-normal: 400;
      --font-medium: 500;
      --font-semibold: 600;
      --font-bold: 700;

      --text-xs: 0.75rem;
      --text-sm: 0.875rem;
      --text-base: 1rem;
      --text-lg: 1.125rem;
      --text-xl: 1.25rem;
      --text-2xl: 1.5rem;
      --text-3xl: 1.875rem;
      --text-4xl: 2.25rem;
      --text-xs--line-height: calc(1 / 0.75);
      --text-sm--line-height: calc(1.25 / 0.875);
      --text-base--line-height: calc(1.5 / 1);
      --text-lg--line-height: calc(1.75 / 1.125);
      --text-xl--line-height: calc(1.75 / 1.25);
      --text-2xl--line-height: calc(2 / 1.5);
      --text-3xl--line-height: calc(2.5 / 1.875);
      --text-4xl--line-height: calc(2.5 / 2.25);

      --radius-none: 0px;
      --radius-xs: 0.125rem;
      --radius-sm: 0.25rem;
      --radius-md: 0.375rem;
      --radius-lg: 0.5rem;
      --radius-xl: 0.75rem;
      --radius-full: calc(infinity * 1px);

      --shadow-xs: 0 1px 2px 0 rgb(0 0 0 / 0.05);
      --shadow-sm: 0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1);
      --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
      --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);

      --gap-xs: 0.25rem;
      --gap-sm: 0.5rem;
      --gap-md: 1rem;
      --gap-lg: 1.5rem;
      --gap-xl: 2rem;

      --view-header-height: 4rem;
      --vim-footer-height: 2.5rem;

      --add-payment-view-max-width: 60rem;
      --summary-view-max-width: 80rem;
      --summary-empty-max-width: 60rem;
      --dialog-max-width: 30rem;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    /* --- Dialog & Popover styles --- */

    /* Open state of the dialog  */
    dialog:open {
      opacity: 1;
    }

    /* Closed state of the dialog   */
    dialog {
      opacity: 0;
      transition: opacity 0.25s allow-discrete;
    }

    /* Before open state  */
    /* Needs to be after the previous dialog:open rule to take effect, as the specificity is the same */
    @starting-style {
      dialog:open {
        opacity: 0;
      }
    }

    /* Transition the :backdrop when the dialog modal is promoted to the top layer */
    dialog::backdrop {
      background-color: hsl(0 0% 0% / 0.75);
      opacity: 0;
      transition: opacity 0.25s allow-discrete;
    }

    dialog:open::backdrop {
      opacity: 0.5;
    }

    /* Apply blur to the entire body when dialog is open. Applying filter-blur to ::backdrop doesn't seem to have any effect */
    body:has(dialog[open]) {
      filter: blur(4px);
    }

    /* This starting-style rule cannot be nested inside the above selector because the nesting selector cannot represent pseudo-elements. */
    @starting-style {
      dialog:open::backdrop {
        opacity: 0;
      }
    }

    [popover] {
      border: 1.5px solid var(--surface-container-high);
      border-radius: var(--gap-xs);
      box-shadow: rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 10px 15px -3px, rgba(0, 0, 0, 0.1) 0px 4px 6px -4px;
      inset: unset;
      position-try-fallbacks: flip-block, flip-inline;
      position-try: flip-block, flip-inline;
      right: anchor(right);
      top: anchor(bottom);
    }

    popover::backdrop {
      background-image: black;
      opacity: 0.75;
    }


    /* Hide native step buttun inside number input */
    /* For Chrome, Safari, Edge, Opera */
    input::-webkit-outer-spin-button,
    input::-webkit-inner-spin-button {
      -webkit-appearance: none;
      margin: 0;
    }

    /* For Firefox */
    input[type=number] {
      -moz-appearance: textfield;
      appearance: textfield;
    }

    #payment-tracker {
      font-family: var(--font-family);
      background-color: var(--background);
      color: var(--on-background);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    .container {
      width: 100%;
      max-width: 1280px;
      margin: 0 auto;
      padding: 2rem 1.5rem;
    }

    .h-1 { height: var(--gap-xs); }
    .h-2 { height: var(--gap-sm); }
    .h-4 { height: var(--gap-md); }
    .h-6 { height: var(--gap-lg); }
    .h-8 { height: var(--gap-xl); }
    .w-1 { width: var(--gap-xs); }
    .w-2 { width: var(--gap-sm); }
    .w-4 { width: var(--gap-md); }
    .w-6 { width: var(--gap-lg); }
    .w-8 { width: var(--gap-xl); }

    /* Typography */
    /* TODO: Only define typography being used */
    .text-h1 { font-size: 2.5rem; font-family: var(--font-family); font-weight: var(--font-bold); line-height: 1.1; letter-spacing: -0.02em; }
    .text-h2 { font-size: 2rem; font-family: var(--font-family); font-weight: var(--font-semibold); line-height: 1.2; letter-spacing: -0.01em; }
    .text-h3 { font-size: 1.5rem; font-family: var(--font-family); font-weight: var(--font-semibold); line-height: 1.2; }
    .text-xs { font-size: var(--text-xs); line-height: var(--text-xs--line-height); }
    .text-sm { font-size: var(--text-sm); line-height: var(--text-sm--line-height); }
    .text-base { font-size: var(--text-base); line-height: var(--text-base--line-height); }
    .text-lg { font-size: var(--text-lg); line-height: var(--text-lg--line-height); }
    .text-xl { font-size: var(--text-xl); line-height: var(--text-xl--line-height); }
    .text-2xl { font-size: var(--text-2xl); line-height: var(--text-2xl--line-height); }
    .text-3xl { font-size: var(--text-3xl); line-height: var(--text-3xl--line-height); }
    .text-body-base { font-size: 1rem; font-family: var(--font-family); font-weight: 400; line-height: 1.5; }
    .text-body-sm { font-size: 0.875rem; font-family: var(--font-family); font-weight: 400; line-height: 1.5; }
    .text-label-caps { font-size: 0.75rem; font-family: var(--font-family); font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; }
    .text-mono-data { font-size: 1rem; font-family: var(--font-family); font-weight: 500; line-height: 1.5; font-variant-numeric: tabular-nums; }

    .font-light { font-weight: 300; }
    .font-normal { font-weight: 400; }
    .font-medium { font-weight: 500; }
    .font-semibold { font-weight: 600; }
    .font-bold { font-weight: 700; }
    .uppercase { text-transform: uppercase; }

    .text-white { color: white; }
    .text-primary { color: var(--primary); }
    .text-on-primary { color: var(--on-primary); }
    .text-on-surface { color: var(--on-surface); }
    .text-on-surface-variant { color: var(--on-surface-variant); }
    .text-on-surface-variant-dark { color: var(--on-surface-variant-dark); }
    .text-success { color: var(--status-paid); }

    .truncate { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

    /* Layout Utilities */
    .flex { display: flex; }
    .flex-col { flex-direction: column; }
    .justify-between { justify-content: space-between; }
    .justify-end { justify-content: space-between; }
    .items-center { align-items: center; }
    .items-end { align-items: flex-end; }
    .items-baseline { align-items: baseline; }
    .grow { flex-grow: 1; }
    .gap-xs { gap: 0.25rem; }
    .gap-sm { gap: 0.5rem; }
    .gap-md { gap: 1rem; }
    .gap-lg { gap: 1.5rem; }
    .gap-xl { gap: 2rem; }
    .h-full { height: 100%; }
    .w-full { width: 100%; }
    .text-center { text-align: center; }
    .text-right { text-align: right; }

    .bg-primary { background-color: var(--primary); }
    .bg-surface-variant-dark { background-color: var(--surface-variant-dark); }
    .bg-surface-container-high { background-color: var(--surface-container-high); }

    .opacity-40 { opacity: 0.4; }
    .opacity-50 { opacity: 0.5; }
    .opacity-70 { opacity: 0.7; }

    .p-xs { padding: var(--gap-xs); }
    .p-sm { padding: var(--gap-sm); }
    .p-md { padding: var(--gap-md); }
    .p-lg { padding: var(--gap-lg); }
    .p-xl { padding: var(--gap-xl); }
    .p-base { padding: var(--gap-sm) var(--gap-md); }

    .mb-xs { margin-bottom: var(--gap-xs); }
    .mb-sm { margin-bottom: var(--gap-sm); }
    .mb-md { margin-bottom: var(--gap-md); }
    .mb-lg { margin-bottom: var(--gap-lg); }
    .mb-xl { margin-bottom: var(--gap-xl); }

    .relative { position: relative; }
    .absolute { position: absolute; }
    .sticky { position: sticky; }
    .top-0 { top: 0; }
    .z-40 { z-index: 40; }
    .z-50 { z-index: 50; }

    .rounded-none { border-radius: var(--radius-none); }
    .rounded-xs { border-radius: var(--radius-xs); }
    .rounded-sm { border-radius: var(--radius-sm); }
    .rounded-md { border-radius: var(--radius-md); }
    .rounded-lg { border-radius: var(--radius-lg); }
    .rounded-xl { border-radius: var(--radius-xl); }
    .rounded-full { border-radius: var(--radius-full); }

    .cursor-auto { cursor: auto; }
    .cursor-default { cursor: default; }
    .cursor-pointer { cursor: pointer; }
    .cursor-progress { cursor: progress; }
    .pointer-events-auto { pointer-events: auto; }
    .pointer-events-none { pointer-events: none; }

    .dot-sm { border-radius: var(--radius-full); height: 0.5rem; width: 0.5rem; }

    .sr-only {
      border-width: 0;
      clip: rect(0, 0, 0, 0);
      height: 1px;
      margin: -1px;
      overflow: hidden;
      padding: 0;
      position: absolute;
      white-space: nowrap;
      width: 1px;
    }

    /* Buttons */
    .btn-primary {
      align-items: center;
      background: var(--primary);
      border-radius: var(--radius-xs);
      color: var(--on-primary);
      border: none;
      padding: 0.625rem 1.25rem;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      gap: 0.5rem;

      &:hover {
        color: white;
      }
    }

    /* .btn-secondary {
      background: transparent;
      border: 1px solid var(--border-subtle);
      color: white;
      padding: 0.625rem 1.25rem;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    } */

    .btn-ghost {
      align-items: center;
      background: none;
      border: none;
      border-radius: var(--radius-xs);
      color: var(--on-surface-level-1);
      cursor: pointer;
      display: flex;
      justify-content: center;
      padding: 0.625rem 1.25rem;

      &.primary {
        color: var(--primary);
      }

      &.p-btn-sm {
        padding: var(--gap-sm) var(--gap-md);
      }

      &:hover {
        color: white;
        background: rgba(255,255,255,0.05);
      }
    }

    .popover-btn {
      &:has(~[data-popover-menu]:popover-open) {
        outline: 1px solid red;
      }
    }

    .popover-menu {
      background: var(--surface-variant-dark);
      border-radius: var(--radius-sm);
      color: var(--on-surface);
      padding: var(--gap-xs);
    }

    .overflow-menu {
      display: flex;
      flex-direction: column;
      gap: var(--gap-xs);
      list-style: none;
      min-width: 12rem;
    }

    .overflow-menu-header {
      border-bottom: 1px solid var(--border-neutral);
      color: var(--on-surface-variant);
      font-size: 0.65rem;
      font-weight: var(--font-semibold);
      letter-spacing: 0.05em;
      margin-bottom: var(--gap-xs);
      padding: var(--gap-xs) var(--gap-sm);
      text-transform: uppercase;
    }

    .overflow-menu-item {
      background: transparent;
      border: none;
      border-radius: var(--radius-sm);
      color: var(--on-surface);
      cursor: pointer;
      display: block;
      font-family: inherit;
      font-size: var(--text-sm);
      padding: var(--gap-sm) var(--gap-md);
      text-align: left;
      transition: background 0.2s, color 0.2s;
      width: 100%;
    }

    .overflow-menu-item:hover {
      background: var(--surface-container-high);
    }

    .overflow-menu-item.danger {
      color: var(--status-owed);
    }

    .overflow-menu-item.danger:hover {
      background: rgb(from var(--status-owed) r g b / 15%);
    }

    /* Cards */
    .grid {
      display: grid;

      .cols-1 {
        grid-template-columns: repeat(1, minmax(0, 1fr));
      }

      .cols-2 {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .center {
        place-items: center;
      }
    }

    .toggle-container,
    .basic-container {
      align-items: center;
      background: var(--surface-container-lowest);
      border: 1px solid var(--surface-variant);
      border-radius: var(--radius-sm);
      color: rgb(from var(--on-surface) r g b / 70%);
      display: flex;
      font-size: var(--text-xs);
      gap: var(--gap-sm);
      justify-content: flex-start;
      padding: 1rem;
      transition: background-color 0.2s, border-color 0.2s;

      &:has(input[type=\"date\"]:read-only) {
        background-color: transparent;
        border-color: transparent;
      }
    }

    .toggle-container {
      align-items: center;
      display: flex;
      justify-content: space-between;
    }

    .toggle {
      align-items: center;
      display: flex;
      justify-content: flex-start;
      position: relative;

      height: 1.25rem;
      padding-inline: 0.125rem;
      width: 2.25rem;

      background: var(--surface-variant);
      border: none;
      border-radius: var(--radius-full);
      cursor: pointer;
      transition: background 0.2s ease;

      /* State: When the internal checkbox is checked */
      &:has([role=\"switch\"]:checked) {
        background: var(--primary);
      }

      /* Accessibility: Focus ring */
      &:focus-within {
        outline: 2px solid var(--on-background);
        outline-offset: 2px;
      }
    }

    /* Hidden switch input - hit area */
    .toggle > [role=\"switch\"] {
      position: absolute;
      inset: 0;
      z-index: 50;
      opacity: 0;
      cursor: pointer;
      margin: 0;
    }

    /* Toggle circle */
    .toggle > [role=\"switch\"] ~ span {
      display: inline-block;
      height: 1rem;
      width: 1rem;

      background: var(--on-surface);
      border-radius: var(--radius-full);
      transition: transform 0.2s ease, background 0.2s ease;
      pointer-events: none;
    }

    /* Move toggle circle when checked */
    .toggle > [role=\"switch\"]:checked ~ span {
      background: var(--surface-container-lowest);
      transform: translateX(100%);
    }

    input[type=\"date\"].calendar-picker {
      background-color: transparent;
      border: none;
      border-radius: var(--radius-xs);
      color: rgb(from var(--on-surface) r g b / 70%);
      outline: none;
      width: 100%;

      appearance: none;
      -moz-appearance: textfield; /* Specific for Firefox */

      background-repeat: no-repeat;
      background-position: right var(--gap-sm) center;
      background-size: 0.875rem;

      &:not(:read-only) {
        cursor: pointer;
      }

      &:focus-visible {
        outline: 1px solid var(--on-background);
        outline-offset: 4px;
      }

      &::-webkit-calendar-picker-indicator {
        opacity: 0;
        cursor: pointer;
      }
    }

    .dialog-base {
      border: 1.5px solid var(--surface-container-high);
      box-shadow: rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 10px 15px -3px, rgba(0, 0, 0, 0.1) 0px 4px 6px -4px;
      background: var(--surface);
      border-radius: var(--radius-sm);
      color: var(--on-surface);
      display: flex;
      flex-direction: column;
      height: -webkit-fit-content;
      height: fit-content;
      max-height: min(90vh, 90dvh);
      margin: auto;
      position: relative;
      width: min(var(--dialog-max-width), 100%);
    }

    .dialog-close {
      background: var(--surface-variant-dark);
      border: none;
      border-radius: var(--radius-full);
      color: var(--on-surface-level-1);
      cursor: pointer;
      font-weight: var(--font-medium);
      font-size: var(--text-lg);
      height: 2.25rem;
      width: 2.25rem;

      &:hover {
        color: var(--on-surface);
        background: var(--surface-container-high);
      }
    }

    .dialog-header {
      align-items: center;
      background: var(--surface-container-low);
      border-bottom: 1px solid var(--level-2);
      display: flex;
      justify-content: space-between;
      padding: var(--gap-md) var(--gap-lg);

      & > h2 {
        color: white;
        font-family: var(--font-family);
        font-size: var(--text-xl);
        font-weight: var(--font-semibold);
        line-height: 1.2;
      }
    }

    .dialog-body {
      display: flex;
      flex-direction: column;
      gap: var(--gap-lg);
      padding: var(--gap-md);

      & label {
        color: var(--on-surface-level-1);
        font-weight: var(--font-normal);
      }
    }

    .dialog-actions {
      align-items: center;
      background: var(--surface-container-low);
      border-bottom: 1px solid var(--level-2);
      display: flex;
      gap: var(--gap-md);
      justify-content: flex-end;
      padding: var(--gap-md) var(--gap-lg);
    }

    .dialog-input {
      background: var(--surface-container-lowest);
      border: 1px solid var(--level-2);
      border-radius: var(--radius-sm);
      box-shadow: 1px 0 0 0 transparent;
      color: white;
      font-size: var(--text-sm);
      line-height: var(--text-sm--line-height);
      outline: none;
      padding: 0.625rem var(--gap-md);
      transition: background 0.2s, box-shadow 0.2s;

      &.price {
        padding-left: var(--gap-sm);
      }


      &:focus-visible {
        box-shadow: -2px 0 0 0 var(--primary);
      }
      &:hover {
        background: var(--level-1);
      }
    }

    input[type=\"date\"].dialog-input {
      appearance: none;
      -moz-appearance: textfield; /* Specific for Firefox */

      background-repeat: no-repeat;
      background-position: right var(--gap-sm) center;
      background-size: 0.875rem;

      padding-right: var(--gap-sm);

      &::-webkit-calendar-picker-indicator {
        opacity: 0;
        cursor: pointer;
      }
    }

    .monthly-payments-container {
      display: grid;
      gap: var(--gap-lg);
      grid-auto-rows: min-content;
      grid-template-columns: repeat(1, minmax(0, 1fr));

      @container (width > 45rem) {
        grid-template-columns: repeat(auto-fit, minmax(0, 1fr));
      }

      & > li {
        list-style: none;
      }
    }

    .month-card-container {
      background: none;
      border: none;
      color: inherit;
      cursor: pointer;
      display: block;
      margin: 0;
      padding: 0;
      width: 100%;
    }

    .month-card {
      display: block;
      background: var(--level-1);
      border: 1px solid var(--border-neutral);
      border-radius: var(--radius-md);
      color: inherit;
      padding: var(--gap-lg);
      padding-bottom: 3.5rem;
      position: relative;
      text-decoration: none;
      transition: all 0.2s;

      &:hover {
        border-color: var(--primary);
        cursor: pointer;
      }
    }

    .month-card-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 24px;
    }

    .arrow-icon {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: var(--surface-variant);
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .month-card:hover .arrow-icon {
      background: var(--primary);
      color: black;
    }

    .stat-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      border-bottom: 1px solid var(--border-neutral);
      padding-bottom: 8px;
      margin-bottom: 16px;
    }

    .quick-add-btn {
      position: absolute;
      bottom: 16px;
      right: 16px;
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border: 1px solid var(--border-subtle);
      background: var(--level-1);
      color: var(--on-surface-variant);
      cursor: pointer;
    }

    .quick-add-btn:hover {
      border-color: var(--primary);
      color: var(--primary);
    }

    /* Detail View Table */
    .table-container {
      background: var(--level-1);
      border: 1px solid var(--border-neutral);
      overflow: hidden;
    }

    .table-header {
      background: var(--level-1);
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--border-neutral);
      position: sticky;
      top: 0;
      z-index: 10;
    }

    .payment-row {
      display: grid;
      grid-template-columns: 100px 1fr 150px 100px 80px 100px 40px;
      gap: var(--gap-md);
      padding: var(--gap-md);
      border-bottom: 1px solid var(--border-neutral);
      align-items: center;
    }

    .payment-row:hover {
      background: var(--level-2);
    }

    .payment-cell-shared-total {
      color: var(--on-surface-level-1);
      font-size: var(--text-xs);
      line-height: var(--text-xs--line-height);
      position: absolute;
      right: var(--gap-md);
      top: var(--gap-sm);
    }

    .badge {
      font-size: 10px;
      font-weight: 600;
      text-transform: uppercase;
      border: 1px solid var(--border-subtle);
      padding: 0.125rem 0.5rem;
      color: var(--on-surface-variant);
    }

    .btn-status-paid { background: var(--primary); color: black; border: none; padding: 4px 8px; font-size: 10px; font-weight: 600; }
    .btn-status-owed { background: transparent; border: 1px solid var(--border-subtle); color: var(--on-surface-variant); padding: 4px 8px; font-size: 10px; font-weight: 600; }

    /* Footer */
    .vim-footer {
      align-items: center;
      background: var(--background);
      border-top: 1px solid var(--border-neutral);
      bottom: 0;
      display: flex;
      height: var(--vim-footer-height);
      left: 0;
      padding: 0 1rem;
      position: fixed;
      right: 0;
      z-index: 50;
    }

    .vim-hint {
      color: var(--on-surface-variant);
      font-size: 10px;
      letter-spacing: 0.1em;
      margin-right: 1rem;
      text-transform: uppercase;
    }

    /* Entry View Header */
    .view-header {
      align-items: center;
      background: var(--background);
      border-bottom: 1px solid var(--border-neutral);
      display: flex;
      height: var(--view-header-height);
      justify-content: space-between;
      left: 0;
      padding: 0 1.5rem;
      position: fixed;
      right: 0;
      top: 0;
      z-index: 40;
    }

    /* Views */
    .add-payment-view {
      background-color: var(--background);
      color: var(--on-background);
      container: add-payment / inline-size;
      display: flex;
      flex-direction: column;
      min-height: inherit;

      main {
        display: grid;
        grid-template-columns: minmax(0, 1fr);
        min-height: inherit;
        padding-block: var(--view-header-height) var(--vim-footer-height);
        place-content: center;
      }

      form {
        display: flex;
        flex-direction: column;
        gap: 2rem;

        max-width: var(--add-payment-view-max-width);
        min-width: auto;
        margin-inline: auto;
        padding: var(--gap-md);
        width: 100%;

        @container add-payment (width > 45rem) {
          width: max(45rem, 80cqi);
        }

        &>.form-layout {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 2rem;

          &>.payment-content {
            display: grid;
            grid-template-columns: minmax(0, 1fr);
            grid-template-rows: minmax(0, 1fr) auto;
            gap: var(--gap-lg);

            & > textarea {
              background: var(--surface-variant-dark);
              border: 1px solid rgb(from var(--surface-variant) r g b / 50%);
              border-radius: var(--radius-sm);
              color: var(--on-surface);
              outline: none;
              padding: var(--gap-sm);
              resize: none;

              &::placeholder {
                color: rgb(from var(--on-surface) r g b / 20%);
              }

              &:focus-visible {
                outline: 2px solid var(--on-background);
                outline-offset: 2px;
              }
            }
          }

          & button[type=\"submit\"] {
            display: grid;
            border-radius: var(--radius-sm);
            place-items: center;
          }
        }
      }
    }

    .payment-price {
      align-items: center;
      background: var(--surface-variant-dark);
      border: 1px solid rgb(from var(--surface-variant) r g b / 50%);
      border-radius: var(--radius-lg);
      display: flex;
      padding: 0 0 0 1rem;
      position: relative;
      width: 100%;

      &:has(input:focus-visible) {
        outline: 2px solid var(--on-background);
        outline-offset: 2px;
        z-index: 1;
      }

      &>.symbol {
        color: rgb(from var(--on-surface) r g b / 50%);
        font-size: var(--text-2xl);
        font-weight: var(--font-bold);
        line-height: var(--text-2xl--line-height);
        margin-right: 0.5rem;
      }

      &>input {
        display: block;
        background: transparent;
        border: none;
        border-radius: var(--radius-xs);
        color: var(--on-surface);
        outline: none;
        flex: 1;
        font-size: var(--text-4xl);
        min-width: 0;
        padding: 0;
        text-overflow: ellipsis;
        width: 0;

        &::placeholder {
          color: rgb(from var(--on-surface) r g b / 20%);
        }
      }

      &>.inc-dec {
        display: flex;
        flex-direction: column;
        flex-shrink: 0;
        border-left: 1px solid rgb(from var(--surface-variant) r g b / 50%);
        margin-left: 1rem;

        &>button {
          align-items: center;
          background: var(--surface-variant-dark);
          border: none;
          border-radius: var(--radius-sm);
          color: rgb(from var(--on-surface) r g b / 70%);
          cursor: pointer;
          display: flex;
          justify-content: center;
          padding: 0.5rem;

          &:hover {
            background: rgb(from var(--surface-variant) r g b / 50%);
            color: var(--primary);
          }

          &:focus-visible {
            outline: 2px solid var(--on-background);
            outline-offset: 2px;
            z-index: 1;
          }

          &.top {
            border-bottom: 1px solid rgb(from var(--surface-variant) r g b / 20%);
          }

          &:not(.top)>svg {
            transform: rotate(180deg);
          }
        }
      }
    }

    .summary-view {
      display: flex;
      flex-direction: column;
      min-height: inherit;
      width: 100%;

      main {
        container: summary-view / inline-size;
        display: grid;
        grid-template-columns: minmax(0, 1fr);
        margin: 0 auto;
        max-width: var(--summary-view-max-width);
        min-height: inherit;
        padding-block: calc(var(--view-header-height) + var(--gap-xl)) calc(var(--vim-footer-height) + var(--gap-xl));
        padding-inline: var(--gap-lg);
        width: 100%;
      }
    }

    .summary-empty {
      --icon-container-size: 10rem;
      align-items: center;
      display: flex;
      flex-direction: column;
      gap: var(--gap-xl);
      margin: auto;
      max-width: var(--summary-empty-max-width);
      padding-bottom: 4rem;

      & .icon-container {
        background-color: var(--surface-variant-dark);
        border-radius: var(--radius-xl);
        display: grid;
        height: var(--icon-container-size);
        place-items: center;
        width: var(--icon-container-size);

        & svg {
          height: 100%;
          padding: var(--gap-xl) var(--gap-md);
          width: 100%;
        }
      }
    }

    .detailed-month-view {
      display: flex;
      flex-direction: column;
      min-height: inherit;
      width: 100%;

      main {
        container: month-view / inline-size;
        display: flex;
        flex-direction: column;
        margin: 0 auto;
        min-height: inherit;
        padding-block: calc(var(--view-header-height) + var(--gap-xl)) calc(var(--vim-footer-height) + var(--gap-xl));
        padding-inline: var(--gap-lg);
        width: 100%;
      }
    }

    .detailed-month-heading {
      align-items: center;
      display: flex;
      justify-content: space-between;
      margin-bottom: var(--gap-xl);

      &:has(~.detailed-month--owed) {
        margin-bottom: var(--gap-sm);
      }
    }

    .detailed-month--owed {
      display: flex;
      justify-content: flex-end;
      margin-bottom: var(--gap-md);
      width: 100%;

      & > button {
        background: transparent;
        border: none;
        border-radius: var(--radius-xs);
        cursor: pointer;
        outline: none;
        padding: var(--gap-sm) var(--gap-sm);
        transition: background 0.2s;

        &:hover {
          background: rgba(255,255,255,0.05);
        }
      }
    }

    .detailed-month-table-container {
      background: var(--level-1);
      border: 1px solid var(--border-neutral);
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-lg);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    .detailed-summary-header {
      align-items: center;
      background: var(--surface-container-lowest);
      border-bottom: 1px solid var(--border-neutral);
      backdrop-filter: blur(12px);
      display: flex;
      justify-content: space-between;
      padding: var(--gap-sm) var(--gap-md);
      position: sticky;
      top: 0;
      z-index: 10;
    }

    .detailed-month-table-row {
      border-bottom: 1px solid var(--level-2);
      position: relative;
      transition: background 0.2s, color 0.2s;

      &:hover {
        background: var(--level-2);
      }

      td {
        padding: var(--gap-md);
        white-space: nowrap;

        & > .category-text {
          border: 1px solid var(--border-subtle);
          border-radius: var(--radius-sm);
          color: var(--on-surface-variant);
          padding: var(--gap-xs) var(--gap-sm);
        }

        .actions-btn {
          background: var(--level-1);
          border: none;
          border-radius: var(--radius-md);
          color: var(--on-surface);
          cursor: pointer;
          display: grid;
          padding: var(--gap-sm);
          place-items: center;
          transition: color 0.2s, background 0.2s;

          &:hover {
            background: var(--surface-variant-dark);
          }

          & > svg {
            height: 1.5rem;
            width: 1.5rem;
          }
        }
      }
    }

    .debug {
      background: black;
      border: 1px solid var(--on-background);
      border-radius: var(--radius-md);
      display: grid;
      gap: var(--gap-sm);
      margin-inline: auto;
      margin-top: var(--gap-xl);
      overflow-x: auto;

      max-width: var(--add-payment-view-max-width);
      min-width: auto;
      margin-inline: auto;
      padding: var(--gap-md);
      width: 100%;

      @container add-payment (width > 45rem) {
        width: max(45rem, 80cqi);
      }

      & > pre {
        white-space: pre-wrap;
      }
    }
    ",
  )
}
