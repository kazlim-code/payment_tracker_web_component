import component
import lustre

// import dev

// UNCOMMENT FOR DEVELOPMENT
// pub fn main() {
//   dev.main()
// }

pub fn main() {
  let tracker = component.register()
  lustre.register(tracker, "payment-tracker")
}
