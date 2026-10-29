import { Ok, Error } from "./gleam.mjs";

export function uuid() {
  return crypto.randomUUID();
}

// LOCAL STORAGE

const getStorage = () => {
  if (typeof window !== "undefined" && window.localStorage) {
    return window.localStorage;
  }
  // Simple in-memory fallback for Node.js testing
  if (!globalThis.__mockLocalStorage) {
    globalThis.__mockLocalStorage = {
      store: new Map(),
      getItem(key) {
        return this.store.has(key) ? this.store.get(key) : null;
      },
      setItem(key, value) {
        if (value === "QUOTA_EXCEEDED") {
          throw new Error("QuotaExceededError");
        }
        this.store.set(key, value);
      },
      removeItem(key) {
        this.store.delete(key);
      },
      clear() {
        this.store.clear();
      },
    };
  }
  return globalThis.__mockLocalStorage;
};

/**
 * Gets a value from localstorage by key.
 * @param {string} key
 */
export function read(key) {
  try {
    const value = getStorage().getItem(key);
    return value !== null ? new Ok(value) : new Error(undefined);
  } catch (e) {
    return new Error(undefined);
  }
}

/**
 * Writes a value to localstorage for a given key.
 * @param {string} key
 * @param {string} value
 */
export function write(key, value) {
  try {
    getStorage().setItem(key, value);
    return new Ok(undefined);
  } catch (e) {
    return new Error(e.message || "Unknown storage error");
  }
}

// INDEXEDDB

const DB_VERSION = 2;
const USERS_STORE = "users";
const PAYMENTS_STORE = "payments";
const USER_PAYMENTS_STORE = "user_payments";

/**
 * Creates the user, payment and joining user_payments stores.
 * @param {IDBCursor} db
 */
function createStores(db) {
  if (!db.objectStoreNames.contains(USERS_STORE)) {
    const userStore = db.createObjectStore(USERS_STORE, {
      keyPath: "username",
    });
    userStore.createIndex("by_created", "created", { unique: false });
  }
  if (!db.objectStoreNames.contains(PAYMENTS_STORE)) {
    db.createObjectStore(PAYMENTS_STORE, { keyPath: "id" });
  }
  if (!db.objectStoreNames.contains(USER_PAYMENTS_STORE)) {
    db.createObjectStore(USER_PAYMENTS_STORE, {
      keyPath: ["username", "payment_id"],
    });
  }
}

/**
 * Opens the database and executes the given callback with the database object.
 * @param {string} dbName
 * @param {function} callback
 */
function withDB(dbName, callback) {
  const request = indexedDB.open(dbName, DB_VERSION);
  request.onupgradeneeded = (event) => {
    const db = request.result;
    createStores(db);
    // Migration from version 1 if necessary
    if (event.oldVersion < 1) {
      // Version 1 had a "keyvaluepairs" store. We'll just let it be or delete it if we were cleaner.
      // For this refactor, we assume a fresh start or simple transition.
    }
  };
  request.onsuccess = () => {
    callback(new Ok(request.result));
  };
  request.onerror = () => {
    callback(
      new Error("⚠️ Failed to open IndexedDB: " + request.error.message),
    );
  };
}

/**
 * Loads the first user found in the database, reconstructing it from relational stores.
 * @param {string} dbName
 * @param {function} callback
 */
export function idb_load_user(dbName, callback) {
  withDB(dbName, (res) => {
    if (res instanceof Error) return callback(res);
    const db = res[0];
    const transaction = db.transaction(
      [USERS_STORE, PAYMENTS_STORE, USER_PAYMENTS_STORE],
      "readonly",
    );

    const usersStore = transaction.objectStore(USERS_STORE);
    const userRequest = usersStore.index("by_created").getAll(null, 1); // Get the first created user

    userRequest.onsuccess = () => {
      const user = userRequest.result[0];
      if (!user) {
        return callback(new Error("NOT_FOUND"));
      }

      const userPaymentsStore = transaction.objectStore(USER_PAYMENTS_STORE);

      const payments = [];
      const userPaymentsRequest = userPaymentsStore.openCursor(
        IDBKeyRange.bound([user.username], [user.username, []]),
      );

      userPaymentsRequest.onsuccess = (event) => {
        const cursor = event.target.result;
        if (cursor) {
          const paymentId = cursor.value.payment_id;
          const paymentsStore = transaction.objectStore(PAYMENTS_STORE);
          const paymentReq = paymentsStore.get(paymentId);
          paymentReq.onsuccess = () => {
            if (paymentReq.result) {
              payments.push(paymentReq.result);
            }
            cursor.continue();
          };
        } else {
          user.payments = payments;
          console.info("🟢 👤 User loaded");
          callback(new Ok(JSON.stringify(user)));
        }
      };
    };

    transaction.onerror = () => {
      callback(
        new Error("⚠️ Failed to load user: " + transaction.error.message),
      );
    };
  });
}

