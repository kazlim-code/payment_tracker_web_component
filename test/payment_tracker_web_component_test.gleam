import component
import core/payment_tracker/internal/sort
import core/payment_tracker/keymap.{
  Control, DateInput, DescriptionTextarea, InsertMode, KeyEvent, NormalMode,
  PriceInput, SharedToggle, SubmitButton, TodayToggle,
}
import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import core/storage.{LocalStorage}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import lustre/element
import tempo/date as tempo_date
import tempo/instant
import ui/state.{
  AddPayment, BackwardNavigation, Dialog, ForwardNavigation, MonthlyDetail,
  MonthlySummary, NoDialog, UserBlurredAmount, UserBlurredTarget,
  UserChangedPaymentDate, UserChangedSearchQuery, UserClearedSearchQuery,
  UserClickedAddMonthPayment, UserClickedAddPayment, UserClickedBack,
  UserClickedDetailedMonthView, UserClickedEditPayment, UserClickedMonthlyView,
  UserClickedSortColumn, UserClosedDialog, UserDecrementedAmount,
  UserDeletedPayment, UserFocusedTarget, UserIncrementedAmount,
  UserInputPaymentName, UserPressedKey, UserSubmittedPayment,
  UserToggledMonthlyPaymentPaid, UserToggledShared, UserToggledSharedPayment,
  UserToggledToday, ViewTransitionedToAddMonthPayment,
  ViewTransitionedToAddPayment, ViewTransitionedToMonthlyDetail,
  ViewTransitionedToMonthlySummary,
}
import ui/view

pub fn main() -> Nil {
  gleeunit.main()
}

// --- HELPERS ---

fn create_mock_model() -> state.Model {
  state.init(storage: LocalStorage, query: False)
}

// --- NAVIGATION & VIEW TESTS ---

pub fn update_navigate_to_summary_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(model, ViewTransitionedToMonthlySummary(ForwardNavigation))

  assert model.current_view == MonthlySummary
  assert model.back_view == [AddPayment]
}

pub fn update_navigate_to_summary_duplicate_test() {
  let model = create_mock_model()
  // Navigate once
  let #(model, _eff) =
    component.update(model, ViewTransitionedToMonthlySummary(ForwardNavigation))
  // Navigate again
  let #(model, _eff) =
    component.update(model, ViewTransitionedToMonthlySummary(ForwardNavigation))

  // Should not duplicate the view on stack if it's already at top
  assert model.back_view == [AddPayment]
}

pub fn update_navigate_back_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(model, ViewTransitionedToMonthlySummary(ForwardNavigation))
  let #(model, _eff) =
    component.update(model, ViewTransitionedToAddPayment(BackwardNavigation))

  assert model.current_view == AddPayment
  assert model.back_view == []
}

pub fn update_navigate_back_empty_stack_test() {
  let model = create_mock_model()
  // Stack is empty
  let #(model, _eff) =
    component.update(model, ViewTransitionedToAddPayment(BackwardNavigation))

  assert model.current_view == AddPayment
  assert model.back_view == []
}

pub fn update_navigate_back_multiple_test() {
  let model = create_mock_model()
  // Navigate: AddPayment -> MonthlySummary -> AddPayment (via button)
  let #(model, _eff) =
    component.update(model, ViewTransitionedToMonthlySummary(ForwardNavigation))
  let #(model, _eff) =
    component.update(
      model,
      ViewTransitionedToAddMonthPayment(ForwardNavigation, ""),
    )

  assert model.back_view == [MonthlySummary, AddPayment]

  // Back to MonthlySummary
  let #(model, _eff) =
    component.update(
      model,
      ViewTransitionedToMonthlySummary(BackwardNavigation),
    )
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
    component.update(
      model,
      ViewTransitionedToMonthlyDetail(ForwardNavigation, my),
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
    component.update(
      model,
      ViewTransitionedToMonthlyDetail(ForwardNavigation, my),
    )

  assert model.current_view == AddPayment
}

pub fn update_click_add_month_payment_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(
      model,
      ViewTransitionedToAddMonthPayment(ForwardNavigation, "2024-06-01"),
    )

  assert model.current_view == AddPayment
  assert model.form_date == "2024-06-01"
  assert model.form_today_toggle == False
}

