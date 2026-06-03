//// Utility functions for the payment tracker core.
////

/// Generates a unique identifier.
///
pub fn generate_uuid() {
  do_uuid()
}

// FFI -------------------------------------------------------------------------

@external(javascript, "../../../ffi.mjs", "uuid")
fn do_uuid() -> String {
  ""
}
