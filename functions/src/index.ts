import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { buildLeaderboardAggregate, type CheckInRow } from "./leaderboard.js";

if (getApps().length === 0) {
  initializeApp();
}

export type RebuildLeaderboardOptions = {
  knownPublicProfileId?: string;
  afterSnapshotRead?: () => Promise<void>;
  beforeDeletionAcknowledgement?: () => Promise<void>;
};

function validPublicAlias(value: unknown, uid: string): string | undefined {
  if (typeof value !== "string") return undefined;
  const alias = value.trim();
  const codePointLength = Array.from(alias).length;
  if (codePointLength < 1 || codePointLength > 24) return undefined;
  if (alias.includes("@")) return undefined;

  const phoneCharacters = alias.replace(/[+() .-]/g, "");
  if (/^\d{7,}$/.test(phoneCharacters)) return undefined;

  const normalized = alias.toLocaleLowerCase("en-US");
  const normalizedUid = uid.toLocaleLowerCase("en-US");
  if (normalized === normalizedUid || (normalized.length >= 8 && normalizedUid.startsWith(normalized))) {
    return undefined;
  }
  return alias;
}

export async function rebuildLeaderboardForUser(
  uid: string,
  options: RebuildLeaderboardOptions = {}
): Promise<void> {
  const db = getFirestore();
  const preferenceReference = db.collection("leaderboardOptIns").doc(uid);
  const linkReference = db.collection("leaderboardProfileLinks").doc(uid);
  const deletionTombstoneReference = db.collection("leaderboardDeletionTombstones").doc(uid);
  const deletionCleanupRequestReference = db.collection("leaderboardDeletionCleanupRequests").doc(uid);
  const checkInsQuery = db.collection("checkIns").where("userId", "==", uid);

  await db.runTransaction(async (transaction) => {
    const preference = await transaction.get(preferenceReference);
    const link = await transaction.get(linkReference);
    const deletionTombstone = await transaction.get(deletionTombstoneReference);
    const deletionCleanupRequest = await transaction.get(deletionCleanupRequestReference);
    const preferenceData = preference.data();
    const linkData = link.data();
    const preferenceProfileId = typeof preferenceData?.publicProfileId === "string"
      ? preferenceData.publicProfileId
      : undefined;
    const linkedProfileId = typeof linkData?.publicProfileId === "string"
      ? linkData.publicProfileId
      : undefined;
    const knownProfileIds = new Set(
      [options.knownPublicProfileId, preferenceProfileId, linkedProfileId]
        .filter((value): value is string => typeof value === "string" && value.length > 0)
    );

    if (deletionTombstone.exists) {
      for (const publicProfileId of knownProfileIds) {
        transaction.delete(db.collection("leaderboardProfiles").doc(publicProfileId));
      }
      transaction.delete(linkReference);
      if (preference.exists) {
        transaction.delete(preferenceReference);
      }
      const storedDeletionRequestId = deletionTombstone.get("deletionRequestId");
      const requestedDeletionRequestId = deletionCleanupRequest.get("deletionRequestId");
      const completedRequestId = deletionTombstone.get("cleanupCompletedRequestId");
      const deletionRequestId = typeof storedDeletionRequestId === "string" && storedDeletionRequestId.length > 0
        ? storedDeletionRequestId
        : typeof requestedDeletionRequestId === "string" && requestedDeletionRequestId.length > 0
          ? requestedDeletionRequestId
          : typeof completedRequestId === "string" && completedRequestId.length > 0
            ? completedRequestId
            : "legacy-tombstone-v1";
      if (completedRequestId !== deletionRequestId) {
        await options.beforeDeletionAcknowledgement?.();
        transaction.set(deletionTombstoneReference, {
          cleanupCompletedRequestId: deletionRequestId,
          cleanupCompletedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      if (deletionCleanupRequest.exists) {
        transaction.delete(deletionCleanupRequestReference);
      }
      return;
    }

    if (!preference.exists
      || preferenceData?.publicationRequested !== true
      || preferenceData?.isVisible !== true) {
      for (const publicProfileId of knownProfileIds) {
        transaction.delete(db.collection("leaderboardProfiles").doc(publicProfileId));
      }
      if (!preference.exists) {
        transaction.delete(linkReference);
      }
      return;
    }

    const checkInSnapshot = await transaction.get(checkInsQuery);
    await options.afterSnapshotRead?.();

    const publicAlias = validPublicAlias(preferenceData.publicAlias, uid);
    if (!publicAlias) {
      for (const publicProfileId of knownProfileIds) {
        transaction.delete(db.collection("leaderboardProfiles").doc(publicProfileId));
      }
      transaction.set(preferenceReference, {
        publicationError: "invalidPublicAlias",
        backendUpdatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      return;
    }

    const publicProfileId = linkedProfileId
      ?? preferenceProfileId
      ?? db.collection("leaderboardProfiles").doc().id;
    const syncRequestId = typeof preferenceData.syncRequestId === "string"
      ? preferenceData.syncRequestId
      : undefined;
    const publicProfileReference = db.collection("leaderboardProfiles").doc(publicProfileId);
    for (const staleProfileId of knownProfileIds) {
      if (staleProfileId !== publicProfileId) {
        transaction.delete(db.collection("leaderboardProfiles").doc(staleProfileId));
      }
    }

    const checkIns: CheckInRow[] = checkInSnapshot.docs.flatMap((document) => {
      const data = document.data();
      const aggregateTimestamp = data.checkInAt instanceof Timestamp
        ? data.checkInAt
        : data.createdAt instanceof Timestamp
          ? data.createdAt
          : undefined;
      const createdAt = aggregateTimestamp?.toDate();
      if (typeof data.mountainId !== "string" || !createdAt) return [];

      return [{
        clientId: typeof data.clientId === "string" ? data.clientId : document.id,
        mountainId: data.mountainId,
        createdAt
      }];
    });
    const aggregate = buildLeaderboardAggregate(checkIns);

    transaction.set(linkReference, { publicProfileId });
    transaction.set(preferenceReference, {
      publicProfileId,
      completedSyncRequestId: syncRequestId ?? FieldValue.delete(),
      publicationError: FieldValue.delete(),
      backendUpdatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    transaction.set(publicProfileReference, {
      publicAlias,
      isVisible: true,
      totalCheckIns: aggregate.totalCheckIns,
      distinctPeaks: aggregate.distinctPeaks,
      monthlyCheckIns: aggregate.monthlyCheckIns
    });
  });
}

export const onLeaderboardPreferenceWritten = onDocumentWritten(
  { document: "leaderboardOptIns/{uid}", region: "asia-east2", retry: true },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) {
      const publicProfileId = typeof before?.publicProfileId === "string"
        ? before.publicProfileId
        : undefined;
      await rebuildLeaderboardForUser(event.params.uid, { knownPublicProfileId: publicProfileId });
      return;
    }
    const clientFieldsChanged = ["isVisible", "publicationRequested", "publicAlias", "migrationVersion", "syncRequestId"]
      .some((key) => before?.[key] !== after?.[key]);

    if (before && after && !clientFieldsChanged) return;
    await rebuildLeaderboardForUser(event.params.uid);
  }
);

export const onOfficialCheckInWritten = onDocumentWritten(
  { document: "checkIns/{checkInId}", region: "asia-east2", retry: true },
  async (event) => {
    const beforeUid = event.data?.before.data()?.userId;
    const afterUid = event.data?.after.data()?.userId;
    const userIds = new Set(
      [beforeUid, afterUid].filter((value): value is string => typeof value === "string" && value.length > 0)
    );

    await Promise.all(Array.from(userIds).map((uid) => rebuildLeaderboardForUser(uid)));
  }
);

export const onLeaderboardDeletionTombstoneWritten = onDocumentWritten(
  { document: "leaderboardDeletionTombstones/{uid}", region: "asia-east2", retry: true },
  async (event) => {
    if (!event.data?.after.exists) return;
    await rebuildLeaderboardForUser(event.params.uid);
  }
);

export const onLeaderboardDeletionCleanupRequestWritten = onDocumentWritten(
  { document: "leaderboardDeletionCleanupRequests/{uid}", region: "asia-east2", retry: true },
  async (event) => {
    if (!event.data?.after.exists) return;
    await rebuildLeaderboardForUser(event.params.uid);
  }
);
