//// This module defines the user interface for the payment tracker web component.
//// It uses Lustre to render a declarative, reactive UI based on the application state.
////

import core/payment_tracker/monthly_payment.{type MonthlyPayment}
import core/payment_tracker/payment.{type Payment}
import core/payment_tracker/user
import core/version
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute.{type Attribute, type_}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import tempo.{type MonthYear}
import tempo/date
import tempo/instant
import ui/state.{
  type Dialog, type Model, type MonthlyBalance, AddPayment,
  AutomatedBankTransfer, Dialog, HomeLoan, MonthlyDetail, MonthlySummary,
  NoDialog, UserBlurredAmount, UserChangedPaymentDate,
  UserClickedAddMonthPayment, UserClickedAddPayment, UserClickedBack,
  UserClickedDetailedMonthView, UserClickedEditHomeLoanAmount,
  UserClickedEditPayment, UserClickedEditTransferAmount, UserClickedMonthlyView,
  UserClosedDialog, UserDecrementedAmount, UserDeletedPayment,
  UserIncrementedAmount, UserInputPaymentName, UserSubmittedEditMonthlyBalance,
  UserSubmittedEditPayment, UserSubmittedPayment, UserToggledMonthlyPaymentPaid,
  UserToggledShared, UserToggledSharedPayment, UserToggledToday,
}

import ui/styles
import ui/svg as ui_svg

/// The main entry point for the view logic, dispatching to specific view
/// functions based on the current application state.
///
pub fn view(model: Model) -> Element(state.Msg) {
  html.div([attribute.id("payment-tracker")], [
    styles.base(),
    case model.current_view {
      AddPayment -> add_payment_view(model)
      MonthlySummary -> summary_view(model)
      MonthlyDetail(month) -> detail_view(model, month)
    },
    footer_view(model),
    dialog(model.dialog),
  ])
}

// --- ENTRY VIEW (Add Payment) ---

/// Renders the entry view for recording a new payment, including the
/// header, form, and debug panel.
///
fn add_payment_view(model: Model) -> Element(state.Msg) {
  html.section([attribute.class("add-payment-view")], [
    header_view(model),
    html.main([], [
      add_payment_form(with: model),

      devtools_panel(model),
    ]),
  ])
}

/// Renders the multi-field form used to capture payment details such as
/// amount, name, and metadata.
///
fn add_payment_form(with model: Model) -> Element(state.Msg) {
  html.form([event.on_submit(UserSubmittedPayment)], [
    add_payment_price(with: model.form_amount),
    html.div([attribute.class("form-layout")], [
      html.div([attribute.class("flex flex-col gap-md")], [
        toggle_container(
          name: "shared-toggle",
          label: "Shared",
          toggle: model.form_shared_toggle,
          emits: UserToggledShared,
        ),
        toggle_container(
          name: "today-toggle",
          label: "Today",
          toggle: model.form_today_toggle,
          emits: UserToggledToday,
        ),
        calendar_picker_container(
          attributes: [],
          today: model.form_today_toggle,
          value: model.form_date,
        ),
      ]),
      html.div([attribute.class("payment-content")], [
        html.textarea(
          [
            attribute.name("payment-name"),
            attribute.placeholder("Add a description..."),
            event.on_input(UserInputPaymentName),
          ],
          model.form_name,
        ),
        html.button(
          [
            attribute.class("btn-primary uppercase"),
            type_("submit"),
          ],
          [html.text("Record payment")],
        ),
      ]),
    ]),
  ])
}

/// Renders a large currency input field with custom increment/decrement
/// controls.
///
fn add_payment_price(with price: Float) -> Element(state.Msg) {
  html.div([attribute.class("payment-price")], [
    html.label([attribute.for("price"), attribute.class("sr-only")], [
      html.text("Payment amount"),
    ]),
    html.span([attribute.class("symbol")], [html.text("$")]),
    html.input([
      attribute.value(price |> float_to_padded_string),
      attribute.autofocus(True),
      attribute.class(""),
      attribute.min("0"),
      attribute.id("price"),
      attribute.name("payment-price"),
      attribute.placeholder("0.00"),
      attribute.step("0.01"),
      on_blur_with_value(UserBlurredAmount),
      type_("number"),
    ]),
    html.div([attribute.class("inc-dec")], [
      html.button(
        [
          attribute.class("inc-dec top"),
          event.on_click(UserIncrementedAmount),
          type_("button"),
        ],
        [
          ui_svg.chevron_up(),
        ],
      ),
      html.button(
        [
          attribute.class("inc-dec"),
          event.on_click(UserDecrementedAmount),
          type_("button"),
        ],
        [
          ui_svg.chevron_up(),
        ],
      ),
    ]),
  ])
}

// --- Toggles ---

