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
