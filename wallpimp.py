#!/usr/bin/env python3
"""
WallPimp - Modern Linux Wallpaper Manager
A terminal-driven wallpaper manager with slideshow support for XFCE and other Linux desktop environments
Developer: 0xb0rn3
Email: q4n0@proton.me
"""

import os
import sys
import json
import subprocess
import shutil
import random
from pathlib import Path
from typing import Dict, List
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed

# Dependency management
DEPENDENCIES = {
    'requests': 'requests>=2.25.0',
    'tqdm': 'tqdm>=4.60.0',
    'PIL': 'Pillow>=8.0.0',
    'colorama': 'colorama>=0.4.4'
}

def install_dependencies():
    """Install required Python dependencies"""
    missing = []
    for module, spec in DEPENDENCIES.items():
        try:
            __import__(module)
        except ImportError:
            missing.append(spec)
    
    if missing:
        print("Installing missing dependencies...")
        methods = [
            lambda dep: subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--break-system-packages', dep]),
            lambda dep: subprocess.check_call([sys.executable, '-m', 'pip', 'install', dep]),
        ]
        
        for dep in missing:
            for method in methods:
                try:
                    method(dep)
                    print(f"✓ Installed {dep}")
                    break
                except (subprocess.CalledProcessError, FileNotFoundError):
                    continue

install_dependencies()

import requests
from tqdm import tqdm
from PIL import Image
from colorama import init, Fore, Style

init(autoreset=True)

class Config:
    """Configuration management"""
    def __init__(self):
        self.config_dir = Path.home() / '.config' / 'wallpimp'
        self.config_file = self.config_dir / 'config.json'
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.load()
    
    def load(self):
        """Load configuration"""
        defaults = {
            'wallpaper_dir': str(Path.home() / 'Pictures' / 'Wallpapers'),
            'slideshow_interval': 300,
            'download_workers': 4,
        }
        
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    self.data = {**defaults, **json.load(f)}
            except:
                self.data = defaults
        else:
            self.data = defaults
        
        Path(self.data['wallpaper_dir']).mkdir(parents=True, exist_ok=True)
    
    def save(self):
        with open(self.config_file, 'w') as f:
            json.dump(self.data, f, indent=2)
    
    def get(self, key, default=None):
        return self.data.get(key, default)
    
    def set(self, key, value):
        self.data[key] = value
        self.save()