/// A labeled layout component that wraps a toggle switch.
///
fn toggle_container(
  name name: String,
  label label: String,
  toggle value: Bool,
  emits msg: state.Msg,
) -> Element(state.Msg) {
  html.div([attribute.class("toggle-container")], [
    html.label([attribute.class("uppercase")], [html.text(label)]),
    toggle(name: name, value: value, emits: msg),
  ])
}

/// A primitive binary switch component that emits messages when toggled.
///
fn toggle(
  name name: String,
  value value: Bool,
  emits msg: state.Msg,
) -> Element(state.Msg) {
  html.div([attribute.class("toggle")], [
    html.input([
      attribute.role("switch"),
      attribute.checked(value),
      attribute.name(name),
      attribute.type_("checkbox"),
      event.on_check(fn(_) { msg }),
    ]),
    html.span([], []),
  ])
}

// --- Calendar ---

/// A layout component that wraps the calendar date selection input.
///
fn calendar_picker_container(
  today today: Bool,
  value value: String,
  attributes attributes: List(Attribute(state.Msg)),
) -> Element(state.Msg) {
  let date_value = case today, string.is_empty(value) {
    False, False -> value
    _, _ -> instant.now() |> instant.as_local_date |> date.to_string
  }

  html.div(attributes |> list.prepend(attribute.class("basic-container")), [
    calendar_picker(value: date_value, readonly: today),
  ])
}

/// A specialized date input component with a custom calendar icon.
///
fn calendar_picker(
  value value: String,
  readonly readonly: Bool,
) -> Element(state.Msg) {
  html.div([attribute.class("w-full")], [
    html.label([attribute.class("sr-only")], [html.text("Payment date")]),
    html.input([
      attribute.class("calendar-picker"),
      attribute.id("payment-date"),
      attribute.name("payment-date"),
      attribute.placeholder("Date"),
      attribute.style(
        "background-image",
        "url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" fill=\"white\" viewBox=\"0 0 16 16\"><path d=\"M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5zM1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4H1z\"/></svg>')",
      ),
      attribute.readonly(readonly),
      type_("date"),
      attribute.value(value),
      event.on_change(fn(date) { UserChangedPaymentDate(date) }),
    ]),
  ])
}

// --- Devtools ---

/// A debug utility that renders the current raw state of payments in
/// the user model.
///
pub fn devtools_panel(model: Model) -> Element(state.Msg) {
  let payments_string = user.payments_to_string(model.user)
  html.div(
    [
      attribute.class("debug"),
    ],
    [
      html.pre([attribute.class("whitespace-pre-wrap")], [
        html.text(payments_string),
      ]),
    ],
  )
}

// --- SUMMARY VIEW ---

/// Renders the summary view, showing a list of cards for each month
/// that has payments associated with it.
///
fn summary_view(model: Model) -> Element(state.Msg) {
  let monthly_payments = model.user |> user.get_monthly_payments

  html.section([attribute.class("summary-view")], [
    header_view(model),
    html.main([attribute.class("grid")], case list.is_empty(monthly_payments) {
      True -> [monthly_summaries_empty()]
      False -> [
        // TODO: Add sticky headers for the year separators
        html.ul(
          [attribute.class("monthly-payments-container")],
          list.map(monthly_payments, fn(monthly) {
            let month_name =
              monthly |> monthly_payment.month_string_from_monthly_payment
            let month_year =
              monthly
              |> monthly_payment.get_month_year
            let total =
              monthly
              |> monthly_payment.get_total
              |> option.unwrap(0.0)
              |> float_to_padded_string
            let paid =
              monthly
              |> monthly_payment.get_paid_timestamp
              |> option.map(fn(paid_timestamp) {
                timestamp.to_rfc3339(paid_timestamp, calendar.utc_offset)
              })
            html.li([], [month_card(month_name:, month_year:, paid:, total:)])
          }),
        ),
      ]
    }),
  ])
}

/// Renders the empty state for the summary view when no payments exist.
///
fn monthly_summaries_empty() {
  html.section([attribute.class("summary-empty")], [
    html.div([attribute.class("icon-container")], [ui_svg.chart()]),
    html.h1([], [html.text("No payments found")]),
    html.div([attribute.class("grid gap-sm center")], [
      html.p([], [html.text("Your records are currently empty.")]),
      html.p([], [html.text("Start tracking adding your first one below.")]),
    ]),
    html.button(
      [
        attribute.class("btn-primary rounded-sm uppercase"),
        event.on_click(UserClickedAddPayment),
      ],
      [html.text("+ Add Your First Payment")],
    ),
  ])
}