pub fn update_user_clicked_monthly_view_triggers_transition_test() {
  let model = create_mock_model()
  let #(new_model, _eff) = component.update(model, UserClickedMonthlyView)

  // Model is not synchronously changed because it delegates to View Transition effect
  assert new_model.current_view == AddPayment
}

pub fn update_user_clicked_monthly_view_when_already_on_summary_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(model, ViewTransitionedToMonthlySummary(ForwardNavigation))

  let #(new_model, _eff) = component.update(model, UserClickedMonthlyView)
  assert new_model.current_view == MonthlySummary
  assert new_model.back_view == [AddPayment]
}

pub fn update_user_clicked_back_when_stack_empty_test() {
  let model = create_mock_model()
  let #(new_model, _eff) = component.update(model, UserClickedBack)

  assert new_model.current_view == AddPayment
  assert new_model.back_view == []
}

pub fn update_user_clicked_add_payment_when_already_on_add_payment_test() {
  let model = create_mock_model()
  let #(new_model, _eff) = component.update(model, UserClickedAddPayment)

  assert new_model.current_view == AddPayment
  assert new_model.back_view == []
}

pub fn update_user_clicked_add_month_payment_triggers_transition_test() {
  let model = create_mock_model()
  let #(new_model, _eff) =
    component.update(model, UserClickedAddMonthPayment("2024-06-01"))

  // Model is not synchronously changed because it delegates to View Transition effect
  assert new_model.current_view == AddPayment
  assert new_model.form_date == ""
}

pub fn update_user_clicked_detailed_month_view_triggers_transition_test() {
  let model = create_mock_model()
  let assert Ok(date) = tempo_date.from_string("2024-06-15")
  let my = tempo_date.get_month_year(date)
  let #(new_model, _eff) =
    component.update(model, UserClickedDetailedMonthView(my))

  // Model is not synchronously changed because it delegates to View Transition effect
  assert new_model.current_view == AddPayment
}

// --- FORM INPUT TESTS ---

pub fn update_input_payment_name_test() {
  let model = create_mock_model()
  let #(model, _eff) = component.update(model, UserInputPaymentName("Rent"))

  assert model.form_name == "Rent"
}

pub fn update_blurred_amount_test() {
  let model = create_mock_model()
  let #(model, _eff) = component.update(model, UserBlurredAmount("123.45"))

  assert model.form_amount == 123.45
}

pub fn update_blurred_amount_invalid_string_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 50.0)
  let #(model, _eff) = component.update(model, UserBlurredAmount("abc"))

  // Keeps old value
  assert model.form_amount == 50.0
}

pub fn update_blurred_amount_negative_test() {
  let model = create_mock_model()
  let #(model, _eff) = component.update(model, UserBlurredAmount("-10.0"))

  // Clamps to 0.0
  assert model.form_amount == 0.0
}

pub fn update_increment_amount_test() {
  let model = create_mock_model()
  let #(model, _eff) = component.update(model, UserIncrementedAmount)

  assert model.form_amount == 0.01
}

pub fn update_decrement_amount_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 1.0)
  let #(model, _eff) = component.update(model, UserDecrementedAmount)

  assert model.form_amount == 0.99
}

pub fn update_decrement_amount_clamp_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 0.0)
  let #(model, _eff) = component.update(model, UserDecrementedAmount)

  assert model.form_amount == 0.0
}

pub fn update_changed_payment_date_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(model, UserChangedPaymentDate("2024-12-25"))

  assert model.form_date == "2024-12-25"
}

