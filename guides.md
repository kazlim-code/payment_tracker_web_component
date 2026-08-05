
--- Guide for same-document-transitions ---
# Same Document Transitions

## The Problem

Web sites often provide multiple views of an object, for instance a list of products, and then a detail page for each product. Navigating between the two views often feels disconnected. When a user clicks a product thumbnail to view its details, the thumbnail disappears and a new, larger image appears instantly elsewhere on the screen. This lack of continuity makes it harder for users to track relationships between elements.

## The Solution

The **View Transitions API** allows you to specify element pairs that exist in different states before and after a transition. When triggering a transition with `document.startViewTransition()` in a Single Page Navigation (SPA), the browser identifies these shared elements by their shared unique `view-transition-name`. It then automatically calculates the difference in their position, size, and styling, and animates them smoothly from the old state to the new state. This transition occurs in the top layer, above even elements with high `z-index` values.

## Implementation Guide

### Step 1: Wrap State Changes in `startViewTransition`

For Single-Page Applications (SPAs) or simple state changes, wrap the logic that updates the DOM in `document.startViewTransition`. The browser captures a snapshot of the current state, runs the update, and then captures the new state. 

```javascript
function navigate(view) {
  // MANDATORY: Wrap the update in startViewTransition
  document.startViewTransition(() => updateDOM(view));
}
```

### Step 2: Assign Shared Transition Names

Use the `view-transition-name` CSS property to tell the browser which elements should be morphed. The name can be anything (except `none`). **MANDATORY**: there must be no more than 1 element before and after with a given `view-transition-name`. If there are 2 or more elements with a given `view-transition-name`, the DOM will be updated to the new state immediately, without a transition.

You can use multiple `view-transition-name`s to morph multiple pairs of elements. For example, you may want to transition both the product image and title with separate transitions.

Because there are multiple items on the list view, you can not give the all of them the same `view-transition-name`. This can be solved in two ways in a SPA.

1. **Dynamic detail page:** Assign each item on the list page a unique `view-transition-name`, and then dynamically apply that name to the matching element on the detail page when the list item is selected, as shown here.

```css
/* In the list view, give each */
#product-1 { view-transition-name: p1 }
#product-2 { view-transition-name: p2 }
#product-3 { view-transition-name: p3 }
```

```js
function updateDOM(clickedTransitionName){
  const hero = document.getElementById("hero");
  hero.style.viewTransitionName = clickedTransitionName;
}
```

2. **Dynamic list item:** Assign the element on the detail page a `view-transition-name`, and apply that name to the item on the list page when it is selected. Remove the `view-transition-name` from the item on the list page when returning to the list page.

The `#hero` element on the detail page and the selected `.thumbnail` element on the list page share a `view-transition-name`. 

```css
#hero{
  view-transition-name: hero;
}
.thumbnail.selected {
  view-transition-name: hero;
}
```

When a thumbnail is clicked, we need to prepare the list view by assigning the `view-transition-name` using the `.selected` class selector, and making any changes to the DOM before starting the transition.

Then, you can call `document.startViewTransition()`, and apply the changes to transition the page from the detail to list view.

After navigating back to the list view, you must clean up the view transition classes to prevent the next navigation from erroring. You can perform this cleanup after the transition's `finished` promise resolves.

```javascript
// Function called when a thumbnail is clicked
function goFromListToDetail(e){
  e.currentTarget.classList.add("selected");
  const hero = document.getElementById("hero");
  const bgColor = getComputedStyle(e.currentTarget).backgroundColor;
  hero.style.background = bgColor;

  // Trigger the transition, checking for support
  if (!document.startViewTransition) {
    document.body.classList.add("detail");
    // MANDATORY Accessibility Routing: Route focus to the newly revealed heading to announce context and preserve logical tab flow
    document.getElementById("detail-heading")?.focus();
    return; // MANDATORY: End function execution if view transitions are not supported.  
  }
  const transition = document.startViewTransition(() => {
    document.body.classList.add("detail");
  });
  // MANDATORY Accessibility Routing: Route focus after the view transition resolves
  transition.finished.finally(() => {
    document.getElementById("detail-heading")?.focus();
  });
}

// Function called when navigating from detail back to list view
function goFromDetailToList() {
  if (!document.startViewTransition) {
    document.body.classList.remove("detail");
    document.getElementById("list-heading")?.focus();
    return;
  }
  const transition = document.startViewTransition(() => {
    document.body.classList.remove("detail");
  });
  // Clean up the list view and route focus
  transition.finished.finally(() => {
    // Route focus back to list view
    document.getElementById("list-heading")?.focus();
    // Remove selected classList to remove view-transition-names
    document.querySelectorAll(".selected").forEach(
      (element) => {
        element.classList.remove("selected");
      },
    );
  });
}
```

