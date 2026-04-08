# Widget Extension セットアップ手順

`EtoTHSensorWidget/EtoTHSensorWidget.swift` のソースコードは作成済みです。
以下の手順でXcodeにWidget Extensionターゲットを追加してください。

## 1. Widget Extension ターゲットの追加

1. Xcodeでプロジェクトを開く
2. メニュー: **File → New → Target...**
3. **Widget Extension** を選択 → Next
4. 設定:
   - Product Name: `EtoTHSensorWidget`
   - Team: `PGMR9WGF47`（または既存のチームを選択）
   - Bundle Identifier: `com.etokoji.EtoTHSensorMonitor.EtoTHSensorWidget`
   - Include Configuration App Intent: **チェックを外す**
5. Finish → **Activate** をクリック

## 2. 自動生成ファイルを置き換え

Xcodeが `EtoTHSensorWidget/` フォルダを作成します。
その中の自動生成された `.swift` ファイルを削除し、代わりに以下のファイルを追加:

- `EtoTHSensorWidget/EtoTHSensorWidget.swift`（本リポジトリに含まれているファイル）

## 3. App Group の設定（両ターゲット共通）

### メインアプリ (EtoTHSensorMonitor)
1. ターゲット **EtoTHSensorMonitor** を選択
2. **Signing & Capabilities** タブ
3. **+ Capability** → **App Groups** を追加
4. **+** ボタンで App Group を追加:
   - `group.com.etokoji.EtoTHSensorMonitor`

### Widget Extension (EtoTHSensorWidget)
1. ターゲット **EtoTHSensorWidget** を選択
2. 同様に **App Groups** を追加
3. 同じ App Group ID を選択:
   - `group.com.etokoji.EtoTHSensorMonitor`

## 4. SensorData を Widget と共有する

`EtoTHSensorMonitor/Models/SensorData.swift` を Widget ターゲットのメンバーにも追加:

1. プロジェクトナビゲーターで `SensorData.swift` を選択
2. **File Inspector** (右パネル) → **Target Membership**
3. **EtoTHSensorWidget** にチェックを追加

## 5. ビルドと確認

```bash
xcodebuild -scheme EtoTHSensorMonitor -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Widget の動作フロー

```
ESP32 (BLE) → BluetoothService → SensorViewModel
  → SharedDataManager.writeLatestReading()
    → App Group UserDefaults に保存
    → WidgetCenter.reloadAllTimelines() を呼び出し
      → EtoTHSensorWidget がデータを読み取り表示
```

## サポートするウィジェットサイズ

| サイズ | 表示内容 |
|--------|----------|
| Small (2×2) | 温度・湿度・最終更新時刻 |
| Medium (4×2) | 温度・湿度・気圧・電圧・時刻 |
| Large (4×4) | 全データをカード形式で表示 |
| Lock Screen Circular | 温度（数値のみ） |
| Lock Screen Rectangular | デバイスID・温度・湿度 |
| Lock Screen Inline | 温度 / 湿度 |
