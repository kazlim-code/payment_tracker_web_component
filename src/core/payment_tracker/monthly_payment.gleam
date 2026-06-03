//// Monthly Payment represents a home loan repayment details for a calendar
//// month.
////

import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import tempo.{type MonthYear, MonthYear}
import tempo/date
import tempo/datetime

// IMPORTS ---------------------------------------------------------------------

/// Monthly payment details representing a specific month and year.
///
pub opaque type MonthlyPayment {
  MonthlyPayment(
    month_year: MonthYear,
    home_loan_transfer: Option(Float),
    home_loan_payment: Option(Float),
    paid: Option(Timestamp),
    total: Option(Float),
  )
}

/// Creates a basic monthly payment with the minimum requirements being the
/// month and year it is for.
///
pub fn new(from month_year_string: String) -> Result(MonthlyPayment, String) {
  use month_year <- result.try(parse_month_year(month_year_string))
  MonthlyPayment(
    month_year:,
    home_loan_payment: None,
    home_loan_transfer: None,
    paid: None,
    total: None,
  )
  |> Ok
}

/// Creates a list of basic monthly payment with the minimum requirements from
/// a set of month/year.
///
pub fn from_set(month_years: Set(MonthYear)) -> List(MonthlyPayment) {
  month_years
  |> set.to_list
  |> list.filter_map(fn(month_year) {
    month_year
    |> month_year_to_string
    |> new
  })
}

/// Adds a home loan payment payment amount to a monthly payment as a builder pattern.
///
pub fn with_home_loan_payment(
  using monthly_payment: MonthlyPayment,
  with home_loan_payment: Option(Float),
) -> MonthlyPayment {
  MonthlyPayment(..monthly_payment, home_loan_payment:)
}

/// Adds a home loan transfer payment amount to a monthly payment as a builder pattern.
///
pub fn with_home_loan_transfer(
  using monthly_payment: MonthlyPayment,
  with home_loan_transfer: Option(Float),
) -> MonthlyPayment {
  MonthlyPayment(..monthly_payment, home_loan_transfer:)
}

/// Adds a timestamp of when a monthly payment has been paid as a builder pattern.
///
pub fn with_paid(
  using monthly_payment: MonthlyPayment,
  with paid: Option(Timestamp),
) -> MonthlyPayment {
  MonthlyPayment(..monthly_payment, paid:)
}

/// Adds a home loan transfer payment amount to a monthly payment as a builder pattern.
///
pub fn with_total(
  using monthly_payment: MonthlyPayment,
  with total: Option(Float),
) -> MonthlyPayment {
  MonthlyPayment(..monthly_payment, total:)
}

/// Gets the month and year for the monthly payment.
///
pub fn get_month_year(from monthly_payment: MonthlyPayment) -> MonthYear {
  monthly_payment.month_year
}

/// Gets the total amount of all payments for the month.
///
pub fn get_total(from monthly_payment: MonthlyPayment) -> Option(Float) {
  monthly_payment.total
}

/// Gets the timestamp of when the monthly payment was paid.
///
pub fn get_paid_timestamp(
  from monthly_payment: MonthlyPayment,
) -> Option(Timestamp) {
  monthly_payment.paid
}

/// Gets the year for the monthly payment.
///
pub fn get_year(from monthly_payment: MonthlyPayment) -> Int {
  monthly_payment.month_year.year
}

/// Gets the home loan payment amount for the month.
///
pub fn get_home_loan_amount(
  from monthly_payment: MonthlyPayment,
) -> Option(Float) {
  monthly_payment.home_loan_payment
}

/// Gets the home loan transfer amount for the month.
///
pub fn get_home_loan_transfer(
  from monthly_payment: MonthlyPayment,
) -> Option(Float) {
  monthly_payment.home_loan_transfer
}

/// Calculates the amount owed for the month, taking into account the total of 
/// all payments, the home loan amount (split in half) and the automated bank 
/// transfer amount.
///
pub fn calculate_owed(monthly_payment: MonthlyPayment) -> Float {
  let total = monthly_payment.total |> option.unwrap(0.0)
  let home_loan_amount = monthly_payment.home_loan_payment |> option.unwrap(0.0)
  let transfer_amount = monthly_payment.home_loan_transfer |> option.unwrap(0.0)

  home_loan_amount /. 2.0 +. total -. transfer_amount
}

