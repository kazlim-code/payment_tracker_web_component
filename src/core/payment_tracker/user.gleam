//// A user is a person that can hold, owe or be owed payments. They **must**
//// have a first name and use a username as their unique identifier.
////

// IMPORTS ---------------------------------------------------------------------

import core/payment_tracker/internal/sort
import core/payment_tracker/monthly_payment.{type MonthlyPayment}
import core/payment_tracker/payment.{type Payment}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import tempo.{type MonthYear}
import tempo/date
import tempo/datetime
import tempo/instant
import tempo/period

/// A person that can hold, owe or be owed payments.
///
pub type User {
  User(
    created: Timestamp,
    first_name: String,
    last_name: Option(String),
    payments: List(Payment),
    monthly_payments: List(MonthlyPayment),
    username: String,
  )
}

/// Simple User decoder.
///
pub fn user_decoder() -> decode.Decoder(User) {
  use created <- decode.field("created", timestamp_string_decoder())
  use first_name <- decode.field("first_name", decode.string)
  use last_name <- decode.field("last_name", decode.optional(decode.string))
  use payments <- decode.field(
    "payments",
    decode.list(payment.payment_decoder()),
  )
  use monthly_payments <- decode.field(
    "monthly_payments",
    decode.list(monthly_payment.monthly_payment_decoder()),
  )
  use username <- decode.field("username", decode.string)
  decode.success(User(
    created,
    first_name,
    last_name,
    payments,
    monthly_payments,
    username,
  ))
}

/// Creates a basic user with the minimum requirements of a name and username.
///
pub fn new(first_name first_name: String, username username: String) -> User {
  User(
    instant.now() |> instant.as_timestamp,
    first_name,
    None,
    [],
    [],
    username,
  )
}

/// Adds a last name to a user as a builder pattern.
///
pub fn with_last_name(user: User, last_name: String) -> User {
  User(..user, last_name: Some(last_name))
}

/// Updates the users payments as a builder pattern.
///
pub fn with_payments(user: User, payments: List(Payment)) -> User {
  User(..user, payments:)
}

/// Updates the users monthly payments as a builder pattern.
///
pub fn with_monthly_payments(
  user: User,
  monthly_payments: List(MonthlyPayment),
) -> User {
  User(..user, monthly_payments:)
}

/// Add a singular payment to the users list of payments.
///
pub fn add_payment(user: User, payment: Payment) -> User {
  User(..user, payments: list.append(user.payments, [payment]))
}

/// Removes any payments from a users list of payments if they match the payment id.
/// No changes are made if no matches for payment id are found.
///
pub fn delete_payment(user: User, payment_id: String) -> User {
  User(
    ..user,
    payments: user.payments
      |> list.filter(fn(payment) { payment.id != payment_id }),
  )
}

/// Gets all of the users payments.
///
pub fn get_payments(user: User) -> List(Payment) {
  user.payments
}

/// Gets all of the users owed payments.
///
pub fn get_owed_payments(user: User) -> List(Payment) {
  user.payments
  |> payment.get_owed()
}

/// Gets all of the users shared payments.
///
pub fn get_shared_payments(user: User) -> List(Payment) {
  user.payments
  |> payment.get_shared()
}

/// Gets a list of all the users payments for a given month/year.
///
pub fn get_payments_for_month(
  from user: User,
  for month_year: MonthYear,
) -> List(Payment) {
  use payment <- list.filter(user.payments)
  case payment.payment_date {
    Some(date) -> {
      period.from_month(month_year) |> period.contains_date(date)
    }
    None -> False
  }
}

/// Gets all of the users monthly payments.
///
pub fn get_monthly_payments(from user: User) {
  user.monthly_payments
}

/// Get a users individual monthly payment if it exists.
///
pub fn get_monthly_payment(
  from user: User,
  for month_year: MonthYear,
) -> Result(MonthlyPayment, Nil) {
  use mp <- list.find(in: user.monthly_payments)
  monthly_payment.get_month_year(mp) == month_year
}

/// Gets the set of unique MonthYear values from the users existing monthly
/// payments.
///
pub fn get_unique_month_years_from_monthly_payments(
  from user: User,
) -> Set(MonthYear) {
  user.monthly_payments
  |> list.map(monthly_payment.get_month_year)
  |> set.from_list
}

/// Gets the set of unique MonthYear values from the users existing payments.
///
pub fn get_unique_month_years_from_payments(from user: User) -> Set(MonthYear) {
  user.payments
  |> list.filter_map(fn(payment) {
    option.to_result(
      payment.payment_date |> option.map(date.get_month_year),
      "No payment date",
    )
  })
  |> set.from_list
}

/// Adds a list of monthly payments to a user.
///
pub fn append_monthly_payments(
  user: User,
  monthly_payments: List(MonthlyPayment),
) -> User {
  user
  |> with_monthly_payments(
    user.monthly_payments
    |> list.append(monthly_payments),
  )
}

