# NEO CHAMELEON — ゲーム仕様書

本ドキュメントは **コードベース準拠** の現行仕様を記述する。実装の正は `game.js` / `chameleon.js` / `bugs.js` / `audio.js` / `index.html` を参照すること。

---

## 1. ゲーム概要・技術前提

### 1.1 概要

**NEO CHAMELEON** は、256×240 のレトロ解像度キャンバス上で、左下に固定されたカメレオンが舌を伸ばして飛行昆虫を捕獲するブラウザ向けアーケードゲームである。空腹（HUNGER）が時間とともに減少し、0 になるとゲームオーバーとなる。

### 1.2 技術スタック

| 項目 | 内容 |
|------|------|
| ランタイム | ブラウザ（Vanilla JavaScript、ビルド不要） |
| 描画 | HTML5 Canvas 2D（内部解像度 256×240） |
| 音声 | Web Audio API（`RetroAudio` クラスで動的生成） |
| 永続化 | `localStorage`（ハイスコア・音量） |
| フォント | Google Fonts「Press Start 2P」（HUD・タイトル） |
| 開発サーバー | `http-server`（`npm run dev`、ポート 3000） |

### 1.3 エントリポイント

- ページ読み込み完了時: `window.addEventListener('load', () => { window.game = new GameEngine(); })`（`game.js`）
- 起動時にブート用ノイズ（`#power-static`）を 400ms 表示後、タイトル画面（`TITLE`）

### 1.4 ゲームループ

- `requestAnimationFrame` による `update()` → `draw()` ループ
- フレームレートはブラウザ依存（設計上 60fps 想定。タイマー類はフレーム単位で記述）

---

## 2. ゲーム状態

`GameEngine.state` で管理される。

| 状態 | 説明 |
|------|------|
| `TITLE` | タイトル画面。エンティティはアニメーションのみ更新 |
| `PLAYING` | 本編。空腹減少・捕食・スコア処理が有効 |
| `GAMEOVER` | ゲームオーバー画面。ハイスコア保存 |

### 未実装

コメント上 `PAUSED` が列挙されているが、**参照・遷移・描画のいずれも未実装**（定義のみ）。

---

## 3. 操作・入力

### 3.1 照準（カメレオン頭の向き）

| 入力 | 動作 | 実装 |
|------|------|------|
| `ArrowUp` / `KeyW` | 角度を −0.04 rad/フレーム | `chameleon.js` |
| `ArrowDown` / `KeyS` | 角度を +0.04 rad/フレーム | 同上 |
| マウス（キャンバス内） | ピボット→カーソル方向へ `atan2`、クランプ後に補間 | 同上 |
| 画面上 D-pad（`gb-dpad-*`） | `keys['ArrowUp']` 等と同等 | `game.js` |

**左右キー（`ArrowLeft`/`ArrowRight`/`KeyA`/`KeyD`）は照準に未使用。**

#### 角度クランプ

- **キーボード**: `targetAngle` を `[-Math.PI * 0.65, Math.PI * 0.15]` にクランプ
- **マウス**: 計算後 `desiredAngle` を `[-Math.PI * 0.6, Math.PI * 0.1]` にクランプ
- 実際の `angle` は `rotationSpeed = 0.08` で `targetAngle` へ補間

### 3.2 舌の発射

| 入力 | 動作 |
|------|------|
| `Space` | `triggerShoot()`（`PLAYING` 時） |
| キャンバス `mousedown` / `touchstart` | 同上（タイトル/ゲームオーバー時は開始/リトライ） |
| `gb-btn-a` / `gb-btn-b` | 同上 |

`triggerShoot()` は `chameleon.shoot()` が成功したときのみ `audio.playShoot()` を再生する。舌が `idle` でないときは発射不可。

### 3.3 ゲーム開始・リトライ

| 状態 | 入力 |
|------|------|
| `TITLE` | `Space`、キャンバスクリック/タッチ、A/B ボタン → `startGame()` |
| `GAMEOVER` | 同上 → `resetGame()`（静的 300ms 後に `startGame()`） |

### 3.4 UI・モーダル

| 操作 | 動作 |
|------|------|
| `gb-select-btn`（SELECT） | `#settings-modal` の表示切替 |
| `gb-start-btn`（START） | `#instructions-modal` の表示切替 |
| モーダル外クリック/タッチ | 該当モーダルを閉じる |

### 3.5 照準カーソル（ゲーム内 HUD）

- **条件**: `PLAYING` かつ舌 `idle` かつ **画面上 D-pad UI のいずれかが押下中**（`isDpadUIAiming()`）
- 舌の最大到達点にネオンピンクの照準線・十字を描画
- マウス照準時はカーソル非表示

### 3.6 設定パネル（永続しない項目除く）

