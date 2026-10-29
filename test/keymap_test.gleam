//// Unit tests for the pure keymap resolution and vim motion logic.
////

import core/payment_tracker/keymap.{
  ActivateTarget, ClearAndFocusTarget, ClearFocus, Control, DateInput,
  DecrementDay, DecrementMonth, DescriptionTextarea, ExitInsertMode, FocusTarget,
  GoToAddPayment, GoToMonthDetail, GoToSummary, IncrementDay, IncrementMonth,
  InsertMode, KeyEvent, NavDown, NavLeft, NavRight, NavUp, NormalMode,
  PriceInput, SearchTable, SharedToggle, Shift, ShowHelp,
  SubmitAndNavigateToMonth, SubmitButton, SubmitPayment, TableSearchInput,
  TodayToggle, ToggleShared, ToggleToday,
}
import gleam/list
import gleam/option.{None, Some}

// --- FOCUS TARGET SELECTOR MAPPING TESTS ---

pub fn focus_target_to_selector_test() {
  assert keymap.focus_target_to_selector(keymap.PriceInput) == "#price"
  assert keymap.focus_target_to_selector(keymap.DescriptionTextarea)
    == "textarea[name='payment-name']"
  assert keymap.focus_target_to_selector(keymap.DateInput)
    == "input[name='payment-date']"
  assert keymap.focus_target_to_selector(keymap.SharedToggle)
    == "input[name='shared-toggle']"
  assert keymap.focus_target_to_selector(keymap.TodayToggle)
    == "input[name='today-toggle']"
  assert keymap.focus_target_to_selector(keymap.SubmitButton)
    == "button[type='submit']"
  assert keymap.focus_target_to_selector(keymap.TableSearchInput)
    == "input[placeholder*='Search']"
}

// --- VIM MODE HELPER TESTS ---

pub fn active_target_extracts_target_from_mode_test() {
  assert keymap.active_target(NormalMode(None)) == None
  assert keymap.active_target(NormalMode(Some(PriceInput))) == Some(PriceInput)
  assert keymap.active_target(InsertMode(DescriptionTextarea))
    == Some(DescriptionTextarea)
}

pub fn to_normal_mode_preserves_active_target_test() {
  assert keymap.to_normal_mode(NormalMode(None)) == NormalMode(None)
  assert keymap.to_normal_mode(NormalMode(Some(SharedToggle)))
    == NormalMode(Some(SharedToggle))
  assert keymap.to_normal_mode(InsertMode(PriceInput))
    == NormalMode(Some(PriceInput))
}

// --- NORMAL MODE SINGLE-KEY RESOLUTION TESTS ---

pub fn normal_mode_focus_price_test() {
  let km = keymap.default_keymap()
  let event = KeyEvent(key: "p", modifiers: [])
  assert keymap.resolve(km, event, NormalMode(None), None)
    == #(Some(FocusTarget(PriceInput)), None)
}

pub fn normal_mode_focus_description_test() {
  let km = keymap.default_keymap()
  let event_d = KeyEvent(key: "d", modifiers: [])
  assert keymap.resolve(km, event_d, NormalMode(None), None)
    == #(Some(FocusTarget(DescriptionTextarea)), None)
}

pub fn normal_mode_activate_target_with_i_test() {
  let km = keymap.default_keymap()
  let event_i = KeyEvent(key: "i", modifiers: [])
  assert keymap.resolve(km, event_i, NormalMode(None), None)
    == #(Some(ActivateTarget), None)
  assert keymap.resolve(km, event_i, NormalMode(Some(PriceInput)), None)
    == #(Some(ActivateTarget), None)
}

pub fn normal_mode_escape_clears_focus_when_target_highlighted_test() {
  let km = keymap.default_keymap()
  let esc = KeyEvent(key: keymap.key_escape, modifiers: [])

  assert keymap.resolve(km, esc, NormalMode(Some(PriceInput)), None)
    == #(Some(ClearFocus), None)
  assert keymap.resolve(km, esc, NormalMode(None), None) == #(None, None)
}

pub fn normal_mode_toggle_shared_test() {
  let km = keymap.default_keymap()
  let event = KeyEvent(key: "s", modifiers: [])
  assert keymap.resolve(km, event, NormalMode(None), None)
    == #(Some(ToggleShared), None)
}

