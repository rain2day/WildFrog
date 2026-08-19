import { describe, expect, it } from "vitest";
import { buildLeaderboardAggregate } from "../src/leaderboard.js";

describe("buildLeaderboardAggregate", () => {
  it("counts totals, distinct peaks, and Hong Kong calendar months", () => {
    const result = buildLeaderboardAggregate([
      { clientId: "a", mountainId: "lion-rock", createdAt: new Date("2026-07-31T16:30:00Z") },
      { clientId: "b", mountainId: "lion-rock", createdAt: new Date("2026-08-01T04:00:00Z") },
      { clientId: "c", mountainId: "tai-mo-shan", createdAt: new Date("2026-08-02T04:00:00Z") }
    ]);

    expect(result.totalCheckIns).toBe(3);
    expect(result.distinctPeaks).toBe(2);
    expect(result.monthlyCheckIns).toEqual({ "2026-08": 3 });
    expect("heroMountainId" in result).toBe(false);
  });

  it("deduplicates retry echoes by stable client ID", () => {
    const duplicate = {
      clientId: "same",
      mountainId: "lion-rock",
      createdAt: new Date("2026-08-01T00:00:00Z")
    };

    expect(buildLeaderboardAggregate([duplicate, duplicate]).totalCheckIns).toBe(1);
  });

  it("keeps legacy rows without client IDs distinct", () => {
    const first = { mountainId: "lion-rock", createdAt: new Date("2026-08-01T00:00:00Z") };
    const second = { mountainId: "lion-rock", createdAt: new Date("2026-08-01T00:00:00Z") };

    expect(buildLeaderboardAggregate([first, second]).totalCheckIns).toBe(2);
  });
});
