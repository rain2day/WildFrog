const mountains = [
  {
    id: "tai-mo-shan",
    nameZh: "大帽山",
    nameEn: "Tai Mo Shan",
    region: "New Territories",
    regionZh: "新界",
    height: 957,
    image: "./assets/tai-mo-shan.png",
    myCheckins: 12,
    rank: 18,
    nextRankDistance: 2,
    totalCheckins: 1245,
    lastZh: "今日",
    lastEn: "Today",
    coordinates: "22.411, 114.123",
  },
  {
    id: "lion-rock",
    nameZh: "獅子山",
    nameEn: "Lion Rock",
    region: "Kowloon",
    regionZh: "九龍",
    height: 495,
    image: "./assets/lion-rock.png",
    myCheckins: 8,
    rank: 32,
    nextRankDistance: 4,
    totalCheckins: 2341,
    lastZh: "本週",
    lastEn: "This week",
    coordinates: "22.352, 114.187",
  },
  {
    id: "lantau-peak",
    nameZh: "鳳凰山",
    nameEn: "Lantau Peak",
    region: "Lantau",
    regionZh: "大嶼山",
    height: 934,
    image: "./assets/lantau-peak.png",
    myCheckins: 7,
    rank: 27,
    nextRankDistance: 3,
    totalCheckins: 987,
    lastZh: "昨日",
    lastEn: "Yesterday",
    coordinates: "22.249, 113.921",
  },
  {
    id: "sunset-peak",
    nameZh: "大東山",
    nameEn: "Sunset Peak",
    region: "Lantau",
    regionZh: "大嶼山",
    height: 869,
    image: "./assets/lantau-peak.png",
    myCheckins: 6,
    rank: 41,
    nextRankDistance: 5,
    totalCheckins: 612,
    lastZh: "本月",
    lastEn: "This month",
    coordinates: "22.263, 113.950",
  },
];

const leaders = [
  { rank: 1, name: "山系行者", count: 68, subZh: "最後打卡：今日", subEn: "Last check-in: today" },
  { rank: 2, name: "Trail_HK", count: 43, subZh: "最後打卡：昨日", subEn: "Last check-in: yesterday" },
  { rank: 3, name: "自然探索者", count: 39, subZh: "最後打卡：本週", subEn: "Last check-in: this week" },
  { rank: 18, name: "You", count: 12, subZh: "即使不在前 10 名，也會顯示你的排名", subEn: "Always shown outside top 10", isUser: true },
];

const history = [
  { mountainId: "tai-mo-shan", dateZh: "今日", dateEn: "Today", time: "07:45", statusZh: "有效", statusEn: "Valid" },
  { mountainId: "lion-rock", dateZh: "6 月 4 日", dateEn: "4 Jun", time: "06:18", statusZh: "有效", statusEn: "Valid" },
  { mountainId: "lantau-peak", dateZh: "6 月 2 日", dateEn: "2 Jun", time: "05:52", statusZh: "有效", statusEn: "Valid" },
  { mountainId: "tai-mo-shan", dateZh: "5 月 29 日", dateEn: "29 May", time: "08:04", statusZh: "有效", statusEn: "Valid" },
];

const regions = [
  { value: "All", zh: "全部", en: "All" },
  { value: "New Territories", zh: "新界", en: "New Territories" },
  { value: "Kowloon", zh: "九龍", en: "Kowloon" },
  { value: "Lantau", zh: "大嶼山", en: "Lantau" },
];

