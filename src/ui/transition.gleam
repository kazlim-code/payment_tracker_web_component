pub type TransitionType {
  Forward
  Backward
  None
}

@external(javascript, "../ffi.mjs", "startViewTransition")
pub fn start_transition(
  update_dom: fn() -> Nil,
  direction: TransitionType,
) -> Nil
