import core/payment_tracker/internal/sort
import core/payment_tracker/internal/utils
import core/payment_tracker/keymap
import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import core/storage.{LoadUser, LocalStorage, SaveUser, UserLoaded, UserSaved}
import formal/form
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre
import lustre/component
import lustre/effect.{type Effect}
import plinth/javascript/global
import tempo.{type Date}
import tempo/date as tempo_date
import tempo/instant
import ui/state.{
  type Model, type Msg, AddPayment, AutomatedBankTransfer, DebugTransitionEnd,
  HomeLoan, MonthlyDetail, MonthlySummary, NoDialog, ParentUpdatedDebug,
  ParentUpdatedDemo, ParentUpdatedStorageBackend, PaymentData,
  StorageUpdatedUser, UserBlurredAmount, UserBlurredTarget,
  UserChangedPaymentDate, UserChangedSearchQuery, UserClearedSearchQuery,
  UserClearedSuccessFeedback, UserClickedAddMonthPayment, UserClickedAddPayment,
  UserClickedBack, UserClickedDetailedMonthView, UserClickedEditHomeLoanAmount,
  UserClickedEditPayment, UserClickedEditTransferAmount, UserClickedMonthlyView,
  UserClickedSortColumn, UserClickedToggleDebug, UserClosedDialog,
  UserDecrementedAmount, UserDeletedPayment, UserFocusedTarget,
  UserIncrementedAmount, UserInputPaymentName, UserPressedKey,
  UserSubmittedEditMonthlyBalance, UserSubmittedEditPayment,
  UserSubmittedPayment, UserToggledMonthlyPaymentPaid, UserToggledShared,
  UserToggledSharedPayment, UserToggledToday, ViewTransitionedToAddMonthPayment,
  ViewTransitionedToAddPayment, ViewTransitionedToMonthlyDetail,
  ViewTransitionedToMonthlySummary,
}
import ui/storage/factory as storage_factory
import ui/transition
import ui/view

const step_amount: Float = 0.01

const success_feedback_delay_ms: Int = 2500

// --- Component API ---

/// Registers the lustre component while handling element changes specific to
/// only the storage backend being used.
///
pub fn register() -> lustre.App(Nil, Model, Msg) {
  lustre.component(init, update, view.view, [
    component.on_attribute_change("storage-backend", fn(value) {
      Ok(ParentUpdatedStorageBackend(value))
    }),
  ])
}

/// Registers the lustre component while handling any core attribute changes on
/// the custom element.
///
pub fn register_using_uri_query() -> lustre.App(Nil, Model, Msg) {
  lustre.component(
    init(Nil) |> init_with_flags(uri_query: True),
    update,
    view.view,
    [
      component.on_attribute_change("debug", fn(value) {
        Ok(ParentUpdatedDebug(value))
      }),
      component.on_attribute_change("demo", fn(value) {
        Ok(ParentUpdatedDemo(value))
      }),
      component.on_attribute_change("storage-backend", fn(value) {
        Ok(ParentUpdatedStorageBackend(value))
      }),
    ],
  )
}

fn init(_: Nil) -> #(Model, Effect(state.Msg)) {
  #(
    state.init(storage: storage.LocalStorage, query: False),
    keyboard_subscription_effect(),
  )
}

