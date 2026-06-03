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