pub fn update_toggled_shared_test() {
  let model = create_mock_model()
  assert model.form_shared_toggle == False

  let #(model, _eff) = component.update(model, UserToggledShared)
  assert model.form_shared_toggle == True

  let #(model, _eff) = component.update(model, UserToggledShared)
  assert model.form_shared_toggle == False
}

pub fn update_toggled_today_test() {
  let model = create_mock_model()
  assert model.form_today_toggle == True

  let #(model, _eff) = component.update(model, UserToggledToday)
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

  let #(model, _eff) = component.update(model, UserSubmittedPayment(values))

  // User should have 1 payment
  assert list.length(user.get_payments(model.user)) == 1
}

pub fn update_submitted_payment_invalid_test() {
  let model = create_mock_model()
  // Empty values or missing fields
  let values = []

  let #(model, _eff) = component.update(model, UserSubmittedPayment(values))

  assert user.get_payments(model.user) == []
}

pub fn update_toggled_shared_payment_test() {
  let model = create_mock_model()
  let p = payment.new("P1") |> payment.with_shared(False)
  let u = user.add_payment(model.user, p)
  let model = state.Model(..model, user: u)

  let #(model, _eff) = component.update(model, UserToggledSharedPayment(p))

  let assert Ok(updated_p) = user.get_payments(model.user) |> list.first
  assert updated_p.shared == True
}

pub fn update_deleted_payment_test() {
  let model = create_mock_model()
  let p = payment.new("P1")
  let u = user.add_payment(model.user, p)
  let model = state.Model(..model, user: u)

  let #(model, _eff) = component.update(model, UserDeletedPayment(p))

  assert user.get_payments(model.user) == []
}

pub fn update_deleted_payment_non_existent_test() {
  let model = create_mock_model()
  let p = payment.new("P1")
  // User has no payments

  let #(model, _eff) = component.update(model, UserDeletedPayment(p))

  assert user.get_payments(model.user) == []
}

// --- DIALOG & MONTHLY OPERATIONS ---

pub fn update_clicked_edit_payment_dialog_test() {
  let model = create_mock_model()
  let dialog = state.Dialog([], [])

  let #(model, _eff) = component.update(model, UserClickedEditPayment(dialog))

  let assert Dialog(_, _) = model.dialog
}

