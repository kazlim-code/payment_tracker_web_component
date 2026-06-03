//// This module defines a "sans-io" interface for storage.
//// It provides pure types for storage commands and responses, allowing
//// the core logic to remain decoupled from specific I/O implementations.
////

import core/payment_tracker/user.{type User}

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
