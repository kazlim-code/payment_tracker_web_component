//// This module defines a "sans-io" interface for storage.
//// It provides pure types for storage commands and responses, allowing
//// the core logic to remain decoupled from specific I/O implementations.
////

import core/payment_tracker/user.{type User}
import gleam/option.{type Option}

/// Represents a command to perform a storage operation.
///
pub type Command {
  /// Save the user data to storage.
  SaveUser(User)
  /// Load the user data from storage.
  LoadUser
}

/// Represents the result of a storage operation.
///
pub type Response {
  /// The result of a LoadUser command.
  UserLoaded(Result(User, Error))
  /// The result of a SaveUser command.
  UserSaved(Result(Nil, Error))
}

/// Possible errors that can occur during storage operations.
///
pub type Error {
  /// An error occurred while reading from or writing to the storage medium.
  StorageError(String)
  /// The data retrieved from storage could not be decoded into the expected type.
  DecodeError(String)
  /// No data was found in storage for the requested key.
  NotFound
}

/// Authentication configuration for a remote storage backend.
///
pub type RemoteAuth {
  /// No authentication required.
  NoAuth
  /// Authenticate using a bearer token or API key.
  TokenAuth(token: String)
  /// Authenticate using a username and password.
  BasicAuth(username: String, password: String)
}

/// Configuration for the storage backend.
///
pub type StorageConfig {
  /// Use the browser's local storage.
  LocalStorage
  /// Use the browser's IndexedDB.
  IndexedDB(name: String)
  /// Use SQLite (via Wasm).
  SQLite(name: String)
  /// Use a remote API or database.
  Remote(endpoint: String, database: Option(String), auth: RemoteAuth)
}
