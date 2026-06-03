// import dev // TESTING
import core/payment_tracker/internal/utils
import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import core/storage.{LoadUser, SaveUser, UserLoaded, UserSaved}
import formal/form
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
import ui/storage/local as local_storage
import ui/view

const step_amount: Float = 0.01

// TESTING
// pub fn main() {
//   dev.main(fn(_) {init(state.Default)}, update)
// }

pub fn main() {
  let init = fn(_: Nil) { init(using: state.Default) }
  let app = lustre.component(init, update, view.view, [])
  lustre.register(app, "payment-tracker")
}

fn init(using state: state.Init) -> #(Model, Effect(state.Msg)) {
  case state {
    state.ToMonthlyDetail -> #(
      state.init_with_example_payments(),
      effect.none(),
    )
    _ -> #(state.init(), local_storage.perform(LoadUser, StorageUpdatedUser))
  }
}

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

fn save_user_effect(user: user.User) -> Effect(Msg) {
  local_storage.perform(SaveUser(user), StorageUpdatedUser)
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

          #(state.Model(..model, user:), save_user_effect(user))
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
      #(state.Model(..model, user:), save_user_effect(user))
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
      #(state.Model(..model, user:), save_user_effect(user))
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
      #(state.Model(..model, user:, dialog: NoDialog), save_user_effect(user))
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

          #(
            state.Model(..model, user:, dialog: NoDialog),
            save_user_effect(user),
          )
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
          #(
            state.Model(..model, user:, dialog: NoDialog),
            save_user_effect(user),
          )
        }
        Error(_) -> {
          io.println_error("Form validation failed")
          #(model, effect.none())
        }
      }
    }
  }
}
