//// Local storage implementation of the Storage interface.
////

import core/payment_tracker/user.{type User}
import core/storage.{type Command, type Response, LoadUser, SaveUser}
import gleam/json
import gleam/result
import lustre/effect.{type Effect}

import gleam/string

const user_storage_key = "pt-user"

/// Performs a storage command using the browser's local storage.
///
pub fn perform(command: Command, to_msg: fn(Response) -> msg) -> Effect(msg) {
  case command {
    SaveUser(user) -> {
      use dispatch <- effect.from
      dispatch(do_save_user(user, to_msg, do_write))
    }
    LoadUser -> {
      use dispatch <- effect.from
      dispatch(do_load_user(to_msg, do_read))
    }
  }
}

/// Internal logic for saving a user, exposed for testing.
///
pub fn do_save_user(
  user: User,
  to_msg: fn(Response) -> msg,
  write: fn(String, String) -> Result(Nil, String),
) -> msg {
  let user_json = user.to_json(user) |> json.to_string
  let result =
    write(user_storage_key, user_json)
    |> result.map_error(storage.StorageError)

  to_msg(storage.UserSaved(result))
}

/// Internal logic for loading a user, exposed for testing.
///
pub fn do_load_user(
  to_msg: fn(Response) -> msg,
  read: fn(String) -> Result(String, Nil),
) -> msg {
  let result = {
    use json_string <- result.try(
      read(user_storage_key)
      |> result.map_error(fn(_) { storage.NotFound }),
    )
    user.from_json_string(json_string)
    |> result.map_error(fn(err) { storage.DecodeError(string.inspect(err)) })
  }

  to_msg(storage.UserLoaded(result))
}

@external(javascript, "../../ffi.mjs", "read")
fn do_read(key: String) -> Result(String, Nil)

@external(javascript, "../../ffi.mjs", "write")
fn do_write(key: String, value: String) -> Result(Nil, String)
