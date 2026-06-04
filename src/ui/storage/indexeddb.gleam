//// IndexedDB implementation of the Storage interface.
////

import core/payment_tracker/user.{type User}
import core/storage.{type Command, type Response, LoadUser, SaveUser}
import gleam/json
import gleam/result
import gleam/string
import lustre/effect.{type Effect}

const user_storage_key = "pt-user"

/// Performs a storage command using IndexedDB.
///
pub fn perform(
  db_name: String,
  command: Command,
  to_msg: fn(Response) -> msg,
) -> Effect(msg) {
  case command {
    SaveUser(user) -> {
      use dispatch <- effect.from
      do_save_user(db_name, user, to_msg, do_idb_set, dispatch)
    }
    LoadUser -> {
      use dispatch <- effect.from
      do_load_user(db_name, to_msg, do_idb_get, dispatch)
    }
  }
}

/// Internal logic for saving a user via IndexedDB, exposed for testing.
///
pub fn do_save_user(
  db_name: String,
  user: User,
  to_msg: fn(Response) -> msg,
  set: fn(String, String, String, fn(Result(Nil, String)) -> Nil) -> Nil,
  dispatch: fn(msg) -> Nil,
) -> Nil {
  let user_json = user.to_json(user) |> json.to_string
  set(db_name, user_storage_key, user_json, fn(res) {
    res
    |> result.map_error(storage.StorageError)
    |> storage.UserSaved
    |> to_msg
    |> dispatch
  })
}

/// Internal logic for loading a user via IndexedDB, exposed for testing.
///
pub fn do_load_user(
  db_name: String,
  to_msg: fn(Response) -> msg,
  get: fn(String, String, fn(Result(String, String)) -> Nil) -> Nil,
  dispatch: fn(msg) -> Nil,
) -> Nil {
  get(db_name, user_storage_key, fn(res) {
    let response = {
      use json_string <- result.try(
        res
        |> result.map_error(fn(err) {
          case err == "NOT_FOUND" {
            True -> storage.NotFound
            False -> storage.StorageError(err)
          }
        }),
      )
      user.from_json_string(json_string)
      |> result.map_error(fn(err) { storage.DecodeError(string.inspect(err)) })
    }
    response
    |> storage.UserLoaded
    |> to_msg
    |> dispatch
  })
}

@external(javascript, "../../ffi.mjs", "idb_get")
fn do_idb_get(
  db_name: String,
  key: String,
  callback: fn(Result(String, String)) -> Nil,
) -> Nil

@external(javascript, "../../ffi.mjs", "idb_set")
fn do_idb_set(
  db_name: String,
  key: String,
  value: String,
  callback: fn(Result(Nil, String)) -> Nil,
) -> Nil
