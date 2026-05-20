//// Payments that can be owed/shared as well as whether or not they are tied to
//// a specific user, either a payment to or a payment from.
////
//// A payment with owed - true means that the payment still needs to be payed
//// back while shared - true means that the payment is split with another person
//// and therefore the payment amount is halved.
////

// IMPORTS ---------------------------------------------------------------------

import core/payment_tracker/internal/sort
import core/payment_tracker/internal/utils
import gleam/bool
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import gleam/string
import tempo.{type Date}
import tempo/date

// TYPES -----------------------------------------------------------------------

pub type Payment {
  Payment(
    id: String,
    amount: Option(Float),
    name: String,
    description: Option(String),
    owed: Bool,
    shared: Bool,
    payment_date: Option(Date),
  )
  PaymentTo(
    id: String,
    amount: Option(Float),
    name: String,
    description: Option(String),
    owed: Bool,
    shared: Bool,
    payment_date: Option(Date),
    to_user: String,
  )
  PaymentFrom(
    id: String,
    amount: Option(Float),
    name: String,
    description: Option(String),
    owed: Bool,
    shared: Bool,
    payment_date: Option(Date),
    from_user: String,
  )
}

// DECODERS --------------------------------------------------------------------

/// Payment decoder that can distinguish between different payment types.
///
pub fn payment_decoder() -> decode.Decoder(Payment) {
  use id <- decode.field("id", decode.string)
  use amount <- decode.field("amount", decode.optional(decode.float))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use owed <- decode.field("owed", decode.bool)
  use shared <- decode.field("shared", decode.bool)
  use payment_date <- decode.field(
    "payment_date",
    decode.optional(date_string_decoder()),
  )
  use to_user <- decode.optional_field(
    "to_user",
    None,
    decode.optional(decode.string),
  )
  use from_user <- decode.optional_field(
    "from_user",
    None,
    decode.optional(decode.string),
  )

  case to_user, from_user {
    Some(to), _ ->
      decode.success(PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user: to,
      ))
    _, Some(from) ->
      decode.success(PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user: from,
      ))
    _, _ ->
      decode.success(Payment(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
      ))
  }
}

// FUNCTIONS -------------------------------------------------------------------

/// Creates a basic payment. Only a name is required for a payment, it can be
/// updated later with further details such as an amount or whether or not it
/// has been payed.
///
pub fn new(name name: String) -> Payment {
  let id = utils.generate_uuid()
  Payment(id, None, name, None, False, False, None)
}

