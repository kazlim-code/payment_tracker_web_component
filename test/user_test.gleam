import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import gleam/list
import gleam/option.{Some}
import tempo/date

pub fn add_payment_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")

  let u = u |> user.add_payment(p)
  assert list.length(user.get_payments(u)) == 1
}

pub fn delete_payment_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")
  let u = u |> user.add_payment(p)

  let u = u |> user.delete_payment(p.id)
  assert user.get_payments(u) == []
}

pub fn delete_payment_non_existent_test() {
  let u = user.new("Test", "tester")
  let u = u |> user.delete_payment("missing")
  assert user.get_payments(u) == []
}

pub fn get_payments_for_month_test() {
  let u = user.new("Test", "tester")
  let assert Ok(d1) = date.from_string("2024-06-01")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let u = u |> user.add_payment(p1)

  let june = date.get_month_year(d1)
  assert list.length(user.get_payments_for_month(u, june)) == 1
}

pub fn get_payments_for_month_empty_test() {
  let u = user.new("Test", "tester")
  let assert Ok(d1) = date.from_string("2024-06-01")
  let june = date.get_month_year(d1)
  assert user.get_payments_for_month(u, june) == []
}

pub fn get_payments_for_month_mismatch_test() {
  let u = user.new("Test", "tester")
  let assert Ok(d1) = date.from_string("2024-06-01")
  let assert Ok(d2) = date.from_string("2024-07-01")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let u = u |> user.add_payment(p1)

  let july = date.get_month_year(d2)
  assert user.get_payments_for_month(u, july) == []
}

pub fn sync_monthly_payments_test() {
  let u = user.new("Test", "tester")
  let assert Ok(d1) = date.from_string("2024-06-01")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let u = u |> user.add_payment(p1)

  let u = u |> user.sync_monthly_payments
  assert list.length(user.get_monthly_payments(u)) == 1
}

pub fn sync_monthly_payments_remove_unused_test() {
  let u = user.new("Test", "tester")
  let assert Ok(d1) = date.from_string("2024-06-01")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))

  let u = u |> user.add_payment(p1) |> user.sync_monthly_payments
  let u = u |> user.delete_payment(p1.id) |> user.sync_monthly_payments
  assert user.get_monthly_payments(u) == []
}

pub fn sync_monthly_payments_no_payments_test() {
  let u = user.new("Test", "tester")
  let u = u |> user.sync_monthly_payments
  assert user.get_monthly_payments(u) == []
}

pub fn update_payment_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")
  let u = u |> user.add_payment(p)

  let updated_p = p |> payment.with_name("Updated P1")
  let u = u |> user.update_payment(updated_p)

  let payments = u |> user.get_payments
  let assert Ok(first) = list.first(payments)
  assert first.name == "Updated P1"
}

pub fn update_payment_non_existent_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")
  let u = u |> user.update_payment(p)
  assert user.get_payments(u) == []
}

pub fn user_sync_integration_test() {
  let test_user = user.new("Test", "tester")
  let assert Ok(date) = date.from_string("2024-06-15")

  let p1 =
    payment.new("P1")
    |> payment.with_amount(100.0)
    |> payment.with_payment_date(Some(date))
  let p2 =
    payment.new("P2")
    |> payment.with_amount(200.0)
    |> payment.with_payment_date(Some(date))
    |> payment.with_shared(True)

  let test_user =
    test_user
    |> user.add_payment(p1)
    |> user.add_payment(p2)
    |> user.sync_monthly_payments
    |> user.sync_month_payment_totals

  let monthly_payments = user.get_monthly_payments(test_user)
  let assert Ok(mp) = list.first(monthly_payments)
  assert monthly_payment.get_total(mp) == Some(200.0)
}
