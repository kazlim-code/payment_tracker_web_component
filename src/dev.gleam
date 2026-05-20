import lustre
import lustre/effect.{type Effect}
import lustre/element
import ui/state
import ui/view

pub fn main(
  comp_init: fn(Nil) -> #(state.Model, Effect(state.Msg)),
  comp_update: fn(state.Model, state.Msg) -> #(state.Model, Effect(state.Msg)),
) {
  // Define and register the component locally in this dev module.
  // This avoids importing the main module and creating a cycle.
  // let app = lustre.component(state_init, state_update, view.view, [])
  let app = lustre.component(comp_init, comp_update, view.view, [])
  let _ = lustre.register(app, "payment-tracker")

  // Start a simple host application that renders the web component
  let dev_app = lustre.application(init, update, render)
  lustre.start(dev_app, "#app", Nil)
}

fn init(_) {
  #(Nil, effect.none())
}

fn update(model, _msg) {
  #(model, effect.none())
}

fn render(_model) {
  element.element("payment-tracker", [], [])
}
