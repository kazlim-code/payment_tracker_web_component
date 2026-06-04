import core/payment_tracker/user
import core/storage.{NotFound, UserLoaded, UserSaved}
import ui/storage/indexeddb
import ui/storage/local

// --- LOCAL STORAGE ---

pub fn do_load_user_not_found_test() {
  let read = fn(_key) { Error(Nil) }

  let result = local.do_load_user(fn(x) { x }, read)
  assert result == UserLoaded(Error(NotFound))
}

pub fn do_save_user_test() {
  let test_user = user.new("Test", "testuser")
  let write = fn(_key, _val) { Ok(Nil) }

  let result = local.do_save_user(test_user, fn(x) { x }, write)
  assert result == UserSaved(Ok(Nil))
}

pub fn do_load_user_test() {
  let test_user = user.new("Test", "testuser")
  let user_json =
    "{\"created\":\"2026-06-03T00:00:00Z\",\"first_name\":\"Test\",\"last_name\":null,\"payments\":[],\"monthly_payments\":[],\"username\":\"testuser\"}"
  let read = fn(_key) { Ok(user_json) }

  let result = local.do_load_user(fn(x) { x }, read)
  let assert UserLoaded(Ok(loaded_user)) = result
  assert loaded_user.username == test_user.username
  assert loaded_user.first_name == test_user.first_name
}

// --- INDEXEDDB ---

pub fn do_load_user_indexeddb_not_found_test() {
  let read = fn(_db, _key, callback) { callback(Error("NOT_FOUND")) }

  indexeddb.do_load_user("test-db", fn(x) { x }, read, fn(result) {
    assert result == UserLoaded(Error(NotFound))
  })
}

pub fn do_save_user_indexeddb_test() {
  let test_user = user.new("Test", "testuser")
  let write = fn(_db, _key, _val, callback) { callback(Ok(Nil)) }

  indexeddb.do_save_user("test-db", test_user, fn(x) { x }, write, fn(result) {
    assert result == UserSaved(Ok(Nil))
  })
}
