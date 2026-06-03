# NEO CHAMELEON

8-bit レトロシンセ風のブラウザアーケードゲーム。左下のカメレオンが舌を伸ばし、画面上を飛ぶ昆虫を捕まえてスコアを稼ぐ。空腹（HUNGER）が尽きる前に生き延びよう。

## 必要環境

- モダンブラウザ（Canvas 2D・Web Audio API・localStorage 対応）
- Node.js（開発用ローカルサーバーのみ。ゲーム本体はビルド不要）

## 起動方法

```bash
npm install
npm run dev
```

ブラウザで [http://localhost:3000](http://localhost:3000) を開く。

`index.html` を直接開くことも可能だが、一部ブラウザでは AudioContext の制限があるため、開発時は `http-server` の利用を推奨する。

## 操作（概要）

| 入力 | 動作 |
|------|------|
| ↑↓ / W S | 照準角度 |
| マウス（キャンバス上） | 照準 |
| Space / クリック / A・B | 舌を伸ばす |
| MENU | 設定 |
| HELP（画面上部） | 操作説明 |

昆虫の種類・点数・パワーアップの詳細はゲーム内ヘルプ（HELP）または仕様書を参照。

## ファイル構成

| ファイル | 説明 |
|----------|------|
| `index.html` | ページ構造・キャンバス・モーダル |
| `style.css` | アーケードキャビネット / CRT / Game Boy UI |
| `game.js` | ゲームエンジン・ループ・スコア・HUD |
| `chameleon.js` | カメレオン・舌・照準 |
| `bugs.js` | 飛行昆虫（4 種） |
| `audio.js` | BGM / SFX（Web Audio 合成） |
| `docs/SPEC.md` | **詳細仕様書（コード準拠）** |

## 詳細仕様

ゲームロジック・数値・状態遷移・既知の UI 差分は次を参照:

**[docs/SPEC.md](docs/SPEC.md)**

## ライセンス

リポジトリのライセンス表記に従う（未記載の場合はプロジェクトオーナーに確認）。