/// Renders a summary card for a specific month, showing payment status
/// and totals.
///
fn month_card(
  month_name month_name: String,
  month_year month_year: MonthYear,
  paid timestamp: Option(String),
  total total: String,
) -> Element(state.Msg) {
  let month_year_string = month_year |> monthly_payment.month_year_to_string
  let #(year, _month) =
    month_year_string |> string.split_once("-") |> result.unwrap(#("", ""))
  let year_month_day = month_year_string <> "-01"
  let valid_date_string = case date.parse_any(year_month_day) {
    Ok(_) -> year_month_day
    Error(_) -> ""
  }
  let #(paid_value, total_label, total_color) = case timestamp {
    option.Some(time) if time != "" -> #(time, "Total", "var(--status-paid)")
    _ -> #("-", "Total Owed", "var(--status-owed)")
  }

  html.button(
    [
      attribute.class("month-card-container"),
      type_("button"),
      event.on_click(UserClickedDetailedMonthView(month_year)),
    ],
    [
      html.div(
        [
          attribute.class("month-card"),
        ],
        [
          html.div([attribute.class("month-card-header")], [
            html.div([], [
              html.h2([attribute.class("text-h2")], [html.text(month_name)]),
              html.span(
                [attribute.class("text-label-caps text-on-surface-variant")],
                [html.text(year)],
              ),
            ]),
            html.div([attribute.class("arrow-icon")], [ui_svg.arrow_forward()]),
          ]),
          html.div([attribute.class("flex flex-col gap-sm")], [
            stat_row("Paid", paid_value, "var(--on-background)"),
            stat_row(total_label, "$" <> total, total_color),
          ]),
          html.button(
            [
              attribute.class("quick-add-btn"),
              event.on_click(UserClickedAddMonthPayment(valid_date_string)),
            ],
            [
              ui_svg.plus(),
              html.span([attribute.class("text-label-caps")], [html.text("ADD")]),
            ],
          ),
        ],
      ),
    ],
  )
}

/// Renders a row with a label and a value, used within summary cards.
///
fn stat_row(label: String, value: String, color: String) -> Element(msg) {
  html.div([attribute.class("stat-row")], [
    html.span([attribute.class("text-label-caps opacity-70")], [
      html.text(label),
    ]),
    html.span(
      [
        attribute.class("text-mono-data"),
        attribute.attribute("style", "color: " <> color),
      ],
      [html.text(value)],
    ),
  ])
}

// --- DETAIL VIEW ---

/// Renders the detailed view for a specific month, showing a list of
/// all payments made during that period.
///
fn detail_view(model: Model, monthly: MonthlyPayment) -> Element(state.Msg) {
  let monthly_payment =
    model.user
    |> user.get_monthly_payment(for: monthly |> monthly_payment.get_month_year)
    |> result.unwrap(monthly)
  let month_name =
    monthly_payment |> monthly_payment.month_string_from_monthly_payment
  let year = monthly_payment |> monthly_payment.get_year |> int.to_string
  let total =
    monthly_payment
    |> monthly_payment.get_total
    |> option.unwrap(0.0)
    |> float_to_padded_string
  let payments =
    monthly_payment
    |> monthly_payment.get_month_year
    |> user.get_payments_for_month(from: model.user, for: _)

  let fallback_date =
    monthly_payment
    |> monthly_payment.get_month_year
    |> monthly_payment.month_year_to_string
    |> string.append("-01")
  let owed_element_result = detail_month_owed(using: monthly_payment)

  html.section([attribute.class("detailed-month-view")], [
    header_view(model),
    html.main([], [
      detailed_month_heading(name: month_name, for: year, total:),
      case owed_element_result {
        Ok(element) -> element
        Error(message) -> {
          echo message
          element.none()
        }
      },
      detailed_month_table(
        using: monthly_payment,
        for: payments,
        fallback_date: fallback_date,
      ),
      html.div([attribute.class("flex flex-col grow")], []),
    ]),
  ])
}

/// Renders the header section of the detail view, including the month
/// name and the total amount.
///
fn detailed_month_heading(
  name month: String,
  for year: String,
  total total: String,
) -> Element(state.Msg) {
  html.div([attribute.class("detailed-month-heading")], [
    html.div([attribute.class("flex flex-col")], [
      html.span([attribute.class("text-label-caps text-on-surface-variant")], [
        html.text("Monthly Summary"),
      ]),
      html.h2([attribute.class("text-h1")], [
        html.text(month <> " " <> year),
      ]),
    ]),
    html.div([attribute.class("flex flex-col items-end")], [
      html.span([attribute.class("text-label-caps text-primary")], [
        html.text("Total"),
      ]),
      html.span([attribute.class("text-h2 text-primary")], [
        html.text("$" <> total),
      ]),
    ]),
  ])
}

