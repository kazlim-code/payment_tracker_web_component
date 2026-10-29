//// This module defines types and logic for Vim-like keyboard navigation,
//// keybindings, and modal input resolution.
////

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

/// Standard key name constant for the Escape key.
///
pub const key_escape = "Escape"

/// Standard key name constant for the Enter key.
///
pub const key_enter = "Enter"

/// Keyboard modifiers that can be held alongside a keypress.
///
pub type Modifier {
  Control
  Alt
  Shift
  Meta
}

/// Represents a keyboard event with its key character/name and any active
/// modifiers.
///
pub type KeyEvent {
  KeyEvent(key: String, modifiers: List(Modifier))
}

/// Strongly-typed DOM interactive targets to focus or blur within the component.
///
pub type FocusTarget {
  PriceInput
  DescriptionTextarea
  DateInput
  SharedToggle
  TodayToggle
  SubmitButton
  TableSearchInput
}

/// Operational Vim mode of the component.
///
/// `NormalMode` holds an optional virtual cursor target (`Option(FocusTarget)`),
/// allowing 2D spatial navigation without locking native DOM text focus.
/// `InsertMode` holds the actively focused `FocusTarget` receiving text input.
///
pub type VimMode {
  NormalMode(Option(FocusTarget))
  InsertMode(FocusTarget)
}

/// Actions dispatched when a keyboard motion or sequence is resolved.
///
pub type Action {
  ActivateTarget
  ClearFocus
  FocusTarget(FocusTarget)
  ClearAndFocusTarget(FocusTarget)
  ToggleShared
  ToggleToday
  IncrementDay
  DecrementDay
  IncrementMonth
  DecrementMonth
  NavDown
  NavUp
  NavLeft
  NavRight
  NextRow
  PreviousRow
  SearchTable
  SubmitPayment
  SubmitAndNavigateToMonth
  GoToAddPayment
  GoToSummary
  GoToMonthDetail
  ShowHelp
  ExitInsertMode
}

/// Defines a trigger pattern for a keybinding.
///
pub type KeyCombination {
  SingleKey(String)
  ChordKey(key: String, modifiers: List(Modifier))
  PrefixKey(prefix: String, key: String)
}