const state = {
  screen: "home",
  selectedMountainId: "tai-mo-shan",
  region: "All",
  query: "",
  didCheckIn: false,
  proofMode: "camera",
  lang: "zh",
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

const copy = {
  zh: {
    appLabel: "WildFrog 手機 app 原型",
    title: "WildFrog 山野紀錄草稿",
    brandSub: "香港山峰紀錄",
    notifications: "通知",
    languageLabel: "切換至英文",
    languageText: "EN",
    searchPlaceholder: "搜尋山峰",
    filterMountains: "篩選山峰",
    regionFilter: "地區篩選",
    emptyMountains: "找不到符合的山峰",
    homeEyebrow: "P0 原型",
    homeHeadline: "每座山都有自己的打卡紀錄",
    homeIntro: "到達有效範圍後解鎖相片證明，再生成官方山峰印章。",
    mountainCount: "山峰",
    todayReady: "GPS 檢查就緒",
    myCheckins: "我的打卡",
    myRank: "我的排名",
    totalCheckins: "總打卡",
    backToList: "返回山峰列表",
    map: "地圖",
    myRecord: "我的紀錄",
    validCheckins: "有效打卡",
    toNextRank: "距離下一名",
    checkIn: "打卡",
    leaderboard: "排行榜",
    total: "總榜",
    valid: "有效",
    you: "你",
    backToDetail: "返回山峰詳情",
    gpsCheckIn: "GPS 打卡",
    checkpointMap: "檢查點地圖",
    gpsStatus: "GPS 狀態",
    good: "良好",
    distanceToCheckpoint: "距離檢查點",
    validRadius: "有效半徑",
    gpsAccuracy: "GPS 精準度",
    photoProof: "相片證明",
    photoProofSub: "進入檢查點範圍後解鎖",
    validArea: "有效範圍",
    proofMethod: "相片證明方式",
    takePhoto: "即場拍照",
    uploadPhoto: "上載相片",
    validCheckIn: "有效打卡",
    cameraStamp: "即場相片印章",
    uploadStamp: "上載相片印章",
    cameraCaption: "在有效範圍內拍攝，系統會加上官方山峰印章。",
    uploadCaption: "上載相片只作證明，位置仍需保持有效才會蓋章。",
    checkInNow: "立即完成打卡",
    lockNote: "離開有效半徑時，此步驟會保持鎖定。",
    safetyCopy: "先確認天氣及路況，遵守封閉區域，危險地形上不要邊行邊用手機。",
    details: "詳情",
    successTitle: "打卡成功",
    successCopy: "此山峰的排行榜紀錄已更新。",
    rank: "排名",
    nextRank: "下一名",
    backToMountain: "返回山峰",
    explore: "探索",
    exploreSub: "地區與檢查點",
    mapFilters: "地圖篩選",
    nearbyRecords: "附近紀錄",
    records: "紀錄",
    recordsSub: "有效山峰歷史",
    privacy: "私隱",
    totalValid: "有效打卡總數",
    mountainsVisited: "已到訪山峰",
    bestMountainCount: "最高山峰次數",
    checkinHistory: "打卡歷史",
    privateCoordinates: "精確座標不公開",
    settings: "設定",
    profileLocation: "香港 · 2022 起開始行山",
    mostVisited: "最多到訪",
    topMountainRecords: "最高山峰紀錄",
    privateProfile: "私人個人檔案",
    privateProfileCopy: "排行榜不會公開精確座標。",
    privateProfileEnabled: "私人個人檔案已啟用",
    checkins: "次打卡",
    navPrimary: "主要導覽",
    home: "首頁",
    profile: "個人",
  },
  en: {
    appLabel: "WildFrog mobile app prototype",
    title: "WildFrog App Draft",
    brandSub: "Mountain records",
    notifications: "Notifications",
    languageLabel: "Switch to Traditional Chinese",
    languageText: "中",
    searchPlaceholder: "Search mountains",
    filterMountains: "Filter mountains",
    regionFilter: "Region filter",
    emptyMountains: "No matching mountains",
    homeEyebrow: "P0 prototype",
    homeHeadline: "Every mountain keeps its own record",
    homeIntro: "Reach the valid area, unlock photo proof, then generate the official mountain stamp.",
    mountainCount: "mountains",
    todayReady: "GPS proof ready",
    myCheckins: "My check-ins",
    myRank: "My rank",
    totalCheckins: "Total check-ins",
    backToList: "Back to mountain list",
    map: "Map",
    myRecord: "My Record",
    validCheckins: "Valid check-ins",
    toNextRank: "To next rank",
    checkIn: "Check In",
    leaderboard: "Leaderboard",
    total: "Total",
    valid: "valid",
    you: "You",
    backToDetail: "Back to mountain detail",
    gpsCheckIn: "GPS Check-in",
    checkpointMap: "Checkpoint map",
    gpsStatus: "GPS status",
    good: "Good",
    distanceToCheckpoint: "Distance to checkpoint",
    validRadius: "Valid radius",
    gpsAccuracy: "GPS accuracy",
    photoProof: "Photo proof",
    photoProofSub: "Unlocked inside checkpoint area",
    validArea: "Valid area",
    proofMethod: "Photo proof method",
    takePhoto: "Take photo",
    uploadPhoto: "Upload photo",
    validCheckIn: "Valid check-in",
    cameraStamp: "On-site photo stamp",
    uploadStamp: "Upload photo stamp",
    cameraCaption: "Capture in the valid area, then the app adds the official mountain stamp.",
    uploadCaption: "Uploaded photos get the same official stamp after location stays valid.",
    checkInNow: "Check In Now",
    lockNote: "Outside the valid radius, this step stays locked.",
    safetyCopy: "Check weather, respect restricted areas, and avoid using your phone while moving through unsafe terrain.",
    details: "details",
    successTitle: "check-in successful",
    successCopy: "Your leaderboard count was updated for this mountain.",
    rank: "Rank",
    nextRank: "Next rank",
    backToMountain: "Back to mountain",
    explore: "Explore",
    exploreSub: "Regions and checkpoints",
    mapFilters: "Map filters",
    nearbyRecords: "Nearby records",
    records: "Records",
    recordsSub: "Valid mountain history",
    privacy: "Privacy",
    totalValid: "Total valid check-ins",
    mountainsVisited: "Mountains visited",
    bestMountainCount: "Best mountain count",
    checkinHistory: "Check-in history",
    privateCoordinates: "Private coordinates",
    settings: "Settings",
    profileLocation: "Hong Kong · Hiker since 2022",
    mostVisited: "Most visited",
    topMountainRecords: "Top mountain records",
    privateProfile: "Private profile",
    privateProfileCopy: "Exact coordinates stay hidden from public leaderboards.",
    privateProfileEnabled: "Private profile enabled",
    checkins: "check-ins",
    navPrimary: "Primary",
    home: "Home",
    profile: "Profile",
  },
};

function byId(id) {
  return document.getElementById(id);
}

function t(key) {
  return copy[state.lang][key];
}

function localized(valueZh, valueEn) {
  return state.lang === "zh" ? valueZh : valueEn;
}

function selectedMountain() {
  return mountains.find((mountain) => mountain.id === state.selectedMountainId) || mountains[0];
}

function formatNumber(value) {
  return new Intl.NumberFormat(state.lang === "zh" ? "zh-HK" : "en-US").format(value);
}

function regionLabel(region) {
  const match = regions.find((item) => item.value === region);
  if (!match) return region;
  return localized(match.zh, match.en);
}

function mountainTitle(mountain) {
  return state.lang === "zh" ? `${mountain.nameZh} ${mountain.nameEn}` : `${mountain.nameEn} ${mountain.nameZh}`;
}

function renderLanguageToggle() {
  return `
    <button class="lang-toggle" data-action="toggle-language" aria-label="${t("languageLabel")}">
      ${t("languageText")}
    </button>
  `;
}

function render() {
  const app = byId("app");
  document.documentElement.lang = state.lang === "zh" ? "zh-Hant-HK" : "en";
  document.title = t("title");
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
    const haystack = `${mountain.nameZh} ${mountain.nameEn} ${mountain.region} ${mountain.regionZh}`.toLowerCase();
    return matchesRegion && haystack.includes(state.query.toLowerCase());
  });

  return `
    <section class="screen fade-in" data-screen="home">
      <header class="screen-header">
        <div class="brand">
          <div class="brand-mark">${icons.mountain}</div>
          <div>
            <h1>WildFrog</h1>
            <p>${t("brandSub")}</p>
          </div>
        </div>
        <div class="header-actions">
          ${renderLanguageToggle()}
          <button class="icon-button" aria-label="${t("notifications")}">${icons.bell}</button>
        </div>
      </header>

      <section class="home-summary" aria-label="${t("homeHeadline")}">
        <div>
          <span class="eyebrow">${t("homeEyebrow")}</span>
          <h2>${t("homeHeadline")}</h2>
          <p>${t("homeIntro")}</p>
        </div>
        <div class="summary-meter">
          <strong>${mountains.length}</strong>
          <span>${t("mountainCount")}</span>
        </div>
      </section>

      <section class="activity-strip" aria-label="${t("recordsSub")}">
        <div class="activity-stat">
          ${icons.records}
          <div><strong>86</strong><span>${t("totalValid")}</span></div>
        </div>
        <div class="activity-stat">
          ${icons.mountain}
          <div><strong>14</strong><span>${t("mountainsVisited")}</span></div>
        </div>
        <div class="activity-stat">
          ${icons.trophy}
          <div><strong>#18</strong><span>${t("myRank")}</span></div>
        </div>
      </section>

      <div class="search-row">
        <label class="search-field">
          ${icons.search}
          <input id="searchInput" type="search" value="${escapeHtml(state.query)}" placeholder="${t("searchPlaceholder")}" autocomplete="off" />
        </label>
        <button class="icon-button" aria-label="${t("filterMountains")}">${icons.filter}</button>
      </div>

      <div class="chip-row" role="tablist" aria-label="${t("regionFilter")}">
        ${regions
          .map(
            (region) => `
              <button class="chip ${state.region === region.value ? "is-active" : ""}" data-region="${region.value}" role="tab" aria-selected="${state.region === region.value}">
                ${localized(region.zh, region.en)}
              </button>
            `
          )
          .join("")}
      </div>

      <div class="mountain-list">
        ${filtered.length ? filtered.map(renderMountainCard).join("") : `<div class="empty-state">${t("emptyMountains")}</div>`}
      </div>
    </section>
  `;
}

