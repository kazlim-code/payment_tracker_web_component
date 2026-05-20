/// This module provides a library of SVG components used throughout the
/// application's user interface.
///
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/svg

/// Renders a plus (+) icon, typically used for 'add' actions.
///
pub fn plus() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "18"),
      attribute.attribute("height", "18"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2.5"),
    ],
    [
      svg.path([attribute.attribute("d", "M12 5v14M5 12h14")]),
    ],
  )
}

/// Renders a forward-pointing arrow icon.
///
pub fn arrow_forward() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "18"),
      attribute.attribute("height", "18"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
    ],
    [
      svg.path([attribute.attribute("d", "M5 12h14M12 5l7 7-7 7")]),
    ],
  )
}

/// Renders a back-pointing arrow icon.
///
pub fn arrow_back() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "16"),
      attribute.attribute("height", "16"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
    ],
    [
      svg.rect([
        attribute.attribute("x", "3.083"),
        attribute.attribute("y", "10.959"),
        attribute.attribute("width", "19.033"),
        attribute.attribute("height", "2.171"),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.path([
        attribute.attribute(
          "d",
          "M10.445,3.569L12,5.124L3.555,13.569L2,12.014L10.445,3.569Z",
        ),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.path([
        attribute.attribute(
          "d",
          "M12,18.876L10.445,20.431L2,11.986L3.555,10.431L12,18.876Z",
        ),
        attribute.attribute("fill", "currentColor"),
      ]),
    ],
  )
}

/// Renders an upward-pointing chevron icon.
///
pub fn chevron_up() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "24"),
      attribute.attribute("height", "24"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
    ],
    [
      svg.path([
        attribute.attribute("d", "M12,9.879L16.243,14.121"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", "M7.757,14.121L12,9.879"),
        attribute.attribute("fill", "none"),
      ]),
    ],
  )
}

/// Renders a calendar icon, typically used for date-related UI elements.
///
pub fn calendar() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "20"),
      attribute.attribute("height", "20"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
    ],
    [
      svg.path([
        attribute.attribute(
          "d",
          "M20,7.776L20,18.558C20,19.998 18.831,21.167 17.391,21.167L6.609,21.167C5.169,21.167 4,19.998 4,18.558L4,7.776C4,6.336 5.169,5.167 6.609,5.167L17.391,5.167C18.831,5.167 20,6.336 20,7.776Z",
        ),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", "M4,9L20,9"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", "M6.5,3.722L6.5,5.167"),
        attribute.attribute("fill", "none"),
      ]),
      svg.path([
        attribute.attribute("d", "M17.5,3.722L17.5,5.167"),
        attribute.attribute("fill", "none"),
      ]),
      svg.circle([
        attribute.attribute("cx", "7"),
        attribute.attribute("cy", "12.5"),
        attribute.attribute("r", "0.5"),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.circle([
        attribute.attribute("cx", "12"),
        attribute.attribute("cy", "12.5"),
        attribute.attribute("r", "0.5"),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.circle([
        attribute.attribute("cx", "17"),
        attribute.attribute("cy", "12.5"),
        attribute.attribute("r", "0.5"),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.circle([
        attribute.attribute("cx", "7"),
        attribute.attribute("cy", "17"),
        attribute.attribute("r", "0.5"),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.circle([
        attribute.attribute("cx", "12"),
        attribute.attribute("cy", "17"),
        attribute.attribute("r", "0.5"),
        attribute.attribute("fill", "currentColor"),
      ]),
      svg.circle([
        attribute.attribute("cx", "17"),
        attribute.attribute("cy", "17"),
        attribute.attribute("r", "0.5"),
        attribute.attribute("fill", "currentColor"),
      ]),
    ],
  )
}

/// Renders a bar chart icon, used to represent data or summaries.
///
pub fn chart() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "24"),
      attribute.attribute("height", "24"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "2"),
    ],
    [
      svg.path([
        attribute.attribute(
          "d",
          "M22.59,4.821L22.59,19.179C22.59,20.442 21.564,21.468 20.301,21.468L3.699,21.468C2.436,21.468 1.41,20.442 1.41,19.179L1.41,4.821C1.41,3.558 2.436,2.532 3.699,2.532L20.301,2.532C21.564,2.532 22.59,3.558 22.59,4.821Z",
        ),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke-width", "2"),
      ]),
      svg.path([
        attribute.attribute("d", "M5.997,12.493L5.997,16.976"),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-linecap", "butt"),
      ]),
      svg.path([
        attribute.attribute("d", "M12.013,10.432L12.013,16.976"),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-linecap", "butt"),
      ]),
      svg.path([
        attribute.attribute("d", "M18,7L18,17"),
        attribute.attribute("fill", "none"),
        attribute.attribute("stroke-width", "3"),
        attribute.attribute("stroke-linecap", "butt"),
      ]),
    ],
  )
}

/// Renders a vertical three-dot (ellipsis) menu icon.
///
pub fn more_vert() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "20"),
      attribute.attribute("height", "20"),
      attribute.attribute("fill", "currentColor"),
    ],
    [
      svg.circle([
        attribute.attribute("cx", "12"),
        attribute.attribute("cy", "5"),
        attribute.attribute("r", "2"),
      ]),
      svg.circle([
        attribute.attribute("cx", "12"),
        attribute.attribute("cy", "12"),
        attribute.attribute("r", "2"),
      ]),
      svg.circle([
        attribute.attribute("cx", "12"),
        attribute.attribute("cy", "19"),
        attribute.attribute("r", "2"),
      ]),
    ],
  )
}

/// Renders an icon representing the absence of payments (a crossed-out card).
///
pub fn no_payments() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.attribute("width", "48"),
      attribute.attribute("height", "48"),
      attribute.attribute("fill", "none"),
      attribute.attribute("stroke", "currentColor"),
      attribute.attribute("stroke-width", "1.5"),
    ],
    [
      // Credit card outline
      svg.rect([
        attribute.attribute("x", "2"),
        attribute.attribute("y", "5"),
        attribute.attribute("width", "20"),
        attribute.attribute("height", "14"),
        attribute.attribute("rx", "2"),
      ]),
      // Card stripe
      svg.path([attribute.attribute("d", "M2 10h20")]),
      // Strike-through line
      svg.path([attribute.attribute("d", "M3 19L21 5")]),
    ],
  )
}