/// Calculates and renders the total amount owed based on the month total, home
/// loan amount and money scheduled to transfer via automatic bank transfer.
///
fn detail_month_owed(
  using monthly_payment: MonthlyPayment,
) -> Result(Element(state.Msg), String) {
  let owed_amount = monthly_payment.calculate_owed(monthly_payment)
  let paid =
    monthly_payment |> monthly_payment.get_paid_timestamp |> option.is_some

  Ok(
    html.div([attribute.class("detailed-month--owed")], [
      case paid {
        True ->
          html.button(
            [
              attribute.class("text-success text-label-caps"),
              event.on_click(UserToggledMonthlyPaymentPaid(monthly_payment)),
            ],
            [html.text("Paid")],
          )
        False ->
          html.button(
            [
              attribute.class(
                "flex items-center gap-sm text-on-surface-variant text-label-caps",
              ),
              event.on_click(UserToggledMonthlyPaymentPaid(monthly_payment)),
            ],
            [
              html.span([], [html.text("Owed")]),
              html.span([], [
                html.text("$" <> owed_amount |> float_to_padded_string),
              ]),
            ],
          )
      },
    ]),
  )
}

/// Renders the table container and toolbar for the monthly payments list.
///
fn detailed_month_table(
  using monthly_payment: MonthlyPayment,
  for payments: List(Payment),
  fallback_date date: String,
) -> Element(state.Msg) {
  let get_entries_label = fn() {
    let payment_length = payments |> list.length
    case payment_length {
      1 -> payment_length |> int.to_string <> " Entry"
      _ -> payment_length |> int.to_string <> " Entries"
    }
  }

  let home_loan_amount =
    monthly_payment
    |> monthly_payment.get_home_loan_amount
    |> option.unwrap(0.0)
    |> float_to_padded_string
  let transfer_amount =
    monthly_payment
    |> monthly_payment.get_home_loan_transfer
    |> option.unwrap(0.0)
    |> float_to_padded_string

  // We keep the outer div to easily control the border-radius and shadow
  html.div([attribute.class("detailed-month-table-container")], [
    // Summary Header / Toolbar
    html.div(
      [
        attribute.class("detailed-summary-header"),
      ],
      [
        html.div(
          [
            attribute.class(
              "font-mono-data text-mono-data text-on-surface-variant",
            ),
          ],
          [html.text(get_entries_label())],
        ),
        html.div([attribute.class("flex items-center gap-xs")], [
          stat_row_small(
            label: "Home loan:",
            value: "$" <> home_loan_amount,
            color: "text-on-surface",
            msg: UserClickedEditHomeLoanAmount(edit_monthly_balance_dialog(
              for: HomeLoan,
              using: monthly_payment,
            )),
          ),
          stat_row_small(
            label: "Transfer:",
            value: "+$" <> transfer_amount,
            color: "text-primary",
            msg: UserClickedEditTransferAmount(edit_monthly_balance_dialog(
              for: AutomatedBankTransfer,
              using: monthly_payment,
            )),
          ),
        ]),
      ],
    ),

    case list.is_empty(payments) {
      True -> month_payment_table_empty(date)
      False -> month_payment_table(with: payments)
    },
  ])
}

/// Renders the empty state for a month's payment table, providing a
/// prompt to add the first payment.
///
fn month_payment_table_empty(fallback_date date: String) -> Element(state.Msg) {
  html.div([attribute.class("flex flex-col items-center gap-xl p-xl")], [
    html.div(
      [
        attribute.class(
          "bg-surface-variant-dark rounded-xl text-on-surface-variant opacity-40",
        ),
      ],
      [ui_svg.no_payments()],
    ),
    html.div(
      [attribute.class("flex flex-col items-center gap-xs text-center")],
      [
        html.h3([attribute.class("text-h3 text-on-surface")], [
          html.text("No entries yet"),
        ]),
        html.p([attribute.class("text-sm text-on-surface")], [
          html.text("You haven't recorded any payments for this month."),
        ]),
      ],
    ),
    html.button(
      [
        attribute.class("btn-primary rounded-sm uppercase"),
        event.on_click(UserClickedAddMonthPayment(date)),
      ],
      [html.text("+ Add Payment")],
    ),
  ])
}

/// Renders the semantic table of payments for a given month.
///
fn month_payment_table(with payments: List(Payment)) -> Element(state.Msg) {
  html.table([attribute.class("w-full text-left border-collapse")], [
    // Screen-reader only headers (Highly recommended for accessibility)
    html.thead([attribute.class("sr-only")], [
      html.tr([], [
        html.th([], [html.text("Date")]),
        html.th([], [html.text("Description")]),
        html.th([], [html.text("Category")]),
        html.th([], [html.text("Amount")]),
        html.th([], [html.text("Selection")]),
        html.th([], [html.text("Status")]),
        html.th([], [html.text("Actions")]),
      ]),
    ]),

    html.tbody(
      [],
      list.index_map(payments, fn(p, index) {
        payment_row(payment: p, index: index)
      }),
    ),
  ])
}

