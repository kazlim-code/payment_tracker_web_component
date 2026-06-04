import core/payment_tracker/internal/utils
import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import core/storage.{LoadUser, SaveUser, UserLoaded, UserSaved}
import formal/form
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/io
import gleam/option.{None, Some}
import gleam/result
import lustre
import lustre/effect.{type Effect}
import tempo/instant
import ui/state.{
  type Model, type Msg, AddPayment, AutomatedBankTransfer, HomeLoan,
  MonthlyDetail, MonthlySummary, NoDialog, PaymentData, StorageUpdatedUser,
  UserBlurredAmount, UserChangedPaymentDate, UserClickedAddMonthPayment,
  UserClickedAddPayment, UserClickedBack, UserClickedDetailedMonthView,
  UserClickedEditHomeLoanAmount, UserClickedEditPayment,
  UserClickedEditTransferAmount, UserClickedMonthlyView, UserClosedDialog,
  UserDecrementedAmount, UserDeletedPayment, UserIncrementedAmount,
  UserInputPaymentName, UserSubmittedEditMonthlyBalance,
  UserSubmittedEditPayment, UserSubmittedPayment, UserToggledMonthlyPaymentPaid,
  UserToggledShared, UserToggledSharedPayment, UserToggledToday,
}
import ui/storage/factory as storage_factory
import ui/view

const step_amount: Float = 0.01

pub fn main() {
  // We use Nil flags for registration as required by lustre.register
  let app = lustre.component(init, update, view.view, [])
  lustre.register(app, "payment-tracker")
}

fn init(_flags: Nil) -> #(Model, Effect(state.Msg)) {
  let attrs = do_get_attributes()
  let storage_config = decode_storage_config(attrs)

  // Determine if we should load with example data (for dev/demo)
  let is_demo =
    decode.run(attrs, decode.at(["demo"], decode.bool))
    |> result.unwrap(False)

  case is_demo {
    True -> #(state.init_with_example_payments(), effect.none())
    _ -> #(
      state.init(storage_config),
      storage_factory.perform(storage_config, LoadUser, StorageUpdatedUser),
    )
  }
}

fn decode_storage_config(attrs: Dynamic) -> storage.StorageConfig {
  let backend =
    decode.run(attrs, decode.at(["storage-backend"], decode.string))
    |> result.unwrap("localstorage")

  case backend {
    "indexeddb" -> {
      let name =
        decode.run(attrs, decode.at(["db-name"], decode.string))
        |> result.unwrap("payment-tracker-db")
      storage.IndexedDB(name)
    }
    "sqlite" -> {
      let name =
        decode.run(attrs, decode.at(["db-name"], decode.string))
        |> result.unwrap("payment-tracker.db")
      storage.SQLite(name)
    }
    "remote" -> {
      let endpoint =
        decode.run(attrs, decode.at(["endpoint"], decode.string))
        |> result.unwrap("")
      let database =
        decode.run(attrs, decode.at(["database"], decode.string))
        |> option.from_result
      let auth = decode_remote_auth(attrs)
      storage.Remote(endpoint, database, auth)
    }
    _ -> storage.LocalStorage
  }
}

fn decode_remote_auth(attrs: Dynamic) -> storage.RemoteAuth {
  let token =
    decode.run(attrs, decode.at(["token"], decode.string))
    |> option.from_result

  case token {
    Some(t) -> storage.TokenAuth(t)
    None -> {
      let username =
        decode.run(attrs, decode.at(["username"], decode.string))
        |> option.from_result
      let password =
        decode.run(attrs, decode.at(["password"], decode.string))
        |> option.from_result

      case username, password {
        Some(u), Some(p) -> storage.BasicAuth(u, p)
        _, _ -> storage.NoAuth
      }
    }
  }
}

@external(javascript, "./ffi.mjs", "get_attributes")
fn do_get_attributes() -> Dynamic

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

