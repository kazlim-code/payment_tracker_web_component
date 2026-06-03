# Testing Strategy

This project uses a **Hybrid Approach** to testing, leveraging both Unit Tests (via `gleeunit`) and Snapshot Tests (via `birdie`). 

The core philosophy is:
*   **Unit Tests** prove the system *thinks* correctly (Logic & Behavior).
*   **Snapshot Tests** prove the system *speaks* correctly (Output & Structure).

## 1. Unit Testing (The "Logic" Guard)

**Use when:** You are verifying a specific behavioral rule, calculation, or state transition.

Unit testing is the primary tool for verifying business logic. It forces the developer to declare explicit intent.

### Standard Assertion Pattern
We use Gleam's built-in **`assert`** and **`let assert`** keywords. The `gleeunit/should` module is deprecated.

*   **Logic & Equality:** Use `assert expression == expected`. This provides superior failure reporting, showing exact values and code context.
*   **Custom Messages:** Use `as` for clarity: `assert condition as "Context description"`.
*   **Pattern Matching:** Use `let assert Ok(val) = result` to unwrap and assert structure.

### When to use Unit Tests:
*   **Financial Calculations:** Ensuring that splits, transfers, and totals sum up perfectly (e.g., `monthly_payment.calculate_owed`).
*   **State Machines / Reducers:** Verifying that a specific action results in a specific state change (e.g., `UserToggledShared` flips a boolean).
*   **Edge Cases & Error Handling:** Proving that invalid input is caught and handled appropriately.

### Naming Conventions

To ensure the test suite remains searchable and its output readable, follow this strict naming pattern:

1.  **Happy Path:** `[function_name]_test`
    *   *Example:* `calculate_owed_test`
2.  **Edge Cases & Variations:** `[function_name]_[scenario_description]_test`
    *   *Example:* `calculate_owed_with_negative_total_test`, `calculate_owed_missing_home_loan_test`

### Coverage Requirement: The "Rule of Three"

For every logic-bearing function being unit tested:
*   **Must include 1 Happy Path test.**
*   **Must include at least 2 Edge Case tests** (where applicable).

This ensures that we aren't just testing that the code *can* work, but that we've explored the boundaries of how it might *fail* or handle unusual state.

## 2. Snapshot Testing (The "Structure" Guard)

**Use when:** You are verifying large, complex, or semi-structured outputs where manual assertions would be brittle, tedious, and hard to read.

Snapshot testing excels at catching *accidental* structural regressions in complex data shapes.

### When to use Snapshot Tests:
*   **JSON Serialization/Deserialization:** Asserting that the entire data model correctly maps to JSON without writing hundreds of individual assertions.
*   **UI Components & Formatting:** Ensuring that formatted strings (e.g., `10.5` -> `"10.50"`) or large text representations of data stay perfectly aligned.
*   **Sorting & Filtering Outputs:** Validating that lists are ordered or filtered correctly by glancing at the structural output.
*   *(Future)* **Lustre HTML Rendering:** Snapshotting the raw string output of Lustre components to ensure DOM structures and CSS classes remain intact.

### ⚠️ Critical Rule: Non-Determinism
Snapshots **MUST ONLY** contain deterministic values. Brittle tests cause "snapshot fatigue" and erode trust in the test suite. 

When writing setup code for snapshot tests:
*   **UUIDs:** Do not use random generators. Use fixed strings (e.g., `"fixed-uuid-1234"`).
*   **Dates/Timestamps:** Do not use `now()`. Use fixed ISO strings or specific mock dates.
*   **Counters/Hashes:** Ensure any incrementing IDs are hardcoded.
*   **Environmental Data:** Do not rely on local timezones or OS-specific details.

## 3. The AI + Snapshot Workflow

When AI agents are contributing to this codebase, they must follow this human-in-the-loop workflow for snapshots:

1.  **Creation:** When implementing new structural behavior, the AI writes a `birdie.snap` test (ensuring determinism).
2.  **Review:** The AI runs the test, which will fail on the first run, and presents the "New Snapshot" output to the user in the chat interface.
3.  **Approval:** The human user reviews the output. If it is correct, the human manually runs `gleam run -m birdie` in their terminal and accepts the snapshot.
4.  **Regression:** On future runs, if a snapshot fails, the AI must determine if the change was intended. If unintended, the AI fixes the code. If intended, the AI presents the diff to the human for approval.

## 4. Test Organization

As the test suite grows, keep files logically organized.

*   `test/*_test.gleam`: Unit tests for specific modules.
*   `test/snapshots_test.gleam`: Contains all snapshot tests, strictly organized into logical sections using comment headers:
    ```gleam
    // --- HELPERS ---
    // --- SERIALIZATION ---
    // --- UI UTILITIES ---
    ```