class SystemDetector:
    """Detect system configuration"""
    
    @staticmethod
    def detect_distro() -> str:
        try:
            with open('/etc/os-release', 'r') as f:
                for line in f:
                    if line.startswith('ID='):
                        return line.split('=')[1].strip().strip('"')
        except:
            pass
        return 'unknown'
    
    @staticmethod
    def detect_de() -> str:
        de_vars = ['DESKTOP_SESSION', 'XDG_CURRENT_DESKTOP', 'GDMSESSION']
        
        for var in de_vars:
            value = os.environ.get(var, '').lower()
            if 'xfce' in value:
                return 'xfce'
            elif 'gnome' in value:
                return 'gnome'
            elif 'kde' in value or 'plasma' in value:
                return 'kde'
            elif 'mate' in value:
                return 'mate'
            elif 'cinnamon' in value:
                return 'cinnamon'
            elif 'i3' in value:
                return 'i3'
            elif 'sway' in value:
                return 'sway'
        
        try:
            processes = subprocess.check_output(['ps', 'aux'], universal_newlines=True)
            for de in ['xfce', 'gnome', 'kde', 'plasma', 'mate', 'cinnamon', 'i3', 'sway']:
                if de in processes.lower():
                    return de
        except:
            pass
        
        return 'unknown'
    
    @staticmethod
    def detect_dm() -> str:
        dm_list = ['sddm', 'lightdm', 'gdm', 'gdm3']
        for dm in dm_list:
            try:
                result = subprocess.run(['systemctl', 'status', dm], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    return dm
            except:
                pass
        return 'unknown'


class RepositoryManager:
    """Manage wallpaper repositories"""
    
    REPOSITORIES = {
        'minimalist': {
            'url': 'https://github.com/dharmx/walls',
            'branch': 'main',
            'description': 'Clean minimalist designs'
        },
        'anime': {
            'url': 'https://github.com/HENTAI-CODER/Anime-Wallpaper',
            'branch': 'main',
            'description': 'Anime & manga artwork'
        },
        'nature': {
            'url': 'https://github.com/FrenzyExists/wallpapers',
            'branch': 'main',
            'description': 'Nature landscapes'
        },
        'scenic': {
            'url': 'https://github.com/michaelScopic/Wallpapers',
            'branch': 'main',
            'description': 'Scenic vistas'
        },
        'artistic': {
            'url': 'https://github.com/D3Ext/aesthetic-wallpapers',
            'branch': 'main',
            'description': 'Artistic styles'
        },
        'animated': {
            'url': 'https://github.com/0xb0rn3/animated-wallpapers',
            'branch': 'main',
            'description': 'Animated GIF wallpapers'
        }
    }
    
    def __init__(self, config: Config):
        self.config = config
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'WallPimp/1.0 (https://github.com/0xb0rn3/wallpimp)'
        })
        
        # Rate limit tracking
        self.api_calls = 0
        self.rate_limit_remaining = 60
        self.rate_limit_reset = 0
        
        # Cache for API responses
        self.cache_dir = Path(config.config_dir) / 'cache'
        self.cache_dir.mkdir(exist_ok=True)
        
        # Download tracking
        self.download_cache_file = self.cache_dir / 'downloaded.json'
        self.downloaded_files = self._load_download_cache()
    
    def _load_download_cache(self) -> set:
        """Load cache of already downloaded files"""
        if self.download_cache_file.exists():
            try:
                with open(self.download_cache_file, 'r') as f:
                    return set(json.load(f))
            except:
                pass
        return set()
    
    def _save_download_cache(self):
        """Save download cache"""
        try:
            with open(self.download_cache_file, 'w') as f:
                json.dump(list(self.downloaded_files), f)
        except:
            pass
    
    def _check_rate_limit(self):
        """Check and handle GitHub API rate limits"""
        import time
        
        if self.rate_limit_remaining <= 5:
            if self.rate_limit_reset > time.time():
                wait_time = int(self.rate_limit_reset - time.time()) + 1
                print(f"{Fore.YELLOW}Rate limit approaching. Waiting {wait_time}s...{Style.RESET_ALL}")
                time.sleep(wait_time)
                self.rate_limit_remaining = 60
    
    def _update_rate_limit(self, response):
        """Update rate limit info from response headers"""
        try:
            self.rate_limit_remaining = int(response.headers.get('X-RateLimit-Remaining', 60))
            self.rate_limit_reset = int(response.headers.get('X-RateLimit-Reset', 0))
        except:
            pass
    
    def _get_cache_key(self, url: str) -> str:
        """Generate cache key for URL"""
        import hashlib
        return hashlib.md5(url.encode()).hexdigest()
    
    def _get_cached_response(self, url: str) -> Optional[List[Dict]]:
        """Get cached API response"""
        cache_key = self._get_cache_key(url)
        cache_file = self.cache_dir / f"{cache_key}.json"
        
        if cache_file.exists():
            try:
                # Check if cache is less than 24 hours old
                import time
                if time.time() - cache_file.stat().st_mtime < 86400:
                    with open(cache_file, 'r') as f:
                        return json.load(f)
            except:
                pass
        return None
    
    def _cache_response(self, url: str, data: List[Dict]):
        """Cache API response"""
        cache_key = self._get_cache_key(url)
        cache_file = self.cache_dir / f"{cache_key}.json"
        
        try:
            with open(cache_file, 'w') as f:
                json.dump(data, f)
        except:
            pass
    
    def list_repositories(self):
        print(f"\n{Fore.CYAN}Available Repositories:{Style.RESET_ALL}")
        print("=" * 60)
        for name, info in self.REPOSITORIES.items():
            print(f"{Fore.YELLOW}{name:<15}{Style.RESET_ALL} - {info['description']}")
    
    def download_from_repo(self, repo_name: str, workers: int = 4) -> bool:
        if repo_name not in self.REPOSITORIES:
            print(f"{Fore.RED}Repository '{repo_name}' not found{Style.RESET_ALL}")
            return False
        
        repo_info = self.REPOSITORIES[repo_name]
        print(f"\n{Fore.CYAN}Downloading from {repo_name}...{Style.RESET_ALL}")
        
        # Try to use git clone first (no rate limits!)
        if self._try_git_clone(repo_info['url'], repo_name):
            print(f"{Fore.GREEN}Successfully cloned repository using git{Style.RESET_ALL}")
            self._cleanup_git_files(repo_name)
            return True
        
        # Fallback to API method
        print(f"{Fore.YELLOW}Git not available, using API method{Style.RESET_ALL}")
        files = self._fetch_repo_contents(repo_info['url'], repo_info['branch'])
        if not files:
            return False
        
        print(f"{Fore.GREEN}Found {len(files)} files{Style.RESET_ALL}")
        
        repo_dir = Path(self.config.get('wallpaper_dir')) / repo_name
        repo_dir.mkdir(parents=True, exist_ok=True)
        
        # Filter out already downloaded files
        new_files = [f for f in files if f['path'] not in self.downloaded_files]
        if new_files:
            print(f"{Fore.CYAN}Downloading {len(new_files)} new files (skipping {len(files) - len(new_files)} existing){Style.RESET_ALL}")
        else:
            print(f"{Fore.GREEN}All files already downloaded!{Style.RESET_ALL}")
            return True
        
        downloaded = 0
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(self._download_file, f, repo_dir): f 
                for f in new_files
            }
            
            for future in tqdm(as_completed(futures), total=len(new_files), desc="Downloading"):
                if future.result():
                    downloaded += 1
                    # Save cache periodically
                    if downloaded % 10 == 0:
                        self._save_download_cache()
        
        self._save_download_cache()
        print(f"{Fore.GREEN}Downloaded {downloaded}/{len(new_files)} wallpapers{Style.RESET_ALL}")
        return True
    
    def _try_git_clone(self, url: str, repo_name: str) -> bool:
        """Try to clone repository using git (avoids rate limits)"""
        if not shutil.which('git'):
            return False
        
        repo_dir = Path(self.config.get('wallpaper_dir')) / repo_name
        
        try:
            # Clone with depth 1 for speed
            result = subprocess.run(
                ['git', 'clone', '--depth', '1', url, str(repo_dir)],
                capture_output=True,
                timeout=300
            )
            return result.returncode == 0
        except:
            return False
    
    def _cleanup_git_files(self, repo_name: str):
        """Remove .git directory after cloning"""
        repo_dir = Path(self.config.get('wallpaper_dir')) / repo_name
        git_dir = repo_dir / '.git'
        
        if git_dir.exists():
            try:
                shutil.rmtree(git_dir)
            except:
                pass
    
    def _fetch_repo_contents(self, url: str, branch: str) -> List[Dict]:
        parsed = urlparse(url)
        parts = parsed.path.strip('/').split('/')
        if len(parts) < 2:
            return []
        
        owner, repo = parts[0], parts[1]
        api_url = f"https://api.github.com/repos/{owner}/{repo}/contents?ref={branch}"
        
        return self._fetch_recursive(api_url)
    
    def _fetch_recursive(self, api_url: str, path: str = "") -> List[Dict]:
        files = []
        
        # Check cache first
        cached = self._get_cached_response(api_url)
        if cached:
            print(f"{Fore.CYAN}Using cached data for {api_url.split('/')[-1]}{Style.RESET_ALL}")
            return cached
        
        # Check rate limit before making request
        self._check_rate_limit()
        
        try:
            response = self.session.get(api_url, timeout=30)
            response.raise_for_status()
            
            # Update rate limit info
            self._update_rate_limit(response)
            
            items = response.json()
            
            if not isinstance(items, list):
                return files
            
            for item in items:
                if item['type'] == 'file' and self._is_image(item['name']):
                    files.append({
                        'name': item['name'],
                        'url': item['download_url'],
                        'path': path + item['name'] if path else item['name']
                    })
                elif item['type'] == 'dir':
                    # Add small delay between directory requests
                    import time
                    time.sleep(0.5)
                    subfiles = self._fetch_recursive(item['url'], path + item['name'] + "/")
                    files.extend(subfiles)
            
            # Cache the response
            self._cache_response(api_url, files)
            
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 403:
                print(f"{Fore.RED}Rate limit exceeded! Using git clone method instead.{Style.RESET_ALL}")
                return []
            else:
                print(f"{Fore.RED}HTTP Error {e.response.status_code}: {api_url}{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}Error fetching {api_url}: {e}{Style.RESET_ALL}")
        
        return files
    
    def _is_image(self, filename: str) -> bool:
        exts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.svg'}
        return Path(filename).suffix.lower() in exts
    
    def _download_file(self, file_info: Dict, dest_dir: Path) -> bool:
        dest_path = dest_dir / file_info['name']
        
        # Check if already downloaded
        if file_info['path'] in self.downloaded_files and dest_path.exists():
            return True
        
        if dest_path.exists():
            # File exists, mark as downloaded
            self.downloaded_files.add(file_info['path'])
            return True
        
        try:
            response = self.session.get(file_info['url'], stream=True, timeout=30)
            response.raise_for_status()
            
            with open(dest_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            
            try:
                with Image.open(dest_path) as img:
                    img.verify()
                self.downloaded_files.add(file_info['path'])
                return True
            except:
                dest_path.unlink()
                return False
        except Exception as e:
            if dest_path.exists():
                dest_path.unlink()
            return False


class WallpaperManager:
    """Main wallpaper management class"""
    
    def __init__(self):
        self.config = Config()
        self.system = SystemDetector()
        self.repo_manager = RepositoryManager(self.config)
        
        self.distro = self.system.detect_distro()
        self.de = self.system.detect_de()
        self.dm = self.system.detect_dm()
    
    def show_banner(self):
        banner = f"""
{Fore.CYAN}╔══════════════════════════════════════════════════════════════╗
║                         WALLPIMP                             ║
║          Modern Linux Wallpaper Manager & Slideshow          ║
╚══════════════════════════════════════════════════════════════╝{Style.RESET_ALL}

{Fore.GREEN}System Information:{Style.RESET_ALL}
  Distribution: {Fore.YELLOW}{self.distro}{Style.RESET_ALL}
  Desktop:      {Fore.YELLOW}{self.de}{Style.RESET_ALL}
  Display Mgr:  {Fore.YELLOW}{self.dm}{Style.RESET_ALL}
  Wallpaper:    {Fore.YELLOW}{self.config.get('wallpaper_dir')}{Style.RESET_ALL}

{Fore.MAGENTA}Developer: 0xb0rn3 | q4n0@proton.me{Style.RESET_ALL}
"""
        print(banner)
    
    def main_menu(self):
        while True:
            print(f"\n{Fore.CYAN}═══ WALLPIMP MAIN MENU ═══{Style.RESET_ALL}\n")
            print(f"{Fore.YELLOW}1.{Style.RESET_ALL} Downloads")
            print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Settings")
            print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Slideshow Control")
            print(f"{Fore.YELLOW}4.{Style.RESET_ALL} Set Static Wallpaper")
            print(f"{Fore.YELLOW}0.{Style.RESET_ALL} Exit")
            
            choice = input(f"\n{Fore.GREEN}Select option: {Style.RESET_ALL}").strip()
            
            if choice == '1':
                self.downloads_menu()
            elif choice == '2':
                self.settings_menu()
            elif choice == '3':
                self.slideshow_menu()
            elif choice == '4':
                self.set_static_wallpaper()
            elif choice == '0':
                print(f"{Fore.GREEN}Goodbye!{Style.RESET_ALL}")
                break
    
    def downloads_menu(self):
        while True:
            print(f"\n{Fore.CYAN}═══ DOWNLOADS MENU ═══{Style.RESET_ALL}\n")
            print(f"{Fore.YELLOW}1.{Style.RESET_ALL} List repositories")
            print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Download from repository")
            print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Download all repositories")
            print(f"{Fore.YELLOW}4.{Style.RESET_ALL} Download from custom URL")
            print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Clear download cache")
            print(f"{Fore.YELLOW}6.{Style.RESET_ALL} Check rate limit status")
            print(f"{Fore.YELLOW}0.{Style.RESET_ALL} Back")
            
            choice = input(f"\n{Fore.GREEN}Select option: {Style.RESET_ALL}").strip()
            
            if choice == '1':
                self.repo_manager.list_repositories()
            elif choice == '2':
                self.download_single_repo()
            elif choice == '3':
                self.download_all_repos()
            elif choice == '4':
                self.download_custom_url()
            elif choice == '5':
                self.clear_download_cache()
            elif choice == '6':
                self.check_rate_limit()
            elif choice == '0':
                break
    
    def settings_menu(self):
        while True:
            print(f"\n{Fore.CYAN}═══ SETTINGS MENU ═══{Style.RESET_ALL}\n")
            print(f"{Fore.YELLOW}1.{Style.RESET_ALL} Change wallpaper directory")
            print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Set slideshow interval")
            print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Set download workers")
            print(f"{Fore.YELLOW}4.{Style.RESET_ALL} View current settings")
            print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Use existing wallpaper directory")
            print(f"{Fore.YELLOW}0.{Style.RESET_ALL} Back")
            
            choice = input(f"\n{Fore.GREEN}Select option: {Style.RESET_ALL}").strip()
            
            if choice == '1':
                self.change_wallpaper_dir()
            elif choice == '2':
                self.set_slideshow_interval()
            elif choice == '3':
                self.set_workers()
            elif choice == '4':
                self.view_settings()
            elif choice == '5':
                self.use_existing_dir()
            elif choice == '0':
                break
    
    def slideshow_menu(self):
        print(f"\n{Fore.CYAN}═══ SLIDESHOW CONTROL ═══{Style.RESET_ALL}\n")
        print(f"{Fore.YELLOW}1.{Style.RESET_ALL} Start slideshow")
        print(f"{Fore.YELLOW}2.{Style.RESET_ALL} Stop slideshow")
        print(f"{Fore.YELLOW}3.{Style.RESET_ALL} Enable autostart")
        print(f"{Fore.YELLOW}4.{Style.RESET_ALL} Disable autostart")
        print(f"{Fore.YELLOW}5.{Style.RESET_ALL} Check slideshow status")
        print(f"{Fore.YELLOW}0.{Style.RESET_ALL} Back")
        
        choice = input(f"\n{Fore.GREEN}Select option: {Style.RESET_ALL}").strip()
        
        if choice == '1':
            self.start_slideshow()
        elif choice == '2':
            self.stop_slideshow()
        elif choice == '3':
            self.enable_autostart()
        elif choice == '4':
            self.disable_autostart()
        elif choice == '5':
            self.check_slideshow_status()
    
    def download_single_repo(self):
        repo_name = input(f"{Fore.GREEN}Enter repository name: {Style.RESET_ALL}").strip().lower()
        workers = self.config.get('download_workers', 4)
        self.repo_manager.download_from_repo(repo_name, workers)
    
    def download_all_repos(self):
        confirm = input(f"{Fore.YELLOW}Download ALL repositories? (y/N): {Style.RESET_ALL}").strip().lower()
        if confirm == 'y':
            workers = self.config.get('download_workers', 4)
            for repo_name in self.repo_manager.REPOSITORIES.keys():
                self.repo_manager.download_from_repo(repo_name, workers)
    
    def download_custom_url(self):
        url = input(f"{Fore.GREEN}Enter GitHub repository URL: {Style.RESET_ALL}").strip()
        if url:
            print(f"{Fore.YELLOW}Custom URL download not yet implemented{Style.RESET_ALL}")
    
    def clear_download_cache(self):
        """Clear download cache"""
        confirm = input(f"{Fore.YELLOW}Clear download cache? Files won't be deleted. (y/N): {Style.RESET_ALL}").strip().lower()
        if confirm == 'y':
            self.repo_manager.downloaded_files.clear()
            self.repo_manager._save_download_cache()
            print(f"{Fore.GREEN}Download cache cleared{Style.RESET_ALL}")
    
    def check_rate_limit(self):
        """Check GitHub API rate limit status"""
        try:
            response = requests.get('https://api.github.com/rate_limit')
            if response.status_code == 200:
                data = response.json()
                core = data['resources']['core']
                
                print(f"\n{Fore.CYAN}GitHub API Rate Limit Status:{Style.RESET_ALL}")
                print(f"  Remaining: {Fore.YELLOW}{core['remaining']}/{core['limit']}{Style.RESET_ALL}")
                
                if core['remaining'] > 0:
                    print(f"  Status: {Fore.GREEN}OK{Style.RESET_ALL}")
                else:
                    from datetime import datetime
                    reset_time = datetime.fromtimestamp(core['reset'])
                    print(f"  Status: {Fore.RED}RATE LIMITED{Style.RESET_ALL}")
                    print(f"  Reset at: {Fore.YELLOW}{reset_time.strftime('%H:%M:%S')}{Style.RESET_ALL}")
                    print(f"\n{Fore.CYAN}Tip: Use 'git clone' method by having git installed{Style.RESET_ALL}")
            else:
                print(f"{Fore.RED}Could not check rate limit{Style.RESET_ALL}")
        except Exception as e:
            print(f"{Fore.RED}Error checking rate limit: {e}{Style.RESET_ALL}")
    
    def change_wallpaper_dir(self):
        current = self.config.get('wallpaper_dir')
        print(f"Current directory: {Fore.BLUE}{current}{Style.RESET_ALL}")
        
        new_dir = input(f"{Fore.GREEN}Enter new directory: {Style.RESET_ALL}").strip()
        if new_dir:
            path = Path(new_dir).expanduser()
            path.mkdir(parents=True, exist_ok=True)
            self.config.set('wallpaper_dir', str(path))
            print(f"{Fore.GREEN}Directory updated to: {path}{Style.RESET_ALL}")
    
    def use_existing_dir(self):
        """Use an existing wallpaper directory"""
        existing = input(f"{Fore.GREEN}Enter existing wallpaper directory path: {Style.RESET_ALL}").strip()
        if existing:
            path = Path(existing).expanduser()
            if path.exists() and path.is_dir():
                self.config.set('wallpaper_dir', str(path))
                print(f"{Fore.GREEN}Now using: {path}{Style.RESET_ALL}")
            else:
                print(f"{Fore.RED}Directory does not exist{Style.RESET_ALL}")
    
    def set_slideshow_interval(self):
        current = self.config.get('slideshow_interval', 300)
        print(f"Current interval: {Fore.BLUE}{current} seconds{Style.RESET_ALL}")
        
        new_interval = input(f"{Fore.GREEN}Enter new interval in seconds: {Style.RESET_ALL}").strip()
        if new_interval.isdigit():
            self.config.set('slideshow_interval', int(new_interval))
            print(f"{Fore.GREEN}Interval updated{Style.RESET_ALL}")
    
    def set_workers(self):
        current = self.config.get('download_workers', 4)
        print(f"Current workers: {Fore.BLUE}{current}{Style.RESET_ALL}")
        
        new_workers = input(f"{Fore.GREEN}Enter number of workers: {Style.RESET_ALL}").strip()
        if new_workers.isdigit():
            self.config.set('download_workers', int(new_workers))
            print(f"{Fore.GREEN}Workers updated{Style.RESET_ALL}")
    
    def view_settings(self):
        print(f"\n{Fore.CYAN}Current Settings:{Style.RESET_ALL}")
        print(f"  Wallpaper Dir:      {self.config.get('wallpaper_dir')}")
        print(f"  Slideshow Interval: {self.config.get('slideshow_interval')} seconds")
        print(f"  Download Workers:   {self.config.get('download_workers')}")
    
    def start_slideshow(self):
        try:
            subprocess.run(['systemctl', '--user', 'start', 'wallpimp-slideshow.timer'], check=True)
            print(f"{Fore.GREEN}Slideshow started{Style.RESET_ALL}")
        except subprocess.CalledProcessError:
            print(f"{Fore.RED}Failed to start slideshow. Run ./install.sh first{Style.RESET_ALL}")
    
    def stop_slideshow(self):
        try:
            subprocess.run(['systemctl', '--user', 'stop', 'wallpimp-slideshow.timer'], check=True)
            print(f"{Fore.YELLOW}Slideshow stopped{Style.RESET_ALL}")
        except subprocess.CalledProcessError:
            print(f"{Fore.RED}Failed to stop slideshow{Style.RESET_ALL}")
    
    def enable_autostart(self):
        try:
            subprocess.run(['systemctl', '--user', 'enable', 'wallpimp-slideshow.timer'], check=True)
            print(f"{Fore.GREEN}Autostart enabled{Style.RESET_ALL}")
        except subprocess.CalledProcessError:
            print(f"{Fore.RED}Failed to enable autostart{Style.RESET_ALL}")
    
    def disable_autostart(self):
        try:
            subprocess.run(['systemctl', '--user', 'disable', 'wallpimp-slideshow.timer'], check=True)
            print(f"{Fore.YELLOW}Autostart disabled{Style.RESET_ALL}")
        except subprocess.CalledProcessError:
            print(f"{Fore.RED}Failed to disable autostart{Style.RESET_ALL}")
    
    def check_slideshow_status(self):
        try:
            result = subprocess.run(['systemctl', '--user', 'status', 'wallpimp-slideshow.timer'],
                                  capture_output=True, text=True)
            print(result.stdout)
        except subprocess.CalledProcessError:
            print(f"{Fore.YELLOW}Slideshow service not found. Run ./install.sh{Style.RESET_ALL}")
    
    def set_static_wallpaper(self):
        wallpaper_dir = Path(self.config.get('wallpaper_dir'))
        
        images = []
        for ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']:
            images.extend(wallpaper_dir.rglob(f'*{ext}'))
        
        if not images:
            print(f"{Fore.RED}No wallpapers found in {wallpaper_dir}{Style.RESET_ALL}")
            return
        
        selected = random.choice(images)
        
        if self.de == 'xfce':
            self._set_xfce_wallpaper(str(selected))
        elif self.de == 'gnome':
            self._set_gnome_wallpaper(str(selected))
        elif self.de == 'kde':
            self._set_kde_wallpaper(str(selected))
        else:
            self._set_feh_wallpaper(str(selected))
        
        print(f"{Fore.GREEN}Wallpaper set to: {selected.name}{Style.RESET_ALL}")
    
    def _set_xfce_wallpaper(self, path: str):
        try:
            result = subprocess.run(['xfconf-query', '-c', 'xfce4-desktop', '-l'],
                                  capture_output=True, text=True)
            properties = [line for line in result.stdout.split('\n') if 'last-image' in line]
            
            for prop in properties:
                subprocess.run(['xfconf-query', '-c', 'xfce4-desktop', '-p', prop, '-s', path])
        except:
            pass
    
    def _set_gnome_wallpaper(self, path: str):
        try:
            subprocess.run(['gsettings', 'set', 'org.gnome.desktop.background',
                          'picture-uri', f'file://{path}'])
            subprocess.run(['gsettings', 'set', 'org.gnome.desktop.background',
                          'picture-uri-dark', f'file://{path}'])
        except:
            pass
    
    def _set_kde_wallpaper(self, path: str):
        script = f'''
        var allDesktops = desktops();
        for (i=0;i<allDesktops.length;i++) {{
            d = allDesktops[i];
            d.wallpaperPlugin = "org.kde.image";
            d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
            d.writeConfig("Image", "file://{path}");
        }}
        '''
        try:
            subprocess.run(['qdbus', 'org.kde.plasmashell', '/PlasmaShell',
                          'org.kde.PlasmaShell.evaluateScript', script])
        except:
            pass
    
    def _set_feh_wallpaper(self, path: str):
        try:
            subprocess.run(['feh', '--bg-fill', path])
        except:
            pass


def main():
    manager = WallpaperManager()
    manager.show_banner()
    manager.main_menu()


if __name__ == '__main__':
    main()
