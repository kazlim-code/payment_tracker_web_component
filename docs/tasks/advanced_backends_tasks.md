# Tasks: Advanced Backends Implementation

- [x] **Task 1: Refactor Core Storage Types**
  - **Acceptance:** `RemoteAuth` type and `StorageConfig` type added to `src/core/storage.gleam`. `StorageConfig` includes variants: `LocalStorage`, `IndexedDB(name: String)`, `SQLite(name: String)`, and `Remote(endpoint: String, database: Option(String), auth: RemoteAuth)`.
  - **Verify:** `gleam build` passes.
  - **Files:** `src/core/storage.gleam`

- [x] **Task 2: Implement Storage Factory**
  - **Acceptance:** `src/ui/storage/factory.gleam` created with a `perform` function that dispatches `Command`s to the correct backend. Initially, all variants except `LocalStorage` can be placeholders or fallback to `LocalStorage`.
  - **Verify:** `gleam build` passes.
  - **Files:** `src/ui/storage/factory.gleam`

- [x] **Task 3: Update State Model**
  - **Acceptance:** `Model` in `src/ui/state.gleam` includes a `storage_config: StorageConfig` field. `init` and `init_with_example_payments` updated to accept/set a default.
  - **Verify:** `gleam build` passes.
  - **Files:** `src/ui/state.gleam`

- [x] **Task 4: Integrate Factory into Web Component**
  - **Acceptance:** `src/payment_tracker_web_component.gleam` updated to use `factory.perform` for all storage operations. `save_user_effect` updated to use `model.storage_config`.
  - **Verify:** `gleam build` and existing tests pass. Manual check confirms LocalStorage still works.
  - **Files:** `src/payment_tracker_web_component.gleam`

- [x] **Task 5: Implement IndexedDB Backend (TDD)**
  - **Acceptance:** `src/ui/storage/indexeddb.gleam` implemented using the same "Sans-IO" pattern as `local.gleam` for testability. Unit tests added to verify logic. JS FFI in `src/ffi.mjs` updated with `indexedDB` logic.
  - **Verify:** `gleam test` passes. Manual check in browser confirms data persists in IndexedDB.
  - **Files:** `src/ui/storage/indexeddb.gleam`, `src/ffi.mjs`, `test/storage_test.gleam`

- [x] **Task 6: Implement Attribute and Flag Parsing**
  - **Acceptance:** `init` in `src/payment_tracker_web_component.gleam` parses the `storage-backend` attribute from the custom element and any initialization flags into a `StorageConfig`.
  - **Verify:** Setting `storage-backend="indexeddb"` on the `<payment-tracker>` element correctly initializes the IndexedDB backend.
  - **Files:** `src/payment_tracker_web_component.gleam`

- [x] **Task 7: Finalize Documentation and Roadmap**
  - **Acceptance:** `ROADMAP.md` updated to reflect the completed architectural change and IndexedDB support. `README.md` and `demo/README.md` updated with instructions on how to use IndexedDB via attributes.
  - **Verify:** Documentation reflects IndexedDB usage.
  - **Files:** `ROADMAP.md`, `README.md`, `demo/README.md`
