import core/payment_tracker/monthly_payment
import core/payment_tracker/payment
import core/payment_tracker/user
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import tempo/date

pub fn add_payment_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")

  let u = u |> user.add_payment(p)
  u |> user.get_payments |> list.length |> should.equal(1)
}

pub fn delete_payment_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")
  let u = u |> user.add_payment(p)

  let u = u |> user.delete_payment(p.id)
  u |> user.get_payments |> list.length |> should.equal(0)
}

pub fn delete_payment_non_existent_test() {
  let u = user.new("Test", "tester")
  let u = u |> user.delete_payment("missing")
  u |> user.get_payments |> list.length |> should.equal(0)
}

pub fn get_payments_for_month_test() {
  let u = user.new("Test", "tester")
  let d1 = date.from_string("2024-06-01") |> should.be_ok
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let u = u |> user.add_payment(p1)

  let june = date.get_month_year(d1)
  u |> user.get_payments_for_month(june) |> list.length |> should.equal(1)
}

pub fn get_payments_for_month_empty_test() {
  let u = user.new("Test", "tester")
  let d1 = date.from_string("2024-06-01") |> should.be_ok
  let june = date.get_month_year(d1)
  u |> user.get_payments_for_month(june) |> list.length |> should.equal(0)
}

pub fn get_payments_for_month_mismatch_test() {
  let u = user.new("Test", "tester")
  let d1 = date.from_string("2024-06-01") |> should.be_ok
  let d2 = date.from_string("2024-07-01") |> should.be_ok
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let u = u |> user.add_payment(p1)

  let july = date.get_month_year(d2)
  u |> user.get_payments_for_month(july) |> list.length |> should.equal(0)
}

pub fn sync_monthly_payments_test() {
  let u = user.new("Test", "tester")
  let d1 = date.from_string("2024-06-01") |> should.be_ok
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let u = u |> user.add_payment(p1)

  let u = u |> user.sync_monthly_payments
  u |> user.get_monthly_payments |> list.length |> should.equal(1)
}

pub fn sync_monthly_payments_remove_unused_test() {
  let u = user.new("Test", "tester")
  let d1 = date.from_string("2024-06-01") |> should.be_ok
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))

  let u = u |> user.add_payment(p1) |> user.sync_monthly_payments
  let u = u |> user.delete_payment(p1.id) |> user.sync_monthly_payments
  u |> user.get_monthly_payments |> list.length |> should.equal(0)
}

pub fn sync_monthly_payments_no_payments_test() {
  let u = user.new("Test", "tester")
  let u = u |> user.sync_monthly_payments
  u |> user.get_monthly_payments |> list.length |> should.equal(0)
}

pub fn update_payment_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")
  let u = u |> user.add_payment(p)

  let updated_p = p |> payment.with_name("Updated P1")
  let u = u |> user.update_payment(updated_p)

  let payments = u |> user.get_payments
  let assert Ok(first) = list.first(payments)
  first.name |> should.equal("Updated P1")
}

pub fn update_payment_non_existent_test() {
  let u = user.new("Test", "tester")
  let p = payment.new("P1")
  let u = u |> user.update_payment(p)
  u |> user.get_payments |> list.length |> should.equal(0)
}

pub fn user_sync_integration_test() {
  let test_user = user.new("Test", "tester")
  let date = date.from_string("2024-06-15") |> should.be_ok

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
  mp |> monthly_payment.get_total |> should.equal(Some(200.0))
}
