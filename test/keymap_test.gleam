//// Unit tests for the pure keymap resolution and vim motion logic.
////

import core/payment_tracker/keymap.{
  ClearAndFocusTarget, Control, DecrementDay, DecrementMonth,
  DescriptionTextarea, ExitInsertMode, FocusTarget, GoToAddPayment,
  GoToMonthDetail, GoToSummary, IncrementDay, IncrementMonth, InsertMode,
  KeyEvent, NavDown, NavLeft, NavRight, NavUp, NormalMode, PriceInput,
  SearchTable, Shift, ShowHelp, SubmitAndNavigateToMonth, SubmitPayment,
  ToggleShared, ToggleToday,
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

// --- NORMAL MODE SINGLE-KEY RESOLUTION TESTS ---

pub fn normal_mode_focus_price_test() {
  let km = keymap.default_keymap()
  let event = KeyEvent(key: "p", modifiers: [])
  assert keymap.resolve(km, event, NormalMode, None)
    == #(Some(FocusTarget(PriceInput)), None)
}

pub fn normal_mode_focus_description_test() {
  let km = keymap.default_keymap()
  let event_d = KeyEvent(key: "d", modifiers: [])
  assert keymap.resolve(km, event_d, NormalMode, None)
    == #(Some(FocusTarget(DescriptionTextarea)), None)

  let event_i = KeyEvent(key: "i", modifiers: [])
  assert keymap.resolve(km, event_i, NormalMode, None)
    == #(Some(FocusTarget(DescriptionTextarea)), None)
}

pub fn normal_mode_toggle_shared_test() {
  let km = keymap.default_keymap()
  let event = KeyEvent(key: "s", modifiers: [])
  assert keymap.resolve(km, event, NormalMode, None)
    == #(Some(ToggleShared), None)
}

pub fn normal_mode_toggle_today_test() {
  let km = keymap.default_keymap()
  let event = KeyEvent(key: "t", modifiers: [])
  assert keymap.resolve(km, event, NormalMode, None)
    == #(Some(ToggleToday), None)
}

pub fn normal_mode_day_adjustments_test() {
  let km = keymap.default_keymap()
  let inc = KeyEvent(key: "]", modifiers: [])
  assert keymap.resolve(km, inc, NormalMode, None)
    == #(Some(IncrementDay), None)

  let dec = KeyEvent(key: "[", modifiers: [])
  assert keymap.resolve(km, dec, NormalMode, None)
    == #(Some(DecrementDay), None)
}

pub fn normal_mode_month_adjustments_test() {
  let km = keymap.default_keymap()
  let inc = KeyEvent(key: "}", modifiers: [Shift])
  assert keymap.resolve(km, inc, NormalMode, None)
    == #(Some(IncrementMonth), None)

  let dec = KeyEvent(key: "{", modifiers: [Shift])
  assert keymap.resolve(km, dec, NormalMode, None)
    == #(Some(DecrementMonth), None)
}

pub fn normal_mode_hjkl_navigation_test() {
  let km = keymap.default_keymap()
  let left = KeyEvent(key: "h", modifiers: [])
  assert keymap.resolve(km, left, NormalMode, None) == #(Some(NavLeft), None)

  let down = KeyEvent(key: "j", modifiers: [])
  assert keymap.resolve(km, down, NormalMode, None) == #(Some(NavDown), None)

  let up = KeyEvent(key: "k", modifiers: [])
  assert keymap.resolve(km, up, NormalMode, None) == #(Some(NavUp), None)

  let right = KeyEvent(key: "l", modifiers: [])
  assert keymap.resolve(km, right, NormalMode, None) == #(Some(NavRight), None)
}

pub fn normal_mode_search_table_test() {
  let km = keymap.default_keymap()
  let search = KeyEvent(key: "/", modifiers: [])
  assert keymap.resolve(km, search, NormalMode, None)
    == #(Some(SearchTable), None)
}

pub fn normal_mode_submit_enter_test() {
  let km = keymap.default_keymap()
  let enter = KeyEvent(key: "Enter", modifiers: [])
  assert keymap.resolve(km, enter, NormalMode, None)
    == #(Some(SubmitPayment), None)
}

pub fn normal_mode_help_test() {
  let km = keymap.default_keymap()
  let help = KeyEvent(key: "?", modifiers: [Shift])
  assert keymap.resolve(km, help, NormalMode, None) == #(Some(ShowHelp), None)
}

// --- PENDING PREFIX SEQUENCE TESTS ---

pub fn pending_change_prefix_test() {
  let km = keymap.default_keymap()

  // Pressing 'c' initiates pending prefix
  let c_event = KeyEvent(key: "c", modifiers: [])
  assert keymap.resolve(km, c_event, NormalMode, None) == #(None, Some("c"))

  // 'c' followed by 'p' clears & focuses price
  let p_event = KeyEvent(key: "p", modifiers: [])
  assert keymap.resolve(km, p_event, NormalMode, Some("c"))
    == #(Some(ClearAndFocusTarget(PriceInput)), None)

  // 'c' followed by 'd' clears & focuses description
  let d_event = KeyEvent(key: "d", modifiers: [])
  assert keymap.resolve(km, d_event, NormalMode, Some("c"))
    == #(Some(ClearAndFocusTarget(DescriptionTextarea)), None)

  // 'c' followed by invalid key resets pending prefix
  let invalid_event = KeyEvent(key: "z", modifiers: [])
  assert keymap.resolve(km, invalid_event, NormalMode, Some("c"))
    == #(None, None)

  // 'c' followed by Escape cancels pending prefix
  let esc_event = KeyEvent(key: "Escape", modifiers: [])
  assert keymap.resolve(km, esc_event, NormalMode, Some("c")) == #(None, None)
}

pub fn pending_go_prefix_test() {
  let km = keymap.default_keymap()

  // Pressing 'g' initiates pending prefix
  let g_event = KeyEvent(key: "g", modifiers: [])
  assert keymap.resolve(km, g_event, NormalMode, None) == #(None, Some("g"))

  // 'g' followed by 'p' goes to Add Payment
  let p_event = KeyEvent(key: "p", modifiers: [])
  assert keymap.resolve(km, p_event, NormalMode, Some("g"))
    == #(Some(GoToAddPayment), None)

  // 'g' followed by 's' goes to Monthly Summary
  let s_event = KeyEvent(key: "s", modifiers: [])
  assert keymap.resolve(km, s_event, NormalMode, Some("g"))
    == #(Some(GoToSummary), None)

  // 'g' followed by 'm' goes to Month Detail
  let m_event = KeyEvent(key: "m", modifiers: [])
  assert keymap.resolve(km, m_event, NormalMode, Some("g"))
    == #(Some(GoToMonthDetail), None)

  // 'g' followed by invalid key cancels pending
  let invalid_event = KeyEvent(key: "x", modifiers: [])
  assert keymap.resolve(km, invalid_event, NormalMode, Some("g"))
    == #(None, None)
}

// --- CHORDED SUBMISSIONS ---

pub fn chorded_submit_payment_test() {
  let km = keymap.default_keymap()
  let ctrl_enter = KeyEvent(key: "Enter", modifiers: [Control])

  // Works in Normal Mode
  assert keymap.resolve(km, ctrl_enter, NormalMode, None)
    == #(Some(SubmitPayment), None)

  // Works in Insert Mode
  assert keymap.resolve(km, ctrl_enter, InsertMode(DescriptionTextarea), None)
    == #(Some(SubmitPayment), None)
}

pub fn chorded_submit_and_view_month_test() {
  let km = keymap.default_keymap()
  let shift_enter = KeyEvent(key: "Enter", modifiers: [Shift])

  // Works in Normal Mode
  assert keymap.resolve(km, shift_enter, NormalMode, None)
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
  let esc = KeyEvent(key: "Escape", modifiers: [])

  assert keymap.resolve(km, esc, InsertMode(PriceInput), None)
    == #(Some(ExitInsertMode), None)
}