pub fn normal_mode_toggle_today_test() {
  let km = keymap.default_keymap()
  let event = KeyEvent(key: "t", modifiers: [])
  assert keymap.resolve(km, event, NormalMode(None), None)
    == #(Some(ToggleToday), None)
}

pub fn normal_mode_day_adjustments_test() {
  let km = keymap.default_keymap()
  let inc = KeyEvent(key: "]", modifiers: [])
  assert keymap.resolve(km, inc, NormalMode(None), None)
    == #(Some(IncrementDay), None)

  let dec = KeyEvent(key: "[", modifiers: [])
  assert keymap.resolve(km, dec, NormalMode(None), None)
    == #(Some(DecrementDay), None)
}

pub fn normal_mode_month_adjustments_test() {
  let km = keymap.default_keymap()
  let inc = KeyEvent(key: "}", modifiers: [Shift])
  assert keymap.resolve(km, inc, NormalMode(None), None)
    == #(Some(IncrementMonth), None)

  let dec = KeyEvent(key: "{", modifiers: [Shift])
  assert keymap.resolve(km, dec, NormalMode(None), None)
    == #(Some(DecrementMonth), None)
}

pub fn normal_mode_hjkl_navigation_test() {
  let km = keymap.default_keymap()
  let left = KeyEvent(key: "h", modifiers: [])
  assert keymap.resolve(km, left, NormalMode(None), None)
    == #(Some(NavLeft), None)

  let down = KeyEvent(key: "j", modifiers: [])
  assert keymap.resolve(km, down, NormalMode(None), None)
    == #(Some(NavDown), None)

  let up = KeyEvent(key: "k", modifiers: [])
  assert keymap.resolve(km, up, NormalMode(None), None) == #(Some(NavUp), None)

  let right = KeyEvent(key: "l", modifiers: [])
  assert keymap.resolve(km, right, NormalMode(None), None)
    == #(Some(NavRight), None)
}

pub fn normal_mode_search_table_test() {
  let km = keymap.default_keymap()
  let search = KeyEvent(key: "/", modifiers: [])
  assert keymap.resolve(km, search, NormalMode(None), None)
    == #(Some(SearchTable), None)
}

pub fn normal_mode_submit_enter_test() {
  let km = keymap.default_keymap()
  let enter = KeyEvent(key: keymap.key_enter, modifiers: [])
  assert keymap.resolve(km, enter, NormalMode(None), None)
    == #(Some(SubmitPayment), None)
}

pub fn normal_mode_help_test() {
  let km = keymap.default_keymap()
  let help = KeyEvent(key: "?", modifiers: [Shift])
  assert keymap.resolve(km, help, NormalMode(None), None)
    == #(Some(ShowHelp), None)
}

// --- 2D SPATIAL NAVIGATION (FOCUS GRID / CLAMPED) TESTS ---

pub fn add_payment_grid_structure_test() {
  assert keymap.add_payment_grid()
    == [
      [PriceInput],
      [SharedToggle, DescriptionTextarea],
      [TodayToggle, DescriptionTextarea],
      [DateInput, SubmitButton],
    ]
}

pub fn navigate_focus_target_from_none_test() {
  let grid = keymap.add_payment_grid()
  assert keymap.navigate_focus_target(grid, None, NavLeft) == Some(PriceInput)
  assert keymap.navigate_focus_target(grid, None, NavDown) == Some(PriceInput)
  assert keymap.navigate_focus_target(grid, None, NavUp) == Some(PriceInput)
  assert keymap.navigate_focus_target(grid, None, NavRight) == Some(PriceInput)
}

pub fn navigate_focus_target_from_price_input_test() {
  let grid = keymap.add_payment_grid()
  let current = Some(PriceInput)
  // j moves to top of left column (SharedToggle)
  assert keymap.navigate_focus_target(grid, current, NavDown)
    == Some(SharedToggle)
  // l moves directly to DescriptionTextarea
  assert keymap.navigate_focus_target(grid, current, NavRight)
    == Some(DescriptionTextarea)
  // k and h clamp at PriceInput
  assert keymap.navigate_focus_target(grid, current, NavUp) == Some(PriceInput)
  assert keymap.navigate_focus_target(grid, current, NavLeft)
    == Some(PriceInput)
}

