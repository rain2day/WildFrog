import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where
} from "firebase/firestore";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

const projectId = "demo-wildfrog";
let environment: RulesTestEnvironment;

describe.runIf(Boolean(process.env.FIRESTORE_EMULATOR_HOST))("Firestore security rules", () => {
  beforeAll(async () => {
    const rulesPath = fileURLToPath(new URL("../../firestore.rules", import.meta.url));
    environment = await initializeTestEnvironment({
      projectId,
      firestore: { rules: await readFile(rulesPath, "utf8") }
    });
  });

  beforeEach(async () => {
    await environment.clearFirestore();
  });

  afterAll(async () => {
    await environment.cleanup();
  });

  it("lets an owner persist only the public participation inputs", async () => {
    const owner = environment.authenticatedContext("owner").firestore();
    const preference = doc(owner, "leaderboardOptIns/owner");

    await assertSucceeds(setDoc(preference, {
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Rain",
      consentedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      syncRequestId: "first-request",
      migrationVersion: 1
    }));
    await assertSucceeds(updateDoc(preference, {
      isVisible: false,
      publicationRequested: false,
      updatedAt: serverTimestamp()
    }));
    await assertFails(updateDoc(preference, { publicProfileId: "forged" }));
    await assertFails(updateDoc(preference, { totalCheckIns: 999 }));
    await assertFails(updateDoc(preference, { displayName: "rain@example.com" }));
    await assertSucceeds(updateDoc(preference, {
      publicAlias: "Renamed Rain",
      syncRequestId: "rename-request",
      updatedAt: serverTimestamp()
    }));
    await assertFails(updateDoc(preference, {
      publicAlias: "rain@example.com",
      syncRequestId: "contact-rename-request",
      updatedAt: serverTimestamp()
    }));

    const declinedOwner = environment.authenticatedContext("declined-owner").firestore();
    const declined = doc(declinedOwner, "leaderboardOptIns/declined-owner");
    await assertSucceeds(setDoc(declined, {
      isVisible: false,
      publicationRequested: false,
      updatedAt: serverTimestamp(),
      syncRequestId: "declined-request",
      migrationVersion: 1
    }));

    const pendingOwner = environment.authenticatedContext("pending-owner").firestore();
    await assertSucceeds(setDoc(doc(pendingOwner, "leaderboardOptIns/pending-owner"), {
      isVisible: false,
      publicationRequested: true,
      publicAlias: "Pending Rain",
      updatedAt: serverTimestamp(),
      syncRequestId: "pending-request",
      migrationVersion: 1
    }));
    const invalidOwner = environment.authenticatedContext("invalid-owner").firestore();
    await assertFails(setDoc(doc(invalidOwner, "leaderboardOptIns/invalid-owner"), {
      isVisible: true,
      publicationRequested: false,
      publicAlias: "Invalid Rain",
      syncRequestId: "invalid-request",
      migrationVersion: 1
    }));
  });

  it("keeps participation private to its owner", async () => {
    const owner = environment.authenticatedContext("owner").firestore();
    await setDoc(doc(owner, "leaderboardOptIns/owner"), {
      isVisible: false,
      publicationRequested: false,
      publicAlias: "Rain",
      migrationVersion: 1,
      syncRequestId: "private-request",
      updatedAt: serverTimestamp()
    });

    const other = environment.authenticatedContext("other").firestore();
    await assertFails(getDoc(doc(other, "leaderboardOptIns/owner")));
    await assertFails(setDoc(doc(other, "leaderboardOptIns/owner"), {
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Other",
      syncRequestId: "other-request",
      migrationVersion: 1
    }));
  });

  it("makes an owner account-deletion tombstone append-only and authoritative", async () => {
    const owner = environment.authenticatedContext("owner").firestore();
    const other = environment.authenticatedContext("other").firestore();
    const tombstone = doc(owner, "leaderboardDeletionTombstones/owner");

    await assertSucceeds(setDoc(tombstone, {
      deletionRequested: true,
      deletionRequestId: "delete-owner",
      deletedAt: serverTimestamp()
    }));
    await assertFails(setDoc(doc(other, "leaderboardDeletionTombstones/owner"), {
      deletionRequested: true,
      deletionRequestId: "delete-other",
      deletedAt: serverTimestamp()
    }));
    await assertFails(updateDoc(tombstone, { deletionRequested: false }));
    await assertFails(deleteDoc(tombstone));
  });

  it("uses the same Unicode code-point alias boundary as app and backend", async () => {
    const owner = environment.authenticatedContext("unicode-owner").firestore();
    await assertSucceeds(setDoc(doc(owner, "leaderboardOptIns/unicode-owner"), {
      isVisible: false,
      publicationRequested: true,
      publicAlias: "😀".repeat(24),
      migrationVersion: 1,
      syncRequestId: "unicode-valid"
    }));
    await assertFails(updateDoc(doc(owner, "leaderboardOptIns/unicode-owner"), {
      publicAlias: "😀".repeat(25),
      syncRequestId: "unicode-invalid"
    }));
    await assertFails(updateDoc(doc(owner, "leaderboardOptIns/unicode-owner"), {
      publicAlias: "👨‍👩‍👧‍👦".repeat(4),
      syncRequestId: "unicode-combined-invalid"
    }));
  });

  it("rejects dotted phone aliases and lets only the tombstone owner request cleanup retry", async () => {
    const owner = environment.authenticatedContext("cleanup-owner").firestore();
    const other = environment.authenticatedContext("cleanup-other").firestore();
    await assertFails(setDoc(doc(owner, "leaderboardOptIns/cleanup-owner"), {
      isVisible: false,
      publicationRequested: true,
      publicAlias: "123.456.7890",
      migrationVersion: 1,
      syncRequestId: "dotted-phone"
    }));

    const cleanupRequest = doc(owner, "leaderboardDeletionCleanupRequests/cleanup-owner");
    await assertFails(setDoc(cleanupRequest, {
      deletionRequestId: "delete-new",
      requestedAt: serverTimestamp()
    }));
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "leaderboardDeletionTombstones/cleanup-owner"), {
        deletionRequested: true,
        deletedAt: Timestamp.now()
      });
    });
    await assertSucceeds(setDoc(cleanupRequest, {
      deletionRequestId: "delete-new",
      requestedAt: serverTimestamp()
    }));
    await assertFails(setDoc(doc(other, "leaderboardDeletionCleanupRequests/cleanup-owner"), {
      deletionRequestId: "delete-other",
      requestedAt: serverTimestamp()
    }));
  });

  it("denies stale outbox writes after tombstoning while allowing the final check-in sweep", async () => {
    const owner = environment.authenticatedContext("deleted-owner").firestore();
    const existingCheckIn = doc(owner, "checkIns/existing-before-deletion");
    const validCheckIn = {
      clientId: "existing-before-deletion",
      userId: "deleted-owner",
      mountainId: "lion-rock",
      dayKey: "2026-08-18",
      checkInAt: Timestamp.fromDate(new Date("2026-08-18T01:00:00Z")),
      createdAt: serverTimestamp()
    };
    await assertSucceeds(setDoc(existingCheckIn, validCheckIn));
    await assertSucceeds(setDoc(doc(owner, "leaderboardDeletionTombstones/deleted-owner"), {
      deletionRequested: true,
      deletionRequestId: "delete-stale-writes",
      deletedAt: serverTimestamp()
    }));

    await assertFails(setDoc(doc(owner, "checkIns/stale-outbox-upload"), {
      ...validCheckIn,
      clientId: "stale-outbox-upload"
    }));
    await assertFails(updateDoc(existingCheckIn, { createdAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(existingCheckIn));
    await environment.withSecurityRulesDisabled(async (context) => {
      expect((await getDoc(doc(context.firestore(), "checkIns/existing-before-deletion"))).exists()).toBe(false);
    });
  });

  it("transaction precondition prevents stale final visibility after opt-out", async () => {
    const owner = environment.authenticatedContext("race-owner").firestore();
    const preference = doc(owner, "leaderboardOptIns/race-owner");
    await setDoc(preference, {
      isVisible: false,
      publicationRequested: true,
      publicAlias: "Race Rain",
      migrationVersion: 1,
      syncRequestId: "opt-in-request",
      updatedAt: serverTimestamp()
    });

    let releaseRead: (() => void) | undefined;
    let markRead: (() => void) | undefined;
    const read = new Promise<void>((resolve) => { markRead = resolve; });
    const release = new Promise<void>((resolve) => { releaseRead = resolve; });
    let didPause = false;
    const staleFinalization = runTransaction(owner, async (transaction) => {
      const snapshot = await transaction.get(preference);
      if (!didPause) {
        didPause = true;
        markRead?.();
        await release;
      }
      if (snapshot.get("syncRequestId") !== "opt-in-request"
        || snapshot.get("publicationRequested") !== true) {
        throw new Error("stale-sync-request");
      }
      transaction.update(preference, { isVisible: true, updatedAt: serverTimestamp() });
    });

    await read;
    await updateDoc(preference, {
      isVisible: false,
      publicationRequested: false,
      syncRequestId: "opt-out-request",
      updatedAt: serverTimestamp()
    });
    releaseRead?.();
    await expect(staleFinalization).rejects.toThrow();

    const finalState = await getDoc(preference);
    expect(finalState.get("isVisible")).toBe(false);
    expect(finalState.get("syncRequestId")).toBe("opt-out-request");
  });

  it("allows public reads only for visible server profiles and blocks client writes", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      await setDoc(doc(admin, "leaderboardProfiles/visible"), { isVisible: true, publicAlias: "Rain" });
      await setDoc(doc(admin, "leaderboardProfiles/private"), { isVisible: false, publicAlias: "Hidden" });
    });

    const guest = environment.unauthenticatedContext().firestore();
    const owner = environment.authenticatedContext("owner").firestore();
    await assertSucceeds(getDoc(doc(guest, "leaderboardProfiles/visible")));
    await assertSucceeds(getDoc(doc(guest, "leaderboardProfiles/not-yet-published")));
    await assertFails(getDoc(doc(guest, "leaderboardProfiles/private")));
    await assertSucceeds(getDocs(query(
      collection(guest, "leaderboardProfiles"),
      where("isVisible", "==", true)
    )));
    await assertFails(getDocs(collection(guest, "leaderboardProfiles")));
    await assertFails(setDoc(doc(owner, "leaderboardProfiles/forged"), {
      isVisible: true,
      totalCheckIns: 999
    }));
  });

  it("returns every visible profile beyond the former one-hundred-row ceiling", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      const admin = context.firestore();
      await Promise.all(Array.from({ length: 125 }, (_, index) => setDoc(
        doc(admin, `leaderboardProfiles/profile-${index + 1}`),
        {
          isVisible: true,
          publicAlias: `Hiker ${index + 1}`,
          totalCheckIns: 125 - index,
          distinctPeaks: 1,
          monthlyCheckIns: { "2026-08": 125 - index }
        }
      )));
    });

    const guest = environment.unauthenticatedContext().firestore();
    const snapshot = await getDocs(query(
      collection(guest, "leaderboardProfiles"),
      where("isVisible", "==", true)
    ));
    expect(snapshot.size).toBe(125);
  });

  it("requires stable ownership and official check-in fields", async () => {
    const owner = environment.authenticatedContext("owner").firestore();
    const other = environment.authenticatedContext("other").firestore();
    const checkIn = doc(owner, "checkIns/stable-client-id");
    const validData = {
      clientId: "stable-client-id",
      userId: "owner",
      mountainId: "lion-rock",
      dayKey: "2026-08-18",
      checkInAt: Timestamp.fromDate(new Date("2026-08-18T01:00:00Z")),
      createdAt: serverTimestamp()
    };

    await assertSucceeds(setDoc(checkIn, validData));
    await assertFails(setDoc(doc(other, "checkIns/other-id"), { ...validData, clientId: "other-id" }));
    await assertFails(updateDoc(checkIn, { userId: "other" }));
    await assertFails(updateDoc(checkIn, { clientId: "changed" }));
    await assertSucceeds(updateDoc(checkIn, { createdAt: serverTimestamp() }));
  });

  it("keeps the approved legacy check-in envelope working during the app transition", async () => {
    const owner = environment.authenticatedContext("legacy-owner").firestore();
    const other = environment.authenticatedContext("legacy-other").firestore();
    const legacyData = {
      clientId: "legacy-client-id",
      userId: "legacy-owner",
      mountainId: "lion-rock",
      dayKey: "2026-08-18",
      createdAt: serverTimestamp()
    };

    await assertSucceeds(setDoc(doc(owner, "checkIns/random-legacy-document-id"), legacyData));
    await assertFails(setDoc(doc(other, "checkIns/other-legacy-document-id"), {
      ...legacyData,
      clientId: "other-client-id"
    }));
    await assertFails(setDoc(doc(owner, "checkIns/legacy-extra-field"), {
      ...legacyData,
      note: "not-approved"
    }));

    await assertSucceeds(setDoc(doc(owner, "leaderboardDeletionTombstones/legacy-owner"), {
      deletionRequested: true,
      deletionRequestId: "delete-legacy-owner",
      deletedAt: serverTimestamp()
    }));
    await assertFails(setDoc(doc(owner, "checkIns/legacy-after-deletion"), legacyData));
  });
});
