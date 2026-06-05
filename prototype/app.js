const mountains = [
  {
    id: "tai-mo-shan",
    nameZh: "大帽山",
    nameEn: "Tai Mo Shan",
    region: "New Territories",
    height: 957,
    image: "./assets/tai-mo-shan.png",
    myCheckins: 12,
    rank: 18,
    nextRankDistance: 2,
    totalCheckins: 1245,
    last: "Today",
    coordinates: "22.411, 114.123",
  },
  {
    id: "lion-rock",
    nameZh: "獅子山",
    nameEn: "Lion Rock",
    region: "Kowloon",
    height: 495,
    image: "./assets/lion-rock.png",
    myCheckins: 8,
    rank: 32,
    nextRankDistance: 4,
    totalCheckins: 2341,
    last: "This week",
    coordinates: "22.352, 114.187",
  },
  {
    id: "lantau-peak",
    nameZh: "鳳凰山",
    nameEn: "Lantau Peak",
    region: "Lantau",
    height: 934,
    image: "./assets/lantau-peak.png",
    myCheckins: 7,
    rank: 27,
    nextRankDistance: 3,
    totalCheckins: 987,
    last: "Yesterday",
    coordinates: "22.249, 113.921",
  },
  {
    id: "sunset-peak",
    nameZh: "大東山",
    nameEn: "Sunset Peak",
    region: "Lantau",
    height: 869,
    image: "./assets/lantau-peak.png",
    myCheckins: 6,
    rank: 41,
    nextRankDistance: 5,
    totalCheckins: 612,
    last: "This month",
    coordinates: "22.263, 113.950",
  },
];

const leaders = [
  { rank: 1, name: "山系行者", count: 68, sub: "Last check-in: today" },
  { rank: 2, name: "Trail_HK", count: 43, sub: "Last check-in: yesterday" },
  { rank: 3, name: "自然探索者", count: 39, sub: "Last check-in: this week" },
  { rank: 18, name: "You", count: 12, sub: "Always shown outside top 10", isUser: true },
];

const history = [
  { mountainId: "tai-mo-shan", date: "Today", time: "07:45", status: "Valid" },
  { mountainId: "lion-rock", date: "8 Jun", time: "06:18", status: "Valid" },
  { mountainId: "lantau-peak", date: "2 Jun", time: "05:52", status: "Valid" },
  { mountainId: "tai-mo-shan", date: "29 May", time: "08:04", status: "Valid" },
];

const regions = ["All", "New Territories", "Kowloon", "Lantau"];

const state = {
  screen: "home",
  selectedMountainId: "tai-mo-shan",
  region: "All",
  query: "",
  didCheckIn: false,
  proofMode: "camera",
};

const icons = {
  bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 21h4"/><path d="M18 8a6 6 0 0 0-12 0c0 7-3 8-3 8h18s-3-1-3-8"/></svg>',
  filter: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 5h18"/><path d="M7 12h10"/><path d="M10 19h4"/></svg>',
  search: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>',
  mountain: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m3 20 7-14 4 8 2-4 5 10Z"/><path d="m10 6 2 4"/></svg>',
  compass: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2.2 5.8-5.8 2.2 2.2-5.8Z"/></svg>',
  target: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/></svg>',
  records: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 20V9"/><path d="M12 20V4"/><path d="M19 20v-7"/></svg>',
  user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 5-6 8-6s6.5 2 8 6"/></svg>',
  pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 21s7-5.7 7-12a7 7 0 1 0-14 0c0 6.3 7 12 7 12Z"/><circle cx="12" cy="9" r="2.5"/></svg>',
  check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m5 12 5 5L20 7"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-5"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
  camera: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.5 4 16 7h3a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h3l1.5-3Z"/><circle cx="12" cy="14" r="4"/></svg>',
  upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 16V4"/><path d="m7 9 5-5 5 5"/><path d="M4 20h16"/></svg>',
  lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>',
  map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m3 6 6-3 6 3 6-3v15l-6 3-6-3-6 3Z"/><path d="M9 3v15"/><path d="M15 6v15"/></svg>',
  chevron: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m9 18 6-6-6-6"/></svg>',
  back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="m15 18-6-6 6-6"/></svg>',
  accuracy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="7"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/></svg>',
  people: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/><path d="M16 3.1a4 4 0 0 1 0 7.8"/></svg>',
  trophy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M8 21h8"/><path d="M12 17v4"/><path d="M7 4h10v5a5 5 0 0 1-10 0Z"/><path d="M5 5H3v2a4 4 0 0 0 4 4"/><path d="M19 5h2v2a4 4 0 0 1-4 4"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.2a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.2a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3 1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.2a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.2a1.7 1.7 0 0 0-1.4 1Z"/></svg>',
};