pub fn init_with_flags(
  init_state init_state: #(Model, Effect(state.Msg)),
  uri_query uri_query: Bool,
) -> fn(Nil) -> #(Model, Effect(state.Msg)) {
  let model = init_state.0
  let config = state.Config(..model.config, uri_query: uri_query)
  fn(_: Nil) { #(state.Model(..model, config:), init_state.1) }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // -- Debug ---
    ParentUpdatedDebug(debug) -> {
      let is_debug = debug |> string.lowercase
      let model = case is_debug {
        "true" -> model |> state.init_with_debug
        _ -> model
      }
      #(model, effect.none())
    }
    UserClickedToggleDebug -> {
      let model = model |> state.toggle_debug_transition
      #(model, effect.none())
    }
    DebugTransitionEnd(_property) -> {
      case model.debug_transition, model.debug_view {
        True, False -> {
          let model = state.Model(..model, debug_transition: False)
          #(model, effect.none())
        }
        _, _ -> #(model, effect.none())
      }
    }
    // -- Demo ---
    ParentUpdatedDemo(demo) -> {
      let is_demo = demo |> string.lowercase
      case is_demo {
        "true" -> #(
          state.init(storage: LocalStorage, query: True)
            |> state.init_with_example_payments(),
          effect.none(),
        )
        _ -> #(
          state.init(
            storage: storage.LocalStorage,
            query: model.config.uri_query,
          ),
          effect.none(),
        )
      }
    }
    // -- Storage ---
    ParentUpdatedStorageBackend(backend) -> {
      let storage = case backend {
        "indexeddb" -> {
          let attrs = do_get_attributes()
          decode.run(attrs, decode.at(["db-name"], decode.string))
          |> result.map(with: storage.IndexedDB)
          |> result.unwrap(storage.IndexedDB("payment-tracker-db"))
        }
        "sqlite" -> {
          let attrs = do_get_attributes()
          decode.run(attrs, decode.at(["db-name"], decode.string))
          |> result.map(with: storage.SQLite)
          |> result.unwrap(storage.SQLite("payment-tracker.db"))
        }
        _ -> storage.LocalStorage
      }
      let config = state.Config(..model.config, storage:)
      let model = state.Model(..model, config:)
      #(
        model,
        storage_factory.perform(
          with: config.storage,
          for: LoadUser,
          using: StorageUpdatedUser,
        ),
      )
    }
    StorageUpdatedUser(UserLoaded(Ok(user))) -> #(
      state.Model(..model, user:),
      effect.none(),
    )
    StorageUpdatedUser(UserLoaded(Error(_))) -> #(model, effect.none())
    StorageUpdatedUser(UserSaved(_)) -> #(model, effect.none())

    // -- Changing Views ---
    ViewTransitionedToAddMonthPayment(navigation_direction, date) -> {
      let back_view =
        model |> state.update_back_stack(direction: navigation_direction)
      let model =
        state.Model(
          ..model,
          current_view: AddPayment,
          back_view:,
          form_date: date,
          form_today_toggle: False,
        )
      #(model, effect.none())
    }
    ViewTransitionedToAddPayment(navigation_direction) -> {
      case model.current_view {
        AddPayment -> #(model, effect.none())
        _ -> {
          let back_view =
            model |> state.update_back_stack(direction: navigation_direction)
          let model = state.Model(..model, current_view: AddPayment, back_view:)
          #(model, effect.none())
        }
      }
    }
    ViewTransitionedToMonthlySummary(navigation_direction) -> {
      case model.current_view {
        MonthlySummary -> #(model, effect.none())
        _ -> {
          let back_view =
            model |> state.update_back_stack(direction: navigation_direction)
          let model =
            state.Model(..model, current_view: MonthlySummary, back_view:)
          #(model, effect.none())
        }
      }
    }
    ViewTransitionedToMonthlyDetail(navigation_direction, month_year) -> {
      let back_view =
        model |> state.update_back_stack(direction: navigation_direction)
      let monthly_payment =
        user.get_monthly_payment(from: model.user, for: month_year)
      case monthly_payment {
        Ok(mp) -> #(
          state.Model(..model, current_view: MonthlyDetail(mp), back_view:),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }
    }

    // -- User actions ---
    UserClickedAddMonthPayment(date) -> #(
      model,
      trigger_transition(
        using: ViewTransitionedToAddMonthPayment(state.ForwardNavigation, date),
        direction: transition.Backward,
      ),
    )
    UserClickedAddPayment -> {
      case model.current_view {
        AddPayment -> #(model, effect.none())
        _ -> #(
          model,
          trigger_transition(
            using: ViewTransitionedToAddPayment(state.ForwardNavigation),
            direction: transition.Backward,
          ),
        )
      }
    }
    UserClickedDetailedMonthView(month_year) -> #(
      model,
      trigger_transition(
        using: ViewTransitionedToMonthlyDetail(
          state.ForwardNavigation,
          month_year,
        ),
        direction: transition.Forward,
      ),
    )
    UserClickedBack -> {
      case model |> state.get_previous_view {
        None -> #(model, effect.none())
        Some(to) -> {
          let direction =
            get_transition_direction(to:, from: Some(model.current_view))
          let view_transition =
            get_view_transition(to, state.BackwardNavigation)
          #(model, trigger_transition(using: view_transition, direction:))
        }
      }
    }
    UserClickedMonthlyView -> {
      case model.current_view {
        MonthlySummary -> #(model, effect.none())
        _ -> {
          let direction =
            get_transition_direction(
              to: MonthlySummary,
              from: Some(model.current_view),
            )
          #(
            model,
            trigger_transition(
              using: ViewTransitionedToMonthlySummary(state.ForwardNavigation),
              direction:,
            ),
          )
        }
      }
    }
    // --- Add Payment View ---
    UserBlurredAmount(amount) -> {
      let model =
        amount
        |> input_amount(model)
        |> exit_to_normal_mode
      #(model, effect.none())
    }
    UserChangedPaymentDate(date_string) -> #(
      state.Model(..model, form_date: date_string),
      effect.none(),
    )
    UserClearedSuccessFeedback(expected_count) -> {
      case expected_count == model.form_success_count {
        True -> #(state.Model(..model, form_success_count: 0), effect.none())
        False -> #(model, effect.none())
      }
    }
    UserDecrementedAmount -> #(decrement_amount(model), effect.none())
    UserIncrementedAmount -> #(increment_amount(model), effect.none())
    UserInputPaymentName(name) -> #(
      state.Model(..model, form_name: name),
      effect.none(),
    )
    UserToggledShared -> #(
      toggle_form_switch(model, keymap.SharedToggle),
      effect.none(),
    )
    UserToggledToday -> #(
      toggle_form_switch(model, keymap.TodayToggle),
      effect.none(),
    )
    UserSubmittedPayment(values) -> {
      let add_payment_form =
        form.new({
          use name <- form.field(
            "payment-name",
            form.parse_string |> form.check_not_empty,
          )
          use amount <- form.field(
            "payment-price",
            form.parse_float |> form.check_float_more_than(0.0),
          )
          use category <- form.field(
            "payment-category",
            form.parse_optional(form.parse_string),
          )
          use date <- form.field("payment-date", state.parse_date())

          form.success(PaymentData(
            name:,
            amount:,
            category:,
            date:,
            shared: False,
          ))
        })

      let results =
        add_payment_form
        |> form.add_values(values)
        |> form.run()

      case results {
        Ok(payment_data) -> {
          let form_success_count = model.form_success_count + 1
          let new_payment =
            payment.Payment(
              id: utils.generate_uuid(),
              name: model.form_name,
              amount: Some(payment_data.amount),
              description: None,
              owed: True,
              shared: payment_data.shared,
              payment_date: Some(payment_data.date),
            )

          let user =
            user.add_payment(model.user, new_payment)
            |> user.sync_monthly_payments
            |> user.sync_month_payment_totals

          let model = state.Model(..model, form_success_count:, user:)
          #(
            model,
            effect.batch([
              save_user_effect(model),
              delay_msg(
                success_feedback_delay_ms,
                UserClearedSuccessFeedback(expected_count: form_success_count),
              ),
            ]),
          )
        }
        Error(_) -> {
          io.println_error("Form validation failed")
          #(model, effect.none())
        }
      }
    }
    // --- Actioning existing payments ---
    UserToggledSharedPayment(selected_payment) -> {
      let updated_payment = payment.toggle_shared(selected_payment)
      let user =
        user.update_payment(model.user, updated_payment)
        |> user.sync_monthly_payments
        |> user.sync_month_payment_totals
      let model = state.Model(..model, user:)
      #(model, save_user_effect(model))
    }
    UserClickedEditPayment(dialog)
    | UserClickedEditHomeLoanAmount(dialog)
    | UserClickedEditTransferAmount(dialog) -> #(
      state.Model(..model, dialog:),
      effect.none(),
    )
    UserDeletedPayment(selected_payment) -> {
      let user =
        user.delete_payment(model.user, selected_payment.id)
        |> user.sync_monthly_payments
        |> user.sync_month_payment_totals
      let model = state.Model(..model, user:)
      #(model, save_user_effect(model))
    }
    // --- Actioning existing monthly payments ---
    UserToggledMonthlyPaymentPaid(monthly_payment) -> {
      let paid = monthly_payment |> monthly_payment.get_paid_timestamp
      let updated_paid_status = case paid {
        Some(_) -> None
        None -> Some(instant.now() |> instant.as_timestamp)
      }
      let user =
        model.user
        |> user.update_monthly_payment(
          with: monthly_payment
          |> monthly_payment.with_paid(updated_paid_status),
        )
      let model = state.Model(..model, user:, dialog: NoDialog)
      #(model, save_user_effect(model))
    }

    // --- Dialog actions ---
    UserClosedDialog -> #(state.Model(..model, dialog: NoDialog), effect.none())
    UserSubmittedEditPayment(values, payment) -> {
      let edit_payment_form =
        form.new({
          use name <- form.field(
            "payment-name",
            form.parse_string |> form.check_not_empty,
          )
          use amount <- form.field(
            "payment-price",
            form.parse_float
              |> form.map(fn(a) { float.to_precision(a, 2) })
              |> form.check_float_more_than(0.0),
          )
          use category <- form.field(
            "payment-category",
            form.parse_optional(form.parse_string),
          )
          use date <- form.field("payment-date", state.parse_date())

          form.success(PaymentData(
            name:,
            amount:,
            category:,
            date:,
            shared: payment.shared,
          ))
        })

      let results =
        edit_payment_form
        |> form.add_values(values)
        |> form.run()

      case results {
        Ok(payment_data) -> {
          let updated_payment =
            payment
            |> payment.with_name(payment_data.name)
            |> payment.with_amount(payment_data.amount)
            |> payment.with_payment_date(Some(payment_data.date))

          let user =
            model.user
            |> user.update_payment(updated_payment)
            |> user.sync_monthly_payments
            |> user.sync_month_payment_totals

          let model = state.Model(..model, user:, dialog: NoDialog)
          #(model, save_user_effect(model))
        }
        Error(_) -> {
          io.println_error("Form validation failed")
          #(model, effect.none())
        }
      }
    }
    UserSubmittedEditMonthlyBalance(values, balance_type, monthly_payment) -> {
      let edit_monthly_balance_form =
        form.new({
          use amount <- form.field(
            "monthly-balance-amount",
            form.parse_float |> form.check_float_more_than(0.0),
          )

          form.success(amount)
        })

      let results =
        edit_monthly_balance_form
        |> form.add_values(values)
        |> form.run()

      case results {
        Ok(amount) -> {
          let mp = case balance_type {
            HomeLoan ->
              monthly_payment
              |> monthly_payment.with_home_loan_payment(Some(amount))
            AutomatedBankTransfer ->
              monthly_payment
              |> monthly_payment.with_home_loan_transfer(Some(amount))
          }
          let user = model.user |> user.update_monthly_payment(with: mp)
          let model = state.Model(..model, user:, dialog: NoDialog)
          #(model, save_user_effect(model))
        }
        Error(_) -> {
          io.println_error("Form validation failed")
          #(model, effect.none())
        }
      }
    }
    UserChangedSearchQuery(query) -> #(
      state.Model(..model, detail_search_query: query),
      effect.none(),
    )
    UserClearedSearchQuery -> #(
      state.Model(..model, detail_search_query: ""),
      effect.none(),
    )
    UserClickedSortColumn(field) -> {
      let direction = case model.detail_sort_by == field {
        True -> {
          case model.detail_sort_direction {
            sort.Asc -> sort.Desc
            sort.Desc -> sort.Asc
          }
        }
        False -> {
          case field {
            sort.Date -> sort.Desc
            _ -> sort.Asc
          }
        }
      }
      #(
        state.Model(
          ..model,
          detail_sort_by: field,
          detail_sort_direction: direction,
        ),
        effect.none(),
      )
    }
    UserFocusedTarget(target) -> {
      #(
        state.Model(..model, vim_mode: keymap.InsertMode(target)),
        effect.none(),
      )
    }
    UserBlurredTarget -> {
      #(exit_to_normal_mode(model), effect.none())
    }
    UserPressedKey(key_event, in_input) -> {
      let current_mode = case in_input {
        True ->
          case keymap.active_target(model.vim_mode) {
            Some(t) -> keymap.InsertMode(t)
            None -> keymap.InsertMode(keymap.DescriptionTextarea)
          }
        False -> keymap.to_normal_mode(model.vim_mode)
      }
      let #(resolved_action, new_prefix) =
        keymap.resolve(
          model.keymap,
          key_event,
          current_mode,
          model.pending_key_prefix,
        )
      let model = state.Model(..model, pending_key_prefix: new_prefix)
      case resolved_action {
        Some(keymap.ActivateTarget) -> {
          case keymap.active_target(model.vim_mode) {
            Some(keymap.SharedToggle as target)
            | Some(keymap.TodayToggle as target) -> {
              let model = toggle_form_switch(model, target)
              #(
                state.Model(..model, vim_mode: keymap.NormalMode(Some(target))),
                effect.none(),
              )
            }
            Some(keymap.SubmitButton) -> submit_payment_from_model(model)
            Some(target) -> {
              let selector = keymap.focus_target_to_selector(target)
              let select_all = target == keymap.PriceInput
              let model =
                state.Model(..model, vim_mode: keymap.InsertMode(target))
              #(model, focus_effect(selector, select_all, False))
            }
            None -> {
              let target = keymap.DescriptionTextarea
              let selector = keymap.focus_target_to_selector(target)
              let model =
                state.Model(..model, vim_mode: keymap.InsertMode(target))
              #(model, focus_effect(selector, False, False))
            }
          }
        }
        Some(keymap.ClearFocus) -> {
          #(
            state.Model(..model, vim_mode: keymap.NormalMode(None)),
            effect.none(),
          )
        }
        Some(keymap.FocusTarget(target)) -> {
          let selector = keymap.focus_target_to_selector(target)
          let select_all = target == keymap.PriceInput
          let model = state.Model(..model, vim_mode: keymap.InsertMode(target))
          #(model, focus_effect(selector, select_all, False))
        }
        Some(keymap.ClearAndFocusTarget(target)) -> {
          let selector = keymap.focus_target_to_selector(target)
          let select_all = target == keymap.PriceInput
          let model = case target {
            keymap.PriceInput -> state.Model(..model, form_amount: 0.0)
            keymap.DescriptionTextarea -> state.Model(..model, form_name: "")
            _ -> model
          }
          let model = state.Model(..model, vim_mode: keymap.InsertMode(target))
          #(model, focus_effect(selector, select_all, True))
        }
        Some(keymap.ToggleShared) -> {
          #(toggle_form_switch(model, keymap.SharedToggle), effect.none())
        }
        Some(keymap.ToggleToday) -> {
          #(toggle_form_switch(model, keymap.TodayToggle), effect.none())
        }
        Some(keymap.IncrementDay) -> {
          let model = adjust_form_date(model, days: 1)
          #(model, effect.none())
        }
        Some(keymap.DecrementDay) -> {
          let model = adjust_form_date(model, days: -1)
          #(model, effect.none())
        }
        Some(keymap.IncrementMonth) -> {
          let model = adjust_form_month(model, months: 1)
          #(model, effect.none())
        }
        Some(keymap.DecrementMonth) -> {
          let model = adjust_form_month(model, months: -1)
          #(model, effect.none())
        }
        Some(keymap.NavLeft) -> {
          case model.current_view {
            AddPayment -> #(
              navigate_add_payment_target(model, keymap.NavLeft),
              effect.none(),
            )
            _ -> update(model, UserClickedBack)
          }
        }
        Some(keymap.NavRight) -> {
          case model.current_view {
            AddPayment -> #(
              navigate_add_payment_target(model, keymap.NavRight),
              effect.none(),
            )
            MonthlySummary -> {
              case user.get_monthly_payments(model.user) |> list.first {
                Ok(first_mp) -> {
                  let month_year = monthly_payment.get_month_year(first_mp)
                  update(model, UserClickedDetailedMonthView(month_year))
                }
                Error(_) -> #(model, effect.none())
              }
            }
            MonthlyDetail(_) -> #(model, effect.none())
          }
        }
        Some(keymap.NavDown) | Some(keymap.NextRow) -> {
          case model.current_view {
            AddPayment -> #(
              navigate_add_payment_target(model, keymap.NavDown),
              effect.none(),
            )
            MonthlySummary -> {
              case user.get_monthly_payments(model.user) |> list.first {
                Ok(first_mp) -> {
                  let month_year = monthly_payment.get_month_year(first_mp)
                  update(model, UserClickedDetailedMonthView(month_year))
                }
                Error(_) -> #(model, effect.none())
              }
            }
            MonthlyDetail(_) -> #(model, effect.none())
          }
        }
        Some(keymap.NavUp) | Some(keymap.PreviousRow) -> {
          case model.current_view {
            AddPayment -> #(
              navigate_add_payment_target(model, keymap.NavUp),
              effect.none(),
            )
            _ -> update(model, UserClickedBack)
          }
        }
        Some(keymap.SearchTable) -> {
          let selector =
            keymap.focus_target_to_selector(keymap.TableSearchInput)
          let model =
            state.Model(
              ..model,
              vim_mode: keymap.InsertMode(keymap.TableSearchInput),
            )
          #(model, focus_effect(selector, False, False))
        }
        Some(keymap.SubmitPayment) -> {
          case model.vim_mode {
            keymap.NormalMode(Some(keymap.SharedToggle as target))
            | keymap.NormalMode(Some(keymap.TodayToggle as target)) -> #(
              toggle_form_switch(model, target),
              effect.none(),
            )
            _ -> submit_payment_from_model(model)
          }
        }
        Some(keymap.SubmitAndNavigateToMonth) -> {
          submit_and_navigate_to_month(model)
        }
        Some(keymap.GoToAddPayment) -> {
          case model.current_view {
            AddPayment -> #(model, effect.none())
            _ -> update(model, UserClickedAddPayment)
          }
        }
        Some(keymap.GoToSummary) -> {
          case model.current_view {
            MonthlySummary -> #(model, effect.none())
            _ -> update(model, UserClickedMonthlyView)
          }
        }
        Some(keymap.GoToMonthDetail) -> {
          case model.current_view {
            MonthlyDetail(_) -> #(model, effect.none())
            _ -> {
              case user.get_monthly_payments(model.user) |> list.first {
                Ok(first_mp) -> {
                  let month_year = monthly_payment.get_month_year(first_mp)
                  update(model, UserClickedDetailedMonthView(month_year))
                }
                Error(_) -> #(model, effect.none())
              }
            }
          }
        }
        Some(keymap.ShowHelp) -> {
          #(model, effect.none())
        }
        Some(keymap.ExitInsertMode) -> {
          let model =
            model
            |> exit_to_normal_mode
            |> fn(m) { state.Model(..m, pending_key_prefix: None) }
          #(model, blur_effect())
        }
        None -> #(model, effect.none())
      }
    }
  }
}

