#!/usr/bin/env python3
"""
WallPimp - Wallpaper Management Tool
A simple cross-platform wallpaper downloader and manager
"""

import os
import sys
import json
import argparse
import logging
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Optional
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

class WallPimp:
    """Main WallPimp class for wallpaper management"""
    
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
                                                                  
{Fore.YELLOW}The Ultimate Wallpaper Manager{Style.RESET_ALL}
{Fore.GREEN}Download Directory: {self.download_dir}{Style.RESET_ALL}
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


def main():
    """Main entry point for WallPimp"""
    parser = argparse.ArgumentParser(
        description='WallPimp - The Ultimate Wallpaper Manager',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Download from curated repositories
  python wallpimp.py --list                    # Show all curated repositories
  python wallpimp.py --repo anime              # Download anime wallpapers
  python wallpimp.py --repo minimalist --workers 8  # Download with 8 workers
  python wallpimp.py --all                     # Download from all curated repos
  
  # Download from custom repositories
  python wallpimp.py --url https://github.com/user/wallpapers
  python wallpimp.py --url https://github.com/user/wallpapers --branch dev
        """
    )
    
    parser.add_argument(
        '--dir', 
        type=str, 
        help='Download directory (default: ~/Pictures/WallPimp)'
    )
    
    parser.add_argument(
        '--repo', 
        type=str, 
        help='Download from a specific curated repository'
    )
    
    parser.add_argument(
        '--url', 
        type=str, 
        help='Download from any GitHub repository URL'
    )
    
    parser.add_argument(
        '--branch', 
        type=str, 
        default='main',
        help='Repository branch to use (default: main)'
    )
    
    parser.add_argument(
        '--list', 
        action='store_true', 
        help='List all available curated repositories'
    )
    
    parser.add_argument(
        '--all', 
        action='store_true', 
        help='Download from all curated repositories'
    )
    
    parser.add_argument(
        '--workers', 
        type=int, 
        default=4, 
        help='Number of download workers (default: 4)'
    )
    
    parser.add_argument(
        '--cleanup', 
        action='store_true', 
        help='Clean up cache and remove orphaned entries'
    )
    
    args = parser.parse_args()
    
    # Validate arguments - ensure only one main action is specified
    main_actions = [args.repo, args.url, args.list, args.all, args.cleanup]
    if sum(bool(action) for action in main_actions) > 1:
        print(f"{Fore.RED}Error: Please specify only one main action (--repo, --url, --list, --all, or --cleanup){Style.RESET_ALL}")
        sys.exit(1)
    
    # Initialize WallPimp
    wallpimp = WallPimp(download_dir=args.dir)
    wallpimp.show_banner()
    
    try:
        if args.list:
            # Display all available curated repositories
            wallpimp.list_repositories()
        elif args.cleanup:
            # Clean up cache
            wallpimp.cleanup_cache()
        elif args.all:
            # Download from all curated repositories
            wallpimp.download_all_curated_repos(max_workers=args.workers)
        elif args.repo:
            # Download from a specific curated repository
            wallpimp.download_curated_repo(args.repo.lower(), max_workers=args.workers)
        elif args.url:
            # Download from any GitHub repository URL
            wallpimp.download_from_repo(args.url, args.branch, max_workers=args.workers)
        else:
            # No arguments provided - show interactive help
            wallpimp.list_repositories()
            print(f"\n{Fore.CYAN}Use --help for all command line options{Style.RESET_ALL}")
            print(f"{Fore.GREEN}Quick start: python wallpimp.py --repo anime{Style.RESET_ALL}")
    
    except KeyboardInterrupt:
        print(f"\n{Fore.YELLOW}Operation cancelled by user{Style.RESET_ALL}")
    except Exception as e:
        print(f"\n{Fore.RED}An error occurred: {e}{Style.RESET_ALL}")
        wallpimp.logger.error(f"Unexpected error: {e}")
    finally:
        # Always show statistics when we're done
        wallpimp.show_statistics()


if __name__ == "__main__":
    main()
