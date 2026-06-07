# 軌跡綁打卡 Design（2026-06-07）

## 背景 / 問題
用戶 feedback：「我的軌跡」功能定位模糊 —— 唔知係跟你行記錄、定揀咗山跟路線,亦唔知有咩用。現狀（rebuild B5）軌跡係**獨立 free-form 記錄**（Strava 嗰種,同打卡無關）+ 另一個獨立「去打卡點導航」,兩者同 WildFrog 核心「打卡」脫節。

## 決定（brainstorm approved）
**軌跡綁打卡** —— 軌跡 = 一次打卡嘅過程證明 + 運動數據,唔再係獨立 Strava 線。

## 設計
### 核心 flow（一次完整行程）
1. 揀一座山（打卡 tab / 山峰詳情）→「**開始行程**」
2. 沿途 app 記 GPS 軌跡（即時距離 / 時間 / 爬升）
3. 行到山頂打卡範圍 → 影相 →**打卡**
4. 完成嗰刻：**軌跡自動停 + 同呢次打卡綁埋 save**
5. 紀錄睇返 = 完整一次：路線圖（replay）+ 山頂相 + 證書 + 距離/時間/爬升

### Optional（唔 block 快速打卡）
已喺山頂 / 唔想記全程 →「**直接打卡**」skip 軌跡。軌跡係 enhancement,唔強制。

### 數據
- `CheckInRecord` 加 optional 軌跡（`TrackSummary { coordinates/distanceMeters/durationSeconds/ascentMeters }` 或 reuse Track）。
- 一次打卡 ≤ 一條軌跡。CheckInStore persist 埋（per-user，跟現有 account-bound）。

### UI
- 打卡入口（CheckInPicker / 山峰詳情）：「開始行程（記軌跡）」vs「直接打卡」。
- 「開始行程」→ recording 畫面（Map + 即時 stats，整合 B5 TrackRecorder）+ 到山頂 GPS in-range → 影相 → 打卡（一體 flow，唔係兩個畫面）。
- 「我的軌跡」segment → **「我嘅行程」**：列每次打卡，有軌跡嗰啲顯示路線圖,純打卡嗰啲淨係相+證書。
- 紀錄 / 打卡 detail：顯示軌跡 replay + 相 + 證書 + stats。

### 保留 / 移除
- **保留**：山峰詳情「路線/導航去呢度」（RouteToCheckpoint，出發前搵路上山，係導航唔係記錄）。
- **移除**：獨立 free-form TrackRecordingView 入口（整合入打卡流程）。

### 限制 / 已知
- 背景記軌跡（app 熄屏/背景）要 `UIBackgroundModes: location` + `allowsBackgroundLocationUpdates`。MVP 可前景記錄優先，背景做 enhancement。
- 真 cross-user 排名仍需 Cloud Function（另議）。

## Implementation（順序，每步 build verify + commit）
- **TC1**：數據（CheckInRecord + optional track）+ 打卡流程整合記錄（開始行程 → 記軌跡 → 山頂打卡 → 綁 save）。reuse TrackRecorder。
- **TC2**：紀錄睇返（打卡 detail 軌跡 replay + stats）+「我的軌跡」→「我嘅行程」列表 + 移除獨立 free-form 入口。
- 保留 RouteToCheckpoint。

## Status
- ✅ Brainstorm approved（軌跡綁打卡）
- ✅ TC1（295909f）數據 + 打卡流程整合（開始行程/直接打卡 + recording 一體）
- ✅ TC2（8476d35）我嘅行程列表 + TripDetailView 睇返 + 移除 free-form 記錄
- ✅ 打卡揀山 UX（4e14dfa）地圖+列表切換（pin 限 40 + 搜尋 + 分區 filter）
- ✅ Device install + launch 成功（FyuRa）
