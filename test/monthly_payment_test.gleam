import core/payment_tracker/monthly_payment
import gleam/option.{Some}
import gleam/result
import gleam/time/calendar
import tempo

pub fn parse_month_year_test() {
  // Valid YYYY-MM
  let assert Ok(res) = monthly_payment.parse_month_year("2024-06")
  assert res == tempo.MonthYear(month: calendar.June, year: 2024)
}

pub fn parse_month_year_single_digit_month_test() {
  // Valid YYYY-M
  let assert Ok(res) = monthly_payment.parse_month_year("2024-1")
  assert res == tempo.MonthYear(month: calendar.January, year: 2024)
}

pub fn parse_month_year_invalid_format_test() {
  assert monthly_payment.parse_month_year("invalid") |> result.is_error
}

pub fn month_year_to_string_test() {
  assert monthly_payment.month_year_to_string(tempo.MonthYear(
      month: calendar.June,
      year: 2024,
    ))
    == "2024-06"
}

pub fn month_year_to_string_double_digit_month_test() {
  assert monthly_payment.month_year_to_string(tempo.MonthYear(
      month: calendar.October,
      year: 2024,
    ))
    == "2024-10"
}

pub fn month_year_to_string_single_digit_month_test() {
  assert monthly_payment.month_year_to_string(tempo.MonthYear(
      month: calendar.January,
      year: 2024,
    ))
    == "2024-01"
}

pub fn calculate_owed_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")

  // Full case: (2000 / 2) + 100 - 500 = 600
  assert monthly_payment.calculate_owed(
      mp
      |> monthly_payment.with_home_loan_payment(Some(2000.0))
      |> monthly_payment.with_home_loan_transfer(Some(500.0))
      |> monthly_payment.with_total(Some(100.0)),
    )
    == 600.0
}

pub fn calculate_owed_no_values_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")
  assert monthly_payment.calculate_owed(mp) == 0.0
}

pub fn calculate_owed_negative_total_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")
  assert monthly_payment.calculate_owed(
      mp |> monthly_payment.with_total(Some(-50.0)),
    )
    == -50.0
}