| 項目 | ID | 既定 |
|------|-----|------|
| CRT スキャンライン | `scanline-toggle` | ON |
| BGM | `music-toggle` | ON |
| BGM 音量 | `bgm-volume-slider` | 30% |
| SFX | `sfx-toggle` | ON |
| SFX 音量 | `sfx-volume-slider` | 50% |

初回操作で `audio.init()` / `audio.resume()` が呼ばれ AudioContext が起動する。

---

## 4. カメレオン（舌・照準）

クラス: `Chameleon`（`chameleon.js`）

### 4.1 配置

| プロパティ | 値 |
|------------|-----|
| 本体基準 `(x, y)` | `(42, 175)` |
| 首ピボット `(pivotX, pivotY)` | `(56, 163)` |
| 初期角度 | `-Math.PI / 6`（約 −30°） |

### 4.2 舌の状態機械

```
idle → shooting → retracting → swallowing → idle
```

| 状態 | 挙動 |
|------|------|
| `idle` | 舌長 0、口閉じ |
| `shooting` | 毎フレーム `tongueLen += tongueSpeed`、先端座標更新。最大長または画面外で `retracting` |
| `retracting` | `tongueLen -= tongueSpeed * 0.8`。0 で `swallowing`。捕獲中はバグを先端に追従 |
| `swallowing` | 口を閉じる。閉じ完了で捕獲バグを `eaten` にし、`game.js` がスコア処理（同一フレームの `update` 内） |

### 4.3 舌パラメータ（通常）

| パラメータ | 値 |
|------------|-----|
| `tongueMaxLen` | 170 px |
| `tongueSpeed` | 16 px/フレーム |
| 発射開始時の `tongueLen` | 5 |

### 4.4 パワーアップ時の舌（`gold` のみ数値変更）

| パラメータ | 値 |
|------------|-----|
| `tongueMaxLen` | 220 |
| `tongueSpeed` | 22 |

`multi` / `slow` は舌の数値パラメータを変更しない（`multi` は副舌の描画のみ）。

### 4.5 目の追尾

- `active` 状態のバグのうち、ピボットから最も近い個体の方向へ瞳孔を向ける
- 該当なし時は `angle` に追従

### 4.6 被弾演出

- `triggerHurt()`: `flashFrames = 15`（赤フラッシュスキン）

---

## 5. 飛行昆虫（Bug）

クラス: `Bug`（`bugs.js`）。識別子は `type` 文字列。

### 5.1 種類一覧

| `type` | UI 名（index.html） | ベーススコア | 体力変化 | `size` | 色（参考） |
|--------|---------------------|-------------|----------|--------|------------|
| `common` | 普通のハエ | 100 | +15 | 4 | `#a0a0a0` |
| `gnat` | 金の羽虫 | 300 | +25 | 3 | `#ffea00` |
| `firefly` | ホタル | 200 | +15 | 4 | `#00f0ff` |
| `wasp` | 毒ハチ | −200 | −25 | 5 | `#ff3b30` |

体力は 0〜100 の `energy` に加算（上限 100、下限 0）。

### 5.2 移動パターン

| `type` | 更新式（概要） |
|--------|----------------|
| `common` | `x += vx`、`y += sin(time) * 0.8` |
| `gnat` | `x += vx`、`y += vy + cos(time * 2.5) * 2.2` |
| `firefly` | `x += vx`、`y += vy + sin(time) * 1.2`（スポーン時に専用速度） |
| `wasp` | `x += vx`、`y += sin(time * 1.5) * 1.5`、2% で `vx` 再抽選 |

`time` は毎フレーム `+= 0.08`。羽ばたきは `wingFrame` 0/1 を交互表示。

### 5.3 スポーン（`respawn()`）

- 出現辺: 右 60% / 上 40%
- 右から: `x = canvasWidth + 10`、`y` は上端 20〜下端手前 90px の範囲
- 上から: `y = -10`、`x` は 60〜幅−80 の範囲
- 速度は種別・辺に応じて乱数（`gnat` 最速、`wasp` やや遅め）

### 5.4 画面外リサイクル

`x < -15` または `y` が上下境界外 → `respawn()`（状態は `active` に戻る）

### 5.5 出現数・構成

| タイミング | 内容 |
|------------|------|
| ゲーム開始 | `maxBugs = 5`。種別配列 `['common','common','gnat','wasp']` をインデックスで循環 |
| レベルアップ | `level <= 4` かつ `bugs.length < maxBugs + 2`（最大 7 体）のとき 1 体追加。種別は `['common','gnat','firefly'][level % 3]`。**`wasp` は追加されない** |

初期構成では `firefly` は出ない。レベルアップ後に出現しうる。

### 5.6 状態

