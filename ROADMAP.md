# Project Roadmap & Backlog

This document tracks the current status of features, planned improvements, and technical debt for the Payment Tracker Web Component.

## 🦋 Bugs & Fixes
- [x] Dialog height css issue in Safari browser (height appears close to 0 whereas Chrome browser shows correct sizing around the minimum heights of the internal elements)
- [x] Hovering each row of the monthly detail table lightens all the td cells, not the tr (visually has breaks between each cell)

## 🚀 Features & Functionality

### 🚦 Demo
- [ ] Update /demo project to include indexeddb run option

### ℹ️ Version Control
- [x] Add incremental/semantic versioning based on industry standards
- [x] Show version number in the Footer UI where appropriate (replace dummy code)

### ⌨️ Keyboard Navigation (Vim-like)
- [ ] Implement Vim-like keyboard shortcuts (`j`, `k`, `i`, `/`, `esc`).
- [ ] Add visual focus states for keyboard navigation.
- [ ] *Status: Currently hidden in UI until implementation starts.*

### 📝 Form Polish & UX
- [x] **Rapid Entry:** The "Add Payment" form does NOT reset after submission to facilitate adding multiple similar payments.
- [ ] **Submission Feedback:** Research and implement user feedback (e.g., toast, animation, or status indicator) for successful payment additions.

### 🔎 Sorting & Filtering
- [ ] Sort Month detail view table by column (Asc/Desc) for applicable columns
- [ ] Filter Month detail view table by name via search input

### 🔄 View Transitions & Modern CSS
- [ ] Implement the **View Transitions API** for seamless navigation between views.
- [ ] **Hero Transition:** Transition the "Add Payment" input box to the header/center when switching to the Monthly Summary view, and back.
- [ ] Explore further use of modern CSS (Container Queries, Scroll Snap).

### 💾 Storage Architecture
- [x] **Standardized Storage API:** Implement a "sans-io" pattern to allow swappable backends.
- [x] **Default Backend:** Local Storage (parity with previous projects).
- [x] **Advanced Backends:** Flag-based opt-in for IndexedDB and extensible architecture for SQLite/Remote.
- [ ] **SQLite Wasm:** Full implementation of SQLite Wasm backend.


### 🧪 Testing
- [x] **Prioritized Coverage:** Implement robust unit and integration tests.
- [x] Recover/Adapt tests from the predecessor project.
- [x] Add tests for core financial calculations and state transitions.

## 🛠 Technical Debt & Internal
- [x] Update core payment and UI `.gleam` files with documentation for the modules and functions.
- [ ] ** Storage:** Ensure that the storage input to the application is being decoded with the latest gleam stdlib patterns
- [ ] Modularize UI components (UI functions in Gleam) for better maintainability.
- [ ] Refine Gleam/JS FFI where necessary for browser-specific APIs (View Transitions, Local Storage).