The method you choose will depend on the use case. The dynamic list item requires less repeated CSS, but more manual JavaScript cleanup.


### Step 3: Fix Aspect Ratio "Stretching"

By default, the browser cross-fades the old and new snapshots within a group that stretches to fit both. If you are transitioning text, set the width of the text element to `fit-content` on both the old and new views, so that the transitioned element's aspect ratio is stable.

```css
#list-page .title {
  width: fit-content;
}

#detail-page #title {
  width: fit-content;
}
```

If you are transitioning elements that change aspect ratio, you may need to set the height of the old and new pseudo-elements to 100% of the `::view-transition-pair()` pseudo-element.

```css
::view-transition-old(hero),
::view-transition-new(hero){
  height: 100%;
}
```

The pseudo-elements are snapshots of the live elements, so you can also use `object-fit` and `object-position` declarations for more control of the transitioning effect.

## Best Practices

-   **DO NOT** specify too many transitions. Only use shared elements for primary content that the user is actively tracking (e.g., hero images, headings).
-   **DO** remove temporary `view-transition-name` values after the transition finishes to avoid side effects on future transitions.
-   **DO NOT** transition elements with active animations. View transitions operate on snapshots, so any animations will appear to be paused during the view transition.
-   **DO** respect user preferences for reduced motion using the `prefers-reduced-motion` media query.
-   **MANDATORY Accessibility Routing**: View transitions morph page layouts dynamically but do not manage programmatic focus. If focus remains on an element that is hidden or removed during the transition, focus is abandoned, leaving keyboard and assistive technology users without context. Shift focus programmatically to an updated page heading or view container (using `tabindex="-1"`) immediately after the DOM updates or when the view transition's `finished` promise resolves.

```css
@media (prefers-reduced-motion: reduce) {
  ::view-transition-group(*),
  ::view-transition-old(*),
  ::view-transition-new(*) {
    animation: none !important;
  }
}
```

## Fallback Strategies

Baseline status for View transitions: Newly available. It's been Baseline since 2025-10-14.
Supported by: Chrome 111 (Mar 2023), Edge 111 (Mar 2023), Firefox 144 (Oct 2025), and Safari 18 (Sep 2024).

The View Transitions API is designed for progressive enhancement. Browsers that do not support it will simply execute the DOM update immediately without animation.

```javascript
function navigate(){
  if (!document.startViewTransition) {
    // Fallback: Just update the DOM
    updateDOM();
  } else {
    document.startViewTransition(() => updateDOM());
  }
}
```


--- Guide for directional-navigation-transitions ---
Single Page Applications (SPAs) provide the appearance of navigation by replacing the content of the page without navigating to a new page. By default, the content is simply replaced, without any transitions. Directional transitions can visually reinforce a spatial relationship between views. 

By sliding new content in from the direction the user is moving you create a mental map of the application structure. For instance, a product site may show a transition to the right for "forward," and to the left for "back", or a slideshow may transition up and down to show next and previous slides.

### Implementation Steps

1. **Detect Navigation Direction**: Determine if the user is moving "forward" or "backward" in the application flow. How you detect the direction depends on your use case.
2. **Trigger Transition with Types**: Pass the direction in a `types` array to `document.startViewTransition()` to categorize the transition.
3. **Define Directional Animations with CSS**: Use the `:active-view-transition-type()` pseudo-class to apply specific animations based on the navigation type.