pub fn update_closed_dialog_test() {
  let model = create_mock_model()
  let model = state.Model(..model, dialog: state.Dialog([], []))

  let #(model, _eff) = component.update(model, UserClosedDialog)

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
    component.update(model, state.UserSubmittedEditPayment(values, p))

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
    component.update(
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
    component.update(model, UserToggledMonthlyPaymentPaid(mp))

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
    component.update(model, UserToggledMonthlyPaymentPaid(mp))

  let monthly_payments = user.get_monthly_payments(model.user)
  let assert Ok(updated_mp) = list.first(monthly_payments)
  assert monthly_payment.get_paid_timestamp(updated_mp) == None
}

pub fn update_changed_search_query_test() {
  let model = create_mock_model()
  let #(model, _eff) = component.update(model, UserChangedSearchQuery("rent"))

  assert model.detail_search_query == "rent"
}

pub fn update_cleared_search_query_test() {
  let model = create_mock_model()
  let model = state.Model(..model, detail_search_query: "rent")
  let #(model, _eff) = component.update(model, UserClearedSearchQuery)

  assert model.detail_search_query == ""
}

pub fn update_clicked_sort_column_test() {
  let model = create_mock_model()
  // Default is sort.Date, Desc
  assert model.detail_sort_by == sort.Date
  assert model.detail_sort_direction == sort.Desc

  // Click same column (Date) -> should toggle to Asc
  let #(model, _eff) = component.update(model, UserClickedSortColumn(sort.Date))
  assert model.detail_sort_by == sort.Date
  assert model.detail_sort_direction == sort.Asc

  // Click different column (Name) -> should switch to sort.Name and default direction (Asc)
  let #(model, _eff) = component.update(model, UserClickedSortColumn(sort.Name))
  assert model.detail_sort_by == sort.Name
  assert model.detail_sort_direction == sort.Asc

  // Click Name again -> toggle to Desc
  let #(model, _eff) = component.update(model, UserClickedSortColumn(sort.Name))
  assert model.detail_sort_by == sort.Name
  assert model.detail_sort_direction == sort.Desc
}

pub fn summary_view_month_order_latest_to_oldest_test() {
  let model = create_mock_model()
  let assert Ok(d1) = tempo_date.from_string("2024-01-10")
  let assert Ok(d2) = tempo_date.from_string("2024-11-05")
  let assert Ok(d3) = tempo_date.from_string("2023-08-15")

  let p1 = payment.new("Jan") |> payment.with_payment_date(Some(d1))
  let p2 = payment.new("Nov") |> payment.with_payment_date(Some(d2))
  let p3 = payment.new("Aug") |> payment.with_payment_date(Some(d3))

  let user =
    model.user
    |> user.add_payment(p1)
    |> user.add_payment(p2)
    |> user.add_payment(p3)
    |> user.sync_monthly_payments

  let model = state.Model(..model, user:)

  let month_strings =
    user.get_monthly_payments(model.user)
    |> list.map(fn(mp) {
      mp
      |> monthly_payment.get_month_year
      |> monthly_payment.month_year_to_string
    })

  assert month_strings == ["2024-11", "2024-01", "2023-08"]
}

// --- VIM & KEYBOARD NAVIGATION TESTS ---

pub fn update_user_focused_target_sets_insert_mode_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(model, UserFocusedTarget(DescriptionTextarea))

  assert model.vim_mode == InsertMode(DescriptionTextarea)
}

pub fn update_user_blurred_target_sets_normal_mode_retaining_target_test() {
  let model = create_mock_model()
  let model = state.Model(..model, vim_mode: InsertMode(PriceInput))
  let #(model, _eff) = component.update(model, UserBlurredTarget)

  assert model.vim_mode == NormalMode(Some(PriceInput))
}

pub fn update_user_pressed_key_toggle_shared_test() {
  let model = create_mock_model()
  assert model.form_shared_toggle == False

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("s", modifiers: []), in_input: False),
    )
  assert model.form_shared_toggle == True

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("s", modifiers: []), in_input: False),
    )
  assert model.form_shared_toggle == False
}

pub fn update_user_pressed_key_toggle_today_test() {
  let model = create_mock_model()
  assert model.form_today_toggle == True

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("t", modifiers: []), in_input: False),
    )
  assert model.form_today_toggle == False
}

pub fn update_user_pressed_key_day_increment_test() {
  let model = create_mock_model()
  let model =
    state.Model(..model, form_date: "2024-06-15", form_today_toggle: False)

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("]", modifiers: []), in_input: False),
    )

  assert model.form_date == "2024-06-16"
  assert model.form_today_toggle == False
}

pub fn update_user_pressed_key_day_decrement_test() {
  let model = create_mock_model()
  let model =
    state.Model(..model, form_date: "2024-06-15", form_today_toggle: False)

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("[", modifiers: []), in_input: False),
    )

  assert model.form_date == "2024-06-14"
  assert model.form_today_toggle == False
}

pub fn update_user_pressed_key_month_increment_test() {
  let model = create_mock_model()
  let model =
    state.Model(..model, form_date: "2024-06-15", form_today_toggle: False)

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("}", modifiers: []), in_input: False),
    )

  assert model.form_date == "2024-07-15"
  assert model.form_today_toggle == False
}

pub fn update_user_pressed_key_month_decrement_test() {
  let model = create_mock_model()
  let model =
    state.Model(..model, form_date: "2024-06-15", form_today_toggle: False)

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("{", modifiers: []), in_input: False),
    )

  assert model.form_date == "2024-05-15"
  assert model.form_today_toggle == False
}

