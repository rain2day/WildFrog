export type CheckInRow = {
  clientId?: string;
  mountainId: string;
  createdAt: Date;
};

export type LeaderboardAggregate = {
  totalCheckIns: number;
  distinctPeaks: number;
  monthlyCheckIns: Record<string, number>;
};

const hongKongMonth = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Hong_Kong",
  year: "numeric",
  month: "2-digit"
});

export function deduplicateCheckIns(rows: CheckInRow[]): CheckInRow[] {
  const seen = new Set<string>();

  return rows.filter((row, index) => {
    const stableId = row.clientId?.trim();
    const key = stableId || `legacy:${row.mountainId}:${row.createdAt.toISOString()}:${index}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

export function buildLeaderboardAggregate(rows: CheckInRow[]): LeaderboardAggregate {
  const checkIns = deduplicateCheckIns(rows)
    .filter((row) => row.mountainId.trim().length > 0 && !Number.isNaN(row.createdAt.getTime()))
    .sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime());
  const monthlyCheckIns: Record<string, number> = {};

  for (const row of checkIns) {
    const parts = hongKongMonth.formatToParts(row.createdAt);
    const year = parts.find((part) => part.type === "year")?.value;
    const month = parts.find((part) => part.type === "month")?.value;
    if (!year || !month) continue;

    const key = `${year}-${month}`;
    monthlyCheckIns[key] = (monthlyCheckIns[key] ?? 0) + 1;
  }

  return {
    totalCheckIns: checkIns.length,
    distinctPeaks: new Set(checkIns.map((row) => row.mountainId)).size,
    monthlyCheckIns
  };
}
