# Agent Instructions

## Overview
This project uses Gleam and Lustre to build a high-quality web component for tracking personal payments. We prioritize type safety, clean separation of logic from UI, and modern CSS. It balances ease of input (the Card) with high-level financial overview (the Timeline) and future-proof keyboard accessibility.

## Core Architecture
- **Language:** Gleam (compiled to JavaScript).
- **UI Framework:** Lustre (for declarative UI and Web Component wrapping).
- **Core Logic:** A standalone Gleam module (re-using types and logic from `old_src`).
- **Styling:** Vanilla CSS with modern features (dialogs, container queries, view transitions).

## Key Constraints
1. **Agent Skills & Planning:** Always follow the Agent Skills lifecycle. Never jump straight into writing code. You MUST engage in planning (e.g., `spec-driven-development`, `planning-and-task-breakdown`) before implementation.
2. **Test-Driven Development (TDD):** Tests MUST ALWAYS be written before implementing the corresponding code. Follow the `test-driven-development` skill strictly.
3. **No External CSS Frameworks:** Use Vanilla CSS with modern primitives.
4. **Pure Core:** Keep `src/core` free of UI concerns (no Lustre imports there).
5. **Stitch-Friendly:** When implementing features, follow the "Gemini Stitch" pattern—implement one logical slice at a time (Core -> UI -> Styles).
6. **Custom Element Wrapper:** Always ensure the component can be used via standard HTML attributes.
7. **Keyboard & VIM Awareness:** Always consider how a view would display VIM-like hints. UI components should have a "focused" state even if not using a mouse.
8. **Form Persistence:** The "Add Payment" form should NOT reset after submission to allow for rapid, repetitive entries.
9. **Storage (Sans-IO):** Implement storage logic using a standardized API following the sans-io pattern, allowing for swappable backends (Local Storage, SQLite, etc.).
10. **FFI:** Ensure Gleam/JS FFI is kept lean and is used as a last resort.
11. **Documentation:** Ensure each module and function accurately and succinctly describe the ideas and functionality in the correct Gleam format.
12. When completing a feature or task refer back to `ROADMAP.md` and check off the item if it appears and has been confirmed to be complete.

## Testing
 - Follow the hybrid testing strategy (Unit + Snapshot) documented in `docs/TESTING.md`. This includes the AI + Snapshot Workflow for managing `birdie` snapshots and ensuring determinism.

## Development
- **Gleam files:** When `.gleam` files are modified or features are complete, run `gleam format` from the root directory.
- **Feature Build:** When a feature is complete, ensure the project still builds correctly by running `gleam run -m lustre/dev build` from the project root.
- **Verification:** Always run `gleam test` to verify logic and structural snapshots before completion.

## Git Workflow & Commits
Follow the `git-workflow-and-versioning` skill for all git operations.

### Atomic Commits
- Make small, focused, and stable changes.
- Each commit should represent one logical change (e.g., a single bug fix, a new feature, or a refactor).
- Never commit work that breaks the build or fails tests.
- Separate refactors from features/fixes.

### Conventional Commits
- Use the Conventional Commits specification: `<type>[optional scope]: <description>`.
- Types:
  - `feat`: New feature
  - `fix`: Bug fix
  - `refactor`: Code change that neither fixes a bug nor adds a feature
  - `test`: Adding or updating tests
  - `docs`: Documentation only
  - `chore`: Tooling, dependencies, config
  - `style`: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- Use the **imperative mood** (e.g., "Add feature" instead of "Added feature").

### AI Attribution
- Any commit generated or significantly assisted by AI must include the following footer, replacing `[MODEL_NAME]` with the identifier of the active model being used:
  `Co-authored-by: Gemini <[MODEL_NAME]>`

### Semantic Versioning
- When completing a feature or task, analyze the changes and suggest the appropriate semantic version bump (Major, Minor, or Patch) based on the rules defined at [https://semver.org/](https://semver.org/):
  - **MAJOR** version when you make incompatible API changes,
  - **MINOR** version when you add functionality in a backward compatible manner, and
  - **PATCH** version when you make backward compatible bug fixes.
- Instruct the user to run `./scripts/sync_version.sh` after manually updating the version in `gleam.toml`, or offer to update `gleam.toml` and run the script for them.

## View Hierarchy & Navigation
1. **Entry Card (View A):**
   - A self-contained "Card" with a form for adding new payments.
   - Designed for quick, focused entry.
2. **Monthly Summary List (View B):**
   - A high-level list where each row shows: `Month Name` | `Total Paid` | `Total Owed`.
   - Clicking a row triggers a transition to the detailed view.
3. **Monthly Detail View (View C):**
   - A scrollable, chronological list of every payment for the selected month.
   - Includes toggles for status and "pre-emptive" payment calculations.

## Technical Goals (Modern CSS)
- **View Transitions API:** Seamless morphing between Card, Summary, and Detail views.
- **Scroll Snap / Overflow:** Precise control for the scrollable payment list.
- **Container Queries:** Ensuring the summary list adapts from 1 to 3 columns depending on available width.

## Reference Material
- `DESIGN.md`: The architectural blueprint.

## Project Structure
- `src/core/`: Pure Gleam logic (Types, Decoders, Calculations).
- `src/ui/`: Lustre views, state management, and component shell.
- `src/demo/`: Simple Vite based representation of how to use the web component.
- `src/payment_tracker_web_component.gleam`: Entry point for the web component registration.
