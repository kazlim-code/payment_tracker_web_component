# Payment Tracker Web Component

A self-contained web component for tracking monthly payments, built with [Gleam](https://gleam.run/) and [Lustre](https://lustre.build/).

## Features

*   **Three Integrated Views**:
    *   **Add Payment (Card)**: Quick entry form for recording new payments.
    *   **Monthly Summary**: High-level financial table showing total paid and owed for each month.
    *   **Monthly Detail**: Chronological checklist of all monthly entries.
*   **Search & Sort**: Filter monthly payments instantly by name and sort them by date, description, or amount with visible sort direction indicators.
*   **WAI-ARIA Accessible**: Fully semantic table markup with screen-reader friendly attributes (`scope="col"` and dynamic `aria-sort` state indicators).
*   **Swappable Storage Engines**: Built-in reactive support for `localStorage` and `IndexedDB` backends.

## Local Development

To maintain a fast development cycle with Hot Module Replacement (HMR), we use a "Dev Wrapper" app. Lustre's dev tools support targeting specific entry points by passing the module name as a command-line argument.

### Running the Dev Server

To run the dev wrapper application using the `main` function in [dev.gleam](file:///Users/callum/Documents/GitHub/payment_tracker_web_component/src/dev.gleam):

1.  Run the Lustre dev server, specifying the `dev` module:
    ```sh
    gleam run -m lustre/dev start dev
    ```
2.  Open [http://localhost:1234](http://localhost:1234). You are now seeing the actual `<payment-tracker>` web component running inside the Lustre host dev app.

### Testing the Production Bundle

To verify the final bundle behavior in a non-Gleam environment:

1.  **Build** the component using the main entry module [payment_tracker_web_component.gleam](file:///Users/callum/Documents/GitHub/payment_tracker_web_component/src/payment_tracker_web_component.gleam):
    ```sh
    gleam run -m lustre/dev build
    ```
2.  **Start the demo server**:
    ```sh
    cd demo && pnpm dev
    ```

## Versioning

This project follows [Semantic Versioning (SemVer)](https://semver.org/).

- **Source of Truth:** The version is defined in `gleam.toml`.
- **Synchronization:** The version is synchronized to the Gleam code via a script. If you update the version in `gleam.toml`, you must run:
  ```sh
  ./scripts/sync_version.sh
  ```
  This generates `src/core/version.gleam`, which is used to display the version in the UI.

## Testing

This project uses a hybrid testing strategy: **Unit Tests** for logic and **Snapshot Tests** for structural output.

### Running Unit Tests
Unit tests verify calculations, state transitions, and edge cases. Run them with:
```sh
gleam test
```

### Reviewing Snapshot Tests (Birdie)
We use [Birdie](https://github.com/lpil/birdie) for snapshot testing. This requires a "Human-in-the-Loop" workflow:

1.  **Run Tests:** `gleam test` will fail if a snapshot is new or has changed.
2.  **Review:** Examine the diff presented in the terminal.
3.  **Accept/Reject:** If the changes are intentional and correct, run the review tool to accept them:
    ```sh
    gleam run -m birdie
    ```

For a detailed breakdown of our testing philosophy and naming conventions, see [docs/TESTING.md](docs/TESTING.md).

## Building for Production

To generate the self-contained JavaScript bundle, target the main entrypoint module:

```sh
gleam run -m lustre/dev build
```

The output will be in the `dist/` directory.

## Usage & Configuration

You can use the component in any HTML file by importing the bundle. The component supports different storage backends via attributes. **The component is reactive**, meaning changing these attributes at runtime via JavaScript will trigger the component to update its state (e.g., swapping storage backends on the fly).

### Storage Backends

By default, the component uses `localStorage`. You can switch to `indexeddb` using the `storage-backend` attribute.

| Attribute | Options | Default | Description |
|-----------|---------|---------|-------------|
| `storage-backend` | `localstorage`, `indexeddb` | `localstorage` | The storage engine to use. |
| `db-name` | *string* | `payment-tracker-db` | The name of the IndexedDB database (only used if `storage-backend="indexeddb"`). |
| `demo` | `true`, `false` | `false` | If true, initializes with example data (useful for demos). |

### Example

```html
<body>
    <!-- Using IndexedDB -->
    <payment-tracker storage-backend="indexeddb" db-name="my-payments"></payment-tracker>

    <script type="module">
        import "@dist/payment_tracker_web_component.js";
    </script>
</body>
```

## Project Structure

- `src/`: Gleam source code
  - `ui/view.gleam`: The main component UI
  - `ui/styles.gleam`: Encapsulated CSS
  - `dev.gleam`: Development host application (for `lustre/dev start`)
- `demo/`: A Vite-powered environment to test the built web component
- `dist/`: Production-ready JavaScript bundle