// --- Model updates ---

/// Parses a string amount and updates `form_amount` on the model, clamping
/// negative values to `0.0` and rounding to 2 decimal places.
///
fn input_amount(value: String, model: Model) -> Model {
  let form_amount =
    value
    |> float.parse
    |> result.unwrap(model.form_amount)
    |> float.to_precision(2)
  case form_amount <. 0.0 {
    True -> state.Model(..model, form_amount: 0.0)
    False -> state.Model(..model, form_amount:)
  }
}

/// Increments `form_amount` by `step_amount` (`0.01`).
///
fn increment_amount(model: Model) -> Model {
  state.Model(
    ..model,
    form_amount: model.form_amount +. step_amount |> float.to_precision(2),
  )
}

/// Decrements `form_amount` by `step_amount` (`0.01`), clamping at `0.0`.
///
fn decrement_amount(model: Model) -> Model {
  let form_amount = model.form_amount -. step_amount |> float.to_precision(2)
  case form_amount <. 0.0 {
    True -> state.Model(..model, form_amount: 0.0)
    False -> state.Model(..model, form_amount:)
  }
}

/// Toggles a boolean form switch (`SharedToggle` or `TodayToggle`) on the
/// model.
///
fn toggle_form_switch(model: Model, target: keymap.FocusTarget) -> Model {
  case target {
    keymap.SharedToggle ->
      state.Model(..model, form_shared_toggle: !model.form_shared_toggle)
    keymap.TodayToggle ->
      state.Model(..model, form_today_toggle: !model.form_today_toggle)
    _ -> model
  }
}