function renderMountainCard(mountain) {
  return `
    <button class="mountain-card" data-open-detail="${mountain.id}" style="--image: url('${mountain.image}')">
      <div class="card-head">
        <div class="card-title">
          <h2>${mountainTitle(mountain)}</h2>
          <p>${regionLabel(mountain.region)} · ${t("todayReady")}</p>
        </div>
        <span class="height-badge">${mountain.height}m</span>
      </div>
      <div class="card-metrics">
        <div class="metric">
          ${icons.mountain}
          <div><small>${t("myCheckins")}</small><strong>${mountain.myCheckins}</strong></div>
        </div>
        <div class="metric">
          ${icons.trophy}
          <div><small>${t("myRank")}</small><strong class="rank">#${mountain.rank}</strong></div>
        </div>
        <div class="metric">
          ${icons.people}
          <div><small>${t("totalCheckins")}</small><strong>${formatNumber(mountain.totalCheckins)}</strong></div>
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
          <button class="icon-button" data-screen-target="home" aria-label="${t("backToList")}">${icons.back}</button>
          <div class="hero-actions">
            <button class="icon-button" aria-label="${t("map")}">${icons.map}</button>
          </div>
        </header>
        <div class="detail-title">
          <h1>${mountainTitle(mountain)}</h1>
          <p>${icons.pin} ${regionLabel(mountain.region)} · ${mountain.height}m · ${formatNumber(mountain.totalCheckins)} ${t("totalCheckins")}</p>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>${t("myRecord")}</h2>
          <span>${localized(mountain.lastZh, mountain.lastEn)}</span>
        </div>
        <div class="record-panel">
          <div class="record-grid">
            <div class="record-cell"><span>${t("validCheckins")}</span><strong>${mountain.myCheckins}</strong></div>
            <div class="record-cell"><span>${t("myRank")}</span><strong class="accent">#${mountain.rank}</strong></div>
            <div class="record-cell"><span>${t("toNextRank")}</span><strong>${mountain.nextRankDistance}</strong></div>
          </div>
        </div>
        <button class="primary-action" data-screen-target="checkin">${icons.target} ${t("checkIn")}</button>
      </section>

      <section class="section">
        <div class="section-title">
          <h2>${t("leaderboard")}</h2>
          <span>${t("total")}</span>
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
      <div class="avatar">${row.isUser ? localized("你", "Y") : row.name.slice(0, 1)}</div>
      <div class="row-main">
        <strong>${row.isUser ? t("you") : row.name}</strong>
        <span>${localized(row.subZh, row.subEn)}</span>
      </div>
      <div class="row-count">
        <strong>${row.count}</strong>
        <span>${t("valid")}</span>
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
        <button class="icon-button" data-screen-target="detail" aria-label="${t("backToDetail")}">${icons.back}</button>
        <h1>${t("gpsCheckIn")}</h1>
        <span></span>
      </header>

      <div class="checkpoint-map" aria-label="${t("checkpointMap")}">
        <div class="radius-circle"></div>
        <div class="trail-line"></div>
        <div class="pin checkpoint">${icons.mountain}</div>
        <div class="pin user-pin"></div>
        <div class="distance-label">82m</div>
      </div>

      <div class="gps-panel">
        <div class="gps-row">${icons.target}<span>${t("gpsStatus")}</span><strong class="good">${t("good")}</strong></div>
        <div class="gps-row">${icons.pin}<span>${t("distanceToCheckpoint")}</span><strong class="good">82 m</strong></div>
        <div class="gps-row">${icons.accuracy}<span>${t("validRadius")}</span><strong class="good">150 m</strong></div>
        <div class="gps-row">${icons.clock}<span>${t("gpsAccuracy")}</span><strong class="good">18 m</strong></div>
      </div>

      <div class="photo-proof">
        <div class="proof-head">
          <div>
            <strong>${t("photoProof")}</strong>
            <span>${t("photoProofSub")}</span>
          </div>
          <span class="unlock-pill">${icons.check} ${t("validArea")}</span>
        </div>
        <div class="proof-actions" role="tablist" aria-label="${t("proofMethod")}">
          <button class="proof-option ${state.proofMode === "camera" ? "is-active" : ""}" data-proof-mode="camera" role="tab" aria-selected="${state.proofMode === "camera"}">
            ${icons.camera}
            <span>${t("takePhoto")}</span>
          </button>
          <button class="proof-option ${state.proofMode === "upload" ? "is-active" : ""}" data-proof-mode="upload" role="tab" aria-selected="${state.proofMode === "upload"}">
            ${icons.upload}
            <span>${t("uploadPhoto")}</span>
          </button>
        </div>
        <div class="stamp-preview ${state.proofMode === "upload" ? "is-upload" : ""}" style="--image: url('${mountain.image}')">
          <div class="stamp-brand">
            <span>${icons.mountain}</span>
            <strong>WildFrog</strong>
          </div>
          <div class="stamp-copy">
            <span>${t("validCheckIn")}</span>
            <strong>${mountainTitle(mountain)}</strong>
            <em>${mountain.height}m · ${regionLabel(mountain.region)} · ${localized(`第 ${mountain.myCheckins + 1} 次打卡`, `${mountain.myCheckins + 1} ${t("checkins")}`)}</em>
          </div>
        </div>
        <div class="proof-caption">
          <strong>${state.proofMode === "camera" ? t("cameraStamp") : t("uploadStamp")}</strong>
          <span>${state.proofMode === "camera" ? t("cameraCaption") : t("uploadCaption")}</span>
        </div>
        <button class="primary-action" data-action="complete-checkin">${icons.check} ${t("checkInNow")}</button>
        <div class="proof-lock-note">${icons.lock} ${t("lockNote")}</div>
      </div>

      <div class="safety-panel">
        ${icons.shield}
        <p>${t("safetyCopy")}</p>
      </div>
      <button class="secondary-action" data-screen-target="detail">${mountain.nameZh} ${t("details")}</button>
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
          <h1>${mountain.nameZh} ${t("successTitle")}</h1>
          <p>${t("successCopy")}</p>
          <div class="success-stats">
            <div class="success-stat"><span>${t("validCheckins")}</span><strong>${state.didCheckIn ? mountain.myCheckins + 1 : mountain.myCheckins}</strong></div>
            <div class="success-stat"><span>${t("rank")}</span><strong>#${mountain.rank - 1}</strong></div>
            <div class="success-stat"><span>${t("nextRank")}</span><strong>1</strong></div>
          </div>
        </div>
        <button class="primary-action" data-screen-target="detail">${icons.mountain} ${t("backToMountain")}</button>
      </div>
    </section>
  `;
}

