#!/usr/bin/env python3
"""
Build script for creating the WallPimp Windows executable
Handles creating the icon and building the executable with PyInstaller
"""
import os
import sys
import shutil
import subprocess
from pathlib import Path

def create_icon():
    """
    Create a custom icon for the executable.
    Falls back to default icon if ImageMagick is not available.
    """
    svg_content = '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
    <rect width="64" height="64" fill="#2d2d2d"/>
    <text x="32" y="42" 
          font-family="Arial" 
          font-size="40" 
          fill="#ffffff" 
          text-anchor="middle">
        WP
    </text>
</svg>
'''
    
    # Save SVG file
    with open('icon.svg', 'w') as f:
        f.write(svg_content)
    
    # Convert to ICO if ImageMagick is available
    try:
        subprocess.run(['convert', 'icon.svg', 'icon.ico'], check=True)
        os.remove('icon.svg')
        return True
    except Exception:
        print("Note: ImageMagick not found. Using default icon.")
        return False

def create_spec_file():
    """
    Create the PyInstaller spec file with optimal settings.
    """
    spec_content = '''# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['wallpimp'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='wallpimp',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='icon.ico' if os.path.exists('icon.ico') else None,
)
'''
    with open('wallpimp.spec', 'w') as f:
        f.write(spec_content)

def build_executable():
    """
    Build the Windows executable using PyInstaller.
    """
    try:
        # Install PyInstaller if not already installed
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'pyinstaller'], check=True)
        
        # Create spec file and icon
        create_spec_file()
        create_icon()
        
        # Build the executable
        subprocess.run(['pyinstaller', 'wallpimp.spec'], check=True)
        
        # Clean up temporary files
        cleanup_files = ['wallpimp.spec', 'icon.svg']
        for file in cleanup_files:
            if os.path.exists(file):
                os.remove(file)
        
        if os.path.exists('build'):
            shutil.rmtree('build')
            
        print("\nBuild complete! The executable is in the 'dist' folder.")
        
    except Exception as e:
        print(f"Error during build: {str(e)}")
        sys.exit(1)

def main():
    """Main build process."""
    print("Building WallPimp executable...")
    build_executable()

if __name__ == "__main__":
    main()