/// Transitions the model's `vim_mode` into `NormalMode` while retaining the
/// currently focused `FocusTarget`.
///
fn exit_to_normal_mode(model: Model) -> Model {
  state.Model(..model, vim_mode: keymap.to_normal_mode(model.vim_mode))
}

/// Moves the Normal mode virtual cursor across the Add Payment 2D `FocusGrid`
/// in the direction specified by `action`.
///
fn navigate_add_payment_target(model: Model, action: keymap.Action) -> Model {
  let current_target = keymap.active_target(model.vim_mode)
  let next_target =
    keymap.navigate_focus_target(
      keymap.add_payment_grid(),
      current_target,
      action,
    )
  state.Model(..model, vim_mode: keymap.NormalMode(next_target))
}

// --- Effects ---

/// Saves a user via an effect based on the storage method set in config.
///
fn save_user_effect(model: state.Model) -> Effect(Msg) {
  storage_factory.perform(
    with: model.config.storage,
    for: SaveUser(model.user),
    using: StorageUpdatedUser,
  )
}

/// Applies a custom delay to a message.
///
fn delay_msg(by delay: Int, msg msg: state.Msg) -> Effect(state.Msg) {
  use dispatch <- effect.from
  global.set_timeout(delay, fn() { dispatch(msg) })
  Nil
}