pub fn update_user_pressed_key_focus_price_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("p", modifiers: []), in_input: False),
    )

  assert model.vim_mode == InsertMode(PriceInput)
}

pub fn update_user_pressed_key_focus_description_test() {
  let model = create_mock_model()
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("d", modifiers: []), in_input: False),
    )

  assert model.vim_mode == InsertMode(DescriptionTextarea)
}

pub fn update_user_pressed_key_clear_and_focus_description_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_name: "Old description")

  // First press 'c' -> pending prefix
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("c", modifiers: []), in_input: False),
    )
  assert model.pending_key_prefix == Some("c")

  // Then press 'd' -> clears description & enters insert mode
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("d", modifiers: []), in_input: False),
    )

  assert model.form_name == ""
  assert model.pending_key_prefix == None
  assert model.vim_mode == InsertMode(DescriptionTextarea)
}

pub fn update_user_pressed_key_clear_and_focus_price_test() {
  let model = create_mock_model()
  let model = state.Model(..model, form_amount: 150.0)

  // First press 'c' -> pending prefix
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("c", modifiers: []), in_input: False),
    )
  assert model.pending_key_prefix == Some("c")

  // Then press 'p' -> resets amount & enters insert mode
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("p", modifiers: []), in_input: False),
    )

  assert model.form_amount == 0.0
  assert model.pending_key_prefix == None
  assert model.vim_mode == InsertMode(PriceInput)
}

pub fn update_user_pressed_key_exit_insert_mode_retains_target_test() {
  let model = create_mock_model()
  let model = state.Model(..model, vim_mode: InsertMode(PriceInput))

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("Escape", modifiers: []), in_input: True),
    )

  assert model.vim_mode == NormalMode(Some(PriceInput))
}

pub fn update_user_pressed_key_enter_in_price_input_confirms_and_returns_to_normal_mode_test() {
  let model = create_mock_model()
  let model = state.Model(..model, vim_mode: InsertMode(PriceInput))

  // Pressing Enter while in PriceInput exits InsertMode to NormalMode(Some(PriceInput))
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("Enter", modifiers: []), in_input: True),
    )

  assert model.vim_mode == NormalMode(Some(PriceInput))

  // The triggered blur_effect dispatches UserBlurredAmount with the typed value,
  // confirming form_amount while staying in NormalMode(Some(PriceInput))
  let #(model, _eff) = component.update(model, UserBlurredAmount("42.5"))

  assert model.form_amount == 42.5
  assert model.vim_mode == NormalMode(Some(PriceInput))
}

pub fn update_user_pressed_key_submit_payment_chord_test() {
  let model = create_mock_model()
  let model =
    state.Model(
      ..model,
      form_name: "Coffee",
      form_amount: 5.5,
      form_date: "2024-06-01",
      form_today_toggle: False,
      vim_mode: InsertMode(DescriptionTextarea),
    )

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("Enter", modifiers: [Control]), in_input: True),
    )

  assert list.length(user.get_payments(model.user)) == 1
}

pub fn update_user_pressed_key_nav_down_traverses_left_column_in_normal_mode_test() {
  let model = create_mock_model()
  assert model.vim_mode == NormalMode(None)

  // 1st j -> NormalMode(Some(PriceInput)) (does NOT enter InsertMode!)
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(PriceInput))

  // 2nd j -> NormalMode(Some(SharedToggle))
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(SharedToggle))

  // 3rd j -> NormalMode(Some(TodayToggle))
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(TodayToggle))

  // 4th j -> NormalMode(Some(DateInput))
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(DateInput))

  // 5th j -> Clamped at NormalMode(Some(DateInput))
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(DateInput))
}

