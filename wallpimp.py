#!/usr/bin/env python3
# WallPimp v0.6.0 - Config-Driven Wallpaper Collector
# Developer: 0xB0RN3 (github.com/0xb0rn3)
import sys
import os
import hashlib
import shutil
import tempfile
import asyncio
import configparser
import subprocess
import logging
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Optional

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

def is_venv():
    return sys.prefix != sys.base_prefix

# Function to set up the virtual environment and install dependencies
def setup_venv():
    venv_dir = os.path.join(os.path.dirname(__file__), "venv")
    if not os.path.exists(venv_dir):
        print("Creating virtual environment...")
        subprocess.check_call([sys.executable, "-m", "venv", venv_dir])
    venv_python = os.path.join(venv_dir, "bin", "python")
    print("Installing dependencies...")
    subprocess.check_call([venv_python, "-m", "pip", "install", "pyside6", "pillow"])
    return venv_python
# Dependency Check and Installation
def install_dependencies() -> bool:
    """Install required dependencies if missing."""
    required = {'PySide6': 'pyside6', 'Pillow': 'pillow'}

    def is_module_installed(module_name: str) -> bool:
        """Check if a module is installed."""
        try:
            __import__(module_name.lower())
            return True
        except ImportError:
            return False

    # Identify missing dependencies
    missing = [pkg for mod, pkg in required.items() if not is_module_installed(mod)]
    if not missing:
        logger.info("All dependencies are already installed.")
        return True

    try:
        subprocess.check_call([sys.executable, '-m', 'pip', '--version'])
        logger.info("pip is available.")
    except subprocess.CalledProcessError:
        logger.info("pip is not installed. Attempting to install pip...")
        # Step 2: Try installing pip using ensurepip
        try:
            subprocess.check_call([sys.executable, '-m', 'ensurepip'])
            logger.info("pip installed successfully using ensurepip.")
        except subprocess.CalledProcessError:
            # Step 3: If ensurepip fails, download and run get-pip.py
            logger.info("ensurepip failed. Downloading get-pip.py...")
            pip_installer = 'get-pip.py'
            import urllib.request
            urllib.request.urlretrieve('https://bootstrap.pypa.io/get-pip.py', pip_installer)
            subprocess.check_call([sys.executable, pip_installer])
            os.remove(pip_installer)  # Clean up
            logger.info("pip installed successfully using get-pip.py.")

    # Step 4: Install the missing dependencies
    try:
        pip_cmd = [sys.executable, '-m', 'pip', 'install'] + missing
        subprocess.run(pip_cmd, check=True)
        logger.info("Dependencies installed successfully: " + ", ".join(missing))
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to install dependencies: {e}")
        return False

if not install_dependencies():
    sys.exit(1)

# Imports After Dependencies
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QGridLayout, QLabel, QProgressBar, QPushButton, QFileDialog,
    QCheckBox, QGroupBox, QMessageBox, QMenuBar, QMenu
)
from PySide6.QtCore import Qt, QThreadPool, QRunnable, Signal, QObject, QTimer
from PySide6.QtGui import QAction, QFont, QKeySequence, QShortcut
from PIL import Image

class WorkerSignals(QObject):
    progress_updated = Signal(int)
    finished = Signal()
    error = Signal(str)