function renderExplore() {
  return `
    <section class="screen fade-in" data-screen="explore">
      <header class="screen-header">
        <div class="plain-title">
          <h1>${t("explore")}</h1>
          <p>${t("exploreSub")}</p>
        </div>
        <button class="icon-button" aria-label="${t("mapFilters")}">${icons.filter}</button>
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
          <h2>${t("nearbyRecords")}</h2>
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
          <h1>${t("records")}</h1>
          <p>${t("recordsSub")}</p>
        </div>
        <button class="icon-button" aria-label="${t("privacy")}">${icons.shield}</button>
      </header>

      <div class="profile-card">
        <div class="profile-stats">
          <div class="profile-stat"><strong>86</strong><span>${t("totalValid")}</span></div>
          <div class="profile-stat"><strong>14</strong><span>${t("mountainsVisited")}</span></div>
          <div class="profile-stat"><strong>12</strong><span>${t("bestMountainCount")}</span></div>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>${t("checkinHistory")}</h2>
          <span>${t("privateCoordinates")}</span>
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
        <strong>${mountainTitle(mountain)}</strong>
        <span>${localized(item.dateZh, item.dateEn)} · ${item.time}</span>
      </div>
      <div class="status-pill">${localized(item.statusZh, item.statusEn)} ${icons.check}</div>
    </button>
  `;
}