/// Updates the name of a payment with the builder pattern.
///
pub fn with_name(payment: Payment, name: String) -> Payment {
  case payment {
    Payment(id, amount, _, description, owed, shared, payment_date) ->
      Payment(id, amount, name, description, owed, shared, payment_date)
    PaymentTo(id, amount, _, description, owed, shared, payment_date, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(
      id,
      amount,
      _,
      description,
      owed,
      shared,
      payment_date,
      from_user,
    ) ->
      PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Adds a price amount to a payment as a builder pattern.
///
pub fn with_amount(payment: Payment, amount: Float) -> Payment {
  case payment {
    Payment(id, _, name, description, owed, shared, payment_date) ->
      Payment(id, Some(amount), name, description, owed, shared, payment_date)
    PaymentTo(id, _, name, description, owed, shared, payment_date, to_user) ->
      PaymentTo(
        id,
        Some(amount),
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(id, _, name, description, owed, shared, payment_date, from_user) ->
      PaymentFrom(
        id,
        Some(amount),
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Attempts to convert a price amount from a string to a float to add the
/// amount to a payment as a builder pattern.
///
/// If the conversion fails, the original payment is returned.
///
pub fn with_amount_string(payment: Payment, amount_string: String) -> Payment {
  let amount_float = case int.parse(amount_string) {
    Ok(amount_int) -> Ok(int.to_float(amount_int))
    Error(_) -> float.parse(amount_string)
  }

  // If amount is not valid, return original payment
  case amount_float {
    Ok(amount) -> with_amount(payment, amount)
    Error(_) -> payment
  }
}

/// Adds a description to a payment as a builder pattern.
///
pub fn with_description(payment: Payment, description: String) -> Payment {
  case payment {
    Payment(id, amount, name, _, owed, shared, payment_date) ->
      Payment(id, amount, name, Some(description), owed, shared, payment_date)
    PaymentTo(id, amount, name, _, owed, shared, payment_date, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        Some(description),
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(id, amount, name, _, owed, shared, payment_date, from_user) ->
      PaymentFrom(
        id,
        amount,
        name,
        Some(description),
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Adds whether the payment is still owed to the payment state as a builder
/// pattern.
///
pub fn with_owed(payment: Payment, owed: Bool) -> Payment {
  case payment {
    Payment(id, amount, name, description, _, shared, payment_date) ->
      Payment(id, amount, name, description, owed, shared, payment_date)
    PaymentTo(id, amount, name, description, _, shared, payment_date, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(
      id,
      amount,
      name,
      description,
      _,
      shared,
      payment_date,
      from_user,
    ) ->
      PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Adds whether the payment is shared with another person to the payment state
/// as a builder pattern.
///
pub fn with_shared(payment: Payment, shared: Bool) -> Payment {
  case payment {
    Payment(id, amount, name, description, owed, _, payment_date) ->
      Payment(id, amount, name, description, owed, shared, payment_date)
    PaymentTo(id, amount, name, description, owed, _, payment_date, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(id, amount, name, description, owed, _, payment_date, from_user) ->
      PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Adds the date that the payment was initially made to the payment state as a
/// builder pattern.
///
pub fn with_payment_date(
  payment: Payment,
  payment_date: Option(Date),
) -> Payment {
  case payment {
    Payment(id, amount, name, description, owed, shared, _) ->
      Payment(id, amount, name, description, owed, shared, payment_date)
    PaymentTo(id, amount, name, description, owed, shared, _, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(id, amount, name, description, owed, shared, _, from_user) ->
      PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Converts a payment to a string representation.
///
pub fn to_string(payment: Payment) {
  case payment {
    Payment(id, amount, name, description, owed, shared, payment_date) ->
      "Payment(id: \""
      <> id
      <> "\", name: "
      <> name
      <> "\", description: "
      <> case description {
        Some(desc) -> "\"" <> desc <> "\""
        None -> "None"
      }
      <> ", amount: "
      <> case amount {
        Some(cost) -> float.to_string(cost)
        None -> "None"
      }
      <> ", owed: "
      <> bool.to_string(owed)
      <> ", shared: "
      <> bool.to_string(shared)
      <> ", payment_date: "
      <> case payment_date {
        Some(date) -> date.to_string(date)
        None -> "None"
      }
      <> ")"
    PaymentTo(
      id,
      amount,
      name,
      description,
      owed,
      shared,
      payment_date,
      to_user,
    ) ->
      "Payment(id: \""
      <> id
      <> "\", name: "
      <> name
      <> "\", description: "
      <> case description {
        Some(desc) -> "\"" <> desc <> "\""
        None -> "None"
      }
      <> ", amount: "
      <> case amount {
        Some(cost) -> float.to_string(cost)
        None -> "None"
      }
      <> ", owed: "
      <> bool.to_string(owed)
      <> ", shared: "
      <> bool.to_string(shared)
      <> ", payment_date: "
      <> case payment_date {
        Some(date) -> date.to_string(date)
        None -> "None"
      }
      <> ", to_user: "
      <> to_user
      <> ")"
    PaymentFrom(
      id,
      amount,
      name,
      description,
      owed,
      shared,
      payment_date,
      from_user,
    ) ->
      "Payment(id: \""
      <> id
      <> "\", name: "
      <> name
      <> "\", description: "
      <> case description {
        Some(desc) -> "\"" <> desc <> "\""
        None -> "None"
      }
      <> ", amount: "
      <> case amount {
        Some(cost) -> float.to_string(cost)
        None -> "None"
      }
      <> ", owed: "
      <> bool.to_string(owed)
      <> ", shared: "
      <> bool.to_string(shared)
      <> ", payment_date: "
      <> case payment_date {
        Some(date) -> date.to_string(date)
        None -> "None"
      }
      <> ", from_user: "
      <> from_user
      <> ")"
  }
}

/// Converts a payment to a json object.
///
pub fn to_json(payment: Payment) -> json.Json {
  json.object([
    #("id", json.string(payment.id)),
    #("amount", case payment.amount {
      Some(amount) -> json.float(amount)
      None -> json.null()
    }),
    #("name", json.string(payment.name)),
    #("description", case payment.description {
      Some(description) -> json.string(description)
      None -> json.null()
    }),
    #("owed", json.bool(payment.owed)),
    #("shared", json.bool(payment.shared)),
    #("payment_date", case payment.payment_date {
      Some(payment_date) -> payment_date |> date.to_string |> json.string
      None -> json.null()
    }),
  ])
}

/// Gets all of the payment names as a list.
///
pub fn get_names(payments: List(Payment)) -> List(String) {
  use payment <- list.map(payments)
  payment.name
}

/// Checks a payment to see if it is currently owed.
///
fn filter_by_owed(payment: Payment) -> Bool {
  payment.owed
}

/// Filters the payments by owed state and returns the ones that are currently
/// owed.
///
pub fn get_owed(payments: List(Payment)) -> List(Payment) {
  payments
  |> list.filter(filter_by_owed)
}

/// Checks a payment to see if it is shared/split.
///
fn filter_by_shared(payment: Payment) -> Bool {
  payment.shared
}

/// Filters the payments by shared state and returns the ones that are
/// shared/split.
///
pub fn get_shared(payments: List(Payment)) -> List(Payment) {
  payments
  |> list.filter(filter_by_shared)
}

/// Changes the direction of the payment list based on ascending/descending
/// order.
///
pub fn sort_by_direction(
  payments: List(Payment),
  direction: sort.Direction,
) -> List(Payment) {
  case direction {
    sort.Asc -> list.reverse(payments)
    sort.Desc -> payments
  }
}

/// Sorts payments by the payment name alphabetically using ascending/descending
/// order.
///
pub fn sort_by_name(
  payments: List(Payment),
  direction: sort.Direction,
) -> List(Payment) {
  {
    use payment1, payment2 <- list.sort(payments)
    string.compare(payment1.name, payment2.name)
  }
  |> sort_by_direction(direction)
}

/// Sorts payments by the initial payment date using ascending/descending order.
///
pub fn sort_by_date(
  payments: List(Payment),
  direction: sort.Direction,
) -> List(Payment) {
  {
    use payment1, payment2 <- list.sort(payments)
    case payment1.payment_date, payment2.payment_date {
      Some(date1), Some(date2) -> date1 |> date.compare(date2)
      Some(_), None -> Gt
      None, Some(_) -> Lt
      _, _ -> Eq
    }
  }
  |> sort_by_direction(direction)
}

/// General payment sorting function which sorts the list of payments given
/// based on a valid payment field and the ascending/descending direction given.
///
pub fn sort_by(
  payments: List(Payment),
  field: sort.Field,
  direction: sort.Direction,
) -> List(Payment) {
  case field {
    sort.Date -> sort_by_date(payments, direction)
    sort.Name -> sort_by_name(payments, direction)
  }
}

/// Sets payment owed status for all Payment cases.
///
fn set_owed(payment: Payment, owed: Bool) -> Payment {
  case payment {
    Payment(id, amount, name, description, _, shared, payment_date) ->
      Payment(id, amount, name, description, owed, shared, payment_date)
    PaymentTo(id, amount, name, description, _, shared, payment_date, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(
      id,
      amount,
      name,
      description,
      _,
      shared,
      payment_date,
      from_user,
    ) ->
      PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Toggles a payments owed status.
///
pub fn toggle_owed(payment: Payment) -> Payment {
  set_owed(payment, !payment.owed)
}

/// Sets payment shared status for all Payment cases.
///
fn set_shared(payment: Payment, shared: Bool) -> Payment {
  case payment {
    Payment(id, amount, name, description, owed, _, payment_date) ->
      Payment(id, amount, name, description, owed, shared, payment_date)
    PaymentTo(id, amount, name, description, owed, _, payment_date, to_user) ->
      PaymentTo(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        to_user,
      )
    PaymentFrom(id, amount, name, description, owed, _, payment_date, from_user) ->
      PaymentFrom(
        id,
        amount,
        name,
        description,
        owed,
        shared,
        payment_date,
        from_user,
      )
  }
}

/// Toggles a payments shared status.
///
pub fn toggle_shared(payment: Payment) -> Payment {
  set_shared(payment, !payment.shared)
}

/// Helper function to calculate the amount given the amount is shared and
/// should be split equally.
///
fn calculate_shared_amount(amount: Float, shared: Bool) -> Float {
  case shared {
    True -> amount /. 2.0
    False -> amount
  }
}

/// Calculates payment amount to display after taking into account the shared
/// value.
///
pub fn calculate_display_amount(payment: Payment) -> Option(Float) {
  case payment.amount {
    Some(amount) -> Some(calculate_shared_amount(amount, payment.shared))
    None -> None
  }
}

/// Computes the sum for a list of payment amount values.
///
pub fn calculate_amount_total(payments: List(Payment)) -> Float {
  payments
  |> list.filter_map(fn(payment) {
    let amount = option.unwrap(payment.amount, 0.0)
    case payment.shared {
      True -> amount /. 2.0
      False -> amount
    }
    |> Ok
  })
  |> float.sum
}

// Format helpers --------------------------------------------------------------

/// Converts a float to a string with 2 decimal places.
///
pub fn format_float_with_decimal_padding(value: Float) -> String {
  let rounded_x_100 = float.round(value *. 100.0)
  let decimal_value_string =
    int.to_string(int.modulo(rounded_x_100, 100) |> result.unwrap(0))
  let whole_string = int.to_string(rounded_x_100 / 100)

  let padded_decimal = case string.length(decimal_value_string) {
    1 -> string.append("0", decimal_value_string)
    // Ensure two decimal places
    _ -> decimal_value_string
  }

  string.concat([whole_string, ".", padded_decimal])
}

/// Converts an optional amount float to a properly formatted currency string
/// with symbol and padded decimal places.
///
pub fn format_amount_to_currency_string(amount: Option(Float)) -> String {
  case amount {
    Some(amount) ->
      amount
      |> format_float_with_decimal_padding
      |> string.append("$", _)
    None -> "-"
  }
}

// Tempo decoders ----------------------------------------------------------------

fn date_string_decoder() -> decode.Decoder(Date) {
  use decoded_string <- decode.then(decode.string)
  case decoded_string {
    string ->
      string
      |> date.from_string
      |> result.unwrap(date.current_local())
      |> decode.success
  }
}