/// Renders a single row in the payment table, including the date,
/// description, category, and action menu.
///
fn payment_row(
  payment payment: Payment,
  index index: Int,
) -> Element(state.Msg) {
  let date_str = case payment.payment_date {
    Some(d) -> date.to_string(d)
    _ -> "No Date"
  }

  let base_id =
    payment.name |> string.replace(" ", "-") |> string.trim |> string.lowercase
  let row_id = base_id <> "-" <> int.to_string(index)
  let row_element_ids = #(row_id <> "-anchor", row_id <> "-popover")

  let split_checkbox = fn() -> Element(state.Msg) {
    case payment.shared {
      True ->
        html.input([
          attribute.checked(True),
          attribute.readonly(True),
          attribute.type_("checkbox"),
          attribute.class("h-4 w-4 pointer-events-none"),
        ])
      False ->
        html.input([
          attribute.checked(False),
          attribute.readonly(True),
          attribute.type_("checkbox"),
          attribute.class("h-4 w-4 pointer-events-none"),
        ])
    }
  }

  let amount_cell = fn(shared: Bool) -> Element(state.Msg) {
    let amount_str = case payment.amount {
      Some(a) -> payment.format_float_with_decimal_padding(a)
      _ -> "0.00"
    }

    case shared {
      True -> {
        let shared_amount_str = case payment.amount {
          Some(a) -> a /. 2.0 |> payment.format_float_with_decimal_padding
          _ -> "0.00"
        }
        element.fragment([
          html.span([attribute.class("payment-cell-shared-total")], [
            html.text("$" <> amount_str),
          ]),
          html.text("$" <> shared_amount_str),
        ])
      }
      False -> html.text("$" <> amount_str)
    }
  }

  html.tr(
    [
      attribute.class("detailed-month-table-row group"),
    ],
    [
      // Date Cell (Fixed Width)
      html.td(
        [
          attribute.class("text-mono-data"),
          attribute.style("min-width", "7.5rem"),
        ],
        [html.text(date_str)],
      ),

      // Name Cell (Flexible Width: w-full pushes against fixed columns, max-w-0 forces truncate to work in tables)
      html.td([attribute.class("w-full"), attribute.style("max-width", "0")], [
        html.div(
          [
            attribute.class("text-body-base text-on-surface truncate"),
          ],
          [html.text(payment.name)],
        ),
      ]),

      // Category Cell (Fixed Width)
      html.td([attribute.style("width", "9.375rem")], [
        html.div([attribute.class("flex items-center gap-xs")], [
          html.span(
            [
              attribute.class("dot-sm bg-surface-container-high"),
              attribute.style("background", "var(--surface-container-high)"),
            ],
            [],
          ),
          html.span(
            [
              attribute.class("category-text text-label-caps"),
            ],
            [html.text("")],
          ),
        ]),
      ]),

      // Checkbox Cell
      html.td([attribute.style("width", "5rem")], [
        html.div([attribute.class("flex justify-center")], [
          split_checkbox(),
        ]),
      ]),

      // Amount Cell (Fixed Width, Right Aligned)
      html.td(
        [
          attribute.class(
            "text-mono-data font-semibold text-on-surface relative",
          ),
          attribute.style("min-width", "9.375rem"),
          attribute.style("text-align", "right"),
        ],
        [amount_cell(payment.shared)],
      ),

      // Actions Cell
      html.td([attribute.style("min-width", "2.5rem")], [
        html.button(
          [
            attribute.aria_label("More actions"),
            attribute.class("actions-btn"),
            attribute.id(row_element_ids.0),
            attribute.popovertarget(row_element_ids.1),
          ],
          [ui_svg.more_vert()],
        ),
        popover_menu(row_element_ids, [payment_table_overflow_menu(payment)]),
      ]),
    ],
  )
}

/// Renders a small label and value pair, used within the table toolbar.
///
fn stat_row_small(
  label label: String,
  value value: String,
  color color_class: String,
  msg message: state.Msg,
) -> Element(state.Msg) {
  html.button(
    [
      attribute.attribute("command", "show-modal"),
      attribute.attribute("commandfor", "main-dialog"),
      attribute.class("btn-ghost p-btn-sm flex items-baseline gap-sm"),
      event.on_click(message),
    ],
    [
      html.span(
        [
          attribute.class(
            "font-label-caps text-label-caps text-on-surface-variant uppercase",
          ),
        ],
        [
          html.text(label),
        ],
      ),
      html.span(
        [attribute.class("font-mono-data text-body-sm " <> color_class)],
        [
          html.text(value),
        ],
      ),
    ],
  )
}

