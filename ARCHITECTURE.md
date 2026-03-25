# 《怪物與我 v3》開發規範與架構聖經（專案內固定版）

這份文件是「固定規範」：用來確保專案長期一致、可維護、可擴充。

- 你的 Google Sheet 可以持續寫日記/進度/數值/靈感（活文件）
- 但**任何會影響程式架構的規則**，以本文件為準（版本控制、避免對話 context 滿後遺忘）

> 如果你在對話裡跟 AI 說「照 `ARCHITECTURE.md` 做」，AI 應該以此文件為最高優先級的專案規範。

---

## 核心五大鐵則（不可破）

1. **純訊號驅動（Signal-Only UI）**
   - UI 嚴禁直接控制 `Player` 或 `Monster`（不直接讀寫玩家/怪物屬性、不 `get_node("../Player")` 去改速度等）
   - UI 只能透過 `SignalBus` 發射/監聽訊號
   - 世界層（Player/Monster/Manager）才可以做邏輯與狀態切換

2. **組件化（Component-first）**
   - 互動/封印/受傷/特效等以「積木」形式存在（`components積木/`）
   - 怪物封印相關必須集中在 `SealingComponent`（避免把封印塞進 UI 或 MonsterBase 亂長）

3. **狀態機節點化（State Machine as nodes）**
   - 玩家/怪物行為以狀態機節點管理（`states狀態機/`）
   - 新行為先想「狀態」再想「if else」

4. **資料驅動（Data-driven）**
   - 任何可調參數優先放 `Resource(.tres/.res)`（例如 `MonsterResource`、`PetResource`）
   - 禁止在程式寫「某怪物特例」：例如 `if monster_name == "Slime": ...`

5. **視覺控制權（Animation/Art > Code Position）**
   - 複雜互動動畫（擁抱、法陣碎裂、收縮旋轉等）優先使用美術/動畫資源
   - 程式只負責觸發、串接、與資料流，不要用大量位移計算硬做演出

---

## 命名規範（Naming Conventions）

### 檔案/資料夾
- **snake_case**（小寫+底線）為主，但本專案部分資料夾已採中文；新增時請遵循既有結構，不要混亂擴散。

### 類別（`class_name`）與節點（Node）
- **PascalCase**
- 例：`class_name PlayerController`、節點 `StateMachine`、`Sprite2D`

### 變數/函數
- **snake_case**
- 例：`move_speed`、`get_dir()`

### 常量
- **UPPER_CASE**
- 例：`MAX_HEALTH`、`ITEMS_PATH`

### 訊號（Signals）
- **過去式（past tense）**：代表「事件已發生」
- 例：`item_collected`、`dash_requested`

---

## 專案目錄結構（Directory Structure）

保持 `res://` 根目錄整潔，核心分類如下（以目前專案實際為準）：

- `assets圖片_字體_音效/`：美術/字體/音效資源（不可放邏輯）
- `scenes場景/`：所有場景 `.tscn`（UI、entities、levels）
- `src腳本/`：所有邏輯腳本（以功能分類）
  - `autoload管理員/`：全域單例（`SignalBus`、`DataManager`、`GlobalBalance`、`PetManager`）
  - `components積木/`：可重用組件（`SealingComponent`、`HealthComponent`…）
  - `entities/`：實體行為（玩家、怪物基底與控制器）
  - `resources身分證/`：資料藍圖（`.gd` 定義 + `.tres` 資料）
  - `states狀態機/`：狀態機與狀態節點

---

## SignalBus 規範（Omni-Protocol）

`SignalBus.gd` 是「電台」，**只負責信號宣告**，禁止放任何邏輯運算。

### 原則
- **UI → SignalBus.emit → Manager/Entity 接收**
- **Manager/Entity → SignalBus.emit → UI/FX 接收**
- 避免互相直接呼叫造成循環、耦合、難測試

### 常用事件分層（建議）
- **Input/Request（請求型）**：UI 發射，世界層接收  
  例：`dash_requested`、`seal_mode_toggled`
- **Result/State（結果型）**：世界層發射，UI/資料層接收  
  例：`player_health_changed`、`seal_attempt_finished`、`pet_captured`

---

## 封印系統（Sealing）協議摘要

封印屬於「儀式型互動」，請嚴格保持 UI 與世界層分離。

### 流程（概念）
1. UI 透過 `SignalBus.seal_mode_toggled` 啟動儀式
2. `SealManager` 控制「畫圈 → 轉場 → 長壓」
3. `SealingComponent` 控制怪物封印進度、掙扎視覺、成功/失敗演出
4. 結算由 `SealManager` 發射 `SignalBus.seal_attempt_finished(success, monster_data)`

### 結算事件（非常重要）
- **封印成功/失敗**都應該只用「事件」往外通知
- 任何 UI 更新、資料寫入、生成演出，都應該由監聽者處理

---

## Phase 4：寵物 Resource 定義與轉化流程（已落地）

### 目標
「封印成功」能把怪物資料轉成寵物資料，並可供後續 UI/召喚/互動使用。

### Resource 定義

#### `MonsterResource`
- 新增欄位：`pet_data: PetResource`
- 讓每隻怪物 `.tres` 可資料驅動指定「封印後變成哪隻寵物」

#### `PetResource`
建議包含：
- `pet_id`、`pet_name`
- `icon`
- `sprite_frames`（多數情況可沿用怪物視覺）
- 跟隨/支援能力相關數值（例如治療量、冷卻、跟隨距離）

### 轉化與資料流

#### 結算事件
- `SealManager` 發射：`SignalBus.seal_attempt_finished(success, monster_data)`

#### 接收與轉化
- `PetManager`（autoload）監聽 `seal_attempt_finished`
  - success 才處理
  - 優先使用 `monster_data.pet_data`
  - 若未設定 `pet_data`，用 fallback 由怪物資料組合出一個 `PetResource`（最小可用）
  - 成功後發射 `SignalBus.pet_captured(pet_data)`

### 後續擴充指引（下一階段會用到）
- **寵物列表 UI**：只監聽 `pet_captured` / 讀 `PetManager.captured_pets`
- **寵物召喚**：由世界層 manager 根據 `PetManager.active_pet` 在玩家旁生成 pet 實體
- **寵物互動**：新增互動事件（SignalBus）與對應世界層行為；UI 不直接控制

---

## 開發節奏建議（降低翻車率）

- 每完成一個「功能點」就做一次 git commit（當作可回復存檔點）
- 大改動先開新分支（例如 `phase5-pet-ui`）
- 如遇到資料夾移動/改名：
  - 盡量在 Godot Editor 內移動（讓引用更新）
  - 移動後立刻跑一次遊戲看輸出是否紅字

---

## 常見地雷（請避免）

- UI 直接抓 Player/Monster 改屬性（破壞解耦）
- 在 `SignalBus.gd` 寫邏輯（破壞電台）
- 用「特例 if」硬寫某怪物/某寵物（破壞資料驅動）
- 移動/改名資源檔但沒同步引用（容易變成「只剩 `.uid`」或丟失 `.tres`）