pub fn navigate_focus_target_left_column_test() {
  let grid = keymap.add_payment_grid()

  // SharedToggle
  assert keymap.navigate_focus_target(grid, Some(SharedToggle), NavUp)
    == Some(PriceInput)
  assert keymap.navigate_focus_target(grid, Some(SharedToggle), NavDown)
    == Some(TodayToggle)
  assert keymap.navigate_focus_target(grid, Some(SharedToggle), NavRight)
    == Some(DescriptionTextarea)
  assert keymap.navigate_focus_target(grid, Some(SharedToggle), NavLeft)
    == Some(SharedToggle)

  // TodayToggle
  assert keymap.navigate_focus_target(grid, Some(TodayToggle), NavUp)
    == Some(SharedToggle)
  assert keymap.navigate_focus_target(grid, Some(TodayToggle), NavDown)
    == Some(DateInput)
  assert keymap.navigate_focus_target(grid, Some(TodayToggle), NavRight)
    == Some(DescriptionTextarea)
  assert keymap.navigate_focus_target(grid, Some(TodayToggle), NavLeft)
    == Some(TodayToggle)

  // DateInput (bottom of left column)
  assert keymap.navigate_focus_target(grid, Some(DateInput), NavUp)
    == Some(TodayToggle)
  assert keymap.navigate_focus_target(grid, Some(DateInput), NavDown)
    == Some(DateInput)
  assert keymap.navigate_focus_target(grid, Some(DateInput), NavRight)
    == Some(SubmitButton)
  assert keymap.navigate_focus_target(grid, Some(DateInput), NavLeft)
    == Some(DateInput)
}

pub fn navigate_focus_target_right_column_test() {
  let grid = keymap.add_payment_grid()

  // DescriptionTextarea (spans rows 1 and 2 in column 1)
  assert keymap.navigate_focus_target(grid, Some(DescriptionTextarea), NavUp)
    == Some(PriceInput)
  assert keymap.navigate_focus_target(grid, Some(DescriptionTextarea), NavDown)
    == Some(SubmitButton)
  assert keymap.navigate_focus_target(grid, Some(DescriptionTextarea), NavLeft)
    == Some(SharedToggle)
  assert keymap.navigate_focus_target(grid, Some(DescriptionTextarea), NavRight)
    == Some(DescriptionTextarea)

  // SubmitButton (bottom of right column)
  assert keymap.navigate_focus_target(grid, Some(SubmitButton), NavUp)
    == Some(DescriptionTextarea)
  assert keymap.navigate_focus_target(grid, Some(SubmitButton), NavDown)
    == Some(SubmitButton)
  assert keymap.navigate_focus_target(grid, Some(SubmitButton), NavLeft)
    == Some(DateInput)
  assert keymap.navigate_focus_target(grid, Some(SubmitButton), NavRight)
    == Some(SubmitButton)
}

pub fn navigate_focus_target_custom_reusable_grid_test() {
  // Verifies that FocusGrid works generically for any arbitrary 2D page layout
  let custom_grid = [
    [TableSearchInput, SharedToggle, TodayToggle],
    [DateInput, DescriptionTextarea, SubmitButton],
  ]

  assert keymap.navigate_focus_target(
      custom_grid,
      Some(TableSearchInput),
      NavRight,
    )
    == Some(SharedToggle)
  assert keymap.navigate_focus_target(custom_grid, Some(SharedToggle), NavRight)
    == Some(TodayToggle)
  assert keymap.navigate_focus_target(custom_grid, Some(SharedToggle), NavDown)
    == Some(DescriptionTextarea)
  assert keymap.navigate_focus_target(
      custom_grid,
      Some(DescriptionTextarea),
      NavLeft,
    )
    == Some(DateInput)
  assert keymap.navigate_focus_target(
      custom_grid,
      Some(DescriptionTextarea),
      NavUp,
    )
    == Some(SharedToggle)
}

// --- PENDING PREFIX SEQUENCE TESTS ---

