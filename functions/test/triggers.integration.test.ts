import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { describe, expect, it } from "vitest";
import {
  onLeaderboardDeletionTombstoneWritten,
  onLeaderboardDeletionCleanupRequestWritten,
  onLeaderboardPreferenceWritten,
  onOfficialCheckInWritten
} from "../src/index.js";

if (getApps().length === 0) {
  initializeApp({ projectId: "demo-wildfrog" });
}

const db = getFirestore();

async function eventually<T>(read: () => Promise<T | undefined>, timeoutMs = 12_000): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = await read();
    if (value !== undefined) return value;
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error("Timed out waiting for the Functions emulator");
}

async function remainsStable(
  read: () => Promise<unknown>,
  expected: unknown,
  durationMs = 1_200
): Promise<void> {
  const deadline = Date.now() + durationMs;
  while (Date.now() < deadline) {
    expect(await read()).toBe(expected);
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
}

describe.runIf(process.env.WILDFROG_FUNCTIONS_EMULATOR === "1")("Firestore trigger end to end", () => {
  it("configures every leaderboard cleanup path for retry", () => {
    const endpoints = [
      onLeaderboardDeletionTombstoneWritten,
      onLeaderboardDeletionCleanupRequestWritten,
      onLeaderboardPreferenceWritten,
      onOfficialCheckInWritten
    ] as unknown as Array<{ __endpoint?: { eventTrigger?: { retry?: boolean } } }>;
    expect(endpoints.every((handler) => handler.__endpoint?.eventTrigger?.retry === true)).toBe(true);
  });

  it("publishes, updates, and removes a consented user's shared profile", async () => {
    const uid = `trigger-user-${Date.now()}`;
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Trigger Rain",
      syncRequestId: "trigger-request",
      migrationVersion: 1
    });
    await db.collection("checkIns").doc(`${uid}-one`).set({
      clientId: `${uid}-one`,
      userId: uid,
      mountainId: "lion-rock",
      checkInAt: Timestamp.fromDate(new Date("2026-08-01T00:00:00Z")),
      createdAt: Timestamp.now()
    });

    const publicProfileId = await eventually(async () => {
      const snapshot = await preference.get();
      const value = snapshot.get("publicProfileId");
      return typeof value === "string" && snapshot.get("completedSyncRequestId") === "trigger-request"
        ? value
        : undefined;
    });
    const publicProfile = db.collection("leaderboardProfiles").doc(publicProfileId);
    await eventually(async () => {
      const snapshot = await publicProfile.get();
      return snapshot.get("totalCheckIns") === 1 ? true : undefined;
    });

    await preference.update({ isVisible: false, publicationRequested: false });
    await eventually(async () => (await publicProfile.get()).exists ? undefined : true);

    expect((await db.collection("checkIns").doc(`${uid}-one`).get()).exists).toBe(true);
  });

  it("deletes the public row and acknowledges the exact tombstone request", async () => {
    const uid = `trigger-delete-${Date.now()}`;
    const preference = db.collection("leaderboardOptIns").doc(uid);
    await preference.set({
      isVisible: true,
      publicationRequested: true,
      publicAlias: "Delete Trigger Rain",
      syncRequestId: "publish-before-delete",
      migrationVersion: 1
    });
    const publicProfileId = await eventually(async () => {
      const snapshot = await preference.get();
      const value = snapshot.get("publicProfileId");
      return typeof value === "string" ? value : undefined;
    });
    const requestId = `delete-request-${Date.now()}`;
    const tombstone = db.collection("leaderboardDeletionTombstones").doc(uid);
    await tombstone.set({
      deletionRequested: true,
      deletionRequestId: requestId,
      deletedAt: Timestamp.now()
    });

    await eventually(async () => {
      const snapshot = await tombstone.get();
      return snapshot.get("cleanupCompletedRequestId") === requestId ? true : undefined;
    });
    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(false);
    expect((await db.collection("leaderboardProfileLinks").doc(uid).get()).exists).toBe(false);
  });

  it("retries a legacy tombstone with missing preference through the cleanup request trigger", async () => {
    const uid = `trigger-legacy-delete-${Date.now()}`;
    const publicProfileId = `legacy-public-${Date.now()}`;
    await db.collection("leaderboardProfiles").doc(publicProfileId).set({
      publicAlias: "Legacy Visible Rain",
      isVisible: true,
      totalCheckIns: 4,
      distinctPeaks: 2,
      monthlyCheckIns: { "2026-08": 4 }
    });
    await db.collection("leaderboardProfileLinks").doc(uid).set({ publicProfileId });
    const tombstone = db.collection("leaderboardDeletionTombstones").doc(uid);
    await tombstone.set({
      deletionRequested: true,
      deletedAt: Timestamp.now()
    });
    await eventually(async () => {
      const snapshot = await tombstone.get();
      return snapshot.get("cleanupCompletedRequestId") === "legacy-tombstone-v1" ? true : undefined;
    });

    // Recreate the exact pre-fix residual: no preference, legacy tombstone,
    // no acknowledgement, and a still-visible linked public row.
    await tombstone.set({
      deletionRequested: true,
      deletedAt: Timestamp.now()
    });
    await db.collection("leaderboardProfiles").doc(publicProfileId).set({
      publicAlias: "Legacy Visible Rain",
      isVisible: true,
      totalCheckIns: 4,
      distinctPeaks: 2,
      monthlyCheckIns: { "2026-08": 4 }
    });
    await db.collection("leaderboardProfileLinks").doc(uid).set({ publicProfileId });
    const requestId = `legacy-retry-${Date.now()}`;
    await db.collection("leaderboardDeletionCleanupRequests").doc(uid).set({
      deletionRequestId: requestId,
      requestedAt: Timestamp.now()
    });

    await eventually(async () => {
      const snapshot = await tombstone.get();
      return snapshot.get("cleanupCompletedRequestId") === requestId ? true : undefined;
    });
    await eventually(async () => (await db.collection("leaderboardDeletionCleanupRequests").doc(uid).get()).exists
      ? undefined
      : true);
    await remainsStable(
      async () => (await tombstone.get()).get("cleanupCompletedRequestId"),
      requestId
    );
    expect((await db.collection("leaderboardProfiles").doc(publicProfileId).get()).exists).toBe(false);
    expect((await db.collection("leaderboardProfileLinks").doc(uid).get()).exists).toBe(false);
  });
});