function byId(id) {
  return document.getElementById(id);
}

function selectedMountain() {
  return mountains.find((mountain) => mountain.id === state.selectedMountainId) || mountains[0];
}

function formatNumber(value) {
  return new Intl.NumberFormat("en-US").format(value);
}

function render() {
  const app = byId("app");
  app.innerHTML = `
    <div class="app-shell">
      ${renderScreen()}
      ${renderNav()}
    </div>
  `;
  bindEvents();
}

function renderScreen() {
  if (state.screen === "home") return renderHome();
  if (state.screen === "explore") return renderExplore();
  if (state.screen === "detail") return renderDetail();
  if (state.screen === "checkin") return renderCheckIn();
  if (state.screen === "success") return renderSuccess();
  if (state.screen === "records") return renderRecords();
  if (state.screen === "profile") return renderProfile();
  return renderHome();
}

function renderHome() {
  const filtered = mountains.filter((mountain) => {
    const matchesRegion = state.region === "All" || mountain.region === state.region;
    const haystack = `${mountain.nameZh} ${mountain.nameEn} ${mountain.region}`.toLowerCase();
    return matchesRegion && haystack.includes(state.query.toLowerCase());
  });

  return `
    <section class="screen fade-in" data-screen="home">
      <header class="screen-header">
        <div class="brand">
          <div class="brand-mark">${icons.mountain}</div>
          <div>
            <h1>WildFrog</h1>
            <p>Mountain records</p>
          </div>
        </div>
        <button class="icon-button" aria-label="Notifications">${icons.bell}</button>
      </header>

      <div class="search-row">
        <label class="search-field">
          ${icons.search}
          <input id="searchInput" type="search" value="${escapeHtml(state.query)}" placeholder="Search mountains" autocomplete="off" />
        </label>
        <button class="icon-button" aria-label="Filter mountains">${icons.filter}</button>
      </div>

      <div class="chip-row" role="tablist" aria-label="Region filter">
        ${regions
          .map(
            (region) => `
              <button class="chip ${state.region === region ? "is-active" : ""}" data-region="${region}" role="tab" aria-selected="${state.region === region}">
                ${region}
              </button>
            `
          )
          .join("")}
      </div>

      <div class="mountain-list">
        ${filtered.length ? filtered.map(renderMountainCard).join("") : '<div class="empty-state">No matching mountains</div>'}
      </div>
    </section>
  `;
}

function renderMountainCard(mountain) {
  return `
    <button class="mountain-card" data-open-detail="${mountain.id}" style="--image: url('${mountain.image}')">
      <div class="card-head">
        <div class="card-title">
          <h2>${mountain.nameZh} ${mountain.nameEn}</h2>
          <p>${mountain.region}</p>
        </div>
        <span class="height-badge">${mountain.height}m</span>
      </div>
      <div class="card-metrics">
        <div class="metric">
          ${icons.mountain}
          <div><small>My check-ins</small><strong>${mountain.myCheckins}</strong></div>
        </div>
        <div class="metric">
          ${icons.trophy}
          <div><small>My rank</small><strong class="rank">#${mountain.rank}</strong></div>
        </div>
        <div class="metric">
          ${icons.people}
          <div><small>Total check-ins</small><strong>${formatNumber(mountain.totalCheckins)}</strong></div>
        </div>
      </div>
    </button>
  `;
}

