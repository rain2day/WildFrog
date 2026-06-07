# WildFrog Function Rebuild Plan（2026-06-07）

## 背景：Dropbox sync 事故
隔夜 Dropbox sync 把 working tree 換成另一條線嘅版本（211 真山相 + FrogTabBar UI + 330 山），**沖走咗 session 後期未 commit 嘅 backend/tracks/location/camera/firestore/certificate/route .swift file**。現狀已 commit 鎖住：branch `wildfrog-recovery-20260607`, commit `38490a4`。
**教訓：每個 batch verify 完即刻 git commit（untracked 會被 sync 沖）。**

## Base（現狀版本）
- 330 山（Mountain.swift）+ 211 imageset 真山相
- FrogTabBar 5 tab：探索(home)/紀錄(records)/打卡(checkIn)/排行(leaderboard)/我的(profile)
- ProfileAuthService 存在（auth）；但打卡冇接 auth/store；冇 LocationManager/CheckInStore/Firestore/tracks/camera
- Base xcodebuild PASS

## 重做 roadmap（順序，每 batch build verify + commit）

### B1 — Foundation
- 加 FirebaseFirestore 落 Package.swift（audit：已 resolved，1-line + rebuild）+ xcodeproj product dep
- `LocationManager`（CLLocationManager wrapper，@Observable/ObservableObject，authorizationStatus + currentLocation + distance(to:)，用現有 NSLocationWhenInUseUsageDescription）
- `CheckInStore`（account-bound 本地 persist，per-user key by ProfileAuthService.session.uid；CheckInRecord {mountainId,date,photoFile?}；computed：per-mountain count / total / distinct / **真 streak** / days-in-month）
- `FirestoreService`（recordCheckIn 寫 `checkIns` {userId,mountainId,dayKey,createdAt}；fetchUserCheckIns restore；personal monthly rank 由自己 checkIns 計）
- root inject（WildFrogNativeApp：locationManager + checkInStore .environment；session→store configure）

### B2 — GPS gating + 打卡 picker
- CheckInCameraView GPS chip 真 distance（取代 hardcoded）+ out-of-range disable 完成打卡
- MountainDetailView「GPS 良好」靜態 caption 改真
- 打卡 tab picker：LocationManager sort 最近山 + 自動選最近（取代 hardcoded lion-rock）+ visited badge（CheckInStore）

### B3 — 真相機 + watermark
- 真相機（UIImagePickerController(.camera) / AVCaptureSession，NSCameraUsageDescription 已有）+ PhotosPicker 上載
- watermark export 用**用戶真相**（唔係 asset）+ count 用 CheckInStore 真數

### B4 — 完成打卡 + 統計/日曆接真
- 完成打卡 → CheckInStore.addCheckIn + FirestoreService 寫 checkIns（要登入）
- 首頁/Profile/Records stats + streak + 日曆 activeDays 接 CheckInStore（取代 hardcoded）
- RecordsCalendar 月份 chevron wire（@State displayedMonth）

### B5 — Tracks 系統（audit：100% absent，重建）
- Track model + TrackRecorder（CLLocationManager 累積，距離/時間/爬升）+ TrackStore（Documents JSON）
- 記錄 UI（路線/軌跡入口）+ TrackDetail replay（MapPolyline）+ GPXExporter + 地圖圖 share + RouteToCheckpoint（MKDirections 真路線 + 導航 + 最近打卡點）
- ⚠️ 留意現狀 nav 結構（FrogTabBar 5 tab，冇 tracks tab）— 決定 tracks 入口（可入「紀錄」segment 或加 tab）

### B6 — Dead buttons / UI（audit clientCompletable）
- 通知🔔 bell → NotificationsView sheet（空狀態）
- MapFloatingButton → Button（map style toggle / recenter）
- VIEW ALL PEAKS / SEE ALL → scroll to directory（ScrollViewReader）
- directory pagination「顯示更多」
- 證書 share（CertificateShareView + ShareLink + ImageRenderer）+ wire ProfileView「VIEW & SHARE」
- achievements/leaderboard「查看全部」→ Button/NavigationLink
- 移除 dead hero()（HomeMapListView 127-171，fake Day-Streak + dead bell）

### B7 — 排名 / leaderboard 真實化
- **Personal（client，真）**：自己當日/當月排名由自己 checkIns 計，誠實顯示
- **Cross-user leaderboard**：audit rankingFix —— 真 cross-user 要 **Cloud Function**（checkIns onCreate → increment mountains + dailyCheckInStats）+ rules `dailyCheckInStats` read-only。需要 **Blaze plan**（外部決定）。**唔好**加 client-writable aggregate rule（可偽造）。Interim：cross-user 榜 label「示範資料」直到 Cloud Function。

## 外部/決定（需用戶）
- Cloud Function（排名 + community totalCheckIns aggregate）→ 要 Firebase Blaze plan + deploy
- Friends leaderboard → social graph 數據模型決定
- Firebase auth providers：已 ready（Email/Google/Apple/Phone，見 memory wildfrog-firebase-auth-ready）

## Status
- ✅ B0 commit 現狀保命（38490a4）
- ✅ B1 Foundation（c9bdb2d）— LocationManager/CheckInStore/FirestoreService/FirebaseFirestore
- ✅ B2 GPS gating + picker（ae2ed80）
- ✅ B3 真相機 + watermark（e394710）
- ✅ B4 完成打卡寫入 + 統計/日曆接真（2a90771）
- ✅ B5 軌跡系統 + 路線導航（dee2d73）
- ✅ B6 dead buttons wiring（4ed8e14）
- ✅ B7 排名誠實化（b68e280）
- 🔄 Final QA + device install
- ⬜ External：Cloud Function 真 cross-user 排名（需 Blaze plan，用戶決定）