class WallpaperWorker(QRunnable):
    def __init__(self, repos: List[Dict], save_dir: Path):
        super().__init__()
        self.repos = repos
        self.save_dir = save_dir
        self.signals = WorkerSignals()
        self._is_running = True
        self.processed_hashes = set()
        self.batch_counter = 0
        self.BATCH_SIZE = 100
        self.supported_formats = {'.jpg', '.jpeg', '.png', '.webp'}
        self.executor = ThreadPoolExecutor(max_workers=os.cpu_count() or 4)
        self.total_files = 0  # Accurate count after scanning

    def stop(self):
        """Stop the worker gracefully."""
        self._is_running = False
        self.executor.shutdown(wait=False)

    def run(self):
        """Execute the worker in a separate thread."""
        try:
            asyncio.run(self._run())
        except Exception as e:
            self.signals.error.emit(f"Worker error: {e}")

    async def _run(self):
        """Asynchronous execution of repository processing."""
        try:
            self.total_files = await self.estimate_total_files()
            self.signals.progress_updated.emit(0)

            for repo in self.repos:
                if not self._is_running:
                    break
                await self.process_repository(repo)
            self.signals.finished.emit()
        except Exception as e:
            self.signals.error.emit(f"Run error: {e}")
        finally:
            self.executor.shutdown(wait=False)

    async def estimate_total_files(self) -> int:
        """Estimate total files by scanning repositories."""
        total = 0
        for repo in self.repos:
            temp_dir = Path(tempfile.mkdtemp())
            try:
                if await self.clone_repository(repo, temp_dir):
                    total += sum(1 for root, _, files in os.walk(temp_dir)
                                 for f in files if Path(f).suffix.lower() in self.supported_formats)
            finally:
                shutil.rmtree(temp_dir, ignore_errors=True)
        return total or 1  # Avoid division by zero

    async def clone_repository(self, repo: Dict, temp_dir: Path) -> bool:
        """Clone a git repository."""
        try:
            process = await asyncio.create_subprocess_exec(
                'git', 'clone', '--depth', '1', '--filter=blob:none',
                '--single-branch', '--branch', repo['branch'],
                repo['url'], str(temp_dir),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            if process.returncode != 0:
                logger.error(f"Git clone failed for {repo['url']}: {stderr.decode()}")
                return False
            return True
        except Exception as e:
            logger.error(f"Clone error for {repo['url']}: {e}")
            return False

    async def process_repository(self, repo: Dict):
        """Process a single repository."""
        temp_dir = Path(tempfile.mkdtemp())
        try:
            if not await self.clone_repository(repo, temp_dir):
                return

            futures = []
            for root, _, files in os.walk(temp_dir):
                if not self._is_running:
                    break
                for file in files:
                    file_path = Path(root) / file
                    if file_path.suffix.lower() in self.supported_formats:
                        futures.append(self.executor.submit(self.process_image, file_path))

            for future in as_completed(futures):
                if not self._is_running:
                    break
                try:
                    future.result()  # Ensure exceptions are caught
                    self.batch_counter += 1
                    if self.batch_counter % self.BATCH_SIZE == 0:
                        self.signals.progress_updated.emit(self.batch_counter * 100 // self.total_files)
                except Exception as e:
                    logger.warning(f"Image processing error: {e}")
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    def process_image(self, source: Path):
        """Process and save an image if valid and not a duplicate."""
        try:
            with Image.open(source) as img:
                if img.size[0] < 1920 or img.size[1] < 1080:
                    return
                file_hash = hashlib.sha256(source.read_bytes()).hexdigest()
                if file_hash in self.processed_hashes:
                    return
                output_path = self.save_dir / f"{file_hash}{source.suffix}"
                img.save(output_path, quality=95, optimize=True, compress_level=3)
                self.processed_hashes.add(file_hash)
        except (IOError, ValueError) as e:
            logger.warning(f"Failed to process {source}: {e}")

class WallpaperGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.load_repositories()
        self.worker: Optional[WallpaperWorker] = None
        self.thread_pool = QThreadPool.globalInstance()
        self.update_timer = QTimer()
        self.pending_updates = 0
        self.total_files = 0
        self.init_ui()
        self.setup_styles()
        self.setWindowTitle("WallPimp v0.6.0 - Wallpaper Collector")
        self.setMinimumSize(800, 600)

    def load_repositories(self):
        """Load repository configurations from config.ini."""
        config = configparser.ConfigParser()
        if not config.read('config.ini') or 'Repositories' not in config:
            self.create_default_config()
            config.read('config.ini')
        self.REPOSITORIES = [
            {'name': name.strip(), 'url': url.strip(), 'branch': branch.strip(),
             'icon': icon.strip(), 'desc': desc.strip()}
            for name, value in config['Repositories'].items()
            for icon, url, branch, desc in [value.split('|')]
        ]
        self.settings = dict(config['Settings']) if 'Settings' in config else {}
        self.estimated_images_per_repo = int(self.settings.get('estimated_images_per_repo', 150))
        self.average_image_size_mb = float(self.settings.get('average_image_size_mb', 5))

    def create_default_config(self):
        """Create a default config.ini if missing."""
        config = configparser.ConfigParser()
        config['Repositories'] = {
            'example': '🌟|https://github.com/example/wallpapers.git|main|Example wallpaper repo'
        }
        config['Settings'] = {
            'estimated_images_per_repo': '150',
            'average_image_size_mb': '5'
        }
        with open('config.ini', 'w') as f:
            config.write(f)
        logger.warning("Created default config.ini. Please customize it.")

    def setup_styles(self):
        """Apply custom styles to the GUI."""
        self.setStyleSheet("""
            QMainWindow { background-color: #f8f9fa; font-family: 'Segoe UI', Arial; }
            QGroupBox { border: 1px solid #dee2e6; border-radius: 6px; margin-top: 1ex; font-size: 13px; color: #2d3436; }
            QProgressBar { height: 20px; border-radius: 4px; border: 1px solid #ced4da; text-align: center; }
            QProgressBar::chunk { background-color: #4dabf7; border-radius: 3px; }
            QCheckBox { spacing: 8px; font-size: 13px; }
            QPushButton { padding: 8px 16px; border-radius: 4px; background-color: #e9ecef; border: 1px solid #dee2e6; min-width: 100px; }
            QPushButton:hover { background-color: #dee2e6; }
        """)

    def init_ui(self):
        """Initialize the GUI layout."""
        main_widget = QWidget()
        main_layout = QVBoxLayout()

        # Menu Bar
        menu_bar = QMenuBar()
        help_menu = QMenu("&Help", self)
        about_action = QAction("&About", self)
        about_action.triggered.connect(self.show_about)
        help_menu.addAction(about_action)
        menu_bar.addMenu(help_menu)
        self.setMenuBar(menu_bar)

        # Header
        header = QLabel("WallPimp - Intelligent Wallpaper Collector")
        header.setFont(QFont("Segoe UI", 16, QFont.Bold))
        header.setStyleSheet("color: #2c3e50; margin: 15px 0;")
        header.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(header)

        # Repository Grid
        repo_group = QGroupBox("Select Collections (Ctrl+A to select all)")
        repo_layout = QGridLayout()
        self.repo_checkboxes = []
        for i, repo in enumerate(self.REPOSITORIES):
            cb = QCheckBox(f"{repo['icon']} {repo['name']}")
            cb.setToolTip(repo['desc'])
            cb.setChecked(True)
            repo_layout.addWidget(cb, i // 3, i % 3)
            self.repo_checkboxes.append(cb)
        repo_group.setLayout(repo_layout)
        main_layout.addWidget(repo_group)

        # Select All Shortcut
        QShortcut(QKeySequence("Ctrl+A"), self, self.select_all_repos)

        # Progress Section
        progress_group = QGroupBox("Download Progress")
        progress_layout = QVBoxLayout()
        self.main_progress = QProgressBar()
        self.main_progress.setRange(0, 100)
        self.main_progress.setFormat("Overall Progress: %p%")
        progress_layout.addWidget(self.main_progress)
        progress_group.setLayout(progress_layout)
        main_layout.addWidget(progress_group)

        # Control Panel
        control_layout = QHBoxLayout()
        self.btn_dir = QPushButton("📁 Choose Folder")
        self.btn_dir.clicked.connect(self.choose_directory)
        self.dir_label = QLabel("No folder selected")
        self.dir_label.setStyleSheet("color: #6c757d; font-size: 12px;")
        self.btn_start = QPushButton("▶ Start Collection")
        self.btn_start.setStyleSheet("background-color: #4dabf7; color: white;")
        self.btn_start.clicked.connect(self.start_download)
        self.btn_stop = QPushButton("⏹ Stop")
        self.btn_stop.setStyleSheet("background-color: #ff6b6b; color: white;")
        self.btn_stop.clicked.connect(self.stop_download)
        self.btn_stop.setEnabled(False)

        control_layout.addWidget(self.btn_dir)
        control_layout.addWidget(self.dir_label)
        control_layout.addStretch()
        control_layout.addWidget(self.btn_start)
        control_layout.addWidget(self.btn_stop)
        main_layout.addLayout(control_layout)

        main_widget.setLayout(main_layout)
        self.setCentralWidget(main_widget)

        self.update_timer.setInterval(200)
        self.update_timer.timeout.connect(self.update_display)

    def select_all_repos(self):
        """Select or deselect all repository checkboxes."""
        all_checked = all(cb.isChecked() for cb in self.repo_checkboxes)
        for cb in self.repo_checkboxes:
            cb.setChecked(not all_checked)

    def choose_directory(self):
        """Select the save directory."""
        path = QFileDialog.getExistingDirectory(self, "Select Save Directory")
        if path:
            self.save_dir = Path(path)
            self.dir_label.setText(path)
            self.dir_label.setStyleSheet("color: #2c3e50; font-size: 12px;")

    def start_download(self):
        """Start the wallpaper download process with disk space check."""
        selected_repos = [repo for repo, cb in zip(self.REPOSITORIES, self.repo_checkboxes) if cb.isChecked()]
        if not selected_repos:
            QMessageBox.warning(self, "Error", "Please select at least one collection!")
            return

        if not hasattr(self, 'save_dir'):
            QMessageBox.warning(self, "Error", "Please select a save directory first!")
            return

        # Estimate required space
        estimated_total_images = len(selected_repos) * self.estimated_images_per_repo
        estimated_required_space_mb = estimated_total_images * self.average_image_size_mb

        # Check available space
        disk_usage = shutil.disk_usage(self.save_dir)
        available_space_mb = disk_usage.free / (1024 * 1024)  # Convert bytes to MB

        # Warn user if space might be insufficient
        if available_space_mb < estimated_required_space_mb:
            reply = QMessageBox.question(
                self, "Low Disk Space",
                f"Estimated required space: {estimated_required_space_mb:.2f} MB\n"
                f"Available space: {available_space_mb:.2f} MB\n"
                "Proceed anyway?",
                QMessageBox.Yes | QMessageBox.No, QMessageBox.No
            )
            if reply == QMessageBox.No:
                return

        self.total_files = len(selected_repos) * 150  # Estimated file count
        self.main_progress.setValue(0)

        self.worker = WallpaperWorker(selected_repos, self.save_dir)
        self.worker.signals.progress_updated.connect(self.queue_update)
        self.worker.signals.finished.connect(self.download_finished)
        self.worker.signals.error.connect(self.show_error)

        self.btn_start.setEnabled(False)
        self.btn_stop.setEnabled(True)
        self.thread_pool.start(self.worker)
        self.update_timer.start()

    def queue_update(self, count):
        """Queue progress updates."""
        self.pending_updates += count
        progress = min(int((self.pending_updates / self.total_files) * 100), 100)
        self.main_progress.setValue(progress)

    def update_display(self):
        """Update the progress bar display."""
        if self.pending_updates > 0:
            self.main_progress.repaint()
            self.pending_updates = 0

    def stop_download(self):
        """Stop the download process."""
        if self.worker:
            self.worker.stop()
        self.btn_start.setEnabled(True)
        self.btn_stop.setEnabled(False)
        self.update_timer.stop()

    def download_finished(self):
        """Handle download completion."""
        self.stop_download()
        QMessageBox.information(self, "Complete",
                                "Download finished successfully!\n"
                                f"Wallpapers saved to: {self.save_dir}")

    def show_error(self, message):
        """Display an error message."""
        QMessageBox.critical(self, "Error", message)
        self.stop_download()

    def show_about(self):
        """Show the About dialog."""
        about_text = """
        <div style='text-align: center'>
            <h3>WallPimp v0.6.0 Config-Driven</h3>
            <p>Developed by <b>0xB0RN3</b></p>
            <p>GitHub: <a href='https://github.com/0xb0rn3'>github.com/0xb0rn3</a></p>
            <hr>
            <p style='color: #6c757d;'>
                Features:<br>
                • Dynamic repository configuration<br>
                • Intelligent wallpaper collection<br>
                • Duplicate prevention<br>
                • Cross-platform support<br>
                • Customizable sources
            </p>
        </div>"""
        msg = QMessageBox(self)
        msg.setWindowTitle("About WallPimp")
        msg.setTextFormat(Qt.TextFormat.RichText)
        msg.setText(about_text)
        msg.setStandardButtons(QMessageBox.StandardButton.Ok)
        msg.exec()

def main():
    # Ensure git is available
    try:
        subprocess.run(['git', '--version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Git is required. Please install Git and ensure it's in your system PATH.")
        sys.exit(1)

    # Check config file exists
    if not os.path.exists('config.ini'):
        print("Error: config.ini not found. A default will be created upon startup.")
    
    # Create application and run
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    window = WallpaperGUI()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    if "--in-venv" not in sys.argv and not is_venv():
        print("Setting up environment...")
        try:
            venv_python = setup_venv()
            print("Re-running script in virtual environment...")
            # Re-run the script in the virtual environment
            subprocess.run([venv_python, sys.argv[0], "--in-venv"])
            sys.exit(0)
        except Exception as e:
            print(f"Failed to set up environment: {e}")
            sys.exit(1)
    else:
        main()