function renderDetail() {
  const mountain = selectedMountain();
  return `
    <section class="screen fade-in" data-screen="detail">
      <div class="detail-hero" style="--image: url('${mountain.image}')">
        <header class="screen-header">
          <button class="icon-button" data-screen-target="home" aria-label="Back to mountain list">${icons.back}</button>
          <div class="hero-actions">
            <button class="icon-button" aria-label="Map">${icons.map}</button>
          </div>
        </header>
        <div class="detail-title">
          <h1>${mountain.nameZh} ${mountain.nameEn}</h1>
          <p>${icons.pin} ${mountain.region} · ${mountain.height}m</p>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>My Record</h2>
          <span>${mountain.last}</span>
        </div>
        <div class="record-panel">
          <div class="record-grid">
            <div class="record-cell"><span>Valid check-ins</span><strong>${mountain.myCheckins}</strong></div>
            <div class="record-cell"><span>My rank</span><strong class="accent">#${mountain.rank}</strong></div>
            <div class="record-cell"><span>To next rank</span><strong>${mountain.nextRankDistance}</strong></div>
          </div>
        </div>
        <button class="primary-action" data-screen-target="checkin">${icons.target} Check In</button>
      </section>

      <section class="section">
        <div class="section-title">
          <h2>Leaderboard</h2>
          <span>Total</span>
        </div>
        <div class="leaderboard">
          ${leaders.map(renderLeaderRow).join("")}
        </div>
      </section>
    </section>
  `;
}

function renderLeaderRow(row) {
  const medal = row.rank <= 3 ? `<span class="medal">${row.rank}</span>` : `<span class="rank-number">${row.rank}</span>`;
  return `
    <div class="leader-row ${row.isUser ? "is-user" : ""}">
      ${medal}
      <div class="avatar">${row.isUser ? "Y" : row.name.slice(0, 1)}</div>
      <div class="row-main">
        <strong>${row.name}</strong>
        <span>${row.sub}</span>
      </div>
      <div class="row-count">
        <strong>${row.count}</strong>
        <span>valid</span>
      </div>
    </div>
  `;
}

function renderCheckIn() {
  const mountain = selectedMountain();
  return `
    <section class="screen is-map fade-in" data-screen="checkin">
      <div class="topo"></div>
      <header class="map-header">
        <button class="icon-button" data-screen-target="detail" aria-label="Back to mountain detail">${icons.back}</button>
        <h1>GPS Check-in</h1>
        <span></span>
      </header>

      <div class="checkpoint-map" aria-label="Checkpoint map">
        <div class="radius-circle"></div>
        <div class="trail-line"></div>
        <div class="pin checkpoint">${icons.mountain}</div>
        <div class="pin user-pin"></div>
        <div class="distance-label">82m</div>
      </div>

      <div class="gps-panel">
        <div class="gps-row">${icons.target}<span>GPS status</span><strong class="good">Good</strong></div>
        <div class="gps-row">${icons.pin}<span>Distance to checkpoint</span><strong class="good">82 m</strong></div>
        <div class="gps-row">${icons.accuracy}<span>Valid radius</span><strong class="good">150 m</strong></div>
        <div class="gps-row">${icons.clock}<span>GPS accuracy</span><strong class="good">18 m</strong></div>
      </div>

      <div class="photo-proof">
        <div class="proof-head">
          <div>
            <strong>Photo proof</strong>
            <span>Unlocked inside checkpoint area</span>
          </div>
          <span class="unlock-pill">${icons.check} Valid area</span>
        </div>
        <div class="proof-actions" role="tablist" aria-label="Photo proof method">
          <button class="proof-option ${state.proofMode === "camera" ? "is-active" : ""}" data-proof-mode="camera" role="tab" aria-selected="${state.proofMode === "camera"}">
            ${icons.camera}
            <span>Take photo</span>
          </button>
          <button class="proof-option ${state.proofMode === "upload" ? "is-active" : ""}" data-proof-mode="upload" role="tab" aria-selected="${state.proofMode === "upload"}">
            ${icons.upload}
            <span>Upload photo</span>
          </button>
        </div>
        <div class="stamp-preview ${state.proofMode === "upload" ? "is-upload" : ""}" style="--image: url('${mountain.image}')">
          <div class="stamp-brand">
            <span>${icons.mountain}</span>
            <strong>WildFrog</strong>
          </div>
          <div class="stamp-copy">
            <span>VALID CHECK-IN</span>
            <strong>${mountain.nameZh} ${mountain.nameEn}</strong>
            <em>${mountain.height}m · ${mountain.region} · 第 ${mountain.myCheckins + 1} 次打卡</em>
          </div>
        </div>
        <div class="proof-caption">
          <strong>${state.proofMode === "camera" ? "On-site photo stamp" : "Upload photo stamp"}</strong>
          <span>${state.proofMode === "camera" ? "Capture in the valid area, then the app adds the official mountain stamp." : "Uploaded photos get the same official stamp after location stays valid."}</span>
        </div>
        <button class="primary-action" data-action="complete-checkin">${icons.check} Check In Now</button>
        <div class="proof-lock-note">${icons.lock} Outside the valid radius, this step stays locked.</div>
      </div>

      <div class="safety-panel">
        ${icons.shield}
        <p>Check weather, respect restricted areas, and avoid using your phone while moving through unsafe terrain.</p>
      </div>
      <button class="secondary-action" data-screen-target="detail">${mountain.nameZh} details</button>
    </section>
  `;
}

