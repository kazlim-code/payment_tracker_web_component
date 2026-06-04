# Payment Tracker Web Component - Demo

This folder contains a [Vite](https://vitejs.dev/) development environment for previewing and testing the `payment-tracker` web component.

## Prerequisites

- [Gleam](https://gleam.run/getting-started/installing-gleam/)
- [Node.js](https://nodejs.org/) (with npm)

## How to Run

### 1. Build the Web Component
From the **root directory** of the project, run:
```bash
gleam run -m lustre/dev build
```
This compiles the Gleam code into JavaScript modules located in `build/dev/javascript`.

### 2. Start the Demo Server
From this `demo` folder, install dependencies (first time only) and start Vite:
```bash
npm install
npm run dev
```

### 3. View in Browser
Open [http://localhost:5173](http://localhost:5173) in your browser.

## Configuring the Demo

You can modify `demo/index.html` to test different storage backends or enable demo mode.

```html
<!-- Test with no data -->
<payment-tracker></payment-tracker>

<!-- Test IndexedDB -->
<payment-tracker storage-backend="indexeddb"></payment-tracker>
<!-- OR with named db -->
<payment-tracker storage-backend="indexeddb" db-name="my-payments"></payment-tracker>

<!-- Test with example data -->
<payment-tracker demo="true"></payment-tracker>
```

## Project Structure
...- `index.html`: The entry point that imports and runs the web component.
- `vite.config.ts`: Configured with an `@dist` alias to resolve the compiled Gleam modules from the root `dist` directory.