/// Attempts to parse a string using tempo.parse_any and return the resulting
/// MonthYear.
///
pub fn parse_month_year(from string: String) -> Result(MonthYear, String) {
  let assert Ok(year_month_regex) =
    regexp.from_string("^[1-9]\\d*-((?:0?[1-9])|(?:1[0-2]))$")
  let parse_string = case regexp.check(year_month_regex, string) {
    True -> string <> "-01"
    // Add a default day value to create a full date
    False -> string
  }
  let #(date, _, __) = tempo.parse_any(parse_string)
  case date {
    Some(date) -> date |> date.get_month_year |> Ok
    None -> Error("Failed to parse month year")
  }
}

/// Simple decoder for MonthlyPayment.
///
pub fn monthly_payment_decoder() -> decode.Decoder(MonthlyPayment) {
  use month_year_string <- decode.field("month_year", decode.string)
  use home_loan_transfer <- decode.field(
    "home_loan_transfer",
    decode.optional(decode.float),
  )
  use home_loan_payment <- decode.field(
    "home_loan_payment",
    decode.optional(decode.float),
  )
  use paid <- decode.field("paid", option_timestamp_string_decoder())
  use total <- decode.field("total", decode.optional(decode.float))
  case parse_month_year(month_year_string) {
    Ok(month_year) ->
      decode.success(MonthlyPayment(
        month_year,
        home_loan_transfer,
        home_loan_payment,
        paid,
        total,
      ))
    Error(_) ->
      decode.failure(
        MonthlyPayment(
          MonthYear(month: calendar.June, year: 1991),
          None,
          None,
          None,
          None,
        ),
        "Failed to parse a valid month value",
      )
  }
}

/// Converts MonthYear to a string of the form YYYY-MM.
///
pub fn month_year_to_string(month_year: MonthYear) -> String {
  let month_int = month_year.month |> calendar.month_to_int
  let padded_month = case month_int {
    month if month < 10 -> "0" <> int.to_string(month)
    _ -> int.to_string(month_int)
  }
  [month_year.year |> int.to_string, padded_month]
  |> string.join("-")
}

/// Converts the month of a monthly payment to its string representation.
///
pub fn month_string_from_monthly_payment(
  monthly_payment: MonthlyPayment,
) -> String {
  monthly_payment.month_year.month |> calendar.month_to_string
}

/// Converts a MonthlyPayment to a json object.
///
pub fn to_json(monthly_payment: MonthlyPayment) -> json.Json {
  json.object([
    #(
      "month_year",
      json.string(monthly_payment.month_year |> month_year_to_string),
    ),
    #("home_loan_transfer", case monthly_payment.home_loan_transfer {
      Some(transfer) -> json.float(transfer)
      None -> json.null()
    }),
    #("home_loan_payment", case monthly_payment.home_loan_payment {
      Some(payment) -> json.float(payment)
      None -> json.null()
    }),
    #("paid", case monthly_payment.paid {
      Some(paid) ->
        paid
        |> datetime.from_timestamp
        |> datetime.to_string
        |> json.string
      None -> json.null()
    }),
    #("total", case monthly_payment.total {
      Some(total) -> json.float(total)
      None -> json.null()
    }),
  ])
}

/// Transforms a json string representation of a monthly payment into a
/// MonthlyPayment.
///
pub fn from_json_string(
  json_string: String,
) -> Result(MonthlyPayment, json.DecodeError) {
  json.parse(json_string, monthly_payment_decoder())
}

/// Converts a monthly payment to a string representation.
///
pub fn to_string(monthly_payment: MonthlyPayment) -> String {
  let month = calendar.month_to_string(monthly_payment.month_year.month)
  let year = int.to_string(monthly_payment.month_year.year)
  "MonthlyPayment(month_year: MonthYear("
  <> month
  <> " "
  <> year
  <> "), home_loan_payment: "
  <> case monthly_payment.home_loan_payment {
    Some(payment) -> payment |> float.to_string
    None -> "None"
  }
  <> ", home_loan_transfer: "
  <> case monthly_payment.home_loan_transfer {
    Some(transfer) -> transfer |> float.to_string
    None -> "None"
  }
  <> ", paid: "
  <> case monthly_payment.paid {
    Some(paid) -> paid |> datetime.from_timestamp |> datetime.to_string
    None -> "None"
  }
  <> ", total: "
  <> case monthly_payment.total {
    Some(total) -> total |> float.to_string
    None -> "None"
  }
  <> ")"
}

// Tempo decoders ----------------------------------------------------------------

fn option_timestamp_string_decoder() -> decode.Decoder(Option(Timestamp)) {
  use decoded_string <- decode.then(decode.optional(decode.string))
  case decoded_string {
    Some(string) -> {
      let result_datetime = string |> datetime.from_string
      case result_datetime {
        Ok(datetime) -> Some(datetime |> datetime.to_timestamp)
        Error(_) -> None
      }
      |> decode.success
    }
    None -> decode.success(None)
  }
}
