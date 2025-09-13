#!/usr/bin/env python3
"""
App Store用スクリーンショットサイズ修正ツール
既存の画像を App Store の要求サイズに合わせてリサイズします
"""

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillowライブラリが必要です。以下のコマンドでインストールしてください：")
    print("pip install Pillow")
    exit(1)

import os
import sys
import argparse
from pathlib import Path

# App Store要求スクリーンショットサイズ
SCREENSHOT_SIZES = {
    "iPhone_6_7": {
        "portrait": (1290, 2796),
        "landscape": (2796, 1290),
        "description": "iPhone 6.7\" (iPhone 14 Pro Max, 15 Pro Max等)"
    },
    "iPhone_6_5": {
        "portrait": (1242, 2688),
        "landscape": (2688, 1242),
        "description": "iPhone 6.5\" (iPhone Xs Max, 11 Pro Max等)"
    },
    "iPhone_5_5": {
        "portrait": (1242, 2208),
        "landscape": (2208, 1242),
        "description": "iPhone 5.5\" (iPhone 8 Plus等)"
    },
    "iPad_Pro_12_9": {
        "portrait": (2048, 2732),
        "landscape": (2732, 2048),
        "description": "iPad Pro 12.9\""
    }
}

def resize_image_for_app_store(input_path, output_dir, device_type="iPhone_6_7", orientation="portrait"):
    """
    画像をApp Store用サイズにリサイズ
    """
    if device_type not in SCREENSHOT_SIZES:
        raise ValueError(f"サポートされていないデバイスタイプ: {device_type}")
    
    if orientation not in ["portrait", "landscape"]:
        raise ValueError(f"サポートされていない向き: {orientation}")
    
    target_size = SCREENSHOT_SIZES[device_type][orientation]
    
    # 画像を読み込み
    try:
        img = Image.open(input_path)
        print(f"元画像サイズ: {img.size}")
    except Exception as e:
        print(f"画像の読み込みに失敗: {e}")
        return None
    
    # 画像の現在の向きを判定
    current_width, current_height = img.size
    is_landscape = current_width > current_height
    
    # 必要に応じて向きを調整
    if orientation == "landscape" and not is_landscape:
        img = img.rotate(90, expand=True)
        print("画像を90度回転しました")
    elif orientation == "portrait" and is_landscape:
        img = img.rotate(-90, expand=True)
        print("画像を-90度回転しました")
    
    # RGB形式に変換（アルファチャンネルを削除）
    if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
        # 白背景でアルファチャンネルを削除
        background = Image.new('RGB', img.size, (255, 255, 255))
        if img.mode == 'P':
            img = img.convert('RGBA')
        background.paste(img, mask=img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    # アスペクト比を保持してリサイズ
    img.thumbnail(target_size, Image.Resampling.LANCZOS)
    
    # 新しい画像を作成（指定サイズで白背景）
    new_img = Image.new('RGB', target_size, (255, 255, 255))
    
    # 中央に配置
    paste_x = (target_size[0] - img.size[0]) // 2
    paste_y = (target_size[1] - img.size[1]) // 2
    new_img.paste(img, (paste_x, paste_y))
    
    # 出力ファイル名を生成
    input_filename = Path(input_path).stem
    output_filename = f"{input_filename}_{device_type}_{orientation}_{target_size[0]}x{target_size[1]}.png"
    output_path = os.path.join(output_dir, output_filename)
    
    # 保存
    new_img.save(output_path, 'PNG')
    print(f"作成完了: {output_path} ({target_size[0]}x{target_size[1]})")
    
    return output_path

def create_sample_screenshot(size, device_name, output_path):
    """
    サンプルスクリーンショットを作成
    """
    img = Image.new('RGB', size, (70, 130, 180))  # Steel Blue背景
    draw = ImageDraw.Draw(img)
    
    # タイトル
    try:
        # デフォルトフォント使用
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
    except:
        title_font = None
        subtitle_font = None
    
    # タイトルテキスト
    title_text = "温度センサー表示"
    subtitle_text = f"App Store スクリーンショット サンプル\n{device_name}\n{size[0]}x{size[1]}"
    
    # テキストのサイズを取得してセンタリング
    if title_font:
        title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
        title_width = title_bbox[2] - title_bbox[0]
        title_height = title_bbox[3] - title_bbox[1]
        
        subtitle_bbox = draw.textbbox((0, 0), subtitle_text, font=subtitle_font)
        subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
        subtitle_height = subtitle_bbox[3] - subtitle_bbox[1]
        
        # テキストを中央に配置
        title_x = (size[0] - title_width) // 2
        title_y = (size[1] - title_height) // 2 - 50
        
        subtitle_x = (size[0] - subtitle_width) // 2
        subtitle_y = title_y + title_height + 20
        
        # テキストを描画
        draw.text((title_x, title_y), title_text, fill='white', font=title_font)
        draw.text((subtitle_x, subtitle_y), subtitle_text, fill='white', font=subtitle_font)
    
    # 温度計アイコンを中央に描画
    center_x = size[0] // 2
    center_y = size[1] // 2
    icon_size = min(size[0], size[1]) // 8
    
    # 温度計の描画
    thermo_width = icon_size // 6
    thermo_height = icon_size
    bulb_radius = icon_size // 4
    
    thermo_left = center_x - thermo_width // 2
    thermo_right = center_x + thermo_width // 2
    thermo_top = center_y - thermo_height // 2 + 100
    thermo_bottom = center_y + thermo_height // 4 + 100
    
    # 温度計本体
    draw.rectangle([(thermo_left, thermo_top), (thermo_right, thermo_bottom)], fill='white', outline='white')
    
    # 温度計の球部分
    bulb_center_y = thermo_bottom + bulb_radius // 2
    draw.ellipse([(center_x - bulb_radius, bulb_center_y - bulb_radius),
                  (center_x + bulb_radius, bulb_center_y + bulb_radius)], 
                 fill='#FF4444', outline='white')
    
    # 保存
    img.save(output_path, 'PNG')
    print(f"サンプルスクリーンショット作成: {output_path}")

def main():
    parser = argparse.ArgumentParser(
        description='App Store用スクリーンショットサイズ修正ツール',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
利用可能なデバイスタイプ:
{chr(10).join([f"  {device}: {info['description']}" for device, info in SCREENSHOT_SIZES.items()])}

使用例:
  # 全デバイス・全向きで生成
  python3 create_screenshots.py screenshot.png
  
  # iPhone 6.7"のみ生成
  python3 create_screenshots.py screenshot.png --device iPhone_6_7
  
  # ポートレートのみ生成
  python3 create_screenshots.py screenshot.png --orientation portrait
  
  # iPhone 6.7"のポートレートのみ生成
  python3 create_screenshots.py screenshot.png --device iPhone_6_7 --orientation portrait
  
  # サンプル画像生成
  python3 create_screenshots.py --sample
  
  # 特定デバイスのサンプル生成
  python3 create_screenshots.py --sample --device iPhone_6_7
        """
    )
    
    parser.add_argument('input_file', nargs='?', help='変換する画像ファイル')
    parser.add_argument('--sample', action='store_true', help='サンプル画像を生成')
    parser.add_argument('--device', '-d', choices=list(SCREENSHOT_SIZES.keys()), 
                       help='特定のデバイスのみ生成')
    parser.add_argument('--orientation', '-o', choices=['portrait', 'landscape'], 
                       help='特定の向きのみ生成')
    parser.add_argument('--output-dir', default='app_store_screenshots', 
                       help='出力ディレクトリ (デフォルト: app_store_screenshots)')
    
    args = parser.parse_args()
    
    print("App Store用スクリーンショットツール")
    print("=" * 50)
    
    # 出力ディレクトリを作成
    os.makedirs(args.output_dir, exist_ok=True)
    
    # 対象デバイスと向きを決定
    target_devices = [args.device] if args.device else list(SCREENSHOT_SIZES.keys())
    target_orientations = [args.orientation] if args.orientation else ['portrait', 'landscape']
    
    # サンプル画像生成モード
    if args.sample:
        print("サンプルスクリーンショットを生成中...")
        if args.device:
            print(f"対象デバイス: {args.device} ({SCREENSHOT_SIZES[args.device]['description']})")
        if args.orientation:
            print(f"対象向き: {args.orientation}")
            
        for device_type in target_devices:
            sizes = SCREENSHOT_SIZES[device_type]
            for orientation in target_orientations:
                size = sizes[orientation]
                filename = f"sample_{device_type}_{orientation}_{size[0]}x{size[1]}.png"
                output_path = os.path.join(args.output_dir, filename)
                create_sample_screenshot(size, sizes["description"], output_path)
        return
    
    # 画像ファイルが指定されていない場合
    if not args.input_file:
        parser.print_help()
        return
    
    # 画像ファイルの存在確認
    if not os.path.exists(args.input_file):
        print(f"エラー: ファイルが見つかりません: {args.input_file}")
        return
    
    print(f"画像を処理中: {args.input_file}")
    if args.device:
        print(f"対象デバイス: {args.device} ({SCREENSHOT_SIZES[args.device]['description']})")
    if args.orientation:
        print(f"対象向き: {args.orientation}")
    
    print()
    
    # 画像変換処理
    success_count = 0
    error_count = 0
    
    for device_type in target_devices:
        for orientation in target_orientations:
            try:
                output_path = resize_image_for_app_store(args.input_file, args.output_dir, device_type, orientation)
                if output_path:
                    success_count += 1
                else:
                    error_count += 1
            except Exception as e:
                print(f"エラー: {device_type} {orientation} - {e}")
                error_count += 1
    
    print()
    print(f"処理完了: 成功 {success_count}件, エラー {error_count}件")
    if success_count > 0:
        print(f"出力先: {args.output_dir}/")

if __name__ == "__main__":
    main()