| `state` | 説明 |
|---------|------|
| `active` | 通常飛行 |
| `caught` | 舌先に吸着（移動更新スキップ） |
| `eaten` | 描画スキップ（直後に `respawn`） |

---

## 6. 当たり判定・捕食

### 6.1 判定タイミング

- `chameleon.tongueState === 'shooting'` かつ未捕獲時
- 舌先 `(tongueTipX, tongueTipY)` と各 `active` バグの中心距離を比較

### 6.2 判定式

```
distance < bug.size * 2.5 + 4
```

最初に満たした 1 体のみキャッチ（`break`）。

### 6.3 捕獲後

1. `bug.state = 'caught'`
2. `tongueState = 'retracting'`
3. 引き戻し完了 → `swallowing` → 処理後 `eaten` → `respawn()` でフィールドに再投入

### 6.4 `multi` パワーアップと当たり

副舌 2 本（角度 ±0.25）は **描画のみ**。当たり判定は **主舌の先端座標のみ**。

---

## 7. スコア・コンボ・レベル

### 7.1 通常捕獲（`wasp` 以外）

1. `fliesEaten++`（表示はゲームオーバー時のみ）
2. `combo++`、`comboTimer = maxComboTime`（150 フレーム）
3. **獲得スコア**: `reward = baseScore * combo`（その時点のコンボ値で乗算）
4. `energy += energyValue`（最大 100）

**例**: 3 連続で `common`（100）を捕獲した場合の加算は 100 + 200 + 300 = 600（コンボ 1, 2, 3 のとき）。

### 7.2 コンボ切れ

- `combo > 0` の間、毎フレーム `comboTimer--`
- `comboTimer <= 0` で `combo = 0`
- 表示は `combo > 1` のとき HUD に `COMBO xN`

### 7.3 毒ハチ（`wasp`）

- `combo = 0`
- `score += scoreValue`（−200、下限 0）
- `energy += energyValue`（−25、下限 0）
- `screenShake = 12`
- `chameleon.triggerHurt()`、`audio.playHurt()`
- 毒ハチ（`wasp`）捕獲時は `fliesEaten` は増えない

### 7.4 レベル

```
level = floor(score / 1200) + 1
```

レベルが上がったとき:

- `levelUpBannerFrames = 80`
- `audio.playPowerup()`
- 条件を満たせばバグ 1 体追加（§5.5）

### 7.5 ハイスコア

- キー: `neo_chameleon_highscore`
- ゲームオーバー時、現在スコアが記録より大きければ保存
- **初回未保存時の表示既定値: 5000**（`parseInt(...) || 5000`）。新規プレイヤーの実スコアとは無関係

---

## 8. 空腹（HUNGER）・ゲームオーバー

### 8.1 空腹メーター

| 項目 | 値 |
|------|-----|
| 初期値 | 100 |
| 毎フレーム減少（`PLAYING`） | `0.06 + (level - 1) * 0.008` |
| 上限 | 100 |

### 8.2 ゲームオーバー条件

`energy <= 0` → `triggerGameOver()`:

- `state = 'GAMEOVER'`
- BGM 停止、`playGameOver()` SFX
- ハイスコア更新（§7.5）

### 8.3 HUD 表示

| 体力 | バー色 |
|------|--------|
| ≥ 60% | 緑 `#39ff14` |
| 30%〜60% | 黄 `#ffea00` |
| < 30% | 赤点滅 + 画面縁ヴィネット（`drawLowHungerWarning`） |

---

## 9. パワーアップ（ホタル起因）

### 9.1 発動条件

`firefly` を **`wasp` 以外と同様に** 通常捕獲したとき `triggerRandomPowerUp()`。

### 9.2 種類（均等ランダム）

| `powerUpType` | HUD 表示名 | 効果 |
|---------------|------------|------|
| `gold` | GOLD TONGUE BUSTER | 舌長 220・速度 22、金色スキン・舌 |
| `multi` | TRIPLE TONGUE BEAST | 虹色スキン、副舌 2 本（当たりなし） |
| `slow` | SLOW-MO FLIES ZONE | バグの `update` をフレームごと 40% 確率のみ実行 |

### 9.3 持続時間

- `powerUpTimeLeft = 480` フレーム（約 8 秒 @ 60fps）
- 0 で `powerUpType = null`、`chameleon.deactivatePowerUp()`
- 発動・レベルアップ時に `audio.playPowerup()`

---

## 10. オーディオ

クラス: `RetroAudio`（`audio.js`）、グローバル `audio`。

### 10.1 マスター

| チャンネル | 最大ゲイン係数 | 既定 UI % |
|------------|----------------|-----------|
| BGM | `MAX_BGM_GAIN = 0.8` | 30% |
| SFX | `MAX_SFX_GAIN = 0.4` | 50% |

