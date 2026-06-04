import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import core/storage.{LocalStorage}
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import payment_tracker_web_component
import tempo/date as tempo_date
import tempo/instant
import ui/state.{
  AddPayment, Dialog, MonthlyDetail, MonthlySummary, NoDialog, UserBlurredAmount,
  UserChangedPaymentDate, UserClickedAddMonthPayment, UserClickedBack,
  UserClickedDetailedMonthView, UserClickedEditPayment, UserClickedMonthlyView,
  UserClosedDialog, UserDecrementedAmount, UserDeletedPayment,
  UserIncrementedAmount, UserInputPaymentName, UserSubmittedPayment,
  UserToggledMonthlyPaymentPaid, UserToggledShared, UserToggledSharedPayment,
  UserToggledToday,
}

pub fn main() -> Nil {
  gleeunit.main()
}

// --- HELPERS ---

fn create_mock_model() -> state.Model {
  state.init(LocalStorage)
}

// --- NAVIGATION & VIEW TESTS ---

pub fn update_navigate_to_summary_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedMonthlyView)

  assert model.current_view == MonthlySummary
  assert model.back_view == [AddPayment]
}

pub fn update_navigate_to_summary_duplicate_test() {
  let model = create_mock_model()
  // Navigate once
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedMonthlyView)
  // Navigate again
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedMonthlyView)

  // Should not duplicate the view on stack if it's already at top
  assert model.back_view == [AddPayment]
}

pub fn update_navigate_back_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedMonthlyView)
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedBack)

  assert model.current_view == AddPayment
  assert model.back_view == []
}

pub fn update_navigate_back_empty_stack_test() {
  let model = create_mock_model()
  // Stack is empty
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedBack)

  assert model.current_view == AddPayment
  assert model.back_view == []
}

pub fn update_navigate_back_multiple_test() {
  let model = create_mock_model()
  // Navigate: AddPayment -> MonthlySummary -> AddPayment (via button)
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedMonthlyView)
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedAddMonthPayment(""))

  assert model.back_view == [MonthlySummary, AddPayment]

  // Back to MonthlySummary
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedBack)
  assert model.current_view == MonthlySummary
  assert model.back_view == [AddPayment]
}

pub fn update_click_detailed_month_view_test() {
  let model = create_mock_model()
  let assert Ok(date) = tempo_date.from_string("2024-06-15")
  let my = tempo_date.get_month_year(date)

  // Need a user with this month
  let p = payment.new("P1") |> payment.with_payment_date(Some(date))
  let u = user.add_payment(model.user, p) |> user.sync_monthly_payments
  let model = state.Model(..model, user: u)

  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      UserClickedDetailedMonthView(my),
    )

  let assert MonthlyDetail(mp) = model.current_view
  assert monthly_payment.month_year_to_string(monthly_payment.get_month_year(mp))
    == "2024-06"
}

pub fn update_click_detailed_month_view_missing_test() {
  let model = create_mock_model()
  let assert Ok(date) = tempo_date.from_string("2024-06-15")
  let my = tempo_date.get_month_year(date)

  // Month doesn't exist for user
  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      UserClickedDetailedMonthView(my),
    )

  assert model.current_view == AddPayment
}

pub fn update_click_add_month_payment_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      UserClickedAddMonthPayment("2024-06-01"),
    )

  assert model.current_view == AddPayment
  assert model.form_date == "2024-06-01"
  assert model.form_today_toggle == False
}

// --- FORM INPUT TESTS ---

pub fn update_input_payment_name_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserInputPaymentName("Rent"))

  assert model.form_name == "Rent"
}

pub fn update_blurred_amount_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserBlurredAmount("123.45"))

  assert model.form_amount == 123.45
}

pub fn update_blurred_amount_invalid_string_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 50.0)
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserBlurredAmount("abc"))

  // Keeps old value
  assert model.form_amount == 50.0
}

pub fn update_blurred_amount_negative_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserBlurredAmount("-10.0"))

  // Clamps to 0.0
  assert model.form_amount == 0.0
}

pub fn update_increment_amount_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserIncrementedAmount)

  assert model.form_amount == 0.01
}

pub fn update_decrement_amount_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 1.0)
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserDecrementedAmount)

  assert model.form_amount == 0.99
}

pub fn update_decrement_amount_clamp_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 0.0)
  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserDecrementedAmount)

  assert model.form_amount == 0.0
}

pub fn update_changed_payment_date_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      UserChangedPaymentDate("2024-12-25"),
    )

  assert model.form_date == "2024-12-25"
}

pub fn update_toggled_shared_test() {
  let model = create_mock_model()
  assert model.form_shared_toggle == False

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserToggledShared)
  assert model.form_shared_toggle == True

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserToggledShared)
  assert model.form_shared_toggle == False
}

pub fn update_toggled_today_test() {
  let model = create_mock_model()
  assert model.form_today_toggle == True

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserToggledToday)
  assert model.form_today_toggle == False
}