function renderProfile() {
  return `
    <section class="screen fade-in" data-screen="profile">
      <header class="screen-header">
        <span></span>
        <div class="header-actions">
          ${renderLanguageToggle()}
          <button class="icon-button" aria-label="${t("settings")}">${icons.settings}</button>
        </div>
      </header>

      <div class="profile-top">
        <div class="profile-photo">山</div>
        <div>
          <h1>山野之心</h1>
          <p>${icons.pin} ${t("profileLocation")}</p>
        </div>
      </div>

      <div class="profile-card">
        <div class="profile-stats">
          <div class="profile-stat"><strong>86</strong><span>${t("totalValid")}</span></div>
          <div class="profile-stat"><strong>14</strong><span>${t("mountainsVisited")}</span></div>
          <div class="profile-stat"><strong>13</strong><span>${t("mostVisited")}</span></div>
        </div>
      </div>

      <section class="section">
        <div class="section-title">
          <h2>${t("topMountainRecords")}</h2>
          <span>${t("total")}</span>
        </div>
        <div class="leaderboard">
          ${mountains.map(renderRecordRow).join("")}
        </div>
      </section>

      <section class="section">
        <div class="privacy-row">
          <div>
            <strong>${t("privateProfile")}</strong>
            <span>${t("privateProfileCopy")}</span>
          </div>
          <button class="switch" aria-label="${t("privateProfileEnabled")}"><span></span></button>
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
        <strong>${mountainTitle(mountain)}</strong>
        <span>${mountain.height}m · ${regionLabel(mountain.region)}</span>
      </div>
      <div class="row-count">
        <strong>${mountain.myCheckins}</strong>
        <span>${t("checkins")}</span>
      </div>
    </button>
  `;
}

function renderNav() {
  const items = [
    ["home", t("home"), icons.mountain],
    ["explore", t("explore"), icons.compass],
    ["checkin", t("checkIn"), icons.target, true],
    ["records", t("records"), icons.records],
    ["profile", t("profile"), icons.user],
  ];

  return `
    <nav class="bottom-nav" aria-label="${t("navPrimary")}">
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
  document.querySelectorAll("[data-action='toggle-language']").forEach((button) => {
    button.addEventListener("click", () => {
      state.lang = state.lang === "zh" ? "en" : "zh";
      render();
    });
  });

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
