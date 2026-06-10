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

### URL Parameters
For convenience, the demo supports setting configuration via URL parameters:
- `?storage=indexeddb`: Sets the storage backend to IndexedDB.
- `?db=my-custom-db`: Sets a custom database name.
- `?demo=true`: Loads example data.

Example: `http://localhost:5173/?storage=indexeddb&db=demo-db`

### Testing Reactivity
The component is **reactive** to attribute changes. You can test this in the browser console:

```javascript
// Switch to IndexedDB on the fly
document.querySelector('payment-tracker').setAttribute('storage-backend', 'indexeddb');

// Switch back to LocalStorage
document.querySelector('payment-tracker').setAttribute('storage-backend', 'localstorage');
```
The component will automatically detect the change and re-sync its state with the new backend.

## Project Structure
...- `index.html`: The entry point that imports and runs the web component.
- `vite.config.ts`: Configured with an `@dist` alias to resolve the compiled Gleam modules from the root `dist` directory.
