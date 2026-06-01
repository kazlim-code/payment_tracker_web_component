# Project Roadmap & Backlog

This document tracks the current status of features, planned improvements, and technical debt for the Payment Tracker Web Component.

## 🚀 Features & Functionality

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
- [ ] **Standardized Storage API:** Implement a "sans-io" pattern to allow swappable storage backends.
- [ ] **Default Backend:** Local Storage (parity with previous projects).
- [ ] **Advanced Backends:** Flag-based opt-in for SQLite or other databases.

### 🧪 Testing
- [ ] **Prioritized Coverage:** Implement robust unit and integration tests.
- [ ] Recover/Adapt tests from the predecessor project.
- [ ] Add tests for core financial calculations and state transitions.

## 🛠 Technical Debt & Internal
- [ ] Update core payment and UI `.gleam` files with documentation for the modules and functions.
- [ ] Modularize UI components (UI functions in Gleam) for better maintainability.
- [ ] Refine Gleam/JS FFI where necessary for browser-specific APIs (View Transitions, Local Storage).