pub fn update_user_pressed_key_hjkl_2d_spatial_navigation_test() {
  let model = create_mock_model()

  // Initial j -> PriceInput
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(PriceInput))

  // l from PriceInput -> fast hop to DescriptionTextarea
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("l", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(DescriptionTextarea))

  // j from DescriptionTextarea -> SubmitButton
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(SubmitButton))

  // h from SubmitButton -> DateInput
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("h", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(DateInput))

  // k from DateInput -> TodayToggle
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("k", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(TodayToggle))

  // k from TodayToggle -> SharedToggle
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("k", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(SharedToggle))

  // k from SharedToggle -> PriceInput
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("k", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(PriceInput))
}

pub fn update_user_pressed_key_i_activates_focused_target_and_escape_continues_navigation_test() {
  let model = create_mock_model()

  // j -> highlights PriceInput in NormalMode
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(PriceInput))

  // i -> enters InsertMode(PriceInput)
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("i", modifiers: []), in_input: False),
    )
  assert model.vim_mode == InsertMode(PriceInput)

  // Escape -> exits to NormalMode(Some(PriceInput))
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("Escape", modifiers: []), in_input: True),
    )
  assert model.vim_mode == NormalMode(Some(PriceInput))

  // Subsequent j -> moves to SharedToggle instead of re-selecting PriceInput!
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("j", modifiers: []), in_input: False),
    )
  assert model.vim_mode == NormalMode(Some(SharedToggle))

  // i on SharedToggle -> toggles form_shared_toggle while staying in NormalMode(Some(SharedToggle))
  assert model.form_shared_toggle == False
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("i", modifiers: []), in_input: False),
    )
  assert model.form_shared_toggle == True
  assert model.vim_mode == NormalMode(Some(SharedToggle))
}

pub fn update_user_pressed_key_gp_when_on_add_payment_is_noop_test() {
  let model = create_mock_model()
  assert model.current_view == AddPayment

  // Press g then p
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("g", modifiers: []), in_input: False),
    )
  assert model.pending_key_prefix == Some("g")

  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("p", modifiers: []), in_input: False),
    )
  assert model.current_view == AddPayment
  assert model.back_view == []
}

pub fn update_user_pressed_key_gm_without_months_is_noop_test() {
  let model = create_mock_model()
  assert user.get_monthly_payments(model.user) == []

  // Press g then m
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("g", modifiers: []), in_input: False),
    )
  let #(model, _eff) =
    component.update(
      model,
      UserPressedKey(KeyEvent("m", modifiers: []), in_input: False),
    )

  // Should stay on AddPayment without any transition
  assert model.current_view == AddPayment
  assert model.back_view == []
}

pub fn footer_hints_normal_mode_includes_hjkl_nav_and_i_insert_test() {
  let model = create_mock_model()
  let html_str = view.view(model) |> element.to_string

  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[h/j/k/l]</span> Nav",
  )
  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[i]</span> Insert",
  )
  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[p/d]</span> Focus",
  )
}

pub fn footer_hints_insert_mode_on_input_shows_esc_enter_normal_and_ctrl_enter_submit_test() {
  let model = create_mock_model()
  let model = state.Model(..model, vim_mode: InsertMode(PriceInput))
  let html_str = view.view(model) |> element.to_string

  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[esc/enter]</span> Normal",
  )
  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[ctrl+enter]</span> Submit",
  )
  assert !string.contains(
    html_str,
    "<span class=\"text-primary\">[h/j/k/l]</span> Nav",
  )
}

pub fn footer_hints_insert_mode_on_textarea_shows_esc_normal_test() {
  let model = create_mock_model()
  let model = state.Model(..model, vim_mode: InsertMode(DescriptionTextarea))
  let html_str = view.view(model) |> element.to_string

  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[esc]</span> Normal",
  )
  assert string.contains(
    html_str,
    "<span class=\"text-primary\">[ctrl+enter]</span> Submit",
  )
  assert !string.contains(
    html_str,
    "<span class=\"text-primary\">[esc/enter]</span> Normal",
  )
}
