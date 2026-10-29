# Project Roadmap & Backlog

This document tracks the current status of features, planned improvements, and technical debt for the Payment Tracker Web Component.

## 🦋 Bugs & Fixes
- [x] Dialog height css issue in Safari browser (height appears close to 0 whereas Chrome browser shows correct sizing around the minimum heights of the internal elements)
- [x] Hovering each row of the monthly detail table lightens all the td cells, not the tr (visually has breaks between each cell)
- [x] Ensure correct order is kept for months appearing in Summary View
- [x] Pressing "Enter" in PriceInput field seems to reset the value. I would like it to confirm the value and leave Insert mode (return to Normal mode)
- [x] Update Footer hints to include all "hjkl" keys for navigation and "i" key for entering insert mode on inputs
- [x] Update Footer hints to include "Enter" key for confirming/returning to normal mode on input elements when in Insert mode

## 🚀 Features & Functionality

### 🚦 Demo
- [x] Update /demo project to include indexeddb run option (via `?storage=indexeddb` URL param)

### ℹ️ Version Control
- [x] Add incremental/semantic versioning based on industry standards
- [x] Show version number in the Footer UI where appropriate (replace dummy code)

### Development
- [x] Look into updating `dev.gleam` to hook into query params much identical in behaviour to how demo works but within gleam code.
- [x] Update debug devtools_panel section in view.gleam to be absolutely placed
- [x] Show debug devtools_panel based only when run via dev.gleam 
- [x] Add show/hide button for debug devtools_panel when run via dev.gleam

### ⌨️ Keyboard Navigation (Vim-like)
- [x] Implement Vim-like keyboard shortcuts (`cp`, `cd`, `p`, `d`, `s`, `t`, `[]`, `{}`, `j`, `k`, `/`, `gp`, `gs`, `gm`, `esc`, `<CR>`, `<C-Enter>`, `<S-Enter>`).
- [x] Add visual mode indicators (`-- NORMAL --`, `-- INSERT --`, `-- PENDING --`) in bottom status bar.
- [x] Add visual focus states for keyboard navigation.
- [ ] **GUI Keymap Editor:** Settings modal/view to customize and persist user keybindings.
- [ ] **Dynamic Bottom Bar:** Context-aware key hints depending on focused input, with global action overlay.
- [ ] **Keymap Cheatsheet Modal:** Triggered by `?` showing all available motions.
- [ ] **Advanced Mode Badge Animations:** Rich CSS transition/animation when switching between Normal and Insert modes.

### 📝 Form Polish & UX
- [x] **Rapid Entry:** The "Add Payment" form does NOT reset after submission to facilitate adding multiple similar payments.
- [x] **Submission Feedback:** Research and implement user feedback (e.g., toast, animation, or status indicator) for successful payment additions.

### 🔎 Sorting & Filtering
- [x] Sort Month detail view table by column (Asc/Desc) for applicable columns
- [x] Filter Month detail view table by name via search input

### 🔄 View Transitions & Modern CSS
- [x] Update hex code colours to oklab hsla or whatever modern practices are used.
- [x] Implement the **View Transitions API** for seamless navigation between views.
- [ ] **Hero Transition:** Transition the "Add Payment" input box to the header/center when switching to the Monthly Summary view, and back.
- [ ] **Scoped View Transitions (Level 2 Future-Proofing):** Migrate from `document.startViewTransition()` to `element.startViewTransition()` / `shadowRoot.startViewTransition()` once baseline browser support is established. Encapsulate `@keyframes` and `view-transition-name` rules entirely within `styles.gleam` (Shadow DOM), removing global Light DOM CSS injection from `ffi.mjs` and `part="content"` attributes from views.
- [ ] Explore further use of modern CSS (Container Queries, Scroll Snap).

### 💾 Storage Architecture
- [x] **Standardized Storage API:** Implement a "sans-io" pattern to allow swappable backends.
- [x] **Default Backend:** Local Storage (parity with previous projects).
- [x] **Advanced Backends:** Flag-based opt-in for IndexedDB and extensible architecture for SQLite/Remote.
- [x] **IndexedDB Refactor:** Transition IndexedDB from a simple key-value blob store to a structured, domain-driven database (separate object stores for users and payments) to establish relational parity for the upcoming SQLite backend.
- [ ] **SQLite Wasm:** Full implementation of SQLite Wasm backend.

### 🧪 Testing
- [x] **Prioritized Coverage:** Implement robust unit and integration tests.
- [x] Recover/Adapt tests from the predecessor project.
- [x] Add tests for core financial calculations and state transitions.
- [x] Explore to see if ffi functions can be unit tested?


## 🛠 Technical Debt & Internal
- [x] Update core payment and UI `.gleam` files with documentation for the modules and functions.
- [x] ** Storage:** Ensure that the storage input to the application is being decoded with the latest gleam stdlib patterns
- [ ] Modularize UI components (UI functions in Gleam) for better maintainability.
- [ ] Refine Gleam/JS FFI where necessary for browser-specific APIs (View Transitions, Local Storage).
