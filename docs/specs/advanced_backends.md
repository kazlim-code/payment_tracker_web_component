# Spec: Advanced Backends (Storage Architecture)

## Objective
Implement a robust, swappable storage architecture for the Payment Tracker Web Component. This architecture will support LocalStorage (default), IndexedDB, and SQLite (via Wasm). It must provide a secure way to pass configuration details, including sensitive credentials for future remote backends.

## Tech Stack
- **Language:** Gleam (compiled to JS)
- **UI Framework:** Lustre (Web Components)
- **Storage Strategy:** Sans-IO (Core defines commands/responses, UI layer handles I/O)
- **Backends:**
    - `LocalStorage`: Current default.
    - `IndexedDB`: Robust local transactional storage.
    - `SQLite`: SQL-based local storage (future Wasm implementation).
    - `Remote`: Placeholder for API-based storage with credential support.

## Configuration & Security
To handle sensitive data (like DB credentials), we will support two configuration paths:
1. **Attributes (Non-sensitive):** Simple flags like `storage-backend="indexeddb"` or `db-name="my-tracker"`.
2. **Init Flags / JS Properties (Sensitive):** For sensitive data, the component will accept a configuration object via Lustre's `init` flags or a dedicated JS property. This avoids exposing secrets in the DOM.

### Configuration Object Shape (JS)
```javascript
{
  backend: "remote",
  config: {
    endpoint: "https://api.example.com",
    apiKey: "secret-token-123"
  }
}
```

## Project Structure
- `src/core/storage.gleam`:
    - `type StorageConfig { LocalStorage, IndexedDB(name: String), SQLite(name: String), Remote(endpoint: String, api_key: String, db_name: String) }`
- `src/ui/storage/`:
    - `indexeddb.gleam`: New robust IndexedDB backend.
    - `sqlite.gleam`: Placeholder for SQLite Wasm logic.
    - `factory.gleam`: Logic to select and initialize the backend based on `StorageConfig`.
- `src/payment_tracker_web_component.gleam`: Updated `init` to parse flags and attributes into `StorageConfig`.

## Code Style (Backend Factory)
```gleam
pub fn perform(config: StorageConfig) -> fn(Command, fn(Response) -> msg) -> Effect(msg) {
  case config {
    LocalStorage -> local_storage.perform
    IndexedDB(name) -> indexeddb_storage.init(name) |> indexeddb_storage.perform
    SQLite(name) -> sqlite_storage.init(name) |> sqlite_storage.perform
    Remote(endpoint, api_key, db_name) -> 
      remote_storage.init(endpoint, api_key, db_name) 
      |> remote_storage.perform
  }
}
```

## Boundaries
- **Always do:** Default to `LocalStorage` if initialization of an advanced backend fails.
- **Ask first:** Before pulling in large SQLite Wasm binaries.
- **Never do:** Print or log any values from the `settings` map if they might contain sensitive data.

## Success Criteria
- [ ] Swappable backend architecture implemented.
- [ ] IndexedDB backend functional and selectable via attribute.
- [ ] Mechanism for passing complex/sensitive config via JS properties/flags exists.
- [ ] Architecture supports future SQLite Wasm integration without core changes.
