import "fake-indexeddb/auto";
import { IDBFactory, IDBIndex } from "fake-indexeddb";
import { afterEach, beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
import { idb_load_user } from "#ffi";
import { Error as GleamError, Ok as GleamOk } from "#gleam";

const DB_NAME = "payment-tracker-test-db";
const DB_VERSION = 2;
const USERS_STORE = "users";
const PAYMENTS_STORE = "payments";
const USER_PAYMENTS_STORE = "user_payments";

// --- Helpers ---

/**
 * Creates the user, payment and joining user_payments stores.
 * @param {IDBDatabase} db
 * @returns {void}
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
 * Creates/updates the IndexedDB stores before tests run.
 * @param {IDBDatabase} idb
 * @param {string} dbName
 * @returns {Promise<void>}
 */
function setupObjectStores(idb, dbName) {
  return new Promise((resolve, reject) => {
    const request = idb.open(dbName, DB_VERSION);
    request.onupgradeneeded = () => createStores(request.result);
    request.onsuccess = () => {
      const db = request.result;
      db.close();
      resolve();
    };
    request.onerror = () => {
      reject(
        new globalThis.Error(
          "⚠️ Failed to open IndexedDB: " + request.error?.message,
        ),
      );
    };
  });
}

/**
 * Adds a user to the IndexedDB respective tables.
 * @param {IDBDatabase} idb
 * @param {string} dbName
 * @param {string[]} userJsonStrings
 * @returns {Promise<void>}
 */
function seedUsers(idb, dbName, userJsonStrings) {
  return new Promise((resolve, reject) => {
    let users = [];
    try {
      const items = Array.isArray(userJsonStrings)
        ? userJsonStrings
        : [userJsonStrings];
      users = items.map((item) =>
        typeof item === "string" ? JSON.parse(item) : item,
      );
    } catch (err) {
      return reject(
        new globalThis.Error(
          "Failed to parse user during seeding: " + err.message,
        ),
      );
    }

    const request = idb.open(dbName, DB_VERSION);
    request.onupgradeneeded = () => createStores(request.result);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction([USERS_STORE], "readwrite");
      const userStore = transaction.objectStore(USERS_STORE);

      for (const user of users) {
        const addUserRequest = userStore.put(user);
        addUserRequest.onerror = () => {
          console.warn(
            "⚠️ Failed to add user: " + addUserRequest.error?.message,
          );
        };
      }

      transaction.oncomplete = () => {
        db.close();
        resolve();
      };
      transaction.onerror = () => {
        db.close();
        reject(
          new globalThis.Error(
            "⚠️ Failed to update User store: " + transaction.error?.message,
          ),
        );
      };
    };
    request.onerror = () => {
      reject(
        new globalThis.Error(
          "⚠️ Failed to open IndexedDB: " + request.error?.message,
        ),
      );
    };
  });
}

/**
 * Replaces the IDBIndex.getAll function with a mock function that ensures the
 * transaction errors.
 * @param {function} idbIndexGetAll
 * @returns {void}
 */
function mockGetAllError(idbIndexGetAll) {
  IDBIndex.prototype.getAll = function (...args) {
    const request = idbIndexGetAll.apply(this, args);
    const transaction = this.objectStore.transaction;
    queueMicrotask(() => {
      transaction.error = new DOMException("Index read failure", "DataError");
      if (typeof transaction.onerror === "function") {
        transaction.onerror(new Event("error"));
      }
    });

    return request;
  };
}

/**
 * Loads the user from the IndexedDB.
 * @param {string} dbName
 * @returns {Promise}
 */
function loadUser(dbName) {
  return new Promise((resolve) => idb_load_user(dbName, resolve));
}

// --- END Helpers ---

describe("IndexedDB FFI", () => {
  const basicUserJsonString =
    '{"created":"2026-06-19T02:40:17.121000Z","first_name":"John","last_name":null,"monthly_payments":[],"home_loan_payment":null,"home_loan_transfer":null,"month_year":"2026-06","paid":null,"total":0,"length":0,"username":"TestUser"}';

  beforeEach(() => {
    // Synchronously resets all databases and stores to a clean state
    globalThis.indexedDB = new IDBFactory();
  });

  describe("idb_load_user()", () => {
    describe("when no user exists", () => {
      it("returns NOT_FOUND", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.equal(res[0], "NOT_FOUND");
      });
    });

    describe("when 1 user exists", () => {
      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedUsers(globalThis.indexedDB, DB_NAME, basicUserJsonString);
      });

      it("returns the first user", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);
        const user = JSON.parse(res[0]);
        assert.equal(user.username, "TestUser");
        assert.equal(user.first_name, "John");
      });
    });

    describe("when multiple users exist", () => {
      const newUserJsonString =
        '{"created":"2026-06-19T02:40:17.121000Z","first_name":"Jane","last_name":null,"monthly_payments":[],"home_loan_payment":null,"home_loan_transfer":null,"month_year":"2026-06","paid":null,"total":0,"length":0,"username":"NewUser"}';

      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedUsers(globalThis.indexedDB, DB_NAME, [
          basicUserJsonString,
          newUserJsonString,
        ]);
      });

      it("returns the first created user", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);
        const user = JSON.parse(res[0]);
        assert.equal(user.username, "NewUser");
        assert.equal(user.first_name, "Jane");
      });
    });

    describe("when indexeddb fails to connect", () => {
      let originalOpen;

      beforeEach(() => {
        originalOpen = globalThis.indexedDB.open;
        globalThis.indexedDB.open = () => {
          const request = new EventTarget();
          // Defer triggering the error until after synchronous execution finishes
          queueMicrotask(() => {
            // Set the standard DOMException on the request
            request.error = new DOMException(
              "Connection failed",
              "UnknownError",
            );
            // Invoke the error callback
            if (typeof request.onerror === "function") {
              request.onerror(new Event("error"));
            }
          });
          return request;
        };
      });

      afterEach(() => {
        // Restore original open to prevent test pollution
        globalThis.indexedDB.open = originalOpen;
      });

      it("throws a 'Failed to open IndexedDB' error", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.match(res[0], /⚠️ Failed to open IndexedDB: Connection failed/);
      });
    });
  });

  describe("when indexeddb fails to load new user", () => {
    let originalIdbIndexGetAll;

    beforeEach(async () => {
      originalIdbIndexGetAll = IDBIndex.prototype.getAll;
      await setupObjectStores(globalThis.indexedDB, DB_NAME);
      mockGetAllError(originalIdbIndexGetAll);
    });

    afterEach(() => {
      IDBIndex.prototype.getAll = originalIdbIndexGetAll;
    });

    it("throws a 'Failed to open IndexedDB' error", async () => {
      const res = await loadUser(DB_NAME);
      assert.equal(res.isOk(), false);
      assert.equal(res instanceof GleamError, true);
      assert.match(res[0], /⚠️ Failed to load user: Index read failure/);
    });
  });
});