/**
 * Saves a user and their payments across relational stores.
 * @param {string} dbName
 * @param {string} userJson
 * @param {function} callback
 */
export function idb_save_user(dbName, userJson, callback) {
  const user = JSON.parse(userJson);
  const payments = user.payments || [];
  // Clean user object for storage in 'users' store (no nested payments)
  const userMetadata = { ...user };
  delete userMetadata.payments;

  withDB(dbName, (res) => {
    if (res instanceof Error) return callback(res);
    const db = res[0];
    const transaction = db.transaction(
      [USERS_STORE, PAYMENTS_STORE, USER_PAYMENTS_STORE],
      "readwrite",
    );

    const usersStore = transaction.objectStore(USERS_STORE);
    const paymentsStore = transaction.objectStore(PAYMENTS_STORE);
    const userPaymentsStore = transaction.objectStore(USER_PAYMENTS_STORE);

    usersStore.put(userMetadata);

    // Clear existing payments for this user in the join table to keep it simple (overwrite sync)
    // In a real app we might do more surgical updates.
    const range = IDBKeyRange.bound([user.username], [user.username, []]);
    const deleteRequest = userPaymentsStore.openCursor(range);
    deleteRequest.onsuccess = (event) => {
      const cursor = event.target.result;
      if (cursor) {
        cursor.delete();
        cursor.continue();
      } else {
        // Now add current payments
        payments.forEach((payment) => {
          paymentsStore.put(payment);
          userPaymentsStore.put({
            username: user.username,
            payment_id: payment.id,
          });
        });
      }
    };

    transaction.oncomplete = () => {
      console.info("🟢 👤 User saved");
      callback(new Ok(undefined));
    };

    transaction.onerror = () => {
      callback(
        new Error("⚠️ Failed to save user: " + transaction.error.message),
      );
    };
  });
}

// ATTRIBUTES

/**
 * Returns the attributes of the payment tracker element.
 * @returns {Object}
 */
export function get_attributes() {
  const el = document.querySelector("payment-tracker");
  if (!el) return {};
  const attrs = {};
  for (const attr of el.attributes) {
    attrs[attr.name] = attr.value;
  }
  return attrs;
}

// View Transitions API

// TODO (Scoped View Transitions Level 2 Migration):
// Once Element-Scoped View Transitions (CSS View Transitions Level 2) gain baseline browser support,
// migrate from `document.startViewTransition()` to `element.startViewTransition()` or
// `shadowRoot.startViewTransition()`. This will allow removing this global Light DOM style injection
// in favour of encapsulating `@keyframes` and `view-transition-name` rules directly in `src/ui/styles.gleam`.

// Apply global styles for the payment tracker and enable view transitions api
const transitionCssText = `
  /* Disable root transition completely so we don't get the default UA fade */
  :root {
    --content-view-transition-time: 0.25s;
    view-transition-name: none;
  }

  /* Expose the inner main element to the document-level view transition */
  payment-tracker::part(content) {
    view-transition-name: content;
    animation: none;
    mix-blend-mode: normal;
  }

  /* Fallback: if browser doesn't support transition types, default to forward */

  /* Animation styles for forward type */
  html:active-view-transition-type(forward) {
    &::view-transition-old(content) {
      animation: slide-left-out var(--content-view-transition-time) ease-out both;
    }
    &::view-transition-new(content) {
      animation: scale-up var(--content-view-transition-time) ease-out both calc(var(--content-view-transition-time) / 4);
    }
  }

  /* Example Backward animation (reverse) */
  html:active-view-transition-type(backward) {
    &::view-transition-old(content) {
      animation: scale-up var(--content-view-transition-time) ease-out both reverse;
    }
    &::view-transition-new(content) {
      animation: slide-right-in var(--content-view-transition-time) ease-out both calc(var(--content-view-transition-time) / 2);
    }
  }

  @keyframes scale-up {
    from {
      transform: scale(0.95);
      opacity: 0;
    }
    to {
      transform: scale(1);
      opacity: 1;
    }
  }
  @keyframes slide-left-out {
    0% {
      opacity: 1;
    }
    10% {
      opacity: 0.9;
    }
    45% {
      opacity: 0.1;
    }
    100% {
      transform: translateX(-45%);
      opacity: 0;
    }
  }
  @keyframes slide-right-in {
    0% {
      transform: translateX(-45%);
      opacity: 0;
    }
    10% {
      opacity: 0.1;
    }
    45% {
      opacity: 0.9;
    }
    100% {
    transform: translateX(0);
      opacity: 1;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    ::view-transition-group(*),
    ::view-transition-old(*),
    ::view-transition-new(*) {
      animation: none !important;
    }
  }
`;

