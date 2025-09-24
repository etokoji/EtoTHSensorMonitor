#!/usr/bin/env python3
"""
Web distribution icon generator
Creates 57x57 and 512x512 icons from 1024x1024 source images
"""

import os
import sys
from PIL import Image
import argparse

def create_web_icons(source_path, output_dir):
    """
    Create web distribution icons from source image
    
    Args:
        source_path (str): Path to the source 1024x1024 image
        output_dir (str): Directory to save the generated icons
    """
    try:
        # Open the source image
        with Image.open(source_path) as img:
            # Verify it's 1024x1024
            if img.size != (1024, 1024):
                print(f"Warning: Source image {source_path} is {img.size}, expected (1024, 1024)")
            
            # Convert to RGBA if needed
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Get base filename without extension
            base_name = os.path.splitext(os.path.basename(source_path))[0]
            
            # Create output directory if it doesn't exist
            os.makedirs(output_dir, exist_ok=True)
            
            # Generate 57x57 icon
            icon_57 = img.resize((57, 57), Image.Resampling.LANCZOS)
            output_57_path = os.path.join(output_dir, f"{base_name}_57x57.png")
            icon_57.save(output_57_path, "PNG", optimize=True)
            print(f"Created: {output_57_path}")
            
            # Generate 512x512 icon
            icon_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
            output_512_path = os.path.join(output_dir, f"{base_name}_512x512.png")
            icon_512.save(output_512_path, "PNG", optimize=True)
            print(f"Created: {output_512_path}")
            
    except Exception as e:
        print(f"Error processing {source_path}: {e}")
        return False
    
    return True

def main():
    parser = argparse.ArgumentParser(description="Generate web distribution icons from 1024x1024 source images")
    parser.add_argument("--source-dir", default="app_icons", help="Source directory containing 1024x1024 images")
    parser.add_argument("--output-dir", default="web_icons", help="Output directory for generated icons")
    
    args = parser.parse_args()
    
    source_dir = args.source_dir
    output_dir = args.output_dir
    
    if not os.path.exists(source_dir):
        print(f"Error: Source directory '{source_dir}' does not exist")
        sys.exit(1)
    
    # Find all 1024x1024 images in the source directory
    source_images = []
    for filename in os.listdir(source_dir):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            filepath = os.path.join(source_dir, filename)
            try:
                with Image.open(filepath) as img:
                    if img.size == (1024, 1024):
                        source_images.append(filepath)
            except Exception:
                continue
    
    if not source_images:
        print(f"No 1024x1024 images found in '{source_dir}'")
        sys.exit(1)
    
    print(f"Found {len(source_images)} 1024x1024 image(s):")
    for img_path in source_images:
        print(f"  - {os.path.basename(img_path)}")
    
    print(f"\nGenerating web icons (57x57 and 512x512) in '{output_dir}'...")
    
    success_count = 0
    for source_path in source_images:
        if create_web_icons(source_path, output_dir):
            success_count += 1
    
    print(f"\nCompleted: {success_count}/{len(source_images)} images processed successfully")

if __name__ == "__main__":
    main()