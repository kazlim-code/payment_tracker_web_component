import core/payment_tracker/internal/sort
import core/payment_tracker/payment
import gleam/list
import gleam/option.{None, Some}
import tempo/date

pub fn sort_by_name_test() {
  let p1 = payment.new("C")
  let p2 = payment.new("A")
  let p3 = payment.new("B")
  let payments = [p1, p2, p3]

  assert payment.sort_by(payments, sort.Name, sort.Asc)
  |> payment.get_names == ["C", "B", "A"]
}

pub fn sort_by_name_desc_test() {
  let p1 = payment.new("C")
  let p2 = payment.new("A")
  let p3 = payment.new("B")
  let payments = [p1, p2, p3]

  assert payment.sort_by(payments, sort.Name, sort.Desc)
  |> payment.get_names == ["A", "B", "C"]
}

pub fn sort_by_name_empty_list_test() {
  assert payment.sort_by([], sort.Name, sort.Asc) == []
}

pub fn sort_by_date_test() {
  let assert Ok(d1) = date.from_string("2024-06-01")
  let assert Ok(d2) = date.from_string("2024-06-15")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let p2 = payment.new("P2") |> payment.with_payment_date(Some(d2))

  assert payment.sort_by([p1, p2], sort.Date, sort.Asc)
  |> list.map(fn(p) { p.name }) == ["P2", "P1"]
}

pub fn sort_by_date_desc_test() {
  let assert Ok(d1) = date.from_string("2024-06-01")
  let assert Ok(d2) = date.from_string("2024-06-15")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let p2 = payment.new("P2") |> payment.with_payment_date(Some(d2))

  assert payment.sort_by([p1, p2], sort.Date, sort.Desc)
  |> list.map(fn(p) { p.name }) == ["P1", "P2"]
}

pub fn sort_by_date_with_none_test() {
  let assert Ok(d1) = date.from_string("2024-06-01")
  let p1 = payment.new("P1") |> payment.with_payment_date(Some(d1))
  let p2 = payment.new("P2")
  // No date

  assert payment.sort_by([p1, p2], sort.Date, sort.Asc)
  |> list.map(fn(p) { p.name }) == ["P1", "P2"]
}

pub fn with_amount_string_test() {
  let p = payment.new("Test")

  assert p
  |> payment.with_amount_string("123.45")
  |> payment.calculate_display_amount == Some(123.45)
}

pub fn with_amount_string_int_test() {
  let p = payment.new("Test")
  assert p
  |> payment.with_amount_string("100")
  |> payment.calculate_display_amount == Some(100.0)
}

pub fn with_amount_string_invalid_test() {
  let p = payment.new("Test")
  assert p
  |> payment.with_amount_string("abc")
  |> payment.calculate_display_amount == None
}

pub fn calculate_display_amount_test() {
  let p = payment.new("Test") |> payment.with_amount(100.0)

  assert p
  |> payment.with_shared(False)
  |> payment.calculate_display_amount == Some(100.0)
}

pub fn calculate_display_amount_shared_test() {
  let p = payment.new("Test") |> payment.with_amount(100.0)
  assert p
  |> payment.with_shared(True)
  |> payment.calculate_display_amount == Some(50.0)
}

pub fn calculate_display_amount_none_test() {
  assert payment.new("Test")
  |> payment.calculate_display_amount == None
}

pub fn calculate_amount_total_test() {
  let p1 = payment.new("P1") |> payment.with_amount(100.0)
  let p2 =
    payment.new("P2") |> payment.with_amount(200.0) |> payment.with_shared(True)

  assert [p1, p2]
  |> payment.calculate_amount_total == 200.0
}

pub fn calculate_amount_total_empty_test() {
  assert []
  |> payment.calculate_amount_total == 0.0
}

pub fn calculate_amount_total_no_amounts_test() {
  assert [payment.new("P1"), payment.new("P2")]
  |> payment.calculate_amount_total == 0.0
}

pub fn format_float_with_decimal_padding_test() {
  assert payment.format_float_with_decimal_padding(10.5) == "10.50"
}

pub fn format_float_with_decimal_padding_whole_test() {
  assert payment.format_float_with_decimal_padding(10.0) == "10.00"
}

pub fn format_float_with_decimal_padding_round_test() {
  assert payment.format_float_with_decimal_padding(10.555) == "10.56"
}

pub fn format_amount_to_currency_string_test() {
  assert payment.format_amount_to_currency_string(Some(123.45)) == "$123.45"
}

pub fn format_amount_to_currency_string_none_test() {
  assert payment.format_amount_to_currency_string(None) == "-"
}

pub fn format_amount_to_currency_string_zero_test() {
  assert payment.format_amount_to_currency_string(Some(0.0)) == "$0.00"
}
