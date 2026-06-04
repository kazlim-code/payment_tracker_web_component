//// This module defines the state and message types for the Lustre application.
////

import core/payment_tracker/monthly_payment.{type MonthlyPayment}
import core/payment_tracker/payment.{type Payment}
import core/payment_tracker/user.{type User}
import core/storage.{type Response, type StorageConfig, LocalStorage}
import formal/form.{type Form}
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import tempo.{type Date, type MonthYear}
import tempo/date as tempo_date
import tempo/instant

/// Initialisation options for the application.
///
pub type Init {
  Default
  ToMonthlyDetail
}

/// The different views available in the application.
///
pub type View {
  MonthlySummary
  MonthlyDetail(MonthlyPayment)
  AddPayment
}

/// Data captured by the payment entry form.
///
pub type PaymentData {
  PaymentData(
    name: String,
    amount: Float,
    category: Option(String),
    date: Date,
    shared: Bool,
  )
}

/// The different types of monthly balances that can be edited.
///
pub type MonthlyBalance {
  HomeLoan
  AutomatedBankTransfer
}

/// Represents the state of a dialog in the UI.
///
pub type Dialog {
  NoDialog
  Dialog(
    attributes: List(attribute.Attribute(Msg)),
    children: List(Element(Msg)),
  )
}

/// The application's state model.
///
pub type Model {
  Model(
    // View
    back_view: List(View),
    current_view: View,
    // User
    user: User,
    // Storage
    storage_config: StorageConfig,
    // Dialog State
    dialog: Dialog,
    // Form State
    form_name: String,
    form_amount: Float,
    form_category: String,
    form_date: String,
    form_shared_toggle: Bool,
    form_today_toggle: Bool,
    payment_data: Form(PaymentData),
  )
}

/// Messages that can be sent to the update function to change the state.
///
pub type Msg {
  StorageUpdatedUser(Response)
  UserBlurredAmount(String)
  UserChangedPaymentDate(String)
  UserClickedAddMonthPayment(String)
  UserClickedAddPayment
  UserClickedBack
  UserClickedDetailedMonthView(MonthYear)
  UserClickedEditHomeLoanAmount(Dialog)
  UserClickedEditPayment(Dialog)
  UserClickedEditTransferAmount(Dialog)
  UserClickedMonthlyView
  UserClosedDialog
  UserDecrementedAmount
  UserDeletedPayment(Payment)
  UserIncrementedAmount
  UserInputPaymentName(String)
  UserSubmittedEditMonthlyBalance(
    List(#(String, String)),
    MonthlyBalance,
    MonthlyPayment,
  )
  UserSubmittedEditPayment(List(#(String, String)), Payment)
  UserSubmittedPayment(List(#(String, String)))
  UserToggledMonthlyPaymentPaid(MonthlyPayment)
  UserToggledShared
  UserToggledSharedPayment(Payment)
  UserToggledToday
}

/// Initialises the application state.
///
pub fn init(storage_config: StorageConfig) -> Model {
  let user = init_default_user()
  Model(
    back_view: [],
    current_view: AddPayment,
    user:,
    storage_config:,
    dialog: NoDialog,
    form_name: "",
    form_amount: 0.0,
    form_category: "",
    form_date: "",
    form_shared_toggle: False,
    form_today_toggle: True,
    payment_data: form.new({
      use name <- form.field(
        "payment-name",
        form.parse_string |> form.check_not_empty,
      )
      use amount <- form.field(
        "payment-amount",
        form.parse_float |> form.check_float_more_than(0.0),
      )
      use category <- form.field(
        "payment-category",
        form.parse_optional(form.parse_string),
      )
      use date <- form.field("payment-date", parse_date())

      form.success(PaymentData(name:, amount:, category:, date:, shared: False))
    }),
  )
}

fn init_default_user() -> User {
  user.new("Callum", "Kazlim")
}

/// Parses a date string into a Date object for use in forms.
///
pub fn parse_date() -> form.Parser(Date) {
  let fallback_error = fn(optional_message: Option(String)) {
    let error_message = case optional_message {
      Some(message) -> message
      None -> "Must be a valid date format"
    }
    Error(#(instant.now() |> instant.as_local_date, error_message))
  }

  form.parse(fn(values) {
    case values {
      [date_string, ..] -> {
        case tempo_date.parse_any(date_string) {
          Ok(date) -> Ok(date)
          Error(message) -> {
            echo message
            fallback_error(None)
          }
        }
      }
      [] -> fallback_error(Some("Must provide a date value"))
    }
  })
}

/// Adds a view to the back stack if it's not already at the top.
///
pub fn add_view_to_back_stack(
  add view: View,
  stack back: List(View),
) -> List(View) {
  case back {
    [first, ..] if view != first -> [view, ..back]
    [] -> [view]
    _ -> back
  }
}

// --- DEBUG/DEVELOPMENT ---

/// Initialises the application with example payment data for development.
///
pub fn init_with_example_payments() -> Model {
  let payments = [
    payment.new(name: "Test payment 1")
      |> payment.with_amount(15.0)
      |> payment.with_payment_date(Some(tempo_date.current_local())),
    payment.new(name: "Test payment 2")
      |> payment.with_amount(30.0)
      |> payment.with_payment_date(Some(tempo_date.current_local())),
  ]
  let user =
    init_default_user()
    |> user.with_payments(payments)
    |> user.sync_monthly_payments
    |> user.sync_month_payment_totals

  let month_year = tempo_date.current_local() |> tempo_date.get_month_year
  let monthly_payment_result = user |> user.get_monthly_payment(month_year)
  let #(current_view, user) = case monthly_payment_result {
    Ok(monthly_payment) -> {
      let mp =
        monthly_payment
        |> monthly_payment.with_home_loan_transfer(with: Some(2500.0))
      let user = user |> user.update_monthly_payment(with: mp)
      #(MonthlyDetail(mp), user)
    }
    Error(_) -> #(AddPayment, user)
  }

  Model(
    back_view: [],
    current_view:,
    user:,
    storage_config: LocalStorage,
    dialog: NoDialog,
    form_name: "",
    form_amount: 0.0,
    form_category: "",
    form_date: "",
    form_shared_toggle: False,
    form_today_toggle: True,
    payment_data: form.new({
      use name <- form.field(
        "payment-name",
        form.parse_string |> form.check_not_empty,
      )
      use amount <- form.field(
        "payment-amount",
        form.parse_float |> form.check_float_more_than(0.0),
      )
      use category <- form.field(
        "payment-category",
        form.parse_optional(form.parse_string),
      )
      use date <- form.field("payment-date", parse_date())

      form.success(PaymentData(name:, amount:, category:, date:, shared: False))
    }),
  )
}
