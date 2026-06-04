# Plan: Advanced Backends Implementation

## 1. Major Components & Dependencies
- **Core Types (`src/core/storage.gleam`):** Defining the `StorageConfig` variant.
- **Storage Factory (`src/ui/storage/factory.gleam`):** The dispatcher that connects commands to the correct backend implementation.
- **IndexedDB Backend (`src/ui/storage/indexeddb.gleam`):** The first advanced backend implementation using browser APIs.
- **Component Entry (`src/payment_tracker_web_component.gleam`):** Refactoring `init` and `update` to use the factory and parse configuration from attributes/flags.

## 2. Implementation Order (Sequential)
1. **Refactor Core Types:** Update `src/core/storage.gleam` with the new `StorageConfig` type.
2. **Implement Factory:** Create `src/ui/storage/factory.gleam` and update the `Model` to hold the current `StorageConfig`.
3. **Refactor `update` and `init`:** Update `src/payment_tracker_web_component.gleam` to use the factory for all storage effects.
4. **Implement IndexedDB Backend:** Create the `indexeddb.gleam` module and associated FFI in `ffi.mjs`.
5. **Config Parsing:** Implement the logic to parse custom element attributes and Lustre flags into the `StorageConfig`.

## 3. Risks & Mitigation
- **Risk:** `StorageConfig` parsing errors from string attributes.
- **Mitigation:** Robust default to `LocalStorage` and clear error logging in the console for invalid configurations.
- **Risk:** IndexedDB async nature vs Lustre effects.
- **Mitigation:** Use `effect.from` to handle the asynchronous callback-based IndexedDB API correctly.

## 4. Verification Checkpoints
- **Checkpoint 1:** Project compiles after core type refactor.
- **Checkpoint 2:** LocalStorage still works correctly using the new factory pattern.
- **Checkpoint 3:** Unit tests confirm that the factory dispatches to the correct backend based on config.
- **Checkpoint 4:** Manual verification: setting `storage-backend="indexeddb"` in `demo/index.html` successfully persists data in IndexedDB (visible in DevTools Application tab).
