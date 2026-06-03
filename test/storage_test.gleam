import core/payment_tracker/user
import core/storage.{DecodeError, NotFound}
import gleeunit/should
import ui/storage/local

pub fn load_user_not_found_test() {
  let read = fn(_key) { Error(Nil) }

  local.do_load_user(fn(x) { x }, read)
  |> should.equal(storage.UserLoaded(Error(NotFound)))
}

pub fn save_user_test() {
  let test_user = user.new("Test", "testuser")
  let write = fn(_key, _val) { Ok(Nil) }

  local.do_save_user(test_user, fn(x) { x }, write)
  |> should.equal(storage.UserSaved(Ok(Nil)))
}

pub fn load_user_test() {
  let test_user = user.new("Test", "testuser")
  // Note: user.to_json(test_user) |> json.to_string would be better but this is fixed for stability
  let user_json =
    "{\"created\":\"2026-06-03T00:00:00Z\",\"first_name\":\"Test\",\"last_name\":null,\"payments\":[],\"monthly_payments\":[],\"username\":\"testuser\"}"
  let read = fn(_key) { Ok(user_json) }

  case local.do_load_user(fn(x) { x }, read) {
    storage.UserLoaded(Ok(loaded_user)) -> {
      should.equal(loaded_user.username, test_user.username)
      should.equal(loaded_user.first_name, test_user.first_name)
    }
    _ -> panic as "Expected UserLoaded(Ok(user))"
  }
}

pub fn load_user_malformed_json_test() {
  let read = fn(_key) { Ok("not json") }

  case local.do_load_user(fn(x) { x }, read) {
    storage.UserLoaded(Error(DecodeError(_))) -> Nil
    _ -> panic as "Expected DecodeError"
  }
}

pub fn load_user_invalid_structure_test() {
  let read = fn(_key) { Ok("{\"wrong\":\"structure\"}") }

  case local.do_load_user(fn(x) { x }, read) {
    storage.UserLoaded(Error(DecodeError(_))) -> Nil
    _ -> panic as "Expected DecodeError for invalid structure"
  }
}

pub fn save_user_quota_exceeded_test() {
  let test_user = user.new("Test", "testuser")
  let write = fn(_key, _val) { Error("QuotaExceededError") }

  local.do_save_user(test_user, fn(x) { x }, write)
  |> should.equal(
    storage.UserSaved(Error(storage.StorageError("QuotaExceededError"))),
  )
}
