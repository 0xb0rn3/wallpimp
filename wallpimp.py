#!/usr/bin/env python3
# WallPimp v0.5.0 - Config-Driven Wallpaper Collector
# Developer: 0xB0RN3 (github.com/0xb0rn3)
import sys
import os
import hashlib
import shutil
import tempfile
import asyncio
import configparser
import importlib
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass

# Dependency Check and Installation
def install_dependencies():
    try:
        import subprocess
        import sys
        
        # Detect package manager
        if shutil.which('pip3'):
            pip_command = [sys.executable, '-m', 'pip', 'install', '--user']
        elif shutil.which('pip'):
            pip_command = ['pip', 'install', '--user']
        else:
            print("No pip installation found. Please install pip.")
            sys.exit(1)

        required = {
            'PySide6': 'pyside6', 
            'Pillow': 'pillow'
        }
        
        # Check for missing dependencies
        missing = []
        for module, package in required.items():
            try:
                __import__(module.lower())
            except ImportError:
                missing.append(package)

        # Install missing dependencies
        if missing:
            print(f"Missing dependencies: {', '.join(missing)}")
            try:
                subprocess.run(
                    pip_command + missing, 
                    check=True, 
                    stdout=subprocess.DEVNULL, 
                    stderr=subprocess.DEVNULL
                )
                print("Dependencies installed successfully!")
            except subprocess.CalledProcessError:
                print("Automatic installation failed. Please install manually:")
                print(f"Run: pip3 install {' '.join(missing)}")
                sys.exit(1)

    except Exception as e:
        print(f"Dependency installation error: {e}")
        sys.exit(1)

# Ensure all dependencies are installed
install_dependencies()

# Imports After Dependencies
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QGridLayout, QLabel, QProgressBar, QPushButton, QFileDialog, 
    QCheckBox, QGroupBox, QMessageBox, QMenuBar, QMenu
)
from PySide6.QtCore import Qt, QThreadPool, QRunnable, Signal, QObject, QTimer
from PySide6.QtGui import QAction, QFont
from PIL import Image

class WorkerSignals(QObject):
    repo_started = Signal(dict)
    repo_finished = Signal(dict, bool)
    progress_updated = Signal(int)
    error = Signal(str)
    finished = Signal()

class WallpaperWorker(QRunnable):
    def __init__(self, repos, save_dir):
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

    def stop(self):
        self._is_running = False
        self.executor.shutdown(wait=True)

    def run(self):
        try:
            import asyncio
            asyncio.run(self._run())
        except Exception as e:
            self.signals.error.emit(str(e))

    async def _run(self):
        try:
            total_files = sum([150 for _ in self.repos])  # Rough estimation
            self.signals.progress_updated.emit(0)
            
            for repo in self.repos:
                if not self._is_running: 
                    break
                await self.process_repository(repo)
                
            self.signals.finished.emit()
        except Exception as e:
            self.signals.error.emit(str(e))
        finally:
            self.executor.shutdown(wait=False)

    async def process_repository(self, repo):
        self.signals.repo_started.emit(repo)
        temp_dir = Path(tempfile.mkdtemp())
        try:
            process = await asyncio.create_subprocess_exec(
                'git', 'clone', '--depth', '1',
                '--filter=blob:none',
                '--single-branch',
                '--branch', repo['branch'], 
                repo['url'], str(temp_dir),
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL
            )
            
            if await process.wait() != 0:
                return False

            futures = []
            for root, _, files in os.walk(temp_dir):
                for file in files:
                    file_path = Path(root) / file
                    if file_path.suffix.lower() in self.supported_formats:
                        futures.append(
                            self.executor.submit(self.process_image, file_path)
                        )
            
            for future in as_completed(futures):
                if not self._is_running:
                    break
                await future
                self.batch_counter += 1
                if self.batch_counter % self.BATCH_SIZE == 0:
                    self.signals.progress_updated.emit(self.BATCH_SIZE)
                    
            self.signals.repo_finished.emit(repo, True)
            return True
        except Exception as e:
            print(f"Repository processing error: {e}")
            self.signals.repo_finished.emit(repo, False)
            return False
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    def process_image(self, source):
        try:
            with Image.open(source) as img:
                if img.size[0] < 1920 or img.size[1] < 1080:
                    return
                with open(source, 'rb') as f:
                    file_hash = hashlib.sha256(f.read()).hexdigest()
                if file_hash in self.processed_hashes:
                    return
                output_path = self.save_dir / f"{file_hash}{source.suffix}"
                img.save(output_path, 
                        quality=95,
                        optimize=True,
                        compress_level=3)
                self.processed_hashes.add(file_hash)
        except Exception:
            pass

