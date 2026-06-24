//// Module for running a barebones development wrapper application for the
//// "payment-tracker" component. Using this we can utilise Lustre dev tools to
//// view the component instead of having to build the application and view it
//// via the demo environment.
////

// IMPORTS ---------------------------------------------------------------------

import component
import gleam/list
import gleam/option
import gleam/result
import gleam/uri
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import modem

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let component = component.register_using_uri_query()
  let assert Ok(_) = lustre.register(component, "payment-tracker")

  // Start a simple host application that renders the web component
  let dev_app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(dev_app, "#app", Nil)
}

fn init(_) {
  // We grab and attach any relevant query params as attributes via our
  // application model state. This keeps our development behaviour in sync with
  // `demo/index.html` and allows us to use lustre dev tools to run rather than
  // requiring a build and running in demo via `pnpm dev`.
  let attrs = attributes_from_uri_query()

  #(attrs, effect.none())
}

/// Required update function. No values actually are updated in this dev
/// application.
///
fn update(model, _msg) {
  #(model, effect.none())
}

/// Renders the "payment-tracker" component with the given model and attributes.
fn view(model) {
  element.element("payment-tracker", model, [])
}

/// Parses the URI query string to extract attributes for the "payment-tracker" component.
///
fn attributes_from_uri_query() -> List(attribute.Attribute(a)) {
  case modem.initial_uri() {
    Ok(u) -> {
      u.query
      |> option.unwrap("")
      |> uri.parse_query
      |> result.unwrap([])
      |> list.filter_map(fn(pair) {
        case pair {
          #("storage", value) ->
            Ok(attribute.attribute("storage-backend", value))
          #("db", value) -> Ok(attribute.attribute("db-name", value))
          #("demo", value) -> Ok(attribute.attribute("demo", value))
          _ -> Error(Nil)
        }
      })
    }
    Error(_) -> []
  }
}
