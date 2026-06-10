//// IndexedDB implementation of the Storage interface.
////

import core/payment_tracker/user.{type User}
import core/storage.{type Command, type Response, LoadUser, SaveUser}
import gleam/json
import gleam/result
import gleam/string
import lustre/effect.{type Effect}

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
      do_save_user(db_name, user, to_msg, do_idb_save_user, dispatch)
    }
    LoadUser -> {
      use dispatch <- effect.from
      do_load_user(db_name, to_msg, do_idb_load_user, dispatch)
    }
  }
}

/// Internal logic for saving a user via IndexedDB, exposed for testing.
///
pub fn do_save_user(
  db_name: String,
  user: User,
  to_msg: fn(Response) -> msg,
  save: fn(String, String, fn(Result(Nil, String)) -> Nil) -> Nil,
  dispatch: fn(msg) -> Nil,
) -> Nil {
  let user_json = user.to_json(user) |> json.to_string
  save(db_name, user_json, fn(res) {
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
  load: fn(String, fn(Result(String, String)) -> Nil) -> Nil,
  dispatch: fn(msg) -> Nil,
) -> Nil {
  load(db_name, fn(res) {
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

@external(javascript, "../../ffi.mjs", "idb_load_user")
fn do_idb_load_user(
  db_name: String,
  callback: fn(Result(String, String)) -> Nil,
) -> Nil

@external(javascript, "../../ffi.mjs", "idb_save_user")
fn do_idb_save_user(
  db_name: String,
  user_json: String,
  callback: fn(Result(Nil, String)) -> Nil,
) -> Nil
