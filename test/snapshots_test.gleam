import birdie
import core/payment_tracker/internal/sort
import core/payment_tracker/payment
import core/payment_tracker/user
import gleam/float
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import tempo/date
import tempo/datetime

// --- HELPERS -----------------------------------------------------------------

fn create_deterministic_user() -> user.User {
  let created =
    "2024-01-01T12:00:00Z"
    |> datetime.from_string
    |> should.be_ok
    |> datetime.to_timestamp

  user.User(
    created: created,
    first_name: "Callum",
    last_name: Some("Tester"),
    payments: [],
    monthly_payments: [],
    username: "kazlim",
  )
}

fn create_deterministic_payments() -> List(payment.Payment) {
  let d1 = date.from_string("2024-06-01") |> should.be_ok
  let d2 = date.from_string("2024-06-15") |> should.be_ok
  let d3 = date.from_string("2024-07-01") |> should.be_ok

  [
    payment.Payment(
      id: "uuid-internet",
      name: "Internet",
      amount: Some(80.0),
      description: None,
      owed: True,
      shared: False,
      payment_date: Some(d1),
    ),
    payment.Payment(
      id: "uuid-groceries",
      name: "Groceries",
      amount: Some(150.0),
      description: Some("Weekly shop"),
      owed: False,
      shared: True,
      payment_date: Some(d2),
    ),
    payment.Payment(
      id: "uuid-rent",
      name: "Rent",
      amount: Some(1200.0),
      description: None,
      owed: True,
      shared: True,
      payment_date: Some(d3),
    ),
  ]
}

// --- SERIALIZATION -----------------------------------------------------------

pub fn user_serialization_snapshot_test() {
  // Arrange
  let test_user = create_deterministic_user()
  let payments = create_deterministic_payments()

  let test_user =
    list.fold(payments, test_user, user.add_payment)
    |> user.sync_monthly_payments
    |> user.sync_month_payment_totals

  // Act
  let user_json =
    test_user
    |> user.to_json
    |> json.to_string

  // Assert
  user_json
  |> birdie.snap(title: "User serialization with multiple months and payments")
}

// --- PAYMENT OPERATIONS ------------------------------------------------------

pub fn payment_sorting_snapshot_test() {
  // Arrange
  let test_user = create_deterministic_user()
  let payments = create_deterministic_payments()
  let test_user = list.fold(payments, test_user, user.add_payment)

  // Act
  let sorted_by_name =
    test_user
    |> user.get_sorted_payments(sort.Name, sort.Asc)
    |> list.map(payment.to_string)
    |> string.join("\n")

  let sorted_by_date =
    test_user
    |> user.get_sorted_payments(sort.Date, sort.Desc)
    |> list.map(payment.to_string)
    |> string.join("\n")

  // Assert
  sorted_by_name
  |> birdie.snap(title: "Payments sorted by Name (Asc)")

  sorted_by_date
  |> birdie.snap(title: "Payments sorted by Date (Desc)")
}

pub fn payment_filtering_snapshot_test() {
  // Arrange
  let test_user = create_deterministic_user()
  let payments = create_deterministic_payments()
  let test_user = list.fold(payments, test_user, user.add_payment)

  // Act
  let owed_payments =
    test_user
    |> user.get_owed_payments
    |> list.map(payment.to_string)
    |> string.join("\n")

  let shared_payments =
    test_user
    |> user.get_shared_payments
    |> list.map(payment.to_string)
    |> string.join("\n")

  // Assert
  owed_payments
  |> birdie.snap(title: "Owed payments filtering")

  shared_payments
  |> birdie.snap(title: "Shared payments filtering")
}

pub fn payment_string_snapshot_test() {
  // Arrange
  let p =
    payment.Payment(
      id: "fixed-uuid-5678",
      name: "Shared Grocery",
      amount: Some(120.5),
      description: Some("Weekly shopping at local market"),
      owed: True,
      shared: True,
      payment_date: None,
    )

  // Act & Assert
  p
  |> payment.to_string
  |> birdie.snap(title: "Payment string representation (shared & owed)")
}

// --- MONTHLY SUMMARIES -------------------------------------------------------

pub fn monthly_grouping_snapshot_test() {
  // Arrange
  let test_user = create_deterministic_user()
  let payments = create_deterministic_payments()
  let test_user =
    list.fold(payments, test_user, user.add_payment)
    |> user.sync_monthly_payments
    |> user.sync_month_payment_totals

  // Act
  let grouped =
    test_user
    |> user.get_payments_grouped_by_month
    |> list.map(fn(group) {
      let #(mp, ps) = group
      user.monthly_payments_to_string(
        user.User(..test_user, monthly_payments: [mp]),
      )
      <> "\n"
      <> "Payments: "
      <> { list.map(ps, payment.to_string) |> string.join(", ") }
    })
    |> string.join("\n---\n")

  // Assert
  grouped
  |> birdie.snap(title: "Monthly payments grouped with their payments")
}

// --- UI UTILITIES ------------------------------------------------------------

pub fn float_formatting_snapshot_test() {
  // Act
  let formats =
    [10.0, 10.5, 10.55, 10.555, 0.0, 0.1, 0.01]
    |> list.map(fn(f) {
      float.to_string(f)
      <> " -> "
      <> payment.format_float_with_decimal_padding(f)
    })
    |> string.join("\n")

  // Assert
  formats
  |> birdie.snap(title: "Float formatting with decimal padding (UI use case)")
}

// --- SYNCHRONIZATION ---------------------------------------------------------

pub fn sync_edge_cases_snapshot_test() {
  // Arrange
  let test_user = create_deterministic_user()

  // Act 1: Sync empty user
  let user1 =
    test_user
    |> user.sync_monthly_payments
    |> user.sync_month_payment_totals
    |> user.to_string

  // Act 2: Sync with payments having no dates (should not generate monthly payments)
  let p_no_date =
    payment.Payment(
      id: "no-date",
      name: "Ghost Payment",
      amount: Some(50.0),
      description: None,
      owed: True,
      shared: False,
      payment_date: None,
    )
  let user2 =
    test_user
    |> user.add_payment(p_no_date)
    |> user.sync_monthly_payments
    |> user.sync_month_payment_totals
    |> user.to_string

  // Assert
  { user1 <> "\n---\n" <> user2 }
  |> birdie.snap(title: "Syncing edge cases (empty user and dateless payments)")
}
