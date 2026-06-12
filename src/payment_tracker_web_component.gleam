import app
import lustre

// import dev

// pub fn main() {
//   dev.main(fn(_) { app.init(Nil) }, app.update)
// }

pub fn main() {
  let tracker = app.register()
  lustre.register(tracker, "payment-tracker")
}