// Inject css required for View Transitions
if (typeof document !== "undefined") {
  if ("adoptedStyleSheets" in document) {
    // Initialise and adopt stylesheet in the document
    const sheet = new CSSStyleSheet();
    sheet.replaceSync(transitionCssText);
    document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet];
    console.log("✅ Using adoptedStyleSheets for View Transitions");
  } else {
    // Fallback for older environments lacking adoptedStylesheets
    const transitionStyles = document.createElement("style");
    transitionStyles.textContent = transitionCssText;
    document.head.appendChild(transitionStyles);
    console.log("🔄 Fallback injecting style tag for View Transitions");
  }
}

/**
 * Starts a view transition with the given update function and direction.
 * @param {function} updateDom
 * @param {string} direction
 */
export function startViewTransition(updateDom, direction) {
  // Ensure feature exists
  if (typeof document === "undefined" || !document.startViewTransition) {
    updateDom();
    return;
  }

  // Passing types dynamically requires the direction string
  const transition = document.startViewTransition({
    update: updateDom,
    types: direction !== "none" ? [direction] : [],
  });

  transition.ready.catch((e) => {
    console.error("❌ View transition failed to start:", e);
  });
}

// KEYBOARD NAVIGATION & FOCUS HELPERS

/**
 * Focuses an element inside the component's shadow root matching the selector.
 * @param {string} selector
 * @param {boolean} selectAll
 * @param {boolean} clearValue
 */
export function focus_element(selector, selectAll, clearValue) {
  if (typeof document === "undefined") return;
  const tracker = document.querySelector("payment-tracker");
  const root = tracker && tracker.shadowRoot ? tracker.shadowRoot : document;
  const el = root.querySelector(selector);
  if (el) {
    if (clearValue && "value" in el) {
      el.value = "";
    }
    el.focus();
    if (selectAll && typeof el.select === "function") {
      el.select();
    }
  }
}

/**
 * Blurs the currently active element in the shadow DOM or document.
 */
export function blur_active_element() {
  if (typeof document === "undefined") return;
  const tracker = document.querySelector("payment-tracker");
  const root = tracker && tracker.shadowRoot ? tracker.shadowRoot : document;
  if (root.activeElement && typeof root.activeElement.blur === "function") {
    root.activeElement.blur();
  } else if (
    document.activeElement &&
    typeof document.activeElement.blur === "function"
  ) {
    document.activeElement.blur();
  }
}

/**
 * Attaches a global keyboard listener to window, calling the Gleam callback.
 * @param {function} callback
 */
export function subscribe_keyboard(callback) {
  if (typeof window === "undefined") return;

  const normalCommandKeys = new Set([
    "c",
    "d",
    "p",
    "i",
    "s",
    "t",
    "j",
    "k",
    "h",
    "l",
    "g",
    "m",
    "[",
    "]",
    "{",
    "}",
    "/",
    "Enter",
    " ",
    "?",
    "Escape",
  ]);

  const handleKeyDown = (e) => {
    const target = e.composedPath ? e.composedPath()[0] : e.target;
    const isInput =
      target &&
      (target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.isContentEditable);

    // In normal mode (not in input), prevent browser default action for all navigation/command keys
    // This prevents the key from being typed into the newly focused field!
    if (!isInput && !e.ctrlKey && !e.metaKey && !e.altKey) {
      if (normalCommandKeys.has(e.key)) {
        e.preventDefault();
      }
    }

    // In input, prevent default on Escape, Ctrl+Enter / Shift+Enter, or Enter on single-line <input>
    if (isInput) {
      if (e.key === "Escape") {
        e.preventDefault();
      }
      if (e.key === "Enter") {
        if (e.isComposing || e.keyCode === 229) {
          return;
        }
        if (e.ctrlKey || e.shiftKey || target.tagName === "INPUT") {
          e.preventDefault();
        }
      }
    }

    callback(
      e.key,
      Boolean(e.ctrlKey),
      Boolean(e.altKey),
      Boolean(e.shiftKey),
      Boolean(e.metaKey),
      Boolean(isInput),
    );
  };

  window.addEventListener("keydown", handleKeyDown);
}