### Defining Keyframes

Define sliding animations to and from each direction. For best performance, animate position changes using the `transform` property or the individual transform properties, `scale`, `rotate`, and `translate`. `opacity` is generally performant as well, but avoid animating other CSS properties without first verifying that they don't trigger layout or painting.

```css
/* Slide an element out to the left */
@keyframes slide-to-left {
  /* Mandatory: animate `transform` instead of inset properties for better performance. */
  to { transform: translateX(-100%); }
}

/* Slide an element in from the right */
@keyframes slide-from-right {
  from { transform: translateX(100%); }
}

/* Slide an element out to the right */
@keyframes slide-to-right {
  to { transform: translateX(100%); }
}

/* Slide an element in from the left */
@keyframes slide-from-left {
  from { transform: translateX(-100%); }
}
```

### Set up shared animation settings

Use the `::view-transition-group(root)` selector to apply animation settings that are shared across all transitions.

```css
::view-transition-group(root){
  animation: 0.4s ease-in-out both;
}
```

### Applying Directional Animations

Use the `active-view-transition-type` pseudo-class to target the transition views specifically when the "forward" or "backward" type is active.

```css
/* MANDATORY: Apply forward animations when the 'forward' type is active */
html:active-view-transition-type(forward)::view-transition-old(root) {
  animation-name: slide-to-left;
}
html:active-view-transition-type(forward)::view-transition-new(root) {
  animation-name: slide-from-right;
}

/* MANDATORY: Apply backward animations when the 'backward' type is active */
html:active-view-transition-type(backward)::view-transition-old(root) {
  animation-name: slide-to-right;
}
html:active-view-transition-type(backward)::view-transition-new(root) {
  animation-name: slide-from-left;
}
```

### Triggering the Transition

When navigating, pass the appropriate type to the `startViewTransition` method.

```javascript
const transitionType = yourTransitionTypeLogic();
const updateDOM = yourUpdateDOMLogic();

document.startViewTransition({
  update: updateDOM,
  types: [transitionType] // Matches the CSS :active-view-transition-type() selectors
});
```


### Accessibility

Always respect user preferences for reduced motion by disabling or simplifying animations.

```css
@media (prefers-reduced-motion: reduce) {
  ::view-transition-group(root) {
    animation: none !important;
  }
}
```

### Fallback strategies

Baseline status for View transitions: Newly available. It's been Baseline since 2025-10-14.
Supported by: Chrome 111 (Mar 2023), Edge 111 (Mar 2023), Firefox 144 (Oct 2025), and Safari 18 (Sep 2024).
Baseline status for Active view transition: Newly available. It's been Baseline since 2026-01-13.
Supported by: Chrome 125 (May 2024), Edge 125 (May 2024), Firefox 147 (Jan 2026), and Safari 18.2 (Dec 2024).

The View Transitions API is a progressive enhancement. In unsupported browsers, `document.startViewTransition` will be `undefined`. You must wrap your navigation logic in a feature detection check to ensure the DOM update still occurs immediately without animation, as shown in this helper function.

```javascript
/**
 * Navigates to a new view with a directional transition.
 * @param {Function} updateDOM - Callback to update the DOM state.
 * @param {string} direction - Either 'forward' or 'backward'.
 */
function navigate(updateDOM, direction) {
  // Feature detect for browsers that do not support View Transitions
  if (!document.startViewTransition) {
    updateDOM();
    return;
  }

  // Start transition with the specific navigation type
  document.startViewTransition({
    update: updateDOM,
    types: [direction] // Matches the CSS :active-view-transition-type() selectors
  });
}
```


--- Guide for group-element-transitions ---
As items are added or removed from a list, or rearranged, transitions can help users maintain context. View transitions provide a way to transition between two states of an element by giving the element a unique `view-transition-name`. When multiple elements on a page share the same transition behavior, `view-transition-class` allows you to define that logic once in CSS rather than repeating it for every unique `view-transition-name`. This keeps your stylesheets maintainable while ensuring consistent animations across a group of elements.

