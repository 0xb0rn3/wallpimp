#!/usr/bin/env python3
"""
WallPimp Enhanced - Universal Linux Wallpaper Manager with Slideshow
A comprehensive wallpaper downloader and slideshow manager for all Linux desktop environments
"""

import os
import sys
import json
import argparse
import logging
import subprocess
import time
import signal
import threading
import random
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed

# Core dependencies - mapping import names to package specifications
REQUIRED_DEPS = {
    'requests': 'requests>=2.25.0',
    'tqdm': 'tqdm>=4.60.0', 
    'PIL': 'Pillow>=8.0.0',  # Note: PIL is the import name for Pillow
    'colorama': 'colorama>=0.4.4'
}

def check_and_install_dependencies():
    """Check for required dependencies and install if missing using multiple strategies"""
    missing_deps = []
    
    # Check each dependency by trying to import it
    for import_name, package_spec in REQUIRED_DEPS.items():
        try:
            __import__(import_name)
            print(f"✓ {import_name} is available")
        except ImportError:
            print(f"✗ {import_name} is missing")
            missing_deps.append(package_spec)
    
    if missing_deps:
        print("\nInstalling missing dependencies...")
        
        # Try multiple installation strategies in order of preference
        installation_methods = [
            # Strategy 1: Try pip with --break-system-packages (for newer Python on Arch/modern distros)
            lambda dep: subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--break-system-packages', dep]),
            # Strategy 2: Try regular pip installation
            lambda dep: subprocess.check_call([sys.executable, '-m', 'pip', 'install', dep]),
            # Strategy 3: Try pip3 directly
            lambda dep: subprocess.check_call(['pip3', 'install', '--break-system-packages', dep]),
            # Strategy 4: Try pip3 without break-system-packages
            lambda dep: subprocess.check_call(['pip3', 'install', dep]),
        ]
        
        for dep in missing_deps:
            installed = False
            
            for i, install_method in enumerate(installation_methods):
                try:
                    install_method(dep)
                    print(f"✓ Installed {dep} using method {i+1}")
                    installed = True
                    break
                except (subprocess.CalledProcessError, FileNotFoundError):
                    continue
            
            if not installed:
                print(f"✗ Failed to install {dep} with all methods")
                print("\nManual installation required:")
                print("Please install dependencies manually using your system package manager:")
                print("\nFor Arch Linux:")
                print("  sudo pacman -S python-requests python-tqdm python-pillow python-colorama")
                print("\nFor Ubuntu/Debian:")
                print("  sudo apt install python3-requests python3-tqdm python3-pil python3-colorama")
                print("\nFor Fedora:")
                print("  sudo dnf install python3-requests python3-tqdm python3-pillow python3-colorama")
                sys.exit(1)
        
        print("All dependencies installed successfully!\n")
    else:
        print("All dependencies are already available!\n")

# Install dependencies before importing them
check_and_install_dependencies()

# Now we can safely import the required modules
import requests
from tqdm import tqdm
from PIL import Image
from colorama import init, Fore, Style

# Initialize colorama for cross-platform colored output
init(autoreset=True)

