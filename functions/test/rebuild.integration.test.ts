import { deleteApp, getApps } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { afterAll, beforeEach, describe, expect, it } from "vitest";
import { rebuildLeaderboardForUser } from "../src/index.js";

const uid = "existing-user-123";

describe.runIf(Boolean(process.env.FIRESTORE_EMULATOR_HOST))("rebuildLeaderboardForUser", () => {
  const db = getFirestore();

  beforeEach(async () => {
    const collections = await db.listCollections();
    for (const collection of collections) {
      const documents = await collection.listDocuments();
      await Promise.all(documents.map((document) => document.delete()));
    }
  });

  afterAll(async () => {
    await Promise.all(getApps().map(deleteApp));
  });

  it("backfills historical official check-ins into one anonymous public document", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: " Rain ",
      syncRequestId: "backfill-request",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc("one").set({
      clientId: "one",
      userId: uid,
      mountainId: "lion-rock",
      createdAt: Timestamp.fromDate(new Date("2026-08-01T04:00:00Z"))
    });
    await db.collection("checkIns").doc("two").set({
      clientId: "two",
      userId: uid,
      mountainId: "tai-mo-shan",
      createdAt: Timestamp.fromDate(new Date("2026-08-02T04:00:00Z"))
    });

    await rebuildLeaderboardForUser(uid);

    const preference = await db.collection("leaderboardOptIns").doc(uid).get();
    const publicProfileId = preference.get("publicProfileId") as string;
    const profile = await db.collection("leaderboardProfiles").doc(publicProfileId).get();

    expect(publicProfileId).toBeTruthy();
    expect(preference.get("completedSyncRequestId")).toBe("backfill-request");
    expect(publicProfileId).not.toBe(uid);
    expect(profile.data()).toMatchObject({
      publicAlias: "Rain",
      isVisible: true,
      totalCheckIns: 2,
      distinctPeaks: 2,
      monthlyCheckIns: { "2026-08": 2 }
    });
    expect(profile.get("heroMountainId")).toBeUndefined();
    expect(profile.get("updatedAt")).toBeUndefined();
    expect(Object.keys(profile.data() ?? {}).sort()).toEqual([
      "distinctPeaks",
      "isVisible",
      "monthlyCheckIns",
      "publicAlias",
      "totalCheckIns"
    ]);

    await rebuildLeaderboardForUser(uid);
    const repeated = await db.collection("leaderboardOptIns").doc(uid).get();
    expect(repeated.get("publicProfileId")).toBe(publicProfileId);
  });

  it("removes the public row on opt-out without deleting private check-ins", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Rain",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc("one").set({
      clientId: "one",
      userId: uid,
      mountainId: "lion-rock",
      createdAt: Timestamp.now()
    });
    await rebuildLeaderboardForUser(uid);

    const publicProfileId = (await db.collection("leaderboardOptIns").doc(uid).get()).get("publicProfileId") as string;
    await db.collection("leaderboardOptIns").doc(uid).update({
      isVisible: false,
      publicationRequested: false
    });
    await rebuildLeaderboardForUser(uid);

    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(false);
    expect((await db.collection("checkIns").doc("one").get()).exists).toBe(true);
  });

  it("keeps durable backfill pending private until visibility is finalized", async () => {
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: false,
      publicationRequested: true,
      publicAlias: "Pending Rain",
      syncRequestId: "pending-request",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc("pending-one").set({
      clientId: "pending-one",
      userId: uid,
      mountainId: "lion-rock",
      createdAt: Timestamp.now()
    });

    await rebuildLeaderboardForUser(uid);
    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);

    await preference.update({
      isVisible: true,
      syncRequestId: "final-request"
    });
    await rebuildLeaderboardForUser(uid);

    const completedPreference = await preference.get();
    expect(completedPreference.get("completedSyncRequestId")).toBe("final-request");
    expect((await db.collection("leaderboardProfiles").get()).size).toBe(1);
  });

  it("fails closed instead of publishing a UID prefix as an alias", async () => {
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: uid.slice(0, 9),
      syncRequestId: "invalid-alias-request",
      migrationVersion: 1
    });

    await rebuildLeaderboardForUser(uid);

    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);
    expect((await preference.get()).get("publicationError")).toBe("invalidPublicAlias");

    await preference.update({
      publicAlias: "👨‍👩‍👧‍👦".repeat(4),
      syncRequestId: "unicode-combined-invalid"
    });
    await rebuildLeaderboardForUser(uid);
    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);
  });

  it("rejects dotted phone aliases exactly like the app and rules", async () => {
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "123.456.7890",
      syncRequestId: "dotted-phone",
      migrationVersion: 1
    });

    await rebuildLeaderboardForUser(uid);
    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);
    expect((await preference.get()).get("publicationError")).toBe("invalidPublicAlias");
  });

  it("keeps the anonymous public identity while renaming and acknowledges readback", async () => {
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Old Trail Name",
      syncRequestId: "initial-request",
      migrationVersion: 1
    });
    await rebuildLeaderboardForUser(uid);
    const initial = await preference.get();
    const publicProfileId = initial.get("publicProfileId") as string;

    await preference.update({
      publicAlias: "New Trail Name",
      syncRequestId: "rename-request"
    });
    await rebuildLeaderboardForUser(uid);

    const renamedPreference = await preference.get();
    const renamedProfile = await db.collection("leaderboardProfiles").doc(publicProfileId).get();
    expect(renamedPreference.get("publicProfileId")).toBe(publicProfileId);
    expect(renamedPreference.get("completedSyncRequestId")).toBe("rename-request");
    expect(renamedProfile.get("publicAlias")).toBe("New Trail Name");
  });

  it("allocates one stable profile during concurrent first rebuilds", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Concurrent Rain",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc("concurrent-one").set({
      clientId: "concurrent-one",
      userId: uid,
      mountainId: "lion-rock",
      createdAt: Timestamp.now()
    });

    await Promise.all(Array.from({ length: 8 }, () => rebuildLeaderboardForUser(uid)));

    const preference = await db.collection("leaderboardOptIns").doc(uid).get();
    const publicProfileId = preference.get("publicProfileId") as string;
    const profiles = await db.collection("leaderboardProfiles").get();
    expect(publicProfileId).toBeTruthy();
    expect(profiles.docs.map((document) => document.id)).toEqual([publicProfileId]);
  }, 30_000);

  it("deletes the public row and private link when the preference is deleted", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Deleted Rain",
      migrationVersion: 1
    });
    await rebuildLeaderboardForUser(uid);
    const publicProfileId = (await db.collection("leaderboardOptIns").doc(uid).get()).get("publicProfileId") as string;

    await db.collection("leaderboardOptIns").doc(uid).delete();
    await Promise.all([
      rebuildLeaderboardForUser(uid),
      rebuildLeaderboardForUser(uid),
      rebuildLeaderboardForUser(uid)
    ]);

    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(false);
    expect((await db.collection("leaderboardProfileLinks").doc(uid).get()).exists).toBe(false);
  }, 30_000);

  it("keeps opt-out final against an in-flight and repeated rebuild", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Opted Out Rain",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc("race-opt-out").set({
      clientId: "race-opt-out",
      userId: uid,
      mountainId: "lion-rock",
      createdAt: Timestamp.now()
    });

    let releaseSnapshot: (() => void) | undefined;
    let markSnapshotRead: (() => void) | undefined;
    const snapshotRead = new Promise<void>((resolve) => { markSnapshotRead = resolve; });
    const release = new Promise<void>((resolve) => { releaseSnapshot = resolve; });
    let didPause = false;
    const inFlight = rebuildLeaderboardForUser(uid, {
      afterSnapshotRead: async () => {
        if (didPause) return;
        didPause = true;
        markSnapshotRead?.();
        await release;
      }
    });
    await snapshotRead;
    const optOut = db.collection("leaderboardOptIns").doc(uid).update({
      isVisible: false,
      publicationRequested: false
    });
    releaseSnapshot?.();
    await Promise.all([inFlight, optOut]);
    await Promise.all([
      rebuildLeaderboardForUser(uid),
      rebuildLeaderboardForUser(uid),
      rebuildLeaderboardForUser(uid)
    ]);

    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);
    expect((await db.collection("leaderboardOptIns").doc(uid).get()).get("isVisible")).toBe(false);
  }, 30_000);

  it("keeps preference deletion final against an in-flight and repeated rebuild", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Deleted During Rebuild",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc("race-delete").set({
      clientId: "race-delete",
      userId: uid,
      mountainId: "lion-rock",
      createdAt: Timestamp.now()
    });

    let releaseSnapshot: (() => void) | undefined;
    let markSnapshotRead: (() => void) | undefined;
    const snapshotRead = new Promise<void>((resolve) => { markSnapshotRead = resolve; });
    const release = new Promise<void>((resolve) => { releaseSnapshot = resolve; });
    let didPause = false;
    const inFlight = rebuildLeaderboardForUser(uid, {
      afterSnapshotRead: async () => {
        if (didPause) return;
        didPause = true;
        markSnapshotRead?.();
        await release;
      }
    });
    await snapshotRead;
    const deletion = db.collection("leaderboardOptIns").doc(uid).delete();
    releaseSnapshot?.();
    await Promise.all([inFlight, deletion]);
    await Promise.all([
      rebuildLeaderboardForUser(uid),
      rebuildLeaderboardForUser(uid),
      rebuildLeaderboardForUser(uid)
    ]);

    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);
    expect((await db.collection("leaderboardProfileLinks").doc(uid).get()).exists).toBe(false);
  }, 30_000);

  it("keeps account-deletion tombstone final against a stale recreated opt-in", async () => {
    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Before Deletion",
      syncRequestId: "before-deletion",
      migrationVersion: 1
    });
    await rebuildLeaderboardForUser(uid);
    const publicProfileId = (await db.collection("leaderboardOptIns").doc(uid).get()).get("publicProfileId") as string;

    const deletionBatch = db.batch();
    deletionBatch.set(db.collection("leaderboardDeletionTombstones").doc(uid), {
      deletionRequested: true,
      deletedAt: Timestamp.now()
    });
    deletionBatch.delete(db.collection("leaderboardOptIns").doc(uid));
    await deletionBatch.commit();

    await db.collection("leaderboardOptIns").doc(uid).set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Stale Recreated Opt In",
      syncRequestId: "stale-after-deletion",
      migrationVersion: 1
    });
    await rebuildLeaderboardForUser(uid);

    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(false);
    expect((await db.collection("leaderboardProfileLinks").doc(uid).get()).exists).toBe(false);
    expect((await db.collection("leaderboardDeletionTombstones").doc(uid).get())
      .get("cleanupCompletedRequestId")).toBe("legacy-tombstone-v1");
  });

  it("atomically retries public cleanup and acknowledges the exact deletion request", async () => {
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Delete Retry Rain",
      syncRequestId: "before-delete",
      migrationVersion: 1
    });
    await rebuildLeaderboardForUser(uid);
    const publicProfileId = (await preference.get()).get("publicProfileId") as string;
    const tombstone = db.collection("leaderboardDeletionTombstones").doc(uid);
    await tombstone.set({
      deletionRequested: true,
      deletionRequestId: "delete-request-1",
      deletedAt: Timestamp.now()
    });

    await expect(rebuildLeaderboardForUser(uid, {
      beforeDeletionAcknowledgement: async () => { throw new Error("injected transient failure"); }
    })).rejects.toThrow("injected transient failure");
    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(true);
    expect((await tombstone.get()).get("cleanupCompletedRequestId")).toBeUndefined();

    await rebuildLeaderboardForUser(uid);
    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(false);
    expect((await db.collection("leaderboardProfileLinks").doc(uid).get()).exists).toBe(false);
    expect((await tombstone.get()).get("cleanupCompletedRequestId")).toBe("delete-request-1");
  });

  it("preserves an exact completed legacy cleanup request after the request document is gone", async () => {
    const tombstone = db.collection("leaderboardDeletionTombstones").doc(uid);
    await tombstone.set({
      deletionRequested: true,
      cleanupCompletedRequestId: "legacy-retry-exact-1",
      deletedAt: Timestamp.now()
    });

    await rebuildLeaderboardForUser(uid);

    expect((await tombstone.get()).get("cleanupCompletedRequestId")).toBe("legacy-retry-exact-1");
  });

  it("uses Unicode code-point length for aliases", async () => {
    const preference = db.collection("leaderboardOptIns").doc(uid);
    const valid = "😀".repeat(24);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: valid,
      syncRequestId: "unicode-valid",
      migrationVersion: 1
    });
    await rebuildLeaderboardForUser(uid);
    expect((await db.collection("leaderboardProfiles").get()).docs[0]?.get("publicAlias")).toBe(valid);

    await preference.update({
      publicAlias: "😀".repeat(25),
      syncRequestId: "unicode-invalid"
    });
    await rebuildLeaderboardForUser(uid);
    expect((await db.collection("leaderboardProfiles").get()).empty).toBe(true);
    expect((await preference.get()).get("publicationError")).toBe("invalidPublicAlias");
  });
});
