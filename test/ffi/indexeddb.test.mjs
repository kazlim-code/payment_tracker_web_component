import "fake-indexeddb/auto";
import { IDBFactory } from "fake-indexeddb";
import { beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
import { idb_load_user } from "#ffi";
import { Error } from "#gleam";

const DB_NAME = "payment-tracker-test-db";
const USERS_STORE = "users";
const PAYMENTS_STORE = "payments";
const USER_PAYMENTS_STORE = "user_payments";

// --- Helpers ---

/// Creates/updates the IndexedDB stores before tests run.
///
function setupObjectStores(idb, dbName) {
  const request = idb.open(dbName);
  request.onupgradeneeded = () => {
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
  };
  request.onsuccess = () => {
    const db = request.result;
    db.close();
  };
  request.onerror = () => {
    throw new Error("⚠️ Failed to open IndexedDB: " + request.error.message)
  };
}

/// Adds a user to the IndexedDB respective tables.
///
function seedUser(idb, dbName, userJson) {
  let user;
  try {
    user = JSON.parse(userJson);
  } catch (err) {
    console.log("Failed to parse user during seeding", err.message);
  }

  const request = idb.open(dbName);
  request.onsuccess = () => {
    const db = request.result?.[0];
    const transaction = db.transaction(
      [USERS_STORE],
      // [USERS_STORE, PAYMENTS_STORE, USER_PAYMENTS_STORE],
      "readwrite",
    );
    const userStore = transaction.USERS_STORE;
    const userStorePutRequest = userStore.put(user);
    userStorePutRequest.onsuccess(() => {
      const data = userStorePutRequest.result;
      console.log("[seedUser] Successfully put data", data);
    });
    userStorePutRequest.onerror(() => {
      console.log("[seedUser] Failed to put user", userStorePutRequest.error.message);
    });
  };
  request.onerror = () => {
    throw new Error("⚠️ Failed to open IndexedDB: " + request.error.message)
  };
}

function loadUser(dbName) {
  return new Promise((resolve) => idb_load_user(dbName, resolve));
}

// --- END Helpers ---

describe("IndexedDB FFI", () => {
  beforeEach(() => {
    // Synchronously resets all databases and stores to a clean state
    globalThis.indexedDB = new IDBFactory();
  });

  describe("idb_load_user()", () => {
    // describe("when no user exists", () => {
    //   it("returns NOT_FOUND", async () => {
    //     const res = await loadUser(DB_NAME);
    //     assert.equal(res.isOk(), false);
    //     assert.equal(res instanceof Error, true);
    //     assert.equal(res[0], "NOT_FOUND");
    //   });
    // });

    describe("when 1 user exists", () => {
      beforeEach(() => {
        // const userJson =
        // TODO: Set up db with stores and a single user
        // const request = globalThis.indexedDB.open(DB_NAME);
        // const transaction = request.transaction(
        //   [USERS_STORE, PAYMENTS_STORE, USER_PAYMENTS_STORE],
        //   "readonly",
        // );
        setupObjectStores(globalThis.indexedDB, DB_NAME);
        // seedUser(globalThis.indexedDB, DB_NAME, userJson);
      });

      it("returns the first user", async () => {
        const res = await loadUser(DB_NAME);
        assert.equal(res.isOk(), false);
        assert.equal(res instanceof Error, true);
        assert.equal(res[0], "NOT_FOUND");
      });
    });

    // describe("when multiple users exist", () => {
    //   it("returns the first user", async () => {
    //     const res = await loadUser(DB_NAME);
    //     assert.equal(res.isOk(), false);
    //     assert.equal(res instanceof Error, true);
    //     assert.equal(res[0], "NOT_FOUND");
    //   });
    // });
  });
});