function renderSuccess() {
  const mountain = selectedMountain();
  return `
    <section class="screen fade-in" data-screen="success">
      <div class="success-screen">
        <div class="stamp">${icons.check}</div>
        <div class="success-card">
          <h1>${mountain.nameZh} check-in successful</h1>
          <p>Your leaderboard count was updated for this mountain.</p>
          <div class="success-stats">
            <div class="success-stat"><span>Valid check-ins</span><strong>${state.didCheckIn ? mountain.myCheckins + 1 : mountain.myCheckins}</strong></div>
            <div class="success-stat"><span>Rank</span><strong>#${mountain.rank - 1}</strong></div>
            <div class="success-stat"><span>Next rank</span><strong>1</strong></div>
          </div>
        </div>
        <button class="primary-action" data-screen-target="detail">${icons.mountain} Back to mountain</button>
      </div>
    </section>
  `;
}

function renderExplore() {
  return `
    <section class="screen fade-in" data-screen="explore">
      <header class="screen-header">
        <div class="plain-title">
          <h1>Explore</h1>
          <p>Regions and checkpoints</p>
        </div>
        <button class="icon-button" aria-label="Map filters">${icons.filter}</button>
      </header>

      <div class="explore-map">
        <div class="map-point">${icons.mountain}</div>
        <div class="map-point">${icons.mountain}</div>
        <div class="map-point">${icons.mountain}</div>
        <div class="map-point">${icons.target}</div>
        <div class="route-line"></div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>Nearby records</h2>
          <span>HKT</span>
        </div>
        <div class="leaderboard">
          ${mountains.slice(0, 3).map((mountain) => renderRecordRow(mountain)).join("")}
        </div>
      </section>
    </section>
  `;
}

function renderRecords() {
  return `
    <section class="screen fade-in" data-screen="records">
      <header class="screen-header">
        <div class="plain-title">
          <h1>Records</h1>
          <p>Valid mountain history</p>
        </div>
        <button class="icon-button" aria-label="Privacy">${icons.shield}</button>
      </header>

      <div class="profile-card">
        <div class="profile-stats">
          <div class="profile-stat"><strong>86</strong><span>Total valid check-ins</span></div>
          <div class="profile-stat"><strong>14</strong><span>Mountains visited</span></div>
          <div class="profile-stat"><strong>12</strong><span>Best mountain count</span></div>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>Check-in history</h2>
          <span>Private coordinates</span>
        </div>
        <div class="leaderboard">
          ${history.map(renderHistoryRow).join("")}
        </div>
      </section>
    </section>
  `;
}

function renderHistoryRow(item) {
  const mountain = mountains.find((candidate) => candidate.id === item.mountainId) || mountains[0];
  return `
    <button class="history-row" data-open-detail="${mountain.id}">
      <img class="record-thumb" src="${mountain.image}" alt="" />
      <div class="row-main">
        <strong>${mountain.nameZh} ${mountain.nameEn}</strong>
        <span>${item.date} · ${item.time}</span>
      </div>
      <div class="status-pill">${item.status} ${icons.check}</div>
    </button>
  `;
}