class WallpaperGUI(QMainWindow):
    def __init__(self):
        super().__init__()
        self.load_repositories()
        self.worker = None
        self.thread_pool = QThreadPool.globalInstance()
        self.update_timer = QTimer()
        self.pending_updates = 0
        self.total_files = 0
        self.init_ui()
        self.setup_styles()
        self.setWindowTitle("WallPimp v0.5.0 - Wallpaper Collector")
        self.setMinimumSize(800, 600)

    def load_repositories(self):
        config = configparser.ConfigParser()
        config.read('config.ini')
        
        self.REPOSITORIES = []
        for name, value in config['Repositories'].items():
            icon, url, branch, desc = value.split('|')
            self.REPOSITORIES.append({
                'name': name.strip(),
                'url': url.strip(),
                'branch': branch.strip(),
                'icon': icon.strip(),
                'desc': desc.strip()
            })

    def setup_styles(self):
        self.setStyleSheet("""
            QMainWindow { 
                background-color: #f8f9fa;
                font-family: 'Segoe UI', Arial;
            }
            QGroupBox { 
                border: 1px solid #dee2e6;
                border-radius: 6px;
                margin-top: 1ex;
                font-size: 13px;
                color: #2d3436;
            }
            QProgressBar { 
                height: 20px;
                border-radius: 4px;
                border: 1px solid #ced4da;
                text-align: center;
            }
            QProgressBar::chunk { 
                background-color: #4dabf7;
                border-radius: 3px;
            }
            QCheckBox { 
                spacing: 8px; 
                font-size: 13px;
            }
            QPushButton {
                padding: 8px 16px;
                border-radius: 4px;
                background-color: #e9ecef;
                border: 1px solid #dee2e6;
                min-width: 100px;
            }
            QPushButton:hover {
                background-color: #dee2e6;
            }
        """)

    def init_ui(self):
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
            repo_layout.addWidget(cb, i//3, i%3)
            self.repo_checkboxes.append(cb)
        
        repo_group.setLayout(repo_layout)
        main_layout.addWidget(repo_group)

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

        # Setup update timer
        self.update_timer.setInterval(200)
        self.update_timer.timeout.connect(self.update_display)

    def choose_directory(self):
        path = QFileDialog.getExistingDirectory(self, "Select Save Directory")
        if path:
            self.save_dir = Path(path)
            self.dir_label.setText(path)
            self.dir_label.setStyleSheet("color: #2c3e50; font-size: 12px;")

    def start_download(self):
        if not hasattr(self, 'save_dir'):
            QMessageBox.warning(self, "Error", "Please select a save directory first!")
            return

        selected_repos = [repo for repo, cb in zip(self.REPOSITORIES, self.repo_checkboxes) if cb.isChecked()]
        if not selected_repos:
            QMessageBox.warning(self, "Error", "Please select at least one collection!")
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
        self.pending_updates += count
        progress = min(int((self.pending_updates / self.total_files) * 100), 100)
        self.main_progress.setValue(progress)

    def update_display(self):
        if self.pending_updates > 0:
            self.main_progress.repaint()
            self.pending_updates = 0

    def stop_download(self):
        if self.worker: 
            self.worker.stop()
        self.btn_start.setEnabled(True)
        self.btn_stop.setEnabled(False)
        self.update_timer.stop()

    def download_finished(self):
        self.stop_download()
        QMessageBox.information(self, "Complete", 
            "Download finished successfully!\n"
            f"Wallpapers saved to: {self.save_dir}")

    def show_error(self, message):
        QMessageBox.critical(self, "Error", message)
        self.stop_download()

    def show_about(self):
        about_text = """
        <div style='text-align: center'>
            <h3>WallPimp v0.5.0 Config-Driven</h3>
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
        import subprocess
        subprocess.run(['git', '--version'], 
                       stdout=subprocess.DEVNULL, 
                       stderr=subprocess.DEVNULL, 
                       check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Git is required. Please install Git and ensure it's in your system PATH.")
        sys.exit(1)

    # Check config file exists
    if not os.path.exists('config.ini'):
        print("Error: config.ini not found. Please ensure the configuration file is present.")
        sys.exit(1)

    # Create application and run
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    window = WallpaperGUI()
    window.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