/// Attaches a menu element as a popover to an anchor.
///
pub fn popover_menu(
  anchor_popover_ids: #(String, String),
  menu: List(Element(state.Msg)),
) -> Element(state.Msg) {
  let #(anchor, popover) = anchor_popover_ids
  html.div(
    [
      attribute.attribute("anchor", anchor),
      attribute.popover("auto"),
      attribute.data("popover-menu", popover),
      attribute.class("popover-menu"),
      attribute.id(popover),
    ],
    menu,
  )
}

/// Overflow actions menu for a payment displayed in the payment table.
///
pub fn payment_table_overflow_menu(payment: Payment) -> Element(state.Msg) {
  html.ul([attribute.class("overflow-menu")], [
    html.li([attribute.class("overflow-menu-header")], [
      html.text("Actions"),
    ]),
    html.li([], [
      html.button(
        [
          attribute.class("overflow-menu-item"),
          event.on_click(UserToggledSharedPayment(payment)),
        ],
        [html.text("Toggle shared")],
      ),
    ]),
    html.li([], [
      html.button(
        [
          attribute.class("overflow-menu-item"),
          attribute.attribute("command", "show-modal"),
          attribute.attribute("commandfor", "main-dialog"),
          event.on_click(UserClickedEditPayment(payment |> edit_payment_dialog)),
        ],
        [html.text("Edit payment")],
      ),
    ]),
    html.li([], [
      html.button(
        [
          attribute.class("overflow-menu-item danger"),
          event.on_click(UserDeletedPayment(payment)),
        ],
        [html.text("Delete payment")],
      ),
    ]),
  ])
}

/// Renders a dialog element with the provided options.
///
fn dialog(options: Dialog) -> Element(state.Msg) {
  case options {
    NoDialog -> html.dialog([attribute.id("main-dialog")], [])
    Dialog(attributes, children) ->
      html.dialog(
        attributes
          |> list.prepend(attribute.id("main-dialog"))
          |> list.prepend(attribute.class("dialog-base")),
        children,
      )
  }
}

/// Renders a standard header for dialogs.
///
fn dialog_header(
  attributes: List(Attribute(state.Msg)),
  children: List(Element(state.Msg)),
) -> Element(state.Msg) {
  html.div(
    attributes |> list.prepend(attribute.class("dialog-header")),
    children |> list.append([dialog_close_button()]),
  )
}

/// Renders a standard body for dialogs.
///
fn dialog_body(
  attributes: List(Attribute(state.Msg)),
  children: List(Element(state.Msg)),
) -> Element(state.Msg) {
  html.div(attributes |> list.prepend(attribute.class("dialog-body")), children)
}

/// Renders a standard action footer for dialogs.
///
fn dialog_actions(
  attributes: List(Attribute(state.Msg)),
  children: List(Element(state.Msg)),
) -> Element(state.Msg) {
  html.div(
    attributes |> list.prepend(attribute.class("dialog-actions")),
    children,
  )
}

/// Renders a close button for dialogs.
///
fn dialog_close_button() -> Element(state.Msg) {
  html.button(
    [
      attribute.attribute("aria-label", "Close"),
      attribute.attribute("commandfor", "main-dialog"),
      attribute.attribute("command", "close"),
      attribute.attribute("commandfor", "main-dialog"),
      attribute.autofocus(True),
      attribute.class("dialog-close"),
      event.on_click(UserClosedDialog),
      type_("button"),
    ],
    [html.text("X")],
  )
}

/// Dialog for editing saved payment details.
///
pub fn edit_payment_dialog(selected payment: Payment) -> Dialog {
  Dialog(attributes: [], children: edit_payment_form(payment:))
}