/// Fires off a View Transition effect for a given message using a specific
/// transition type.
///
fn trigger_transition(
  using message: state.Msg,
  direction direction: transition.TransitionType,
) -> Effect(state.Msg) {
  use dispatch <- effect.from
  transition.start(fn() { dispatch(message) }, direction)
}

// --- Helpers ---

fn get_effective_date(model: Model) -> Date {
  case model.form_today_toggle, string.is_empty(model.form_date) {
    False, False ->
      tempo_date.from_string(model.form_date)
      |> result.unwrap(tempo_date.current_local())
    _, _ -> tempo_date.current_local()
  }
}

fn adjust_form_date(model: Model, days days_offset: Int) -> Model {
  let current = get_effective_date(model)
  let updated = case days_offset >= 0 {
    True -> tempo_date.add(current, days: days_offset)
    False -> tempo_date.subtract(current, days: -days_offset)
  }
  state.Model(
    ..model,
    form_date: tempo_date.to_string(updated),
    form_today_toggle: False,
  )
}

fn adjust_form_month(model: Model, months months_offset: Int) -> Model {
  let current = get_effective_date(model)
  let #(year, month, day) = tempo_date.to_tuple(current)
  let total_months = year * 12 + month - 1 + months_offset
  let new_year = total_months / 12
  let new_month = { total_months % 12 } + 1
  let target_day = case day {
    31
      if new_month == 4 || new_month == 6 || new_month == 9 || new_month == 11
    -> 30
    _ if new_month == 2 && day > 28 -> {
      let is_leap =
        { new_year % 4 == 0 && new_year % 100 != 0 } || new_year % 400 == 0
      case is_leap {
        True -> 29
        False -> 28
      }
    }
    d -> d
  }
  let updated = case tempo_date.from_tuple(#(new_year, new_month, target_day)) {
    Ok(d) -> d
    Error(_) -> current
  }
  state.Model(
    ..model,
    form_date: tempo_date.to_string(updated),
    form_today_toggle: False,
  )
}

