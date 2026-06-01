import core/payment_tracker/monthly_payment
import gleam/option.{Some}
import gleam/time/calendar
import gleeunit/should
import tempo

pub fn parse_month_year_test() {
  // Valid YYYY-MM
  monthly_payment.parse_month_year("2024-06")
  |> should.be_ok
  |> should.equal(tempo.MonthYear(month: calendar.June, year: 2024))
}

pub fn parse_month_year_single_digit_month_test() {
  // Valid YYYY-M
  monthly_payment.parse_month_year("2024-1")
  |> should.be_ok
  |> should.equal(tempo.MonthYear(month: calendar.January, year: 2024))
}

pub fn parse_month_year_invalid_format_test() {
  monthly_payment.parse_month_year("invalid")
  |> should.be_error
}

pub fn month_year_to_string_test() {
  tempo.MonthYear(month: calendar.June, year: 2024)
  |> monthly_payment.month_year_to_string
  |> should.equal("2024-06")
}

pub fn month_year_to_string_double_digit_month_test() {
  tempo.MonthYear(month: calendar.October, year: 2024)
  |> monthly_payment.month_year_to_string
  |> should.equal("2024-10")
}

pub fn month_year_to_string_single_digit_month_test() {
  tempo.MonthYear(month: calendar.January, year: 2024)
  |> monthly_payment.month_year_to_string
  |> should.equal("2024-01")
}

pub fn calculate_owed_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")

  // Full case: (2000 / 2) + 100 - 500 = 600
  mp
  |> monthly_payment.with_home_loan_payment(Some(2000.0))
  |> monthly_payment.with_home_loan_transfer(Some(500.0))
  |> monthly_payment.with_total(Some(100.0))
  |> monthly_payment.calculate_owed
  |> should.equal(600.0)
}

pub fn calculate_owed_no_values_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")
  mp
  |> monthly_payment.calculate_owed
  |> should.equal(0.0)
}

pub fn calculate_owed_negative_total_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")
  mp
  |> monthly_payment.with_total(Some(-50.0))
  |> monthly_payment.calculate_owed
  |> should.equal(-50.0)
}
