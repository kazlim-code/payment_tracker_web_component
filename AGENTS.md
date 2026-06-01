# Agent Instructions

## Overview
This project uses Gleam and Lustre to build a high-quality web component for tracking personal payments. We prioritize type safety, clean separation of logic from UI, and modern CSS. It balances ease of input (the Card) with high-level financial overview (the Timeline) and future-proof keyboard accessibility.

## Core Architecture
- **Language:** Gleam (compiled to JavaScript).
- **UI Framework:** Lustre (for declarative UI and Web Component wrapping).
- **Core Logic:** A standalone Gleam module (re-using types and logic from `old_src`).
- **Styling:** Vanilla CSS with modern features (dialogs, container queries, view transitions).

## Key Constraints
1. **No External CSS Frameworks:** Use Vanilla CSS with modern primitives.
2. **Pure Core:** Keep `src/core` free of UI concerns (no Lustre imports there).
3. **Stitch-Friendly:** When implementing features, follow the "Gemini Stitch" pattern—implement one logical slice at a time (Core -> UI -> Styles).
4. **Custom Element Wrapper:** Always ensure the component can be used via standard HTML attributes.
5. **Keyboard & VIM Awareness:** Always consider how a view would display VIM-like hints. UI components should have a "focused" state even if not using a mouse.
6. **Form Persistence:** The "Add Payment" form should NOT reset after submission to allow for rapid, repetitive entries.
7. **Storage (Sans-IO):** Implement storage logic using a standardized API following the sans-io pattern, allowing for swappable backends (Local Storage, SQLite, etc.).

## AI + Snapshot Workflow Strategy (Birdie)
We use `birdie` for snapshot testing of complex structures (JSON, large strings).
1. **Creation:** When implementing new behavior, the AI writes a `birdie.snap` test.
2. **Review:** The AI presents the "New Snapshot" output to the user in the chat.
3. **Approval:** The user manually runs `gleam run -m birdie` to accept/reject changes.
4. **Non-Determinism (CRITICAL):** Snapshots MUST ONLY contain deterministic values. Brittle tests cause "snapshot fatigue" and erode trust. 
   - **UUIDs:** Use fixed strings (e.g., `"test-uuid-1"`) instead of random generators.
   - **Dates/Timestamps:** Use fixed ISO strings or specific mock dates instead of `now()`.
   - **Random/Incrementing Values:** Ensure any IDs, counters, or hashes are reset or hardcoded in the test setup.
   - **Environmental Data:** Avoid snapshots that depend on the local timezone, file paths, or OS-specific line endings.
8. ** FFI:** Ensure Gleam/JS FFI is kept lean and is used as a last resort.
9. ** Documentation:** Ensure each module and function accurately and succinctly describe the ideas and functionality in the correct Gleam format.
10. ** Testing:** Provide unit testing and integration tests based on best Gleam/Lustre practices

<development>
- ** Gleam files:** When `.gleam` files are modified or features are complete, run `gleam format` from the root directory.
- ** Feature:** When a feature is complete that contains modified or key gleam files then ensure that the project still builds correctly by running `gleam run -m lustre/dev build` from the project root and check for build issues.
</development>

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