/// A mapping from key combinations to their corresponding actions.
///
pub type Keymap =
  List(#(KeyCombination, Action))

/// A 2D spatial grid of `FocusTarget` elements modelled after CSS
/// `grid-template-areas`. Elements that span multiple rows or columns repeat
/// their `FocusTarget` across the cells they occupy.
///
pub type FocusGrid =
  List(List(FocusTarget))

type BoundingBox {
  BoundingBox(min_row: Int, max_row: Int, min_col: Int, max_col: Int)
}

/// Extracts the active `FocusTarget` (if any) from the given `VimMode`.
///
pub fn active_target(mode: VimMode) -> Option(FocusTarget) {
  case mode {
    NormalMode(focused) -> focused
    InsertMode(target) -> Some(target)
  }
}

/// Transitions any `VimMode` into `NormalMode` while preserving the active
/// `FocusTarget` (e.g. `InsertMode(target)` -> `NormalMode(Some(target))`).
///
pub fn to_normal_mode(mode: VimMode) -> VimMode {
  NormalMode(active_target(mode))
}

/// Returns `True` when the given `FocusTarget` is a single-line `<input>`
/// element where pressing unmodified `Enter` in Insert mode confirms the
/// value and returns to Normal mode.
///
pub fn is_single_line_input(target: FocusTarget) -> Bool {
  case target {
    PriceInput | DateInput | TableSearchInput -> True
    _ -> False
  }
}

/// Maps a strongly-typed `FocusTarget` to its corresponding CSS selector within
/// the component's Shadow DOM.
///
pub fn focus_target_to_selector(target: FocusTarget) -> String {
  case target {
    PriceInput -> "#price"
    DescriptionTextarea -> "textarea[name='payment-name']"
    DateInput -> "input[name='payment-date']"
    SharedToggle -> "input[name='shared-toggle']"
    TodayToggle -> "input[name='today-toggle']"
    SubmitButton -> "button[type='submit']"
    TableSearchInput -> "input[placeholder*='Search']"
  }
}

/// Returns the 2D `FocusGrid` layout for the Add Payment view, mirroring CSS
/// `grid-template-areas` where `DescriptionTextarea` spans two rows alongside
/// the left-column toggles.
///
pub fn add_payment_grid() -> FocusGrid {
  [
    [PriceInput],
    [SharedToggle, DescriptionTextarea],
    [TodayToggle, DescriptionTextarea],
    [DateInput, SubmitButton],
  ]
}

/// Returns the standard default keymap for the application.
///
pub fn default_keymap() -> Keymap {
  [
    // Single key motions in Normal mode
    #(SingleKey("p"), FocusTarget(PriceInput)),
    #(SingleKey("d"), FocusTarget(DescriptionTextarea)),
    #(SingleKey("i"), ActivateTarget),
    #(SingleKey("s"), ToggleShared),
    #(SingleKey("t"), ToggleToday),
    #(SingleKey("]"), IncrementDay),
    #(SingleKey("["), DecrementDay),
    #(SingleKey("}"), IncrementMonth),
    #(SingleKey("{"), DecrementMonth),
    #(SingleKey("h"), NavLeft),
    #(SingleKey("j"), NavDown),
    #(SingleKey("k"), NavUp),
    #(SingleKey("l"), NavRight),
    #(SingleKey("/"), SearchTable),
    #(SingleKey(key_enter), SubmitPayment),
    #(SingleKey("?"), ShowHelp),
    // Prefix sequences: 'c' (Change / Clear)
    #(PrefixKey("c", "p"), ClearAndFocusTarget(PriceInput)),
    #(PrefixKey("c", "d"), ClearAndFocusTarget(DescriptionTextarea)),
    // Prefix sequences: 'g' (Go)
    #(PrefixKey("g", "p"), GoToAddPayment),
    #(PrefixKey("g", "s"), GoToSummary),
    #(PrefixKey("g", "m"), GoToMonthDetail),
    // Chorded shortcuts (accessible in both Normal and Insert modes)
    #(ChordKey(key_enter, [Control]), SubmitPayment),
    #(ChordKey(key_enter, [Shift]), SubmitAndNavigateToMonth),
  ]
}

/// Calculates the next `FocusTarget` within a 2D `FocusGrid` using clamped
/// bounding-box navigation (no wrap-around).
///
pub fn navigate_focus_target(
  grid: FocusGrid,
  current: Option(FocusTarget),
  action: Action,
) -> Option(FocusTarget) {
  case action {
    NavLeft | NavDown | NavUp | NavRight -> {
      case current {
        None -> first_in_grid(grid)
        Some(target) -> {
          case find_bounding_box(grid, target) {
            None -> first_in_grid(grid)
            Some(box) -> step_in_grid(grid, target, box, action)
          }
        }
      }
    }
    _ -> current
  }
}

fn first_in_grid(grid: FocusGrid) -> Option(FocusTarget) {
  grid
  |> list.find_map(fn(row) { list.first(row) })
  |> option.from_result
}

fn find_bounding_box(
  grid: FocusGrid,
  target: FocusTarget,
) -> Option(BoundingBox) {
  list.index_fold(grid, None, fn(acc, row, row_idx) {
    list.index_fold(row, acc, fn(inner_acc, cell, col_idx) {
      case cell == target {
        False -> inner_acc
        True ->
          case inner_acc {
            None ->
              Some(BoundingBox(
                min_row: row_idx,
                max_row: row_idx,
                min_col: col_idx,
                max_col: col_idx,
              ))
            Some(BoundingBox(min_row:, max_row:, min_col:, max_col:)) ->
              Some(BoundingBox(
                min_row: int.min(min_row, row_idx),
                max_row: int.max(max_row, row_idx),
                min_col: int.min(min_col, col_idx),
                max_col: int.max(max_col, col_idx),
              ))
          }
      }
    })
  })
}

fn step_in_grid(
  grid: FocusGrid,
  current: FocusTarget,
  box: BoundingBox,
  action: Action,
) -> Option(FocusTarget) {
  case action {
    NavDown ->
      case get_clamped_cell(grid, box.max_row + 1, box.min_col) {
        Some(next) -> Some(next)
        None -> Some(current)
      }
    NavUp ->
      case box.min_row > 0 {
        True ->
          case get_clamped_cell(grid, box.min_row - 1, box.min_col) {
            Some(prev) -> Some(prev)
            None -> Some(current)
          }
        False -> Some(current)
      }
    NavLeft ->
      case box.min_col > 0 {
        True ->
          case get_exact_cell(grid, box.min_row, box.min_col - 1) {
            Some(left) -> Some(left)
            None -> Some(current)
          }
        False -> Some(current)
      }
    NavRight ->
      case get_exact_cell(grid, box.min_row, box.max_col + 1) {
        Some(right) -> Some(right)
        None ->
          // If current row is a narrower banner row (e.g. [PriceInput]),
          // allow stepping right into the adjacent column of the row below.
          case get_exact_cell(grid, box.min_row + 1, box.max_col + 1) {
            Some(diagonal_right) -> Some(diagonal_right)
            None -> Some(current)
          }
      }
    _ -> Some(current)
  }
}

fn get_exact_cell(
  grid: FocusGrid,
  row_idx: Int,
  col_idx: Int,
) -> Option(FocusTarget) {
  case get_at(grid, row_idx) {
    None -> None
    Some(row) -> get_at(row, col_idx)
  }
}

fn get_clamped_cell(
  grid: FocusGrid,
  row_idx: Int,
  col_idx: Int,
) -> Option(FocusTarget) {
  case get_at(grid, row_idx) {
    None -> None
    Some(row) -> {
      let row_len = list.length(row)
      case row_len > 0 {
        True -> {
          let clamped_col = int.max(0, int.min(col_idx, row_len - 1))
          get_at(row, clamped_col)
        }
        False -> None
      }
    }
  }
}

fn get_at(items: List(a), target_index: Int) -> Option(a) {
  case target_index < 0 {
    True -> None
    False ->
      items
      |> list.drop(target_index)
      |> list.first
      |> option.from_result
  }
}

/// Resolves a key event against the active keymap, current Vim mode, and any
/// pending key prefix.
///
/// Returns a tuple containing the optional resolved `Action` and the new
/// pending prefix state (`Some(prefix)` if awaiting the second key of a
/// sequence, or `None` if cleared/completed).
///
pub fn resolve(
  keymap: Keymap,
  event: KeyEvent,
  mode: VimMode,
  pending_prefix: Option(String),
) -> #(Option(Action), Option(String)) {
  // Always check chorded actions first (e.g. Ctrl+Enter or Shift+Enter) regardless of mode
  case find_chord_action(keymap, event) {
    Some(action) -> #(Some(action), None)
    None -> {
      case mode {
        InsertMode(target) -> {
          // In insert mode, Escape always exits back to Normal mode.
          // Unmodified Enter also confirms and exits on single-line inputs.
          let is_enter_confirm =
            event.key == key_enter
            && list.is_empty(event.modifiers)
            && is_single_line_input(target)
          case event.key == key_escape || is_enter_confirm {
            True -> #(Some(ExitInsertMode), None)
            False -> #(None, None)
          }
        }
        NormalMode(focused) ->
          resolve_normal_mode(keymap, event, focused, pending_prefix)
      }
    }
  }
}