function renderProfile() {
  return `
    <section class="screen fade-in" data-screen="profile">
      <header class="screen-header">
        <span></span>
        <button class="icon-button" aria-label="Settings">${icons.settings}</button>
      </header>

      <div class="profile-top">
        <div class="profile-photo">山</div>
        <div>
          <h1>山野之心</h1>
          <p>${icons.pin} Hong Kong · Hiker since 2022</p>
        </div>
      </div>

      <div class="profile-card">
        <div class="profile-stats">
          <div class="profile-stat"><strong>86</strong><span>Total valid check-ins</span></div>
          <div class="profile-stat"><strong>14</strong><span>Mountains visited</span></div>
          <div class="profile-stat"><strong>13</strong><span>Most visited</span></div>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>Top mountain records</h2>
          <span>Total</span>
        </div>
        <div class="leaderboard">
          ${mountains.map(renderRecordRow).join("")}
        </div>
      </section>

      <section class="section">
        <div class="privacy-row">
          <div>
            <strong>Private profile</strong>
            <span>Exact coordinates stay hidden from public leaderboards.</span>
          </div>
          <button class="switch" aria-label="Private profile enabled"><span></span></button>
        </div>
      </section>
    </section>
  `;
}

function renderRecordRow(mountain) {
  return `
    <button class="record-row" data-open-detail="${mountain.id}">
      <img class="record-thumb" src="${mountain.image}" alt="" />
      <div class="row-main">
        <strong>${mountain.nameZh} ${mountain.nameEn}</strong>
        <span>${mountain.height}m · ${mountain.region}</span>
      </div>
      <div class="row-count">
        <strong>${mountain.myCheckins}</strong>
        <span>check-ins</span>
      </div>
    </button>
  `;
}

function renderNav() {
  const items = [
    ["home", "Home", icons.mountain],
    ["explore", "Explore", icons.compass],
    ["checkin", "Check In", icons.target, true],
    ["records", "Records", icons.records],
    ["profile", "Profile", icons.user],
  ];

  return `
    <nav class="bottom-nav" aria-label="Primary">
      ${items
        .map(([screen, label, icon, primary]) => {
          const active = state.screen === screen || (screen === "checkin" && state.screen === "success");
          if (primary) {
            return `
              <button class="nav-item is-primary ${active ? "is-active" : ""}" data-screen-target="checkin" aria-label="${label}">
                <span class="nav-bubble">${icon}</span>
                <span>${label}</span>
              </button>
            `;
          }
          return `
            <button class="nav-item ${active ? "is-active" : ""}" data-screen-target="${screen}" aria-label="${label}">
              ${icon}
              <span>${label}</span>
            </button>
          `;
        })
        .join("")}
    </nav>
  `;
}

function bindEvents() {
  document.querySelectorAll("[data-screen-target]").forEach((button) => {
    button.addEventListener("click", () => {
      state.screen = button.dataset.screenTarget;
      render();
    });
  });

  document.querySelectorAll("[data-open-detail]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedMountainId = button.dataset.openDetail;
      state.screen = "detail";
      render();
    });
  });

  document.querySelectorAll("[data-region]").forEach((button) => {
    button.addEventListener("click", () => {
      state.region = button.dataset.region;
      render();
    });
  });

  document.querySelectorAll("[data-proof-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      state.proofMode = button.dataset.proofMode;
      render();
    });
  });

  const searchInput = byId("searchInput");
  if (searchInput) {
    searchInput.addEventListener("input", (event) => {
      state.query = event.target.value;
      render();
      const nextInput = byId("searchInput");
      if (nextInput) {
        nextInput.focus();
        nextInput.setSelectionRange(nextInput.value.length, nextInput.value.length);
      }
    });
  }

  const checkinButton = document.querySelector("[data-action='complete-checkin']");
  if (checkinButton) {
    checkinButton.addEventListener("click", () => {
      state.didCheckIn = true;
      state.screen = "success";
      render();
    });
  }
}

function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

render();