### Implementation steps

1. **Assign unique names and a shared class**

Each element that needs to be tracked individually during a transition must have a unique `view-transition-name`.

```html
<!-- Mandatory: Each element must have a unique view-transition-name -->
<li style="view-transition-name: item-1" class="item">Item 1</li>
<li style="view-transition-name: item-2" class="item">Item 2</li>
```

To apply shared styles, also assign a `view-transition-class`.

```css
.item {
  view-transition-class: list-item;
}
```

2. **Define the shared transition logic**
   
Use the `::view-transition-group()` pseudo-element with the class selector to apply styles to all members of that group.

```css
/* Targets any view transition group that has the 'list-item' class */
::view-transition-group(.list-item) {
  animation-duration: 0.5s;
  animation-timing-function: ease-in-out;
}

/* Handle accessibility by respecting motion preferences */
@media (prefers-reduced-motion: reduce) {
  /* Disable all group transitions, including the default `root` group. */
  ::view-transition-group(*),
  ::view-transition-old(*),
  ::view-transition-new(*) {
    animation: none !important;
  }
}
```

3. **Optional: Define entry and exit animations**

Use the `:only-child` selector to add specific transitions to the elements that are added or removed. `::view-transition-new()` and `::view-transition-old()` pseudo-elements are children of a `::view-transition-image-pair()` pseudo-element, so we can determine it is an added or removed element if it is the only child.

```css
/* A `::view-transition-new()` element is the only child if it wasn't present before the view transition, so it is an added element. */
::view-transition-new(.list-item):only-child {
  animation-name: slide-in;
  /* Specify an animation duration if you want something different than the UA default of 0.5s */
  animation-duration: 1s;
}
/* A `::view-transition-old()` element is the only child if it isn't present after the view transition, so it is a removed element. */
::view-transition-old(.list-item):only-child {
  animation-name: slide-out;
  /* Specify an animation duration if you want something different than the UA default of 0.5s */
  animation-duration: 1s;
}

@keyframes slide-in {
  from {
    translate: -100vw 0;
  }
}
@keyframes slide-out {
  to {
    translate: -100vw 0;
  }
}
```

4. **Trigger the transition**

Wrap the DOM update in `document.startViewTransition()`. The browser will capture the old state, perform the update, and then animate to the new state.

```javascript
function updateList(newData) {
  document.startViewTransition(() => {
    // All DOM changes inside this callback will be transitioned
    render(newData);
  });
}
```

5. **Maintain interactivity of non-transitioned elements**

View transitions work by overlaying snapshots of the DOM elements, and then transitioning the snapshots. This means that during the transition, elements are not interactive. If there are interactive elements that are not transitioned, you can make them interactive by disabling touch events on the view transitions.

```css
::view-transition {
  /* Non-transitioned elements below the view transitions remain interactive */
  pointer-events: none;
}
```

In addition, by default, the `:root` element has a view transition named `root`, which enables default full-page transitions. If there are no changes to the root element, this will be a transition between two identical snapshots, which are not interactive. Because we are only transitioning specific elements, and not the entire screen, we can disable the `root` transition. 

```css
:root {
  /* Disable the root transition because we are only transitioning specific elements. */
  view-transition-name: none;
}
```

### Fallback strategies

Baseline status for view-transition-class: Newly available. It's been Baseline since 2025-10-14.
Supported by: Chrome 125 (May 2024), Edge 125 (May 2024), Firefox 144 (Oct 2025), and Safari 18.2 (Dec 2024).

View Transitions are a progressive enhancement. If the browser does not support `document.startViewTransition`, the DOM update should still occur immediately, providing a functional but non-animated experience.

```javascript
if (document.startViewTransition) {
  document.startViewTransition(() => updateDOM());
} else {
  // Fallback: Perform the update without animation
  updateDOM();
}
```

For CSS, browsers that do not recognize `view-transition-class` or the `::view-transition-group()` class selector will simply ignore those rules, and no animation will be applied.