fn increment_amount(model: Model) -> Model {
  state.Model(
    ..model,
    form_amount: model.form_amount +. step_amount |> float.to_precision(2),
  )
}

fn decrement_amount(model: Model) -> Model {
  let form_amount = model.form_amount -. step_amount |> float.to_precision(2)
  case form_amount <. 0.0 {
    True -> state.Model(..model, form_amount: 0.0)
    False -> state.Model(..model, form_amount:)
  }
}

fn save_user_effect(model: state.Model) -> Effect(Msg) {
  storage_factory.perform(
    model.storage_config,
    SaveUser(model.user),
    StorageUpdatedUser,
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // -- Storage ---
    StorageUpdatedUser(UserLoaded(Ok(user))) -> #(
      state.Model(..model, user:),
      effect.none(),
    )
    StorageUpdatedUser(UserLoaded(Error(_))) -> #(model, effect.none())
    StorageUpdatedUser(UserSaved(_)) -> #(model, effect.none())

    // -- Changing Views ---
    UserClickedAddMonthPayment(date) -> #(
      state.Model(
        ..model,
        current_view: AddPayment,
        back_view: state.add_view_to_back_stack(
          add: model.current_view,
          stack: model.back_view,
        ),
        form_date: date,
        form_today_toggle: False,
      ),
      effect.none(),
    )
    UserClickedAddPayment -> #(
      state.Model(..model, current_view: AddPayment, back_view: []),
      effect.none(),
    )
    UserClickedDetailedMonthView(month_year) -> {
      let monthly_payment =
        user.get_monthly_payment(from: model.user, for: month_year)
      case monthly_payment {
        Ok(mp) -> #(
          state.Model(
            ..model,
            current_view: MonthlyDetail(mp),
            back_view: state.add_view_to_back_stack(
              add: model.current_view,
              stack: model.back_view,
            ),
          ),
          effect.none(),
        )
        Error(_) -> #(model, effect.none())
      }
    }
    UserClickedBack -> #(
      case model.back_view {
        [] -> model
        [previous_view] ->
          state.Model(..model, current_view: previous_view, back_view: [])
        [previous_view, ..rest] ->
          state.Model(..model, current_view: previous_view, back_view: rest)
      },
      effect.none(),
    )
    UserClickedMonthlyView -> {
      case model.current_view {
        MonthlySummary -> #(model, effect.none())
        _ -> #(
          state.Model(
            ..model,
            current_view: MonthlySummary,
            back_view: state.add_view_to_back_stack(
              add: model.current_view,
              stack: model.back_view,
            ),
          ),
          effect.none(),
        )
      }
    }
    // --- Add Payment View ---
    UserBlurredAmount(amount) -> #(input_amount(amount, model), effect.none())
    UserChangedPaymentDate(date_string) -> #(
      state.Model(..model, form_date: date_string),
      effect.none(),
    )
    UserDecrementedAmount -> #(decrement_amount(model), effect.none())
    UserIncrementedAmount -> #(increment_amount(model), effect.none())
    UserInputPaymentName(name) -> #(
      state.Model(..model, form_name: name),
      effect.none(),
    )
    UserToggledShared -> #(
      state.Model(..model, form_shared_toggle: !model.form_shared_toggle),
      effect.none(),
    )
    UserToggledToday -> #(
      state.Model(..model, form_today_toggle: !model.form_today_toggle),
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
            // form.parse_string |> form.check_not_empty,
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
          let new_payment =
            payment.Payment(
              id: utils.generate_uuid(),
              name: model.form_name,
              amount: Some(payment_data.amount),
              // amount: payment_data.amount |> float.parse |> option.from_result,
              description: None,
              owed: True,
              shared: payment_data.shared,
              payment_date: Some(payment_data.date),
            )

          let user =
            user.add_payment(model.user, new_payment)
            |> user.sync_monthly_payments
            |> user.sync_month_payment_totals

          let model = state.Model(..model, user:)
          #(model, save_user_effect(model))
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
  }
}
