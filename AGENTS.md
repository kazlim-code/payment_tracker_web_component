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
- `src/payment_tracker_web_component.gleam`: Entry point for the web component registration.