/// Form element that enables editing saved payment details.
///
pub fn edit_payment_form(payment payment: Payment) -> List(Element(state.Msg)) {
  [
    html.form(
      [
        attribute.class("flex flex-col w-full"),
        attribute.method("dialog"),
        on_submit_native_close(fn(values: List(#(String, String))) {
          UserSubmittedEditPayment(values, payment)
        }),
      ],
      [
        dialog_header([], [
          html.h2([], [html.text("Edit payment")]),
        ]),
        dialog_body([], [
          html.div([attribute.class("grid gap-xs w-full")], [
            html.label(
              [
                attribute.class("text-sm font-semibold"),
                attribute.for("payment-name"),
              ],
              [html.text("Payment name")],
            ),
            html.input([
              attribute.class("dialog-input flex grow"),
              attribute.id("payment-name"),
              attribute.name("payment-name"),
              attribute.placeholder("Name"),
              attribute.required(True),
              attribute.value(payment.name),
            ]),
          ]),
          html.div([attribute.class("flex gap-xl w-full")], [
            html.div([attribute.class("grid gap-xs w-full")], [
              html.label(
                [
                  attribute.class("text-sm font-semibold"),
                  attribute.for("payment-date"),
                ],
                [html.text("Payment date")],
              ),
              html.input([
                attribute.class("dialog-input"),
                attribute.id("payment-date"),
                attribute.name("payment-date"),
                attribute.placeholder("Date"),
                attribute.style(
                  "background-image",
                  "url('data:image/svg+xml;utf8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" fill=\"white\" viewBox=\"0 0 16 16\"><path d=\"M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5zM1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4H1z\"/></svg>')",
                ),
                type_("date"),
                attribute.value({
                  case payment.payment_date {
                    Some(date) -> date |> date.to_string
                    None -> ""
                  }
                }),
              ]),
            ]),
            html.div([attribute.class("grid gap-xs w-full")], [
              html.label(
                [
                  attribute.class("text-sm font-semibold"),
                  attribute.for("price"),
                ],
                [html.text("Price")],
              ),
              html.div([attribute.class("flex items-center gap-sm w-full")], [
                html.div(
                  [
                    attribute.class("text-on-surface"),
                  ],
                  [html.text("$")],
                ),
                html.input([
                  attribute.autofocus(True),
                  attribute.class("dialog-input price w-full"),
                  attribute.min("0"),
                  attribute.id("price"),
                  attribute.name("payment-price"),
                  attribute.placeholder("Amount"),
                  attribute.step("0.01"),
                  type_("number"),
                  attribute.value(case payment.amount {
                    Some(amount) ->
                      payment.format_float_with_decimal_padding(amount)
                    None -> ""
                  }),
                ]),
              ]),
            ]),
          ]),
        ]),
        dialog_actions([], [
          html.button(
            [
              attribute.class("btn-ghost"),
              attribute.attribute("command", "close"),
              attribute.attribute("commandfor", "main-dialog"),
              event.on_click(UserClosedDialog),
              type_("button"),
            ],
            [html.text("Cancel")],
          ),
          html.button(
            [
              attribute.class("btn-primary"),
              type_("submit"),
            ],
            [html.text("Save")],
          ),
        ]),
      ],
    ),
  ]
}

/// Dialog for editing saved home loan or transfer amounts.
///
pub fn edit_monthly_balance_dialog(
  for balance_type: MonthlyBalance,
  using monthly_payment: MonthlyPayment,
) -> Dialog {
  Dialog(
    attributes: [],
    children: edit_monthly_balance_form(
      for: balance_type,
      using: monthly_payment,
    ),
  )
}

pub fn edit_monthly_balance_form(
  for balance_type: MonthlyBalance,
  using monthly_payment: MonthlyPayment,
) -> List(Element(state.Msg)) {
  let title = case balance_type {
    HomeLoan -> "Edit Home Loan amount"
    AutomatedBankTransfer -> "Edit transfer amount"
  }
  let amount = case balance_type {
    HomeLoan -> monthly_payment |> monthly_payment.get_home_loan_amount
    AutomatedBankTransfer ->
      monthly_payment |> monthly_payment.get_home_loan_transfer
  }

  [
    html.form(
      [
        attribute.class("flex flex-col w-full"),
        attribute.method("dialog"),
        on_submit_native_close(fn(values: List(#(String, String))) {
          UserSubmittedEditMonthlyBalance(values, balance_type, monthly_payment)
        }),
      ],
      [
        dialog_header([], [
          html.h2([], [html.text(title)]),
        ]),
        dialog_body([attribute.style("padding-block", "var(--gap-xl)")], [
          html.div([attribute.class("flex items-center gap-md w-full")], [
            html.label(
              [
                attribute.for("monthly-balance-amount"),
              ],
              [html.text("Amount:")],
            ),
            html.div([attribute.class("flex items-center gap-sm grow")], [
              html.div(
                [
                  attribute.class("text-on-surface"),
                ],
                [html.text("$")],
              ),
              html.input([
                attribute.value(
                  amount |> option.unwrap(0.0) |> float_to_padded_string,
                ),
                attribute.autofocus(True),
                attribute.class("dialog-input price flex grow"),
                attribute.min("0"),
                attribute.id("monthly-balance-amount"),
                attribute.name("monthly-balance-amount"),
                attribute.placeholder("0.00"),
                attribute.step("0.01"),
                type_("number"),
              ]),
            ]),
          ]),
        ]),
        dialog_actions([], [
          html.button(
            [
              attribute.class("btn-ghost"),
              attribute.attribute("command", "close"),
              attribute.attribute("commandfor", "main-dialog"),
              event.on_click(UserClosedDialog),
              type_("button"),
            ],
            [html.text("Cancel")],
          ),
          html.button(
            [
              attribute.class("btn-primary"),
              type_("submit"),
            ],
            [html.text("Save")],
          ),
        ]),
      ],
    ),
  ]
}

/// Renders the top navigation bar, including the back button and
/// view-specific controls.
///
fn header_view(model: Model) -> Element(state.Msg) {
  html.nav([attribute.class("view-header")], [
    html.div([attribute.class("flex gap-sm")], [
      case model.back_view {
        [] -> element.none()
        _ -> back_button(UserClickedBack)
      },
      case model.current_view {
        AddPayment ->
          html.button(
            [
              attribute.class("btn-ghost primary text-label-caps gap-xs"),
              event.on_click(UserClickedMonthlyView),
            ],
            [
              ui_svg.calendar(),
              html.text("Monthly view"),
            ],
          )
        MonthlySummary ->
          case model.back_view {
            [] -> back_button(UserClickedAddPayment)
            _ -> element.none()
          }
        MonthlyDetail(_) ->
          case model.back_view {
            [] -> back_button(UserClickedMonthlyView)
            _ -> element.none()
          }
      },
    ]),
    case model.current_view {
      MonthlySummary -> add_payment_button(UserClickedAddPayment)
      MonthlyDetail(mp) -> {
        let month_year_string =
          mp
          |> monthly_payment.get_month_year
          |> monthly_payment.month_year_to_string
        let year_month_day = month_year_string <> "-01"
        let valid_date_string = case date.parse_any(year_month_day) {
          Ok(_) -> year_month_day
          Error(_) -> ""
        }
        add_payment_button(UserClickedAddMonthPayment(valid_date_string))
      }
      _ -> element.none()
    },
  ])
}

/// Renders the sticky footer containing keyboard shortcut hints and
/// version information.
///
/// NOTE: Keyboard navigation logic and associated tests are currently
/// incomplete and not yet implemented.
///
fn footer_view(_model: Model) -> Element(msg) {
  html.footer([attribute.class("vim-footer")], [
    html.div([attribute.class("flex justify-between w-full")], [
      html.div([attribute.class("flex items-center gap-md")], [
        hint("[j]", "Next"),
        hint("[k]", "Prev"),
        hint("[i]", "Entry"),
        hint("[/]", "Search"),
        hint("[esc]", "Summary"),
      ]),
      html.div([attribute.class("text-label-caps opacity-50")], [
        html.text("v" <> version.string),
      ]),
    ]),
  ])
}

/// Renders a back button that emits the provided message.
///
fn back_button(message: state.Msg) -> Element(state.Msg) {
  html.button(
    [
      attribute.class("btn-ghost primary font-bold gap-xs"),
      event.on_click(message),
    ],
    [
      ui_svg.arrow_back(),
      html.text("Back"),
    ],
  )
}

/// Renders a button to add a new payment.
///
fn add_payment_button(message: state.Msg) -> Element(state.Msg) {
  html.button(
    [
      attribute.class("btn-primary"),
      event.on_click(message),
    ],
    [html.text("+ Add payment")],
  )
}

/// Renders a single keyboard shortcut hint.
///
fn hint(key: String, label: String) -> Element(msg) {
  html.span([attribute.class("vim-hint")], [
    html.span([attribute.class("text-primary")], [html.text(key)]),
    html.text(" " <> label),
  ])
}

// --- Helpers ---

/// Formats a float value to a string with at least two decimal places.
///
pub fn float_to_padded_string(value: Float) -> String {
  let value_string = value |> float.to_string
  let decimal_length =
    value_string
    |> string.split(".")
    |> list.reverse
    |> list.first
    |> result.unwrap("0")
    |> string.length
  case decimal_length {
    1 -> value_string <> "0"
    // Ensure two decimal places
    _ -> value_string
  }
}

/// A custom event handler for blur events that decodes the target's value.
///
pub fn on_blur_with_value(
  message: fn(String) -> message,
) -> Attribute(message) {
  event.on("blur", {
    use value <- decode.subfield(["target", "value"], decode.string)
    decode.success(message(value))
  })
}

/// A custom event handler for submit events that decodes the target's form data
/// without preventing the default action. This allows `<form method="dialog">`
/// to natively close a `<dialog>` while still capturing the submitted values.
pub fn on_submit_native_close(
  message: fn(List(#(String, String))) -> message,
) -> Attribute(message) {
  event.on("submit", {
    let string_value_decoder = {
      use key <- decode.field(0, decode.string)
      use value <- decode.field(1, decode.string)
      decode.success(#(key, value))
    }

    use formdata <- decode.subfield(
      ["detail", "formData"],
      decode.list(string_value_decoder),
    )

    formdata
    |> message
    |> decode.success
  })
}