実ゲイン = `(percent / 100) * MAX_*_GAIN`

### 10.2 localStorage キー

| キー | 内容 |
|------|------|
| `neo_chameleon_bgm_volume` | BGM 音量 0–100 |
| `neo_chameleon_sfx_volume` | SFX 音量 0–100 |
| `neo_chameleon_highscore` | ハイスコア |

### 10.3 BGM

- 120 BPM、8 分音符ステップのシーケンサ
- ベース（sawtooth）+ リード（square）+ ノイズ（ハット/スネア風）
- `music-toggle` OFF で `stopBGM()`、`PLAYING` 開始時に設定に応じて再開

### 10.4 SFX 一覧

| メソッド | トリガー |
|----------|----------|
| `playShoot()` | 舌発射成功 |
| `playEat()` | 通常捕獲 |
| `playHurt()` | 毒ハチ捕獲 |
| `playPowerup()` | パワーアップ・レベルアップ |
| `playGameOver()` | ゲームオーバー |

---

## 11. UI・永続データ・起動フロー

### 11.1 画面構成（index.html + style.css）

- アーケードキャビネット風レイアウト
- CRT: スキャンライン、ベゼル、カーブ、ヴィネット、起動時静的ノイズ
- Game Boy 風コントロールパネル（D-pad / A / B / SELECT / START）

### 11.2 HUD（`PLAYING`）

| 要素 | 位置・内容 |
|------|------------|
| SCORE / HI-SCORE | 上段左右 |
| LVL | レベル |
| ハエ捕獲数 | ゲームオーバー画面のみ `FLIES CAUGHT: N`（プレイ中 HUD には非表示） |
| COMBO | コンボ 2 以上で表示 |
| パワーアップ名 | 空腹バー上、残り秒数 |
| HUNGER | 画面下部バー |

### 11.3 起動・リトライフロー

```
ページロード → GameEngine 生成 → 静的 400ms → TITLE
TITLE で開始 → PLAYING（スコア等リセット、初期バグスポーン）
GAMEOVER → 操作で resetGame → 静的 300ms → startGame()
```

### 11.4 index.html 凡例との対応

| 凡例 | `type` | ベース点 | 備考 |
|------|--------|----------|------|
| 普通のハエ | `common` | 100 | コンボ乗算あり（§7.1） |
| 金の羽虫 | `gnat` | 300 | 高速 |
| ホタル | `firefly` | 200 | パワーアップ抽選 |
| 毒ハチ | `wasp` | −200 | 体力 −25、コンボリセット |

凡例の点数は **ベーススコア** であり、コンボ倍率は別途適用される。

---

## 12. ファイル責務・拡張時の参照先

| ファイル | 責務 |
|----------|------|
| `index.html` | DOM、モーダル、スクリプト読み込み順 |
| `style.css` | キャビネット・CRT・Game Boy UI・モーダル |
| `game.js` | `GameEngine`：ループ、状態、入力、スコア、当たり、HUD 描画 |
| `chameleon.js` | `Chameleon`：照準、舌状態機械、スプライト描画 |
| `bugs.js` | `Bug`：種別パラメータ、移動、描画 |
| `audio.js` | `RetroAudio`：BGM/SFX、音量永続化 |

### 拡張時のフック例

| 機能 | 推奨編集箇所 |
|------|--------------|
| `PAUSED` 実装 | `game.js` `update`/`draw`、入力で `state` 切替 |
| HELP ボタン | `game.js` `initEventListeners` に `#info-toggle-btn` → `instructions-modal` |
| 新バグ種別 | `bugs.js` `initTypeProperties` / `update` / `draw`、`game.js` スポーン配列・捕食分岐 |
| 新パワーアップ | `game.js` `triggerRandomPowerUp`、`chameleon.js` `activatePowerUp` / 描画 |

---

## 13. 既知の UI とコードの差分

実装を正とし、プレイヤー向け UI との差は以下のとおり。

| 項目 | UI / コメント | コードの実態 |
|------|---------------|--------------|
| スコア表示（凡例） | 固定点数（100, 300 等） | ベース点 × 現在コンボ（§7.1） |
| ゲーム状態 | — | `PAUSED` は未実装 |
| マーキー HELP ボタン | ボタン存在 | **イベント未接続**。操作説明は START |
| `multi` パワーアップ | 「TRIPLE TONGUE」 | 副舌は見た目のみ、当たりは主舌のみ |
| 左右キー | ヘルプは上下のみ記載 | コードも上下のみ（一致） |
| ハイスコア初期表示 | — | 未保存時 **5000** と表示 |

---

## 改訂

- ドキュメント初版: コードベース `neo-chameleon` v1.0.0 時点の静的解析に基づく。
