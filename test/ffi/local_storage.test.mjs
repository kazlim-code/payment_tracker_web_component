import { beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
import { read, write } from "#ffi";
import { Error, Ok } from "#gleam";

function mockLocalStorage() {
  globalThis.__mockLocalStorage = {
    store: new Map(),
    getItem(key) {
      return this.store.has(key) ? this.store.get(key) : null;
    },
    setItem(key, value) {
      // Simulates browser throwing QuotaExceededError when storage limit is reached
      if (value === "QUOTA_EXCEEDED") {
        throw new globalThis.Error("QuotaExceededError");
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

describe("Local Storage FFI", () => {
  beforeEach(() => {
    mockLocalStorage();
  });

  describe("read()", () => {
    describe("when no keys exist / key is missing", () => {
      it("returns Error for non-existing key", () => {
        const readRes = read("TEST_USER_ID");
        assert.equal(readRes.isOk(), false);
        assert.equal(readRes instanceof Error, true);
        assert.equal(readRes[0], undefined);
      });

      it("returns Error for non-existing empty string key", () => {
        const readRes = read("");
        assert.equal(readRes.isOk(), false);
        assert.equal(readRes instanceof Error, true);
      });

      it("returns Error for non-existing '0' string key", () => {
        const readRes = read("0");
        assert.equal(readRes.isOk(), false);
        assert.equal(readRes instanceof Error, true);
      });
    });

    describe("when a key exists", () => {
      it("returns Ok for an existing standard key", () => {
        globalThis.__mockLocalStorage.store.set("TEST_USER_ID", "USER_VALUE");
        const readRes = read("TEST_USER_ID");
        assert.equal(readRes.isOk(), true);
        assert.equal(readRes instanceof Ok, true);
        assert.equal(readRes[0], "USER_VALUE");
      });

      it("returns Ok for existing empty string key", () => {
        globalThis.__mockLocalStorage.store.set("", "VALUE_FOR_EMPTY_KEY");
        const readRes = read("");
        assert.equal(readRes.isOk(), true);
        assert.equal(readRes[0], "VALUE_FOR_EMPTY_KEY");
      });

      it("returns Ok('') when the stored value is an empty string", () => {
        globalThis.__mockLocalStorage.store.set("EMPTY_VALUE_KEY", "");
        const readRes = read("EMPTY_VALUE_KEY");
        assert.equal(readRes.isOk(), true);
        assert.equal(readRes[0], "");
      });

      it("returns Ok for '0' string key and value", () => {
        globalThis.__mockLocalStorage.store.set("0", "0");
        const readRes = read("0");
        assert.equal(readRes.isOk(), true);
        assert.equal(readRes[0], "0");
      });
    });

    describe("when storage access throws an exception", () => {
      it("returns Error(undefined) if getItem throws a SecurityError", () => {
        globalThis.__mockLocalStorage.getItem = () => {
          throw new globalThis.Error("SecurityError: Access Denied");
        };
        const readRes = read("TEST_KEY");
        assert.equal(readRes.isOk(), false);
        assert.equal(readRes instanceof Error, true);
        assert.equal(readRes[0], undefined);
      });
    });
  });

  describe("write()", () => {
    describe("when writing succeeds", () => {
      it("returns Ok(undefined) and saves string value to store", () => {
        const writeRes = write("USER_TOKEN", "token_abc123");
        assert.equal(writeRes.isOk(), true);
        assert.equal(writeRes[0], undefined);
        assert.equal(globalThis.__mockLocalStorage.store.get("USER_TOKEN"), "token_abc123");
      });

      it("returns Ok(undefined) when writing an empty string value", () => {
        const writeRes = write("EMPTY_VAL", "");
        assert.equal(writeRes.isOk(), true);
        assert.equal(globalThis.__mockLocalStorage.store.get("EMPTY_VAL"), "");
      });

      it("overwrites existing value for a key", () => {
        globalThis.__mockLocalStorage.store.set("SETTING", "OLD_VAL");
        const writeRes = write("SETTING", "NEW_VAL");
        assert.equal(writeRes.isOk(), true);
        assert.equal(globalThis.__mockLocalStorage.store.get("SETTING"), "NEW_VAL");
      });
    });

    describe("when writing fails", () => {
      it("returns Error with message on quota exhaustion", () => {
        // Passing "QUOTA_EXCEEDED" triggers the mock's quota error to verify FFI error propagation
        const writeRes = write("BIG_DATA", "QUOTA_EXCEEDED");
        assert.equal(writeRes.isOk(), false);
        assert.equal(writeRes instanceof Error, true);
        assert.equal(writeRes[0], "QuotaExceededError");
      });

      it("returns Error with fallback message when error has no message", () => {
        globalThis.__mockLocalStorage.setItem = () => {
          throw {};
        };
        const writeRes = write("KEY", "VAL");
        assert.equal(writeRes.isOk(), false);
        assert.equal(writeRes[0], "Unknown storage error");
      });
    });
  });

  describe("round-trip (write -> read)", () => {
    it("persists and retrieves serialised JSON payloads", () => {
      const userPayload = JSON.stringify({
        username: "TEST_USER",
        first_name: "USER_FIRST_NAME",
        payments: [{ id: "TEST_PAYMENT_1", amount: 150.0 }],
      });
      const writeRes = write("TEST_USER_ID", userPayload);
      assert.equal(writeRes.isOk(), true);

      const readRes = read("TEST_USER_ID");
      assert.equal(readRes.isOk(), true);
      assert.equal(readRes[0], userPayload);
    });
  });
});
