//// This module defines types and logic for Vim-like keyboard navigation,
//// keybindings, and modal input resolution.
////

import gleam/list
import gleam/option.{type Option, None, Some}

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
pub type VimMode {
  NormalMode
  InsertMode(FocusTarget)
}

/// Actions dispatched when a keyboard motion or sequence is resolved.
///
pub type Action {
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

/// Returns the standard default keymap for the application.
///
pub fn default_keymap() -> Keymap {
  [
    // Single key motions in Normal mode
    #(SingleKey("p"), FocusTarget(PriceInput)),
    #(SingleKey("d"), FocusTarget(DescriptionTextarea)),
    #(SingleKey("i"), FocusTarget(DescriptionTextarea)),
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
    #(SingleKey("Enter"), SubmitPayment),
    #(SingleKey("?"), ShowHelp),
    // Prefix sequences: 'c' (Change / Clear)
    #(PrefixKey("c", "p"), ClearAndFocusTarget(PriceInput)),
    #(PrefixKey("c", "d"), ClearAndFocusTarget(DescriptionTextarea)),
    // Prefix sequences: 'g' (Go)
    #(PrefixKey("g", "p"), GoToAddPayment),
    #(PrefixKey("g", "s"), GoToSummary),
    #(PrefixKey("g", "m"), GoToMonthDetail),
    // Chorded shortcuts (accessible in both Normal and Insert modes)
    #(ChordKey("Enter", [Control]), SubmitPayment),
    #(ChordKey("Enter", [Shift]), SubmitAndNavigateToMonth),
  ]
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
        InsertMode(_) -> {
          // In insert mode, Escape always exits back to Normal mode
          case event.key {
            "Escape" -> #(Some(ExitInsertMode), None)
            _ -> #(None, None)
          }
        }
        NormalMode -> resolve_normal_mode(keymap, event, pending_prefix)
      }
    }
  }
}

fn resolve_normal_mode(
  keymap: Keymap,
  event: KeyEvent,
  pending_prefix: Option(String),
) -> #(Option(Action), Option(String)) {
  case pending_prefix {
    Some(prefix) -> {
      case event.key {
        "Escape" -> #(None, None)
        second_key -> {
          let action =
            list.find_map(keymap, fn(binding) {
              case binding.0 {
                PrefixKey(p, k) if p == prefix && k == second_key ->
                  Ok(binding.1)
                _ -> Error(Nil)
              }
            })
            |> option.from_result
          #(action, None)
        }
      }
    }
    None -> {
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
                      event.modifiers == [Shift] && is_shifted_symbol(event.key)
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