class DesktopEnvironmentManager:
    """Universal desktop environment manager for Linux systems"""
    
    @staticmethod
    def detect_desktop_environment():
        """Detect the current desktop environment"""
        # Check common environment variables
        desktop_session = os.environ.get('DESKTOP_SESSION', '').lower()
        xdg_current_desktop = os.environ.get('XDG_CURRENT_DESKTOP', '').lower()
        gdmsession = os.environ.get('GDMSESSION', '').lower()
        
        # Map environment variables to DE names
        de_mappings = {
            'gnome': 'gnome',
            'kde': 'kde',
            'plasma': 'kde',
            'xfce': 'xfce',
            'lxde': 'lxde',
            'lxqt': 'lxqt',
            'mate': 'mate',
            'cinnamon': 'cinnamon',
            'i3': 'i3',
            'sway': 'sway',
            'bspwm': 'bspwm',
            'openbox': 'openbox',
            'fluxbox': 'fluxbox',
            'dwm': 'dwm',
            'awesome': 'awesome',
            'qtile': 'qtile'
        }
        
        # Check all environment variables
        for env_var in [desktop_session, xdg_current_desktop, gdmsession]:
            for de_key, de_name in de_mappings.items():
                if de_key in env_var:
                    return de_name
        
        # Fallback: check running processes
        try:
            processes = subprocess.check_output(['ps', 'aux'], universal_newlines=True)
            for de_key, de_name in de_mappings.items():
                if de_key in processes.lower():
                    return de_name
        except subprocess.CalledProcessError:
            pass
        
        return 'unknown'
    
    @staticmethod
    def set_wallpaper(image_path: str, desktop_env: str = None) -> bool:
        """Set wallpaper for the detected desktop environment"""
        if not desktop_env:
            desktop_env = DesktopEnvironmentManager.detect_desktop_environment()
        
        image_path = os.path.abspath(image_path)
        
        # Desktop environment specific commands
        wallpaper_commands = {
            'gnome': [
                ['gsettings', 'set', 'org.gnome.desktop.background', 'picture-uri', f'file://{image_path}'],
                ['gsettings', 'set', 'org.gnome.desktop.background', 'picture-uri-dark', f'file://{image_path}']
            ],
            'kde': [
                ['qdbus', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.evaluateScript', 
                 f'''
                 var allDesktops = desktops();
                 for (i=0;i<allDesktops.length;i++) {{
                     d = allDesktops[i];
                     d.wallpaperPlugin = "org.kde.image";
                     d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
                     d.writeConfig("Image", "file://{image_path}");
                 }}
                 ''']
            ],
            'xfce': [
                ['xfconf-query', '-c', 'xfce4-desktop', '-p', '/backdrop/screen0/monitor0/workspace0/last-image', '-s', image_path]
            ],
            'lxde': [
                ['pcmanfm', '--set-wallpaper', image_path]
            ],
            'lxqt': [
                ['pcmanfm-qt', '--set-wallpaper', image_path]
            ],
            'mate': [
                ['gsettings', 'set', 'org.mate.background', 'picture-filename', image_path]
            ],
            'cinnamon': [
                ['gsettings', 'set', 'org.cinnamon.desktop.background', 'picture-uri', f'file://{image_path}']
            ],
            'i3': [
                ['feh', '--bg-fill', image_path]
            ],
            'sway': [
                ['swaymsg', 'output', '*', 'bg', image_path, 'fill']
            ],
            'bspwm': [
                ['feh', '--bg-fill', image_path]
            ],
            'openbox': [
                ['feh', '--bg-fill', image_path]
            ],
            'fluxbox': [
                ['feh', '--bg-fill', image_path]
            ],
            'dwm': [
                ['feh', '--bg-fill', image_path]
            ],
            'awesome': [
                ['feh', '--bg-fill', image_path]
            ],
            'qtile': [
                ['feh', '--bg-fill', image_path]
            ]
        }
        
        # Get commands for the desktop environment
        commands = wallpaper_commands.get(desktop_env, [['feh', '--bg-fill', image_path]])
        
        # Execute all commands for the desktop environment
        for command in commands:
            try:
                subprocess.run(command, check=True, capture_output=True)
                return True
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
        
        # Fallback methods
        fallback_commands = [
            ['feh', '--bg-fill', image_path],
            ['nitrogen', '--set-zoom-fill', image_path],
            ['hsetroot', '-fill', image_path]
        ]
        
        for command in fallback_commands:
            try:
                subprocess.run(command, check=True, capture_output=True)
                return True
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
        
        return False

class SlideshowManager:
    """Manages wallpaper slideshow functionality"""
    
    def __init__(self, wallpaper_dir: str, interval_seconds: int, desktop_env: str = None):
        self.wallpaper_dir = Path(wallpaper_dir)
        self.interval_seconds = interval_seconds
        self.desktop_env = desktop_env or DesktopEnvironmentManager.detect_desktop_environment()
        self.running = False
        self.thread = None
        self.image_files = []
        self.current_index = 0
        
        # Load image files
        self._load_image_files()
    
    def _load_image_files(self):
        """Load all image files from the wallpaper directory"""
        image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'}
        
        self.image_files = []
        for ext in image_extensions:
            self.image_files.extend(self.wallpaper_dir.glob(f'*{ext}'))
            self.image_files.extend(self.wallpaper_dir.glob(f'*{ext.upper()}'))
        
        # Shuffle the list for variety
        random.shuffle(self.image_files)
        
        if not self.image_files:
            raise ValueError(f"No image files found in {self.wallpaper_dir}")
    
    def start_slideshow(self):
        """Start the wallpaper slideshow"""
        if self.running:
            return
        
        self.running = True
        self.thread = threading.Thread(target=self._slideshow_loop, daemon=True)
        self.thread.start()
        print(f"{Fore.GREEN}Slideshow started! Changing wallpaper every {self._format_interval()}{Style.RESET_ALL}")
    
    def stop_slideshow(self):
        """Stop the wallpaper slideshow"""
        self.running = False
        if self.thread:
            self.thread.join(timeout=1)
        print(f"{Fore.YELLOW}Slideshow stopped{Style.RESET_ALL}")
    
    def _slideshow_loop(self):
        """Main slideshow loop"""
        while self.running:
            if self.image_files:
                current_image = self.image_files[self.current_index]
                
                if DesktopEnvironmentManager.set_wallpaper(str(current_image), self.desktop_env):
                    print(f"{Fore.CYAN}Changed wallpaper to: {current_image.name}{Style.RESET_ALL}")
                else:
                    print(f"{Fore.RED}Failed to set wallpaper: {current_image.name}{Style.RESET_ALL}")
                
                # Move to next image
                self.current_index = (self.current_index + 1) % len(self.image_files)
            
            # Wait for the specified interval
            time.sleep(self.interval_seconds)
    
    def set_static_wallpaper(self, image_path: str = None):
        """Set a static wallpaper (random if none specified)"""
        if image_path:
            target_image = Path(image_path)
        else:
            if not self.image_files:
                raise ValueError("No image files available")
            target_image = random.choice(self.image_files)
        
        if DesktopEnvironmentManager.set_wallpaper(str(target_image), self.desktop_env):
            print(f"{Fore.GREEN}Set static wallpaper: {target_image.name}{Style.RESET_ALL}")
            return True
        else:
            print(f"{Fore.RED}Failed to set wallpaper: {target_image.name}{Style.RESET_ALL}")
            return False
    
    def _format_interval(self) -> str:
        """Format interval seconds to human readable format"""
        if self.interval_seconds < 60:
            return f"{self.interval_seconds}s"
        elif self.interval_seconds < 3600:
            minutes = self.interval_seconds // 60
            seconds = self.interval_seconds % 60
            if seconds:
                return f"{minutes}m {seconds}s"
            return f"{minutes}m"
        else:
            hours = self.interval_seconds // 3600
            remaining = self.interval_seconds % 3600
            minutes = remaining // 60
            seconds = remaining % 60
            
            result = f"{hours}h"
            if minutes:
                result += f" {minutes}m"
            if seconds:
                result += f" {seconds}s"
            return result

