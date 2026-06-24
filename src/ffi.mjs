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
        return this.store.get(key) || null;
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
    return value ? new Ok(value) : new Error(undefined);
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

function withDB(dbName, callback) {
  const request = indexedDB.open(dbName, DB_VERSION);
  request.onupgradeneeded = (event) => {
    const db = request.result;
    if (!db.objectStoreNames.contains(USERS_STORE)) {
      db.createObjectStore(USERS_STORE, { keyPath: "username" });
    }
    if (!db.objectStoreNames.contains(PAYMENTS_STORE)) {
      db.createObjectStore(PAYMENTS_STORE, { keyPath: "id" });
    }
    if (!db.objectStoreNames.contains(USER_PAYMENTS_STORE)) {
      db.createObjectStore(USER_PAYMENTS_STORE, {
        keyPath: ["username", "payment_id"],
      });
    }
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
    callback(new Error("⚠️ Failed to open IndexedDB: " + request.error.message));
  };
}

/**
 * Loads the first user found in the database, reconstructing it from relational stores.
 */
export function idb_load_user(dbName, callback) {
  withDB(dbName, (res) => {
    if (res instanceof Error) return callback(res);
    const db = res[0];
    const transaction = db.transaction(
      [USERS_STORE, PAYMENTS_STORE, USER_PAYMENTS_STORE],
      "readonly"
    );

    const usersStore = transaction.objectStore(USERS_STORE);
    const userRequest = usersStore.getAll(null, 1); // Get the first user

    userRequest.onsuccess = () => {
      const user = userRequest.result[0];
      if (!user) {
        return callback(new Error("NOT_FOUND"));
      }

      const userPaymentsStore = transaction.objectStore(USER_PAYMENTS_STORE);

      // I'll update onupgradeneeded to add an index.
      const payments = [];
      const userPaymentsRequest = userPaymentsStore.openCursor(IDBKeyRange.bound([user.username], [user.username, []]));

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
          // Finished gathering payments
          user.payments = payments;
          console.info("🟢 👤 User loaded");
          callback(new Ok(JSON.stringify(user)));
        }
      };
    };

    transaction.onerror = () => {
      callback(new Error("⚠️ Failed to load user: " + transaction.error.message));
    };
  });
}

/**
 * Saves a user and their payments across relational stores.
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
      "readwrite"
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
      callback(new Error("⚠️ Failed to save user: " + transaction.error.message));
    };
  });
}

// ATTRIBUTES

export function get_attributes() {
  const el = document.querySelector("payment-tracker");
  if (!el) return {};
  const attrs = {};
  for (const attr of el.attributes) {
    attrs[attr.name] = attr.value;
  }
  return attrs;
}