// --- PAYMENT ACTIONS & SUBMISSIONS ---

pub fn update_submitted_payment_valid_test() {
  let model = create_mock_model()
  let model =
    state.Model(
      ..model,
      form_name: "Internet",
      form_amount: 80.0,
      form_date: "2024-06-01",
    )

  let values = [
    #("payment-name", "Internet"),
    #("payment-price", "80.0"),
    #("payment-date", "2024-06-01"),
  ]

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserSubmittedPayment(values))

  // User should have 1 payment
  assert list.length(user.get_payments(model.user)) == 1
}

pub fn update_submitted_payment_invalid_test() {
  let model = create_mock_model()
  // Empty values or missing fields
  let values = []

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserSubmittedPayment(values))

  assert user.get_payments(model.user) == []
}

pub fn update_toggled_shared_payment_test() {
  let model = create_mock_model()
  let p = payment.new("P1") |> payment.with_shared(False)
  let u = user.add_payment(model.user, p)
  let model = state.Model(..model, user: u)

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserToggledSharedPayment(p))

  let assert Ok(updated_p) = user.get_payments(model.user) |> list.first
  assert updated_p.shared == True
}

pub fn update_deleted_payment_test() {
  let model = create_mock_model()
  let p = payment.new("P1")
  let u = user.add_payment(model.user, p)
  let model = state.Model(..model, user: u)

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserDeletedPayment(p))

  assert user.get_payments(model.user) == []
}

pub fn update_deleted_payment_non_existent_test() {
  let model = create_mock_model()
  let p = payment.new("P1")
  // User has no payments

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserDeletedPayment(p))

  assert user.get_payments(model.user) == []
}

// --- DIALOG & MONTHLY OPERATIONS ---

pub fn update_clicked_edit_payment_dialog_test() {
  let model = create_mock_model()
  let dialog = state.Dialog([], [])

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClickedEditPayment(dialog))

  let assert Dialog(_, _) = model.dialog
}

pub fn update_closed_dialog_test() {
  let model = create_mock_model()
  let model = state.Model(..model, dialog: state.Dialog([], []))

  let #(model, _eff) =
    payment_tracker_web_component.update(model, UserClosedDialog)

  assert model.dialog == NoDialog
}

pub fn update_submitted_edit_payment_test() {
  let model = create_mock_model()
  let p = payment.new("Old Name") |> payment.with_amount(50.0)
  let u = user.add_payment(model.user, p)
  let model = state.Model(..model, user: u)

  let values = [
    #("payment-name", "New Name"),
    #("payment-price", "100.0"),
    #("payment-date", "2024-06-01"),
  ]

  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      state.UserSubmittedEditPayment(values, p),
    )

  let assert Ok(updated_p) = user.get_payments(model.user) |> list.first
  assert updated_p.name == "New Name"
  assert updated_p.amount == Some(100.0)
}

pub fn update_submitted_edit_monthly_balance_test() {
  let model = create_mock_model()
  let assert Ok(mp) = monthly_payment.new("2024-06")
  let u = user.append_monthly_payments(model.user, [mp])
  let model = state.Model(..model, user: u)

  let values = [#("monthly-balance-amount", "2500.0")]

  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      state.UserSubmittedEditMonthlyBalance(values, state.HomeLoan, mp),
    )

  let monthly_payments = user.get_monthly_payments(model.user)
  let assert Ok(updated_mp) = list.first(monthly_payments)
  assert monthly_payment.get_home_loan_amount(updated_mp) == Some(2500.0)
}

pub fn update_toggled_monthly_payment_paid_test() {
  let model = create_mock_model()
  let assert Ok(mp) = monthly_payment.new("2024-06")
  let u = model.user |> user.append_monthly_payments([mp])
  let model = state.Model(..model, user: u)

  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      UserToggledMonthlyPaymentPaid(mp),
    )

  let monthly_payments = user.get_monthly_payments(model.user)
  let assert Ok(updated_mp) = list.first(monthly_payments)
  assert option.is_some(monthly_payment.get_paid_timestamp(updated_mp)) == True
}

pub fn update_toggled_monthly_payment_unpaid_test() {
  let model = create_mock_model()
  let assert Ok(mp) = monthly_payment.new("2024-06")
  let mp =
    mp |> monthly_payment.with_paid(Some(instant.now() |> instant.as_timestamp))
  let u = model.user |> user.append_monthly_payments([mp])
  let model = state.Model(..model, user: u)

  let #(model, _eff) =
    payment_tracker_web_component.update(
      model,
      UserToggledMonthlyPaymentPaid(mp),
    )

  let monthly_payments = user.get_monthly_payments(model.user)
  let assert Ok(updated_mp) = list.first(monthly_payments)
  assert monthly_payment.get_paid_timestamp(updated_mp) == None
}