/// Updates a specific monthly payment if it exists for a user.
///
pub fn update_monthly_payment(
  for user: User,
  with monthly_payment: MonthlyPayment,
) -> User {
  let update_month_year = monthly_payment |> monthly_payment.get_month_year
  let monthly_payments =
    user.monthly_payments
    |> list.map(fn(mp: MonthlyPayment) {
      let mp_month_year = mp |> monthly_payment.get_month_year
      case update_month_year == mp_month_year {
        True -> monthly_payment
        False -> mp
      }
    })
  User(..user, monthly_payments:)
}

/// Ensures there exists monthly_payments that cover all the users payment
/// dates.
///
/// It will generate any missing monthly_payments and it will remove any
/// existing monthly_payments that do not have any associated payments.
///
pub fn sync_monthly_payments(user user: User) -> User {
  let existing_months = get_unique_month_years_from_monthly_payments(user)
  let payment_months = get_unique_month_years_from_payments(user)
  let missing_months = set.difference(payment_months, existing_months)

  let new_monthly_payments = missing_months |> monthly_payment.from_set
  let monthly_payments =
    user.monthly_payments
    |> list.filter(fn(mp) {
      let month_year = mp |> monthly_payment.get_month_year
      let does_set_contain = payment_months |> set.contains(month_year)
      does_set_contain
    })

  user
  |> with_monthly_payments(
    monthly_payments |> list.append(new_monthly_payments),
  )
}

/// Updates all the users monthly payment totals by calculating the sum of 
/// payments for each month.
///
pub fn sync_month_payment_totals(user user: User) -> User {
  let monthly_payments_with_totals =
    list.map(user.monthly_payments, fn(mp) {
      let payments =
        get_payments_for_month(
          from: user,
          for: mp |> monthly_payment.get_month_year,
        )
      let total = payment.calculate_amount_total(payments)
      monthly_payment.with_total(mp, Some(total))
    })
  with_monthly_payments(user, monthly_payments_with_totals)
}

/// Gets a list of the users payments sorted by a valid payment field either in
/// ascending or descending order.
///
pub fn get_sorted_payments(
  user: User,
  field: sort.Field,
  direction: sort.Direction,
) -> List(Payment) {
  user.payments
  |> payment.sort_by(field, direction)
}

/// Gets a list payments linked to their monthly payment months.
///
pub fn get_payments_grouped_by_month(
  user: User,
) -> List(#(MonthlyPayment, List(Payment))) {
  use monthly_payment <- list.map(user.monthly_payments)
  let payments =
    get_payments_for_month(
      from: user,
      for: monthly_payment |> monthly_payment.get_month_year,
    )
  let total = payment.calculate_amount_total(payments)
  #(monthly_payment.with_total(monthly_payment, Some(total)), payments)
}

/// Updates a user payment given the id exists.
///
pub fn update_payment(user: User, payment: Payment) -> User {
  let payments =
    user
    |> get_payments
    |> list.map(fn(p) {
      case p.id == payment.id {
        True -> payment
        False -> p
      }
    })

  User(..user, payments:)
}

/// Converts a list of user payments to a single string.
///
pub fn payments_to_string(user: User) -> String {
  "["
  <> list.map(user.payments, payment.to_string) |> string.join(with: ", ")
  <> "]"
}

/// Converts a list of user monthly payments to a single string.
///
pub fn monthly_payments_to_string(user: User) -> String {
  "["
  <> list.map(user.monthly_payments, monthly_payment.to_string)
  |> string.join(with: ", ")
  <> "]"
}

/// Converts a user to a string representation.
///
pub fn to_string(user: User) -> String {
  "User(created: "
  <> user.created |> datetime.from_timestamp |> datetime.to_string
  <> "), first_name: \""
  <> user.first_name
  <> "\", last_name: "
  <> case user.last_name {
    Some(last_name) -> "\"" <> last_name <> "\""
    None -> "None"
  }
  <> ", payments: "
  <> payments_to_string(user)
  <> ", monthly_payments: "
  <> monthly_payments_to_string(user)
  <> ", username: \""
  <> user.username
  <> "\")"
}

/// Transforms a User into a json object.
///
pub fn to_json(user: User) -> json.Json {
  json.object([
    #(
      "created",
      user.created
        |> datetime.from_timestamp
        |> datetime.to_string
        |> json.string,
    ),
    #("first_name", json.string(user.first_name)),
    #("last_name", case user.last_name {
      Some(last_name) -> json.string(last_name)
      None -> json.null()
    }),
    #("payments", json.array(user.payments, payment.to_json)),
    #(
      "monthly_payments",
      json.array(user.monthly_payments, monthly_payment.to_json),
    ),
    #("username", json.string(user.username)),
  ])
}

/// Transforms a json string representation of a user into a User.
///
pub fn from_json_string(json_string: String) -> Result(User, json.DecodeError) {
  json.parse(json_string, user_decoder())
}

fn timestamp_string_decoder() -> decode.Decoder(Timestamp) {
  use decoded_string <- decode.then(decode.string)
  case decoded_string {
    string ->
      string
      |> datetime.from_string
      |> result.unwrap(instant.now() |> instant.as_local_datetime)
      |> datetime.to_timestamp
      |> decode.success
  }
}
