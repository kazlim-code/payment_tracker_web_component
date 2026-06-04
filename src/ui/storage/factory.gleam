//// This module acts as a factory for storage backends.
//// It dispatches storage commands to the appropriate implementation
//// based on the provided `StorageConfig`.
////

import core/storage.{
  type Command, type Response, type StorageConfig, IndexedDB, LocalStorage,
  Remote, SQLite,
}
import lustre/effect.{type Effect}
import ui/storage/indexeddb as indexeddb_storage
import ui/storage/local as local_storage

/// Performs a storage command using the configured backend.
///
pub fn perform(
  config: StorageConfig,
  command: Command,
  to_msg: fn(Response) -> msg,
) -> Effect(msg) {
  case config {
    LocalStorage -> local_storage.perform(command, to_msg)
    IndexedDB(name) -> indexeddb_storage.perform(name, command, to_msg)
    // Placeholders for now, falling back to LocalStorage
    SQLite(_) -> local_storage.perform(command, to_msg)
    Remote(_, _, _) -> local_storage.perform(command, to_msg)
  }
}
