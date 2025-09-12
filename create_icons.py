#!/usr/bin/env python3
"""
温度センサー表示アプリ用のアイコン生成スクリプト
温度計をモチーフにしたアイコンを生成します
"""

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillowライブラリが必要です。以下のコマンドでインストールしてください：")
    print("pip install Pillow")
    exit(1)

import os
import math

def create_temperature_icon(size, output_path):
    """温度計アイコンを作成"""
    
    # 背景色 - 温かみのあるグラデーション風
    bg_color = (70, 130, 180)  # Steel Blue
    
    # 画像作成
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 角丸四角形の背景
    margin = size // 8
    corner_radius = size // 8
    
    # 背景の角丸四角形を描画
    draw.rounded_rectangle(
        [(margin, margin), (size - margin, size - margin)],
        radius=corner_radius,
        fill=bg_color
    )
    
    # 温度計の設計
    thermo_width = size // 12
    thermo_height = size // 2
    bulb_radius = size // 8
    
    # 温度計の位置計算
    center_x = size // 2
    center_y = size // 2
    
    # 温度計の棒部分
    thermo_left = center_x - thermo_width // 2
    thermo_right = center_x + thermo_width // 2
    thermo_top = center_y - thermo_height // 2
    thermo_bottom = center_y + thermo_height // 4
    
    # 温度計の棒を描画（白色）
    draw.rectangle(
        [(thermo_left, thermo_top), (thermo_right, thermo_bottom)],
        fill='white',
        outline='white'
    )
    
    # 温度計の電球部分を描画（赤色）
    bulb_center_y = thermo_bottom + bulb_radius // 2
    draw.ellipse(
        [(center_x - bulb_radius, bulb_center_y - bulb_radius),
         (center_x + bulb_radius, bulb_center_y + bulb_radius)],
        fill='#FF4444',  # 明るい赤色
        outline='white'
    )
    
    # 温度計内の液体（赤色）
    liquid_width = max(2, thermo_width - 4)  # 最小幅を確保
    liquid_height = max(4, thermo_height // 2)  # 最小高さを確保
    liquid_left = center_x - liquid_width // 2
    liquid_right = center_x + liquid_width // 2
    liquid_top = thermo_bottom - liquid_height
    liquid_bottom = thermo_bottom
    
    # 座標の妥当性チェック
    if liquid_right > liquid_left and liquid_bottom > liquid_top:
        draw.rectangle(
            [(liquid_left, liquid_top), (liquid_right, liquid_bottom)],
            fill='#FF4444'
        )
    
    # 目盛りを描画
    scale_count = 5
    scale_start_x = thermo_right + 2
    scale_end_x = scale_start_x + size // 20
    
    for i in range(scale_count):
        y_pos = thermo_top + (thermo_height * i) // (scale_count - 1)
        draw.line(
            [(scale_start_x, y_pos), (scale_end_x, y_pos)],
            fill='white',
            width=max(1, size // 200)
        )
    
    # 小さなサイズでは温度マーク（℃）を追加
    if size >= 60:
        try:
            # システムフォントを使用
            font_size = max(size // 12, 8)
            # デフォルトフォントを使用
            font = ImageFont.load_default()
            
            # ℃マークを右上に配置
            temp_text = "℃"
            text_x = size - size // 4
            text_y = size // 4
            
            draw.text((text_x, text_y), temp_text, fill='white', font=font)
        except:
            pass  # フォントエラーは無視
    
    # 保存
    img.save(output_path, 'PNG')
    print(f"作成完了: {output_path} ({size}x{size})")

def main():
    """メイン処理"""
    
    # 出力ディレクトリ
    icon_dir = "EtoTHSensorMonitor/Assets.xcassets/AppIcon.appiconset"
    
    if not os.path.exists(icon_dir):
        print(f"アイコンディレクトリが見つかりません: {icon_dir}")
        return
    
    # 必要なアイコンサイズとファイル名のマッピング
    icon_specs = [
        # iPhone
        (40, "icon_40x40 2.png"),      # 20pt@2x
        (60, "icon_60x60 1.png"),      # 20pt@3x
        (58, "icon_58x58 1.png"),      # 29pt@2x
        (87, "icon_87x87.png"),        # 29pt@3x
        (80, "icon_80x80 1.png"),      # 40pt@2x
        (120, "icon_120x120.png"),     # 40pt@3x
        (120, "icon_120x120 1.png"),   # 60pt@2x
        (180, "icon_180x180.png"),     # 60pt@3x
        
        # iPad
        (20, "icon_20x20 1.png"),      # 20pt@1x
        (40, "icon_40x40 1.png"),      # 20pt@2x
        (29, "icon_29x29 1.png"),      # 29pt@1x
        (58, "icon_58x58.png"),        # 29pt@2x
        (80, "icon_80x80.png"),        # 40pt@2x
        (152, "icon_152x152.png"),     # 76pt@2x
        (167, "icon_167x167.png"),     # 83.5pt@2x
        
        # App Store
        (1024, "icon_1024x1024.png"),  # 1024pt@1x
    ]
    
    print("温度センサー表示アプリのアイコンを作成中...")
    print("=" * 50)
    
    # 各サイズのアイコンを作成
    for size, filename in icon_specs:
        output_path = os.path.join(icon_dir, filename)
        create_temperature_icon(size, output_path)
    
    print("=" * 50)
    print("アイコン作成が完了しました！")
    print("Xcodeでプロジェクトを開き直してアイコンを確認してください。")

if __name__ == "__main__":
    main()