class AutostartManager:
    """Manages autostart functionality for the slideshow"""
    
    @staticmethod
    def create_autostart_entry(script_path: str, wallpaper_dir: str, interval: str, mode: str = 'slideshow'):
        """Create autostart entry for the slideshow"""
        autostart_dir = Path.home() / '.config' / 'autostart'
        autostart_dir.mkdir(parents=True, exist_ok=True)
        
        desktop_file = autostart_dir / 'wallpimp-slideshow.desktop'
        
        # Create the command based on mode
        if mode == 'slideshow':
            command = f'python3 {script_path} --slideshow --dir "{wallpaper_dir}" --interval {interval}'
        else:
            command = f'python3 {script_path} --static --dir "{wallpaper_dir}"'
        
        desktop_content = f"""[Desktop Entry]
Type=Application
Name=WallPimp Slideshow
Comment=Automatic wallpaper slideshow
Exec={command}
Icon=preferences-desktop-wallpaper
StartupNotify=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
"""
        
        with open(desktop_file, 'w') as f:
            f.write(desktop_content)
        
        # Make it executable
        desktop_file.chmod(0o755)
        
        print(f"{Fore.GREEN}Autostart entry created: {desktop_file}{Style.RESET_ALL}")
        return str(desktop_file)
    
    @staticmethod
    def remove_autostart_entry():
        """Remove autostart entry"""
        desktop_file = Path.home() / '.config' / 'autostart' / 'wallpimp-slideshow.desktop'
        
        if desktop_file.exists():
            desktop_file.unlink()
            print(f"{Fore.YELLOW}Autostart entry removed{Style.RESET_ALL}")
            return True
        else:
            print(f"{Fore.YELLOW}No autostart entry found{Style.RESET_ALL}")
            return False