fn resolve_normal_mode(
  keymap: Keymap,
  event: KeyEvent,
  focused: Option(FocusTarget),
  pending_prefix: Option(String),
) -> #(Option(Action), Option(String)) {
  case pending_prefix {
    Some(prefix) -> {
      case event.key == key_escape {
        True -> #(None, None)
        False -> {
          let action =
            list.find_map(keymap, fn(binding) {
              case binding.0 {
                PrefixKey(p, k) if p == prefix && k == event.key -> Ok(binding.1)
                _ -> Error(Nil)
              }
            })
            |> option.from_result
          #(action, None)
        }
      }
    }
    None -> {
      case event.key == key_escape, focused {
        True, Some(_) -> #(Some(ClearFocus), None)
        True, None -> #(None, None)
        False, _ -> {
          // Check if this key is a prefix leader key (e.g. 'c' or 'g')
          case is_prefix_leader(keymap, event.key) {
            True -> #(None, Some(event.key))
            False -> {
              let action =
                list.find_map(keymap, fn(binding) {
                  case binding.0 {
                    SingleKey(k) if k == event.key -> {
                      let is_valid_modifiers =
                        event.modifiers == []
                        || {
                          event.modifiers == [Shift]
                          && is_shifted_symbol(event.key)
                        }
                      case is_valid_modifiers {
                        True -> Ok(binding.1)
                        False -> Error(Nil)
                      }
                    }
                    _ -> Error(Nil)
                  }
                })
                |> option.from_result
              #(action, None)
            }
          }
        }
      }
    }
  }
}

fn is_shifted_symbol(key: String) -> Bool {
  case key {
    "{" | "}" | "?" | ":" | "<" | ">" | "+" | "_" | "|" | "~" -> True
    _ -> False
  }
}

fn find_chord_action(keymap: Keymap, event: KeyEvent) -> Option(Action) {
  case list.is_empty(event.modifiers) {
    True -> None
    False -> {
      list.find_map(keymap, fn(binding) {
        case binding.0 {
          ChordKey(key, modifiers) if key == event.key -> {
            case same_modifiers(modifiers, event.modifiers) {
              True -> Ok(binding.1)
              False -> Error(Nil)
            }
          }
          _ -> Error(Nil)
        }
      })
      |> option.from_result
    }
  }
}

fn same_modifiers(expected: List(Modifier), actual: List(Modifier)) -> Bool {
  list.length(expected) == list.length(actual)
  && list.all(expected, fn(m) { list.contains(actual, m) })
}

fn is_prefix_leader(keymap: Keymap, key: String) -> Bool {
  list.any(keymap, fn(binding) {
    case binding.0 {
      PrefixKey(prefix, _) if prefix == key -> True
      _ -> False
    }
  })
}