fn form_values_from_model(model: Model) -> List(#(String, String)) {
  let effective_date = case
    model.form_today_toggle,
    string.is_empty(model.form_date)
  {
    False, False -> model.form_date
    _, _ -> tempo_date.current_local() |> tempo_date.to_string
  }
  [
    #("payment-name", model.form_name),
    #("payment-price", float.to_string(model.form_amount)),
    #("payment-date", effective_date),
  ]
}

fn submit_payment_from_model(model: Model) -> #(Model, Effect(Msg)) {
  let values = form_values_from_model(model)
  update(model, UserSubmittedPayment(values))
}

fn submit_and_navigate_to_month(model: Model) -> #(Model, Effect(Msg)) {
  let effective_date = get_effective_date(model)
  let month_year = tempo_date.get_month_year(effective_date)
  let values = form_values_from_model(model)
  let #(new_model, submit_eff) = update(model, UserSubmittedPayment(values))
  let nav_eff =
    trigger_transition(
      using: ViewTransitionedToMonthlyDetail(
        state.ForwardNavigation,
        month_year,
      ),
      direction: transition.Forward,
    )
  #(new_model, effect.batch([submit_eff, nav_eff]))
}

fn focus_effect(
  selector: String,
  select_all: Bool,
  clear_value: Bool,
) -> Effect(Msg) {
  use _dispatch <- effect.from
  do_focus_element(selector, select_all, clear_value)
}

