import "fake-indexeddb/auto";
import { IDBFactory, IDBIndex, IDBObjectStore } from "fake-indexeddb";
import { afterEach, beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
import { idb_load_user, idb_save_user } from "#ffi";
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

/**
 * Promisified wrapper around idb_save_user callback to simplify async test assertions.
 *
 * @param {string} dbName
 * @param {string} userJson
 * @returns {Promise<any>}
 */
function saveUser(dbName, userJson) {
  return new Promise((resolve) => idb_save_user(dbName, userJson, resolve));
}

/**
 * Replaces IDBObjectStore.prototype.put with a mock implementation that forces
 * the transaction to error asynchronously when putting a record.
 *
 * @param {function} idbStorePut - Original reference to restore in teardown
 * @returns {void}
 */
function mockPutError(idbStorePut) {
  IDBObjectStore.prototype.put = function (...args) {
    const request = idbStorePut.apply(this, args);
    const transaction = this.transaction;
    queueMicrotask(() => {
      transaction.error = new DOMException("Store write failure", "DataError");
      if (typeof transaction.onerror === "function") {
        transaction.onerror(new Event("error"));
      }
    });

    return request;
  };
}

/**
 * Reads all records directly from an IndexedDB object store.
 * Useful for verifying database state independently of idb_load_user.
 *
 * @param {IDBDatabase} idb
 * @param {string} dbName
 * @param {string} storeName
 * @returns {Promise<Array<any>>}
 */
function getAllFromStore(idb, dbName, storeName) {
  return new Promise((resolve, reject) => {
    const request = idb.open(dbName, DB_VERSION);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction([storeName], "readonly");
      const store = transaction.objectStore(storeName);
      const getAllRequest = store.getAll();
      getAllRequest.onsuccess = () => {
        db.close();
        resolve(getAllRequest.result);
      };
      getAllRequest.onerror = () => {
        db.close();
        reject(
          new globalThis.Error(
            "⚠️ Failed to read store: " + getAllRequest.error?.message,
          ),
        );
      };
    };
    request.onerror = () => {
      reject(
        new globalThis.Error(
          "⚠️ Failed to open DB for reading store: " + request.error?.message,
        ),
      );
    };
  });
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
      let res;
      let user;

      beforeEach(async () => {
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        await seedUsers(globalThis.indexedDB, DB_NAME, basicUserJsonString);
        res = await loadUser(DB_NAME);
        user = JSON.parse(res[0]);
      });

      it("returns a successful GleamOk result", () => {
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);
      });

      it("returns the user profile metadata", () => {
        assert.equal(user.username, "TestUser");
        assert.equal(user.first_name, "John");
      });

      it("returns an empty payments array", () => {
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
      let res;
      let user;
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
        res = await loadUser(DB_NAME);
        user = JSON.parse(res[0]);
      });

      it("returns a successful GleamOk result", () => {
        assert.equal(res.isOk(), true);
      });

      it("returns user metadata matching the special characters", () => {
        assert.equal(user.username, "user+testing@example.com (personal)");
        assert.equal(user.first_name, "Renée");
        assert.equal(user.last_name, "O'Connor");
      });

      it("returns the associated payments", () => {
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

  describe("idb_save_user()", () => {
    describe("when saving a new user without payments", () => {
      let res;
      const userObj = {
        username: "NoPaymentsUser",
        first_name: "Charlie",
        last_name: "Brown",
        created: "2026-05-01T00:00:00.000Z",
        month_year: "2026-05",
        payments: [],
      };

      beforeEach(async () => {
        res = await saveUser(DB_NAME, JSON.stringify(userObj));
      });

      it("returns GleamOk(undefined)", () => {
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);
        assert.equal(res[0], undefined);
      });

      it("persists user metadata without nested payments", async () => {
        const usersInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USERS_STORE,
        );
        assert.equal(usersInDb.length, 1);
        assert.equal(usersInDb[0].username, "NoPaymentsUser");
        assert.equal(usersInDb[0].first_name, "Charlie");
        assert.equal(usersInDb[0].last_name, "Brown");
        assert.equal("payments" in usersInDb[0], false);
      });

      it("leaves payment stores empty", async () => {
        const paymentsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          PAYMENTS_STORE,
        );
        assert.equal(paymentsInDb.length, 0);

        const joinsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USER_PAYMENTS_STORE,
        );
        assert.equal(joinsInDb.length, 0);
      });
    });

    describe("when saving a new user with payments", () => {
      let res;
      const userObj = {
        username: "PaidUser",
        first_name: "Dana",
        last_name: "Scully",
        created: "2026-05-02T00:00:00.000Z",
        month_year: "2026-05",
        payments: [
          { id: "p_1", amount: 120.0, description: "Electricity", paid: true },
          { id: "p_2", amount: 55.5, description: "Gas", paid: false },
        ],
      };

      beforeEach(async () => {
        res = await saveUser(DB_NAME, JSON.stringify(userObj));
      });

      it("returns GleamOk(undefined)", () => {
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);
      });

      it("persists clean metadata in the users store", async () => {
        const usersInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USERS_STORE,
        );
        assert.equal(usersInDb.length, 1);
        assert.equal(usersInDb[0].username, "PaidUser");
        assert.equal("payments" in usersInDb[0], false);
      });

      it("persists payments in the payments store", async () => {
        const paymentsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          PAYMENTS_STORE,
        );
        assert.equal(paymentsInDb.length, 2);
        const paymentIds = paymentsInDb.map((p) => p.id).sort();
        assert.deepEqual(paymentIds, ["p_1", "p_2"]);
      });

      it("persists relational join records in the user_payments store", async () => {
        const joinsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USER_PAYMENTS_STORE,
        );
        assert.equal(joinsInDb.length, 2);
        assert.deepEqual(joinsInDb, [
          { username: "PaidUser", payment_id: "p_1" },
          { username: "PaidUser", payment_id: "p_2" },
        ]);
      });
    });

    describe("when updating an existing user with modified payments", () => {
      let res;
      const initialUser = {
        username: "UpdateUser",
        first_name: "InitialName",
        created: "2026-05-03T00:00:00.000Z",
        payments: [
          { id: "old_p1", amount: 20 },
          { id: "old_p2", amount: 30 },
        ],
      };
      const updatedUser = {
        username: "UpdateUser",
        first_name: "UpdatedName",
        created: "2026-05-03T00:00:00.000Z",
        payments: [{ id: "new_p3", amount: 150 }],
      };

      beforeEach(async () => {
        await saveUser(DB_NAME, JSON.stringify(initialUser));
        res = await saveUser(DB_NAME, JSON.stringify(updatedUser));
      });

      it("returns GleamOk(undefined)", () => {
        assert.equal(res.isOk(), true);
        assert.equal(res instanceof GleamOk, true);
      });

      it("updates user profile data in the users store", async () => {
        const usersInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USERS_STORE,
        );
        assert.equal(usersInDb.length, 1);
        assert.equal(usersInDb[0].first_name, "UpdatedName");
      });

      it("replaces old join records with updated payment join records", async () => {
        const joinsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USER_PAYMENTS_STORE,
        );
        assert.equal(joinsInDb.length, 1);
        assert.deepEqual(joinsInDb[0], {
          username: "UpdateUser",
          payment_id: "new_p3",
        });
      });
    });

    describe("when round-tripping with idb_load_user", () => {
      let loadedUser;
      const userObj = {
        username: "RoundTripUser",
        first_name: "Sam",
        last_name: "Taylor",
        created: "2026-05-04T00:00:00.000Z",
        month_year: "2026-05",
        monthly_payments: [],
        payments: [
          {
            id: "rt_p1",
            amount: 88.0,
            description: "Gym Membership",
            paid: true,
          },
        ],
      };

      beforeEach(async () => {
        const saveRes = await saveUser(DB_NAME, JSON.stringify(userObj));
        assert.equal(saveRes.isOk(), true);

        const loadRes = await loadUser(DB_NAME);
        assert.equal(loadRes.isOk(), true);

        loadedUser = JSON.parse(loadRes[0]);
      });

      it("reconstructs user metadata accurately", () => {
        assert.equal(loadedUser.username, "RoundTripUser");
        assert.equal(loadedUser.first_name, "Sam");
        assert.equal(loadedUser.last_name, "Taylor");
        assert.equal(loadedUser.month_year, "2026-05");
      });

      it("reconstructs user payments accurately", () => {
        assert.deepEqual(loadedUser.payments, userObj.payments);
      });
    });

    describe("when clearing payments for a prefix-sharing username", () => {
      let updateRes;

      beforeEach(async () => {
        // Save "alexander" with a payment
        await saveUser(
          DB_NAME,
          JSON.stringify({
            username: "alexander",
            created: "2026-01-01T00:00:00.000Z",
            payments: [{ id: "p_alexander", amount: 99 }],
          }),
        );

        // Save "alex" with a payment
        await saveUser(
          DB_NAME,
          JSON.stringify({
            username: "alex",
            created: "2026-01-02T00:00:00.000Z",
            payments: [{ id: "p_alex", amount: 15 }],
          }),
        );

        // Update "alex" with empty payments, triggering delete cursor sweep
        updateRes = await saveUser(
          DB_NAME,
          JSON.stringify({
            username: "alex",
            created: "2026-01-02T00:00:00.000Z",
            payments: [],
          }),
        );
      });

      it("returns GleamOk(undefined)", () => {
        assert.equal(updateRes.isOk(), true);
      });

      it("does not delete join records belonging to an extended username", async () => {
        const joinsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USER_PAYMENTS_STORE,
        );
        assert.equal(joinsInDb.length, 1);
        assert.deepEqual(joinsInDb[0], {
          username: "alexander",
          payment_id: "p_alexander",
        });
      });
    });

    describe("when user JSON has no payments property", () => {
      let res;
      const noPaymentsField = {
        username: "NoFieldUser",
        first_name: "Jordan",
        created: "2026-05-05T00:00:00.000Z",
      };

      beforeEach(async () => {
        res = await saveUser(DB_NAME, JSON.stringify(noPaymentsField));
      });

      it("returns GleamOk(undefined)", () => {
        assert.equal(res.isOk(), true);
      });

      it("persists user metadata successfully", async () => {
        const usersInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USERS_STORE,
        );
        assert.equal(usersInDb.length, 1);
        assert.equal(usersInDb[0].username, "NoFieldUser");
      });

      it("leaves join store empty", async () => {
        const joinsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USER_PAYMENTS_STORE,
        );
        assert.equal(joinsInDb.length, 0);
      });
    });

    describe("when user metadata contains special characters", () => {
      let res;
      const specialUser = {
        username: "user+dev@domain.co.nz (work)",
        first_name: "Hélène",
        created: "2026-05-06T00:00:00.000Z",
        payments: [{ id: "pay_special_99", amount: 49.95 }],
      };

      beforeEach(async () => {
        res = await saveUser(DB_NAME, JSON.stringify(specialUser));
      });

      it("returns GleamOk(undefined)", () => {
        assert.equal(res.isOk(), true);
      });

      it("persists special character username in the users store", async () => {
        const usersInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USERS_STORE,
        );
        assert.equal(usersInDb.length, 1);
        assert.equal(usersInDb[0].username, "user+dev@domain.co.nz (work)");
      });

      it("persists join record linked to special character username", async () => {
        const joinsInDb = await getAllFromStore(
          globalThis.indexedDB,
          DB_NAME,
          USER_PAYMENTS_STORE,
        );
        assert.equal(joinsInDb.length, 1);
        assert.deepEqual(joinsInDb[0], {
          username: "user+dev@domain.co.nz (work)",
          payment_id: "pay_special_99",
        });
      });
    });

    describe("when userJson is invalid JSON", () => {
      it("throws a SyntaxError synchronously", () => {
        assert.throws(
          () => idb_save_user(DB_NAME, "not_valid_json_payload", () => {}),
          /SyntaxError/,
        );
      });
    });

    describe("when IndexedDB connection fails", () => {
      let originalOpen;

      beforeEach(() => {
        originalOpen = globalThis.indexedDB.open;
        globalThis.indexedDB.open = () => {
          const request = new EventTarget();
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
        const res = await saveUser(DB_NAME, basicUserJsonString);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.match(res[0], /⚠️ Failed to open IndexedDB: Connection failed/);
      });
    });

    describe("when writing to an object store fails", () => {
      let originalPut;

      beforeEach(async () => {
        originalPut = IDBObjectStore.prototype.put;
        await setupObjectStores(globalThis.indexedDB, DB_NAME);
        mockPutError(originalPut);
      });

      afterEach(() => {
        IDBObjectStore.prototype.put = originalPut;
      });

      it("returns a GleamError with '⚠️ Failed to save user' message", async () => {
        const res = await saveUser(DB_NAME, basicUserJsonString);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof GleamError, true);
        assert.match(res[0], /⚠️ Failed to save user: Store write failure/);
      });
    });
  });
});


