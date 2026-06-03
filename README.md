# Payment Tracker Web Component

A self-contained web component for tracking monthly payments, built with [Gleam](https://gleam.run/) and [Lustre](https://lustre.build/).

## Local Development

To maintain a fast development cycle with Hot Module Replacement (HMR), we use a "Dev Wrapper" app.

### Running the Dev Server
Lustre's dev server currently defaults to the project's main module. To use the dev wrapper:

1.  Open `src/payment_tracker_web_component.gleam`.
2.  Switch the `main` function to use the dev entry point:
    ```gleam
    import dev
    pub fn main() { dev.main(state.Default) }

    // pub fn main() {
    //   let app = lustre.component(init, update, view.view, [])
    //   lustre.register(app, "payment-tracker")
    // }
    ```
3.  Run the Lustre dev server:
    ```sh
    gleam run -m lustre/dev start
    ```
4.  Open [http://localhost:1234](http://localhost:1234). You are now seeing the actual `<payment-tracker>` web component running inside a Lustre host app.

### Testing the Production Bundle
To verify the final bundle behavior in a non-Gleam environment:

1.  **Revert** the `main` function in `src/payment_tracker_web_component.gleam` to its production version (registration only).
2.  **Build** the component:
    ```sh
    gleam run -m lustre/dev build
    ```
3.  **Start the demo server**:
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

To generate the self-contained JavaScript bundle:

```sh
gleam run -m lustre/dev build
```

The output will be in the `dist/` directory. You can then use it in any HTML file:

```html
<body>
    <payment-tracker></payment-tracker>
    <script type="module">
        import "@dist/payment_tracker_web_component.js";

        // Diagnostic: Check if the element is registered
        customElements.whenDefined('payment-tracker').then(() => {
            console.log('✅ <payment-tracker> has been registered.');
            const el = document.querySelector('payment-tracker');
            if (el.shadowRoot) {
                console.log('✅ Shadow DOM is present.');
            } else {
                console.error('❌ Shadow DOM is missing! Registration might have failed or initialized incorrectly.');
            }
        });
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
