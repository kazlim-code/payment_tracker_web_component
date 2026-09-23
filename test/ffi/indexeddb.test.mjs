import "fake-indexeddb/auto";
import { IDBFactory, IDBIndex, IDBObjectStore } from "fake-indexeddb";
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
 * Creates the user, payment, and joining user_payments stores.
 *
 * Relational schema layout:
 * - `users`: Primary key is `username`. Contains `by_created` index on `created`.
 * - `payments`: Primary key is `id`.
 * - `user_payments`: Composite primary key `["username", "payment_id"]`.
 *
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
 * Initialises and creates the IndexedDB stores before tests run.
 *
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
 * Atomically seeds the test database with users, payments, and join records.
 *
 * Accepts structured objects or raw JSON strings for users. Records are written
 * inside a single `readwrite` transaction spanning all three stores.
 *
 * @param {IDBDatabase} idb
 * @param {string} dbName
 * @param {{
 *   users?: Array<Object|string>,
 *   payments?: Array<Object>,
 *   userPayments?: Array<{ username: string, payment_id: string }>
 * }} options
 * @returns {Promise<void>}
 */
function seedDatabase(
  idb,
  dbName,
  { users = [], payments = [], userPayments = [] } = {},
) {
  return new Promise((resolve, reject) => {
    let parsedUsers = [];
    try {
      parsedUsers = users.map((item) =>
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
      const transaction = db.transaction(
        [USERS_STORE, PAYMENTS_STORE, USER_PAYMENTS_STORE],
        "readwrite",
      );

      const userStore = transaction.objectStore(USERS_STORE);
      for (const user of parsedUsers) {
        userStore.put(user);
      }

      const paymentStore = transaction.objectStore(PAYMENTS_STORE);
      for (const payment of payments) {
        paymentStore.put(payment);
      }

      const joinStore = transaction.objectStore(USER_PAYMENTS_STORE);
      for (const join of userPayments) {
        joinStore.put(join);
      }

      transaction.oncomplete = () => {
        db.close();
        resolve();
      };
      transaction.onerror = () => {
        db.close();
        reject(
          new globalThis.Error(
            "⚠️ Failed to seed database: " + transaction.error?.message,
          ),
        );
      };
    };
    request.onerror = () => {
      reject(
        new globalThis.Error(
          "⚠️ Failed to open IndexedDB for seeding: " + request.error?.message,
        ),
      );
    };
  });
}

/**
 * Convenience helper to seed only users into the USERS_STORE.
 *
 * @param {IDBDatabase} idb
 * @param {string} dbName
 * @param {Array<string|Object>|string|Object} userJsonStrings
 * @returns {Promise<void>}
 */
function seedUsers(idb, dbName, userJsonStrings) {
  const items = Array.isArray(userJsonStrings)
    ? userJsonStrings
    : [userJsonStrings];
  return seedDatabase(idb, dbName, { users: items });
}

/**
 * Replaces IDBIndex.prototype.getAll with a mock implementation that forces
 * the enclosing transaction to error asynchronously via a microtask.
 *
 * In fake-indexeddb and browser environments, transaction error events occur
 * asynchronously after request dispatch. Using `queueMicrotask` simulates this
 * authentic DOMException dispatch without introducing timers.
 *
 * @param {function} idbIndexGetAll - Original reference to restore in teardown
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
 * Replaces IDBObjectStore.prototype.openCursor with a mock implementation that forces
 * the transaction to error asynchronously when opening a cursor.
 *
 * @param {function} idbStoreOpenCursor - Original reference to restore in teardown
 * @returns {void}
 */
function mockOpenCursorError(idbStoreOpenCursor) {
  IDBObjectStore.prototype.openCursor = function (...args) {
    const request = idbStoreOpenCursor.apply(this, args);
    const transaction = this.transaction;
    queueMicrotask(() => {
      transaction.error = new DOMException("Cursor read failure", "DataError");
      if (typeof transaction.onerror === "function") {
        transaction.onerror(new Event("error"));
      }
    });

    return request;
  };
}

/**
 * Promisified wrapper around idb_load_user callback to simplify async test assertions.
 *
 * @param {string} dbName
 * @returns {Promise<any>}
 */
function loadUser(dbName) {
  return new Promise((resolve) => idb_load_user(dbName, resolve));
}

// --- END Helpers ---

describe("IndexedDB FFI", () => {
  const basicUserJsonString =
    '{"created":"2026-06-19T02:40:17.121000Z","first_name":"John","last_name":null,"monthly_payments":[],"home_loan_payment":null,"home_loan_transfer":null,"month_year":"2026-06","paid":null,"total":0,"length":0,"username":"TestUser"}';

  beforeEach(() => {
    // Synchronously resets all databases and stores to a clean, isolated state
    globalThis.indexedDB = new IDBFactory();
  });

  describe("idb_load_user()", () => {
    describe("when no user exists in the database", () => {
      it("returns GleamError('NOT_FOUND')", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.equal(res[0], "NOT_FOUND");
      });
    });

    describe("when a user exists without payments", () => {
      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedUsers(globalThis.indexedDB, DB_NAME, basicUserJsonString);
      });

      it("returns the user with an empty payments array", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);

        const user = JSON.parse(res[0]);
        assert.equal(user.username, "TestUser");
        assert.equal(user.first_name, "John");
        assert.deepEqual(user.payments, []);
      });
    });

    describe("when a user exists with associated payments", () => {
      const samplePayments = [
        {
          id: "pay_001",
          amount: 120.5,
          description: "Electricity Bill",
          category: "Utilities",
          paid: true,
        },
        {
          id: "pay_002",
          amount: 45.0,
          description: "Internet",
          category: "Utilities",
          paid: false,
        },
      ];

      const sampleJoinRecords = [
        { username: "TestUser", payment_id: "pay_001" },
        { username: "TestUser", payment_id: "pay_002" },
      ];

      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedDatabase(globalThis.indexedDB, DB_NAME, {
          users: [basicUserJsonString],
          payments: samplePayments,
          userPayments: sampleJoinRecords,
        });
      });

      it("reconstructs the user with all corresponding payment records", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);

        const user = JSON.parse(res[0]);
        assert.equal(user.username, "TestUser");
        assert.equal(Array.isArray(user.payments), true);
        assert.equal(user.payments.length, 2);
        assert.deepEqual(user.payments, samplePayments);
      });

      it("preserves original user profile attributes alongside reconstructed payments", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);

        const user = JSON.parse(res[0]);
        assert.equal(user.first_name, "John");
        assert.equal(user.last_name, null);
        assert.equal(user.created, "2026-06-19T02:40:17.121000Z");
        assert.equal(user.month_year, "2026-06");
      });
    });

    describe("when multiple users exist in the database", () => {
      const earlierUser = {
        username: "EarlyBird",
        first_name: "Alice",
        last_name: "Smith",
        created: "2026-01-15T08:00:00.000000Z",
        monthly_payments: [],
      };

      const laterUser = {
        username: "LateComer",
        first_name: "Bob",
        last_name: "Jones",
        created: "2026-06-20T12:00:00.000000Z",
        monthly_payments: [],
      };

      const earlyPayments = [
        { id: "early_pay_1", amount: 200, description: "Council Rates" },
      ];

      const latePayments = [
        { id: "late_pay_1", amount: 500, description: "Home Insurance" },
      ];

      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        // Seed later user first in the store to verify selection relies on by_created index,
        // not natural primary key insertion order.
        await seedDatabase(globalThis.indexedDB, DB_NAME, {
          users: [laterUser, earlierUser],
          payments: [...earlyPayments, ...latePayments],
          userPayments: [
            { username: "LateComer", payment_id: "late_pay_1" },
            { username: "EarlyBird", payment_id: "early_pay_1" },
          ],
        });
      });

      it("returns the earliest created user using the by_created index", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);

        const user = JSON.parse(res[0]);
        assert.equal(user.username, "EarlyBird");
        assert.equal(user.first_name, "Alice");
      });

      it("isolates payments so only the target user's payments are attached", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);

        const user = JSON.parse(res[0]);
        assert.equal(user.payments.length, 1);
        assert.equal(user.payments[0].id, "early_pay_1");
        assert.equal(user.payments[0].description, "Council Rates");
      });
    });

    describe("when usernames share a prefix", () => {
      // In IndexedDB composite index range queries, bounding by [user.username] to [user.username, []]
      // relies on IndexedDB key sorting rules where an Array ([]) sorts higher than any string or number.
      // This test proves that a prefix like "alex" never captures rows belonging to "alexander".
      const prefixUser = {
        username: "alex",
        first_name: "Alex",
        created: "2026-02-01T00:00:00.000Z",
      };

      const extendedUser = {
        username: "alexander",
        first_name: "Alexander",
        created: "2026-03-01T00:00:00.000Z",
      };

      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedDatabase(globalThis.indexedDB, DB_NAME, {
          users: [prefixUser, extendedUser],
          payments: [
            { id: "alex_p1", amount: 10 },
            { id: "alexander_p1", amount: 99 },
          ],
          userPayments: [
            { username: "alex", payment_id: "alex_p1" },
            { username: "alexander", payment_id: "alexander_p1" },
          ],
        });
      });

      it("does not leak payments from extended usernames into the prefix username", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);

        const user = JSON.parse(res[0]);
        assert.equal(user.username, "alex");
        assert.equal(user.payments.length, 1);
        assert.equal(user.payments[0].id, "alex_p1");
      });
    });

    describe("when the join store contains orphaned payment references", () => {
      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        // Seeds user_payments join records referencing a missing payment id alongside a valid one
        await seedDatabase(globalThis.indexedDB, DB_NAME, {
          users: [basicUserJsonString],
          payments: [{ id: "valid_01", amount: 80.0, description: "Water" }],
          userPayments: [
            { username: "TestUser", payment_id: "dangling_orphan_id" },
            { username: "TestUser", payment_id: "valid_01" },
          ],
        });
      });

      it("gracefully omits non-existent payment records without stalling cursor traversal", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);

        const user = JSON.parse(res[0]);
        assert.equal(user.username, "TestUser");
        // Only the existing payment should be accumulated
        assert.equal(user.payments.length, 1);
        assert.equal(user.payments[0].id, "valid_01");
      });
    });

    describe("when user metadata contains special characters", () => {
      const specialUser = {
        username: "user+testing@example.com (personal)",
        first_name: "Renée",
        last_name: "O'Connor",
        created: "2026-04-10T10:00:00.000Z",
      };

      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedDatabase(globalThis.indexedDB, DB_NAME, {
          users: [specialUser],
          payments: [{ id: "special_p1", amount: 15.75, description: "Coffee" }],
          userPayments: [
            {
              username: "user+testing@example.com (personal)",
              payment_id: "special_p1",
            },
          ],
        });
      });

      it("correctly queries composite key bounds and returns the user and payments", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), true);

        const user = JSON.parse(res[0]);
        assert.equal(user.username, "user+testing@example.com (personal)");
        assert.equal(user.first_name, "Renée");
        assert.equal(user.last_name, "O'Connor");
        assert.equal(user.payments.length, 1);
        assert.equal(user.payments[0].id, "special_p1");
      });
    });

    describe("when IndexedDB connection fails", () => {
      let originalOpen;

      beforeEach(() => {
        originalOpen = globalThis.indexedDB.open;
        globalThis.indexedDB.open = () => {
          const request = new EventTarget();
          // Defer triggering the error until after synchronous execution finishes
          queueMicrotask(() => {
            request.error = new DOMException(
              "Connection failed",
              "UnknownError",
            );
            if (typeof request.onerror === "function") {
              request.onerror(new Event("error"));
            }
          });
          return request;
        };
      });

      afterEach(() => {
        globalThis.indexedDB.open = originalOpen;
      });

      it("returns a GleamError with '⚠️ Failed to open IndexedDB' message", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.match(res[0], /⚠️ Failed to open IndexedDB: Connection failed/);
      });
    });

    describe("when reading from the by_created index fails", () => {
      let originalIdbIndexGetAll;

      beforeEach(async () => {
        originalIdbIndexGetAll = IDBIndex.prototype.getAll;
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        mockGetAllError(originalIdbIndexGetAll);
      });

      afterEach(() => {
        IDBIndex.prototype.getAll = originalIdbIndexGetAll;
      });

      it("returns a GleamError with '⚠️ Failed to load user' message", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.match(res[0], /⚠️ Failed to load user: Index read failure/);
      });
    });

    describe("when opening cursor on user_payments fails", () => {
      let originalOpenCursor;

      beforeEach(async () => {
        originalOpenCursor = IDBObjectStore.prototype.openCursor;
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedUsers(globalThis.indexedDB, DB_NAME, basicUserJsonString);
        mockOpenCursorError(originalOpenCursor);
      });

      afterEach(() => {
        IDBObjectStore.prototype.openCursor = originalOpenCursor;
      });

      it("aborts and returns a GleamError with '⚠️ Failed to load user' message", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.match(res[0], /⚠️ Failed to load user: Cursor read failure/);
      });
    });
  });
});

