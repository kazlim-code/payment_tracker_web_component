import component
import lustre

pub fn main() {
  let tracker = component.register()
  let assert Ok(_) = lustre.register(tracker, "payment-tracker")
}
