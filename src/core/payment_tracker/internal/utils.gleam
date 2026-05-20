pub fn generate_uuid() {
  do_uuid()
}

// FFI -------------------------------------------------------------------------

@external(javascript, "../../../ffi.mjs", "uuid")
fn do_uuid() -> String {
  ""
}