pub fn pending_change_prefix_test() {
  let km = keymap.default_keymap()

  // Pressing 'c' initiates pending prefix
  let c_event = KeyEvent(key: "c", modifiers: [])
  assert keymap.resolve(km, c_event, NormalMode(None), None)
    == #(None, Some("c"))

  // 'c' followed by 'p' clears & focuses price
  let p_event = KeyEvent(key: "p", modifiers: [])
  assert keymap.resolve(km, p_event, NormalMode(None), Some("c"))
    == #(Some(ClearAndFocusTarget(PriceInput)), None)

  // 'c' followed by 'd' clears & focuses description
  let d_event = KeyEvent(key: "d", modifiers: [])
  assert keymap.resolve(km, d_event, NormalMode(None), Some("c"))
    == #(Some(ClearAndFocusTarget(DescriptionTextarea)), None)

  // 'c' followed by invalid key resets pending prefix
  let invalid_event = KeyEvent(key: "z", modifiers: [])
  assert keymap.resolve(km, invalid_event, NormalMode(None), Some("c"))
    == #(None, None)

  // 'c' followed by Escape cancels pending prefix
  let esc_event = KeyEvent(key: keymap.key_escape, modifiers: [])
  assert keymap.resolve(km, esc_event, NormalMode(None), Some("c"))
    == #(None, None)
}

pub fn pending_go_prefix_test() {
  let km = keymap.default_keymap()

  // Pressing 'g' initiates pending prefix
  let g_event = KeyEvent(key: "g", modifiers: [])
  assert keymap.resolve(km, g_event, NormalMode(None), None)
    == #(None, Some("g"))

  // 'g' followed by 'p' goes to Add Payment
  let p_event = KeyEvent(key: "p", modifiers: [])
  assert keymap.resolve(km, p_event, NormalMode(None), Some("g"))
    == #(Some(GoToAddPayment), None)

  // 'g' followed by 's' goes to Monthly Summary
  let s_event = KeyEvent(key: "s", modifiers: [])
  assert keymap.resolve(km, s_event, NormalMode(None), Some("g"))
    == #(Some(GoToSummary), None)

  // 'g' followed by 'm' goes to Month Detail
  let m_event = KeyEvent(key: "m", modifiers: [])
  assert keymap.resolve(km, m_event, NormalMode(None), Some("g"))
    == #(Some(GoToMonthDetail), None)

  // 'g' followed by invalid key cancels pending
  let invalid_event = KeyEvent(key: "x", modifiers: [])
  assert keymap.resolve(km, invalid_event, NormalMode(None), Some("g"))
    == #(None, None)
}

// --- CHORDED SUBMISSIONS ---

pub fn chorded_submit_payment_test() {
  let km = keymap.default_keymap()
  let ctrl_enter = KeyEvent(key: keymap.key_enter, modifiers: [Control])

  // Works in Normal Mode
  assert keymap.resolve(km, ctrl_enter, NormalMode(None), None)
    == #(Some(SubmitPayment), None)

  // Works in Insert Mode
  assert keymap.resolve(km, ctrl_enter, InsertMode(DescriptionTextarea), None)
    == #(Some(SubmitPayment), None)
}

pub fn chorded_submit_and_view_month_test() {
  let km = keymap.default_keymap()
  let shift_enter = KeyEvent(key: keymap.key_enter, modifiers: [Shift])

  // Works in Normal Mode
  assert keymap.resolve(km, shift_enter, NormalMode(None), None)
    == #(Some(SubmitAndNavigateToMonth), None)

  // Works in Insert Mode
  assert keymap.resolve(km, shift_enter, InsertMode(PriceInput), None)
    == #(Some(SubmitAndNavigateToMonth), None)
}

// --- INSERT MODE ISOLATION TESTS ---

pub fn insert_mode_ignores_standard_keys_test() {
  let km = keymap.default_keymap()

  let keys = ["p", "d", "s", "t", "]", "[", "}", "{", "c", "g", "j", "k", "/"]
  let mode = InsertMode(DescriptionTextarea)

  keys
  |> list.each(fn(k) {
    let event = KeyEvent(key: k, modifiers: [])
    assert keymap.resolve(km, event, mode, None) == #(None, None)
  })
}

pub fn insert_mode_escape_returns_to_normal_test() {
  let km = keymap.default_keymap()
  let esc = KeyEvent(key: keymap.key_escape, modifiers: [])

  assert keymap.resolve(km, esc, InsertMode(PriceInput), None)
    == #(Some(ExitInsertMode), None)
}