class WallPimp:
    """Enhanced WallPimp class with slideshow functionality"""
    
    # Curated repository collection - each entry contains icon, URL, branch, and description
    REPOSITORIES = {
        'minimalist': {
            'icon': '🖼️',
            'url': 'https://github.com/dharmx/walls',
            'branch': 'main',
            'description': 'Clean minimalist designs'
        },
        'anime': {
            'icon': '🌸',
            'url': 'https://github.com/HENTAI-CODER/Anime-Wallpaper',
            'branch': 'main',
            'description': 'Anime & manga artwork'
        },
        'nature': {
            'icon': '🌿',
            'url': 'https://github.com/FrenzyExists/wallpapers',
            'branch': 'main',
            'description': 'Nature landscapes'
        },
        'scenic': {
            'icon': '🏞️',
            'url': 'https://github.com/michaelScopic/Wallpapers',
            'branch': 'main',
            'description': 'Scenic vistas'
        },
        'artistic': {
            'icon': '🎨',
            'url': 'https://github.com/D3Ext/aesthetic-wallpapers',
            'branch': 'main',
            'description': 'Artistic styles'
        },
        'anime_pack': {
            'icon': '🎎',
            'url': 'https://github.com/Dreamer-Paul/Anime-Wallpaper',
            'branch': 'main',
            'description': 'Curated anime art'
        },
        'linux': {
            'icon': '🐧',
            'url': 'https://github.com/polluxau/linuxnext-wallpapers',
            'branch': 'main',
            'description': 'Linux desktop art'
        },
        'mixed': {
            'icon': '🌟',
            'url': 'https://github.com/makccr/wallpapers',
            'branch': 'main',
            'description': 'Diverse styles'
        },
        'desktop': {
            'icon': '💻',
            'url': 'https://github.com/port19x/Wallpapers',
            'branch': 'main',
            'description': 'Minimalist desktop'
        },
        'gaming': {
            'icon': '🎮',
            'url': 'https://github.com/ryan4yin/wallpapers',
            'branch': 'main',
            'description': 'Gaming-inspired art'
        },
        'photos': {
            'icon': '📷',
            'url': 'https://github.com/linuxdotexe/wallpapers',
            'branch': 'main',
            'description': 'Professional photography'
        },
        'digital': {
            'icon': '🖥️',
            'url': 'https://github.com/0xb0rn3/wallpapers',
            'branch': 'main',
            'description': 'Digital creations'
        }
    }
    
    def __init__(self, download_dir: str = None):
        """Initialize WallPimp with configuration"""
        self.download_dir = Path(download_dir) if download_dir else self._get_default_download_dir()
        
        # Create download directory first - this fixes the original bug
        self.download_dir.mkdir(parents=True, exist_ok=True)
        
        # Now we can safely setup logging since the directory exists
        self._setup_logging()
        
        # Setup HTTP session with proper headers
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'WallPimp-Wallpaper-Manager (https://github.com/wallpimp/wallpimp)'
        })
        
        # Load cache for tracking downloaded files
        self.cache_file = self.download_dir / '.wallpimp_cache.json'
        self.cache = self._load_cache()
        
        # Statistics tracking
        self.stats = {
            'downloaded': 0,
            'skipped': 0,
            'failed': 0,
            'total_size': 0
        }
        
        # Desktop environment detection
        self.desktop_env = DesktopEnvironmentManager.detect_desktop_environment()
    
    def _get_default_download_dir(self) -> Path:
        """Get default download directory based on operating system"""
        return Path.home() / 'Pictures' / 'WallPimp'
    
    def _setup_logging(self):
        """Setup logging configuration - called after directory creation"""
        log_file = self.download_dir / 'wallpimp.log'
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _load_cache(self) -> Dict:
        """Load cache from file to track what we've already downloaded"""
        if self.cache_file.exists():
            try:
                with open(self.cache_file, 'r') as f:
                    cache_data = json.load(f)
                    # Convert downloaded_files back to set if it exists
                    if 'downloaded_files' in cache_data and isinstance(cache_data['downloaded_files'], list):
                        cache_data['downloaded_files'] = set(cache_data['downloaded_files'])
                    return cache_data
            except (json.JSONDecodeError, IOError):
                self.logger.warning("Cache file corrupted, starting fresh")
        return {'downloaded_files': set()}
    
    def _save_cache(self):
        """Save cache to file for persistence between runs"""
        # Convert set to list for JSON serialization
        cache_copy = self.cache.copy()
        cache_copy['downloaded_files'] = list(cache_copy['downloaded_files'])
        
        try:
            with open(self.cache_file, 'w') as f:
                json.dump(cache_copy, f, indent=2)
        except IOError as e:
            self.logger.error(f"Failed to save cache: {e}")
    
    def show_banner(self):
        """Display the WallPimp banner with basic info"""
        banner = f"""
{Fore.CYAN}██╗    ██╗ █████╗ ██╗     ██╗     ██████╗ ██╗███╗   ███╗██████╗ 
██║    ██║██╔══██╗██║     ██║     ██╔══██╗██║████╗ ████║██╔══██╗
██║ █╗ ██║███████║██║     ██║     ██████╔╝██║██╔████╔██║██████╔╝
██║███╗██║██╔══██║██║     ██║     ██╔═══╝ ██║██║╚██╔╝██║██╔═══╝ 
╚███╔███╔╝██║  ██║███████╗███████╗██║     ██║██║ ╚═╝ ██║██║     
 ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚═╝     ╚═╝╚═╝     {Style.RESET_ALL}
                                                                  
{Fore.YELLOW}Enhanced - Universal Linux Wallpaper Manager with Slideshow{Style.RESET_ALL}
{Fore.GREEN}Download Directory: {self.download_dir}{Style.RESET_ALL}
{Fore.BLUE}Desktop Environment: {self.desktop_env.upper()}{Style.RESET_ALL}
"""
        print(banner)
    
    def list_repositories(self):
        """Display all available curated repositories in an organized format"""
        print(f"\n{Fore.CYAN}Available Curated Repositories:{Style.RESET_ALL}")
        print("-" * 60)
        
        # Display each repository with its icon, name, and description
        for repo_key, repo_info in self.REPOSITORIES.items():
            print(f"{repo_info['icon']} {Fore.YELLOW}{repo_key.upper():<12}{Style.RESET_ALL} - {repo_info['description']}")
        
        print(f"\n{Fore.GREEN}Total repositories: {len(self.REPOSITORIES)}{Style.RESET_ALL}")
        print(f"{Fore.CYAN}Use --repo <name> to download from a specific repository{Style.RESET_ALL}")
        print(f"{Fore.CYAN}Use --url <github-url> to download from any GitHub repository{Style.RESET_ALL}")
    
    def get_github_api_url(self, repo_url: str, branch: str = "main") -> str:
        """Convert GitHub repo URL to API URL for file listing"""
        # Parse the GitHub URL to extract owner and repo name
        parsed = urlparse(repo_url)
        path_parts = parsed.path.strip('/').split('/')
        
        if len(path_parts) >= 2:
            owner, repo = path_parts[0], path_parts[1]
            return f"https://api.github.com/repos/{owner}/{repo}/contents?ref={branch}"
        else:
            raise ValueError(f"Invalid GitHub URL format: {repo_url}")
    
    def fetch_repo_contents(self, repo_url: str, branch: str = "main") -> List[Dict]:
        """Fetch contents of a GitHub repository recursively"""
        try:
            api_url = self.get_github_api_url(repo_url, branch)
            return self._fetch_contents_recursive(api_url, repo_url)
        except Exception as e:
            self.logger.error(f"Failed to fetch contents for {repo_url}: {e}")
            return []
    
    def _fetch_contents_recursive(self, api_url: str, repo_url: str, path: str = "") -> List[Dict]:
        """Recursively fetch all image files from a GitHub repository"""
        contents = []
        
        try:
            response = self.session.get(api_url, timeout=30)
            response.raise_for_status()
            
            items = response.json()
            if not isinstance(items, list):
                return contents
            
            for item in items:
                if item['type'] == 'file':
                    # Check if it's an image file
                    if self._is_image_file(item['name']):
                        contents.append({
                            'name': item['name'],
                            'download_url': item['download_url'],
                            'size': item['size'],
                            'path': path + item['name'] if path else item['name'],
                            'repo_url': repo_url
                        })
                elif item['type'] == 'dir':
                    # Recursively fetch directory contents
                    subdir_contents = self._fetch_contents_recursive(
                        item['url'], 
                        repo_url, 
                        path + item['name'] + "/"
                    )
                    contents.extend(subdir_contents)
                    
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Error fetching {api_url}: {e}")
        except (KeyError, TypeError) as e:
            self.logger.error(f"Error parsing API response: {e}")
        
        return contents
    
    def _is_image_file(self, filename: str) -> bool:
        """Check if file is an image based on extension"""
        image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'}
        return Path(filename).suffix.lower() in image_extensions
    
    def download_file(self, file_info: Dict, repo_name: str) -> bool:
        """Download a single file with progress tracking"""
        # Create a clean folder name from the repo name
        file_path = self.download_dir / repo_name / file_info['path']
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Check if file already exists and is in cache
        cache_key = f"{repo_name}/{file_info['path']}"
        if cache_key in self.cache['downloaded_files'] and file_path.exists():
            self.stats['skipped'] += 1
            return True
        
        try:
            response = self.session.get(file_info['download_url'], stream=True, timeout=30)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            
            with open(file_path, 'wb') as f:
                if total_size > 0:
                    with tqdm(total=total_size, unit='B', unit_scale=True, 
                             desc=f"Downloading {file_info['name'][:30]}") as pbar:
                        for chunk in response.iter_content(chunk_size=8192):
                            if chunk:
                                f.write(chunk)
                                pbar.update(len(chunk))
                else:
                    # Fallback for unknown content length
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
            
            # Verify the downloaded image
            if self._verify_image(file_path):
                self.cache['downloaded_files'].add(cache_key)
                self.stats['downloaded'] += 1
                self.stats['total_size'] += file_path.stat().st_size
                return True
            else:
                file_path.unlink()  # Remove corrupted file
                self.stats['failed'] += 1
                return False
                
        except Exception as e:
            self.logger.error(f"Failed to download {file_info['name']}: {e}")
            self.stats['failed'] += 1
            return False
    
    def _verify_image(self, file_path: Path) -> bool:
        """Verify that the downloaded file is a valid image"""
        try:
            with Image.open(file_path) as img:
                img.verify()
            return True
        except Exception:
            self.logger.warning(f"Invalid image file: {file_path}")
            return False
    
    def download_from_repo(self, repo_url: str, branch: str = "main", max_workers: int = 4, repo_name: str = None) -> bool:
        """Download all wallpapers from a specific GitHub repository"""
        # Extract repo name for folder organization if not provided
        if not repo_name:
            parsed = urlparse(repo_url)
            repo_name = parsed.path.strip('/').split('/')[-1] if parsed.path else "wallpapers"
        
        print(f"\n🖼️ Fetching wallpapers from {Fore.YELLOW}{repo_url}{Style.RESET_ALL}...")
        
        # Fetch repository contents
        contents = self.fetch_repo_contents(repo_url, branch)
        
        if not contents:
            print(f"{Fore.RED}No wallpapers found in repository{Style.RESET_ALL}")
            return False
        
        print(f"{Fore.GREEN}Found {len(contents)} wallpapers{Style.RESET_ALL}")
        
        # Download files using thread pool
        success_count = 0
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(self.download_file, file_info, repo_name): file_info 
                      for file_info in contents}
            
            for future in as_completed(futures):
                if future.result():
                    success_count += 1
        
        print(f"\n{Fore.GREEN}Successfully downloaded {success_count}/{len(contents)} wallpapers{Style.RESET_ALL}")
        return True
    
    def download_curated_repo(self, repo_key: str, max_workers: int = 4) -> bool:
        """Download wallpapers from one of our curated repositories"""
        if repo_key not in self.REPOSITORIES:
            print(f"{Fore.RED}Repository '{repo_key}' not found in curated list{Style.RESET_ALL}")
            return False
        
        repo_info = self.REPOSITORIES[repo_key]
        print(f"\n{repo_info['icon']} Starting download from {Fore.YELLOW}{repo_key.upper()}{Style.RESET_ALL}")
        print(f"📝 Description: {repo_info['description']}")
        
        # Use the repo key as the folder name for better organization
        return self.download_from_repo(
            repo_info['url'], 
            repo_info['branch'], 
            max_workers, 
            repo_key
        )
    
    def download_all_curated_repos(self, max_workers: int = 4):
        """Download wallpapers from all curated repositories"""
        print(f"\n{Fore.CYAN}Starting bulk download from all curated repositories...{Style.RESET_ALL}")
        
        successful_repos = 0
        total_repos = len(self.REPOSITORIES)
        
        for i, repo_key in enumerate(self.REPOSITORIES, 1):
            print(f"\n{Fore.MAGENTA}[{i}/{total_repos}] Processing {repo_key}...{Style.RESET_ALL}")
            
            if self.download_curated_repo(repo_key, max_workers):
                successful_repos += 1
            
            # Save cache after each repository
            self._save_cache()
            
            # Small delay between repositories to be respectful to GitHub API
            time.sleep(1)
        
        print(f"\n{Fore.GREEN}Completed downloads from {successful_repos}/{total_repos} repositories{Style.RESET_ALL}")
        self.show_statistics()
    
    def show_statistics(self):
        """Display download statistics"""
        print(f"\n{Fore.CYAN}Download Statistics:{Style.RESET_ALL}")
        print("-" * 40)
        print(f"📥 Downloaded: {Fore.GREEN}{self.stats['downloaded']}{Style.RESET_ALL}")
        print(f"⏭️  Skipped: {Fore.YELLOW}{self.stats['skipped']}{Style.RESET_ALL}")
        print(f"❌ Failed: {Fore.RED}{self.stats['failed']}{Style.RESET_ALL}")
        print(f"💾 Total Size: {Fore.CYAN}{self._format_bytes(self.stats['total_size'])}{Style.RESET_ALL}")
        print(f"📁 Storage Path: {Fore.BLUE}{self.download_dir}{Style.RESET_ALL}")
    
    def _format_bytes(self, bytes_count: int) -> str:
        """Format bytes to human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_count < 1024.0:
                return f"{bytes_count:.1f} {unit}"
            bytes_count /= 1024.0
        return f"{bytes_count:.1f} PB"
    
    def cleanup_cache(self):
        """Clean up cache and remove orphaned entries"""
        cleaned_count = 0
        if 'downloaded_files' in self.cache:
            for cache_key in list(self.cache['downloaded_files']):
                file_path = self.download_dir / cache_key
                if not file_path.exists():
                    self.cache['downloaded_files'].discard(cache_key)
                    cleaned_count += 1
        
        if cleaned_count > 0:
            print(f"{Fore.GREEN}Cleaned {cleaned_count} orphaned cache entries{Style.RESET_ALL}")
            self._save_cache()
    
    def __del__(self):
        """Cleanup when object is destroyed"""
        if hasattr(self, 'cache'):
            self._save_cache()

def parse_interval(interval_str: str) -> int:
    """Parse interval string (e.g., '30s', '5m', '1h', '1h 30m 45s') to seconds"""
    if not interval_str:
        return 0
    
    # Pattern to match time components
    pattern = r'(\d+)([smh])'
    matches = re.findall(pattern, interval_str.lower())
    
    if not matches:
        # Try to parse as plain number (assume seconds)
        try:
            return int(interval_str)
        except ValueError:
            raise ValueError(f"Invalid interval format: {interval_str}")
    
    total_seconds = 0
    for value, unit in matches:
        value = int(value)
        if unit == 's':
            total_seconds += value
        elif unit == 'm':
            total_seconds += value * 60
        elif unit == 'h':
            total_seconds += value * 3600
    
    return total_seconds

def interactive_setup():
    """Interactive setup for wallpaper slideshow"""
    print(f"\n{Fore.CYAN}🎨 WallPimp Interactive Setup{Style.RESET_ALL}")
    print("=" * 50)
    
    # Detect desktop environment
    desktop_env = DesktopEnvironmentManager.detect_desktop_environment()
    print(f"{Fore.BLUE}Detected Desktop Environment: {desktop_env.upper()}{Style.RESET_ALL}")
    
    # Ask for wallpaper directory
    default_dir = str(Path.home() / 'Pictures')
    wallpaper_dir = input(f"\n📁 Enter wallpaper directory (default: {default_dir}): ").strip()
    if not wallpaper_dir:
        wallpaper_dir = default_dir
    
    wallpaper_path = Path(wallpaper_dir)
    if not wallpaper_path.exists():
        print(f"{Fore.RED}Directory doesn't exist: {wallpaper_path}{Style.RESET_ALL}")
        return None, None, None
    
    # Check for images in directory
    image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'}
    image_count = sum(1 for ext in image_extensions 
                     for _ in wallpaper_path.glob(f'*{ext}'))
    
    if image_count == 0:
        print(f"{Fore.YELLOW}No images found in {wallpaper_path}{Style.RESET_ALL}")
        print(f"{Fore.CYAN}You can download wallpapers first using: --repo <name> or --all{Style.RESET_ALL}")
        return None, None, None
    
    print(f"{Fore.GREEN}Found {image_count} images in directory{Style.RESET_ALL}")
    
    # Ask for mode (static or slideshow)
    print(f"\n🔄 Choose wallpaper mode:")
    print(f"1. Static wallpaper (set once)")
    print(f"2. Slideshow (change automatically)")
    
    while True:
        mode_choice = input("\nEnter choice (1 or 2): ").strip()
        if mode_choice in ['1', '2']:
            break
        print(f"{Fore.RED}Invalid choice. Please enter 1 or 2.{Style.RESET_ALL}")
    
    if mode_choice == '1':
        return wallpaper_dir, 'static', 0
    
    # Ask for slideshow interval
    print(f"\n⏱️  Enter slideshow interval:")
    print(f"Examples: 30s (30 seconds), 5m (5 minutes), 1h (1 hour)")
    print(f"Advanced: 1h 30m 45s (1 hour 30 minutes 45 seconds)")
    
    while True:
        interval_str = input("Interval: ").strip()
        try:
            interval_seconds = parse_interval(interval_str)
            if interval_seconds < 1:
                print(f"{Fore.RED}Interval must be at least 1 second{Style.RESET_ALL}")
                continue
            break
        except ValueError as e:
            print(f"{Fore.RED}{e}{Style.RESET_ALL}")
    
    return wallpaper_dir, 'slideshow', interval_seconds

def main():
    """Main entry point for WallPimp Enhanced"""
    parser = argparse.ArgumentParser(
        description='WallPimp Enhanced - Universal Linux Wallpaper Manager with Slideshow',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Download wallpapers
  python wallpimp.py --list                    # Show all curated repositories
  python wallpimp.py --repo anime              # Download anime wallpapers
  python wallpimp.py --all                     # Download from all curated repos
  python wallpimp.py --url https://github.com/user/wallpapers
  
  # Wallpaper management
  python wallpimp.py --setup                   # Interactive setup
  python wallpimp.py --static --dir ~/Pictures # Set random static wallpaper
  python wallpimp.py --slideshow --dir ~/Pictures --interval 5m
  python wallpimp.py --slideshow --dir ~/Pictures --interval "1h 30m"
  
  # Autostart management
  python wallpimp.py --enable-autostart --dir ~/Pictures --interval 10m
  python wallpimp.py --disable-autostart
        """
    )
    
    # Download options
    download_group = parser.add_argument_group('Download Options')
    download_group.add_argument('--dir', type=str, help='Download/wallpaper directory')
    download_group.add_argument('--repo', type=str, help='Download from curated repository')
    download_group.add_argument('--url', type=str, help='Download from GitHub repository URL')
    download_group.add_argument('--branch', type=str, default='main', help='Repository branch (default: main)')
    download_group.add_argument('--list', action='store_true', help='List curated repositories')
    download_group.add_argument('--all', action='store_true', help='Download from all curated repositories')
    download_group.add_argument('--workers', type=int, default=4, help='Download workers (default: 4)')
    download_group.add_argument('--cleanup', action='store_true', help='Clean up cache')
    
    # Wallpaper management options
    wallpaper_group = parser.add_argument_group('Wallpaper Management')
    wallpaper_group.add_argument('--setup', action='store_true', help='Interactive setup')
    wallpaper_group.add_argument('--static', action='store_true', help='Set random static wallpaper')
    wallpaper_group.add_argument('--slideshow', action='store_true', help='Start slideshow mode')
    wallpaper_group.add_argument('--interval', type=str, help='Slideshow interval (e.g., 30s, 5m, 1h)')
    wallpaper_group.add_argument('--image', type=str, help='Specific image path for static mode')
    
    # Autostart options
    autostart_group = parser.add_argument_group('Autostart Management')
    autostart_group.add_argument('--enable-autostart', action='store_true', help='Enable autostart')
    autostart_group.add_argument('--disable-autostart', action='store_true', help='Disable autostart')
    
    args = parser.parse_args()
    
    # Validate argument combinations
    main_actions = [
        args.repo, args.url, args.list, args.all, args.cleanup,
        args.setup, args.static, args.slideshow, 
        args.enable_autostart, args.disable_autostart
    ]
    
    if sum(bool(action) for action in main_actions) > 1:
        print(f"{Fore.RED}Error: Please specify only one main action{Style.RESET_ALL}")
        sys.exit(1)
    
    # Initialize WallPimp
    wallpimp = WallPimp(download_dir=args.dir)
    wallpimp.show_banner()
    
    try:
        # Handle download operations
        if args.list:
            wallpimp.list_repositories()
        elif args.cleanup:
            wallpimp.cleanup_cache()
        elif args.all:
            wallpimp.download_all_curated_repos(max_workers=args.workers)
        elif args.repo:
            wallpimp.download_curated_repo(args.repo.lower(), max_workers=args.workers)
        elif args.url:
            wallpimp.download_from_repo(args.url, args.branch, max_workers=args.workers)
        
        # Handle wallpaper management
        elif args.setup:
            wallpaper_dir, mode, interval = interactive_setup()
            if wallpaper_dir:
                if mode == 'static':
                    slideshow_manager = SlideshowManager(wallpaper_dir, 0)
                    slideshow_manager.set_static_wallpaper()
                else:
                    # Create autostart entry
                    script_path = os.path.abspath(__file__)
                    AutostartManager.create_autostart_entry(
                        script_path, wallpaper_dir, f"{interval}s", 'slideshow'
                    )
                    print(f"{Fore.GREEN}Slideshow will start automatically on next login{Style.RESET_ALL}")
        
        elif args.static:
            if not args.dir:
                print(f"{Fore.RED}Error: --dir is required for static mode{Style.RESET_ALL}")
                sys.exit(1)
            
            slideshow_manager = SlideshowManager(args.dir, 0)
            slideshow_manager.set_static_wallpaper(args.image)
        
        elif args.slideshow:
            if not args.dir:
                print(f"{Fore.RED}Error: --dir is required for slideshow mode{Style.RESET_ALL}")
                sys.exit(1)
            if not args.interval:
                print(f"{Fore.RED}Error: --interval is required for slideshow mode{Style.RESET_ALL}")
                sys.exit(1)
            
            try:
                interval_seconds = parse_interval(args.interval)
                slideshow_manager = SlideshowManager(args.dir, interval_seconds)
                
                # Handle graceful shutdown
                def signal_handler(signum, frame):
                    print(f"\n{Fore.YELLOW}Stopping slideshow...{Style.RESET_ALL}")
                    slideshow_manager.stop_slideshow()
                    sys.exit(0)
                
                signal.signal(signal.SIGINT, signal_handler)
                signal.signal(signal.SIGTERM, signal_handler)
                
                slideshow_manager.start_slideshow()
                
                # Keep the program running
                while True:
                    time.sleep(1)
                    
            except ValueError as e:
                print(f"{Fore.RED}Error parsing interval: {e}{Style.RESET_ALL}")
                sys.exit(1)
            except Exception as e:
                print(f"{Fore.RED}Error starting slideshow: {e}{Style.RESET_ALL}")
                sys.exit(1)
        
        # Handle autostart management
        elif args.enable_autostart:
            if not args.dir:
                print(f"{Fore.RED}Error: --dir is required for autostart{Style.RESET_ALL}")
                sys.exit(1)
            
            script_path = os.path.abspath(__file__)
            if args.interval:
                AutostartManager.create_autostart_entry(
                    script_path, args.dir, args.interval, 'slideshow'
                )
            else:
                AutostartManager.create_autostart_entry(
                    script_path, args.dir, '10m', 'static'
                )
        
        elif args.disable_autostart:
            AutostartManager.remove_autostart_entry()
        
        else:
            # No arguments provided - show interactive help
            wallpimp.list_repositories()
            print(f"\n{Fore.CYAN}🚀 Quick Start Options:{Style.RESET_ALL}")
            print(f"{Fore.GREEN}  python wallpimp.py --setup           # Interactive setup{Style.RESET_ALL}")
            print(f"{Fore.GREEN}  python wallpimp.py --repo anime      # Download anime wallpapers{Style.RESET_ALL}")
            print(f"{Fore.GREEN}  python wallpimp.py --all             # Download all wallpapers{Style.RESET_ALL}")
            print(f"{Fore.CYAN}  python wallpimp.py --help            # Show all options{Style.RESET_ALL}")
    
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Operation cancelled by user{Style.RESET_ALL}")
    except Exception as e:
        print(f"\n{Fore.RED}An error occurred: {e}{Style.RESET_ALL}")
        if hasattr(wallpimp, 'logger'):
            wallpimp.logger.error(f"Unexpected error: {e}")
    finally:
        # Always show statistics for download operations
        if any([args.repo, args.url, args.all]):
            wallpimp.show_statistics()

if __name__ == "__main__":
    main()
