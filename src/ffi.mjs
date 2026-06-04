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

const DB_VERSION = 1;
const STORE_NAME = "keyvaluepairs";

function withDB(dbName, callback) {
  const request = indexedDB.open(dbName, DB_VERSION);
  request.onupgradeneeded = () => {
    request.result.createObjectStore(STORE_NAME);
  };
  request.onsuccess = () => {
    callback(new Ok(request.result));
  };
  request.onerror = () => {
    callback(new Error("Failed to open IndexedDB: " + request.error.message));
  };
}

export function idb_get(dbName, key, callback) {
  withDB(dbName, (res) => {
    if (res instanceof Error) return callback(res);
    const db = res[0];
    const transaction = db.transaction(STORE_NAME, "readonly");
    const store = transaction.objectStore(STORE_NAME);
    const request = store.get(key);
    request.onsuccess = () => {
      if (request.result === undefined) {
        callback(new Error("NOT_FOUND"));
      } else {
        callback(new Ok(request.result));
      }
    };
    request.onerror = () => {
      callback(new Error("Failed to read from IndexedDB: " + request.error.message));
    };
  });
}

export function idb_set(dbName, key, value, callback) {
  withDB(dbName, (res) => {
    if (res instanceof Error) return callback(res);
    const db = res[0];
    const transaction = db.transaction(STORE_NAME, "readwrite");
    const store = transaction.objectStore(STORE_NAME);
    const request = store.put(value, key);
    request.onsuccess = () => {
      callback(new Ok(undefined));
    };
    request.onerror = () => {
      callback(new Error("Failed to write to IndexedDB: " + request.error.message));
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