fn blur_effect() -> Effect(Msg) {
  use _dispatch <- effect.from
  do_blur_active_element()
}

fn keyboard_subscription_effect() -> Effect(Msg) {
  use dispatch <- effect.from
  do_subscribe_keyboard(fn(key, ctrl, alt, shift, meta, in_input) {
    let modifiers = []
    let modifiers = case ctrl {
      True -> [keymap.Control, ..modifiers]
      False -> modifiers
    }
    let modifiers = case alt {
      True -> [keymap.Alt, ..modifiers]
      False -> modifiers
    }
    let modifiers = case shift {
      True -> [keymap.Shift, ..modifiers]
      False -> modifiers
    }
    let modifiers = case meta {
      True -> [keymap.Meta, ..modifiers]
      False -> modifiers
    }
    let event = keymap.KeyEvent(key:, modifiers:)
    dispatch(state.UserPressedKey(event, in_input:))
  })
}

/// Returns the directional View Transition based on the current view and the
/// new view it is transitioning to.
///
fn get_transition_direction(
  to to: state.View,
  from from: Option(state.View),
) -> transition.TransitionType {
  case to, from {
    AddPayment, None -> transition.None
    AddPayment, _ -> transition.Backward
    MonthlySummary, Some(AddPayment) -> transition.Forward
    MonthlySummary, Some(MonthlyDetail(_)) -> transition.Backward
    MonthlySummary, _ -> transition.None
    MonthlyDetail(_), None -> transition.None
    MonthlyDetail(_), _ -> transition.Forward
  }
}

/// Maps a View to its corresponding View Transition message.
///
fn get_view_transition(
  from view: state.View,
  direction direction: state.NavigationDirection,
) -> state.Msg {
  case view {
    AddPayment -> ViewTransitionedToAddPayment(direction)
    MonthlySummary -> ViewTransitionedToMonthlySummary(direction)
    MonthlyDetail(mp) ->
      ViewTransitionedToMonthlyDetail(
        direction,
        mp |> monthly_payment.get_month_year,
      )
  }
}

// --- FFI ---

@external(javascript, "./ffi.mjs", "get_attributes")
fn do_get_attributes() -> Dynamic

@external(javascript, "./ffi.mjs", "focus_element")
fn do_focus_element(
  selector: String,
  select_all: Bool,
  clear_value: Bool,
) -> Nil

@external(javascript, "./ffi.mjs", "blur_active_element")
fn do_blur_active_element() -> Nil

@external(javascript, "./ffi.mjs", "subscribe_keyboard")
fn do_subscribe_keyboard(
  callback: fn(String, Bool, Bool, Bool, Bool, Bool) -> Nil,
) -> Nil
