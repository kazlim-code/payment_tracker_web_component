//// This module defines the state and message types for the Lustre application.
////

import core/payment_tracker/internal/sort
import core/payment_tracker/monthly_payment.{type MonthlyPayment}
import core/payment_tracker/payment.{type Payment}
import core/payment_tracker/user.{type User}
import core/storage.{type Response, type StorageConfig}
import formal/form.{type Form}
import gleam/option.{type Option, None, Some}
import gleam/pair
import lustre/attribute
import lustre/element.{type Element}
import tempo.{type Date, type MonthYear}
import tempo/date as tempo_date
import tempo/instant

/// Initial configuration options including storage, flag and debug options.
///
pub type Config {
  Config(storage: StorageConfig, uri_query: Bool, debug: Bool)
}

/// The different views available in the application.
///
pub type View {
  MonthlySummary
  MonthlyDetail(MonthlyPayment)
  AddPayment
}

/// The direction of the view change. Useful for determining if the user has
/// clicked 'back'.
///
pub type NavigationDirection {
  ForwardNavigation
  BackwardNavigation
  NoNavigation
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
    // Config
    config: Config,
    // View
    back_view: List(View),
    current_view: View,
    debug_transition: Bool,
    debug_view: Bool,
    // User
    user: User,
    // Dialog State
    dialog: Dialog,
    // Form State
    form_name: String,
    form_amount: Float,
    form_category: String,
    form_date: String,
    form_shared_toggle: Bool,
    form_today_toggle: Bool,
    form_success_count: Int,
    payment_data: Form(PaymentData),
    // Sorting & Filtering State
    detail_search_query: String,
    detail_sort_by: sort.Field,
    detail_sort_direction: sort.Direction,
  )
}

/// Messages that can be sent to the update function to change the state.
///
pub type Msg {
  DebugTransitionEnd(String)
  ParentUpdatedDebug(String)
  ParentUpdatedDemo(String)
  ParentUpdatedStorageBackend(String)
  StorageUpdatedUser(Response)
  UserBlurredAmount(String)
  UserChangedPaymentDate(String)
  UserClearedSuccessFeedback(expected_count: Int)
  UserClickedAddMonthPayment(String)
  UserClickedAddPayment
  UserClickedBack
  UserClickedDetailedMonthView(MonthYear)
  UserClickedEditHomeLoanAmount(Dialog)
  UserClickedEditPayment(Dialog)
  UserClickedEditTransferAmount(Dialog)
  UserClickedMonthlyView
  UserClickedToggleDebug
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
  UserChangedSearchQuery(String)
  UserClearedSearchQuery
  UserClickedSortColumn(sort.Field)
  ViewTransitionedToAddPayment(NavigationDirection)
  ViewTransitionedToAddMonthPayment(NavigationDirection, String)
  ViewTransitionedToMonthlySummary(NavigationDirection)
  ViewTransitionedToMonthlyDetail(NavigationDirection, MonthYear)
}

/// Initialises the application state.
///
pub fn init(storage storage: StorageConfig, query uri_query: Bool) -> Model {
  let user = init_default_user()
  Model(
    config: Config(storage:, uri_query:, debug: False),
    back_view: [],
    current_view: AddPayment,
    debug_transition: False,
    debug_view: False,
    user:,
    dialog: NoDialog,
    form_name: "",
    form_amount: 0.0,
    form_category: "",
    form_date: "",
    form_shared_toggle: False,
    form_today_toggle: True,
    form_success_count: 0,
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
    detail_search_query: "",
    detail_sort_by: sort.Date,
    detail_sort_direction: sort.Desc,
  )
}

/// Initialises the application in debug mode.
///
pub fn init_with_debug(model: Model) -> Model {
  Model(..model, config: Config(..model.config, debug: True), debug_view: True)
}

/// Initialises the application with example payment data for development.
///
pub fn init_with_example_payments(model: Model) -> Model {
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

  Model(..model, current_view:, user:)
}

/// Creates a default user for test environments.
///
fn init_default_user() -> User {
  user.new("John Doe", "TestAccount")
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
  stack back: List(View),
  add view: View,
) -> List(View) {
  case back {
    [first, ..] if view != first -> [view, ..back]
    [] -> [view]
    _ -> back
  }
}

/// Pops the top view from the back stack if one exists.
///
pub fn pop_view_to_back_stack(
  stack back: List(View),
) -> #(Option(View), List(View)) {
  case back {
    [first, ..rest] -> #(Some(first), rest)
    _ -> #(None, [])
  }
}

/// Updates back history stack based on forward/backward navigation.
///
pub fn update_back_stack(
  model model: Model,
  direction navigation_direction: NavigationDirection,
) -> List(View) {
  case navigation_direction {
    ForwardNavigation ->
      add_view_to_back_stack(add: model.current_view, stack: model.back_view)
    BackwardNavigation ->
      model.back_view |> pop_view_to_back_stack |> pair.second
    _ -> model.back_view
  }
}

/// Updates the debug transition show/hide state.
///
pub fn toggle_debug_transition(model: Model) -> Model {
  let debug_view = !model.debug_view
  let debug_transition = True
  Model(..model, debug_transition:, debug_view:)
}

/// Gets the previous view in the back view stack if one exists.
///
pub fn get_previous_view(model model: Model) -> Option(View) {
  case model.back_view {
    [] -> None
    [previous_view] -> Some(previous_view)
    [previous_view, ..] -> Some(previous_view)
  }
}
