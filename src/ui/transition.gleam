pub type TransitionType {
  Forward
  Backward
  None
}

/// Starts a View Transition for a given transition type via the
/// startViewTransition FFI.
///
/// TODO (Scoped View Transitions Level 2):
/// Update this FFI binding to accept a target Element or ShadowRoot once
/// `element.startViewTransition()` reaches cross-browser baseline support.
///
pub fn start(update_dom: fn() -> Nil, direction: TransitionType) -> Nil {
  let dir_str = case direction {
    Forward -> "forward"
    Backward -> "backward"
    None -> "none"
  }
  do_start_transition(update_dom, dir_str)
}

@external(javascript, "../ffi.mjs", "startViewTransition")
fn do_start_transition(update_dom: fn() -> Nil, direction: String) -> Nil
