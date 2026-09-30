import core/payment_tracker/internal/sort
import core/payment_tracker/monthly_payment
import gleam/list
import gleam/option.{Some}
import gleam/order
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

pub fn compare_earlier_to_later_test() {
  let assert Ok(mp1) = monthly_payment.new("2024-01")
  let assert Ok(mp2) = monthly_payment.new("2024-06")
  assert monthly_payment.compare(mp1, to: mp2) == order.Lt
}

pub fn compare_same_month_year_test() {
  let assert Ok(mp1) = monthly_payment.new("2024-06")
  let assert Ok(mp2) = monthly_payment.new("2024-06")
  assert monthly_payment.compare(mp1, to: mp2) == order.Eq
}

pub fn compare_later_to_earlier_test() {
  let assert Ok(mp1) = monthly_payment.new("2025-01")
  let assert Ok(mp2) = monthly_payment.new("2024-12")
  assert monthly_payment.compare(mp1, to: mp2) == order.Gt
}

pub fn sort_by_month_year_asc_test() {
  let assert Ok(mp1) = monthly_payment.new("2024-06")
  let assert Ok(mp2) = monthly_payment.new("2023-12")
  let assert Ok(mp3) = monthly_payment.new("2025-01")

  let sorted =
    monthly_payment.sort_by_month_year([mp1, mp2, mp3], sort.Asc)
    |> list.map(fn(mp) {
      mp
      |> monthly_payment.get_month_year
      |> monthly_payment.month_year_to_string
    })

  assert sorted == ["2023-12", "2024-06", "2025-01"]
}

pub fn sort_by_month_year_desc_test() {
  let assert Ok(mp1) = monthly_payment.new("2024-06")
  let assert Ok(mp2) = monthly_payment.new("2023-12")
  let assert Ok(mp3) = monthly_payment.new("2025-01")

  let sorted =
    monthly_payment.sort_by_month_year([mp1, mp2, mp3], sort.Desc)
    |> list.map(fn(mp) {
      mp
      |> monthly_payment.get_month_year
      |> monthly_payment.month_year_to_string
    })

  assert sorted == ["2025-01", "2024-06", "2023-12"]
}

pub fn sort_by_month_year_empty_test() {
  assert monthly_payment.sort_by_month_year([], sort.Desc) == []
}

pub fn sort_by_month_year_single_test() {
  let assert Ok(mp) = monthly_payment.new("2024-06")
  assert monthly_payment.sort_by_month_year([mp], sort.Desc) == [mp]
}
