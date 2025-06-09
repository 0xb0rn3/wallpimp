# WallPimp - The Ultimate Wallpaper Manager

```
██╗    ██╗ █████╗ ██╗     ██╗     ██████╗ ██╗███╗   ███╗██████╗ 
██║    ██║██╔══██╗██║     ██║     ██╔══██╗██║████╗ ████║██╔══██╗
██║ █╗ ██║███████║██║     ██║     ██████╔╝██║██╔████╔██║██████╔╝
██║███╗██║██╔══██║██║     ██║     ██╔═══╝ ██║██║╚██╔╝██║██╔═══╝ 
╚███╔███╔╝██║  ██║███████╗███████╗██║     ██║██║ ╚═╝ ██║██║     
 ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝╚═╝     ╚═╝╚═╝     
```

**Version 0.0.1** - A cross-platform wallpaper management tool that intelligently downloads and organizes high-quality wallpapers from curated GitHub repositories.

WallPimp transforms the tedious process of wallpaper collection into an automated, efficient experience. Built with Python for maximum compatibility, it handles everything from dependency management to duplicate detection, ensuring you get the best wallpapers without the hassle.

## Key Features

WallPimp delivers a comprehensive wallpaper management solution with these powerful capabilities:

**Intelligent Repository Management**: Access twelve carefully curated repositories spanning minimalist designs, anime artwork, nature landscapes, gaming-inspired art, and professional photography. Each repository is automatically scanned for image files using GitHub's API, ensuring you never miss new additions.

**Automatic Dependency Management**: The tool handles its own setup by detecting and installing required Python packages automatically. This means you can run WallPimp immediately after download without worrying about missing dependencies or complex installation procedures.

**Cross-Platform Compatibility**: Designed to work seamlessly across Windows, macOS, and Linux systems. The tool automatically detects your operating system and configures appropriate default directories, following platform-specific conventions for storing downloaded wallpapers.

**Smart Caching System**: Built-in cache management prevents duplicate downloads and tracks your collection across sessions. The cache system includes cleanup functionality to maintain consistency when files are manually moved or deleted.

**Concurrent Download Engine**: Utilize multi-threaded downloading to maximize your bandwidth while respecting rate limits. The configurable worker system allows you to balance download speed with system resources.

**Image Verification**: Every downloaded image undergoes validation to ensure file integrity. Corrupted or invalid files are automatically detected and removed, maintaining the quality of your collection.

**Comprehensive Progress Tracking**: Real-time progress bars and statistics keep you informed about download status, including files downloaded, skipped, failed, and total storage space used.

**Flexible Command-Line Interface**: Whether you prefer quick one-time downloads or interactive exploration, WallPimp accommodates different usage patterns with intuitive command-line options.

## Repository Collection

WallPimp connects to these expertly curated repositories:

🖼️ **Minimalist** - Clean, simple designs perfect for distraction-free desktops
🌸 **Anime** - High-quality anime and manga artwork from dedicated collections
🌿 **Nature** - Breathtaking natural landscapes and scenic photography
🏞️ **Scenic** - Stunning vistas and panoramic views from around the world
🎨 **Artistic** - Creative and aesthetic wallpapers with unique visual styles
🎎 **Anime Pack** - Carefully curated anime art collections
🐧 **Linux** - Desktop art specifically chosen for Linux environments
🌟 **Mixed** - Diverse collections spanning multiple artistic styles
💻 **Desktop** - Minimalist designs optimized for desktop environments
🎮 **Gaming** - Gaming-inspired artwork and designs
📷 **Photos** - Professional photography collections
🖥️ **Digital** - Modern digital art and computer-generated imagery

## Installation and Setup

Getting started with WallPimp requires only Python 3.6 or later. The tool handles all other dependencies automatically, making installation straightforward regardless of your operating system.

### Quick Start

Download the WallPimp script and run it directly. The tool will automatically install required dependencies during its first execution:

```bash
# Download the script
curl -O https://raw.githubusercontent.com/0xb0rn3/wallpimp/main/wallpimp.py

# Make it executable (Linux/macOS)
chmod +x wallpimp.py

# Run WallPimp
python wallpimp.py
```

### System Requirements

WallPimp requires minimal system resources but benefits from adequate storage space and network connectivity:

**Python Version**: Python 3.6 or later is required for compatibility with all features. The tool uses modern Python features like f-strings and type hints for improved code clarity and performance.

**Storage Space**: Each repository typically contains 50-500 wallpapers ranging from 100KB to 10MB per file. Plan for approximately 2-5GB of storage space per repository, though actual requirements vary based on collection size and image quality.

**Network Connection**: A stable internet connection is essential for downloading from GitHub repositories. The tool implements retry logic and error handling to manage temporary network issues gracefully.

**Memory Usage**: WallPimp uses efficient streaming downloads to minimize memory consumption. Typical memory usage remains under 100MB even during intensive download operations.

## Usage Guide

WallPimp offers flexible usage patterns to accommodate different workflows and preferences. Understanding these options helps you maximize the tool's effectiveness.

### Command-Line Operations

The tool provides comprehensive command-line functionality for both quick operations and detailed control:

```bash
# List all available repositories
python wallpimp.py --list

# Download from a specific repository
python wallpimp.py --repo anime

# Download from all repositories
python wallpimp.py --all

# Specify custom download directory
python wallpimp.py --repo nature --dir /path/to/wallpapers

# Adjust concurrent download workers
python wallpimp.py --repo gaming --workers 8

# Clean up cache and remove orphaned entries
python wallpimp.py --cleanup
```

### Interactive Mode

Running WallPimp without arguments launches interactive mode, which provides a user-friendly interface for exploring repositories:

```bash
python wallpimp.py
```

Interactive mode displays the ASCII banner, lists available repositories with descriptions, and provides guidance for command-line usage. This mode is particularly helpful for first-time users or when exploring new repositories.

### Advanced Configuration

Power users can customize WallPimp's behavior through various command-line options:

**Worker Threads**: Adjust the number of concurrent download workers based on your system capabilities and network capacity. More workers increase download speed but consume additional system resources.

**Custom Directories**: Specify custom download locations to organize wallpapers according to your preferences. The tool maintains repository-based subdirectories within your chosen location.

**Cache Management**: Regular cache cleanup ensures optimal performance and storage efficiency. The cleanup operation removes references to deleted files and optimizes cache structure.

## Understanding the Architecture

WallPimp's architecture reflects modern software design principles, emphasizing modularity, error resilience, and user experience. Understanding these design decisions helps explain the tool's reliability and performance characteristics.

### Repository Integration

The tool integrates with GitHub's REST API to discover and download wallpapers. This approach provides several advantages over web scraping or static file lists. The API integration enables automatic discovery of new files, provides detailed metadata for each image, and supports recursive directory traversal for comprehensive repository scanning.

Each repository is scanned recursively, meaning the tool explores all subdirectories to find image files. This comprehensive approach ensures no wallpapers are missed, even in repositories with complex organizational structures.

### Download Management

The concurrent download system balances speed with resource management. Multiple worker threads handle downloads simultaneously while respecting rate limits to maintain good citizenship with GitHub's infrastructure. Each download includes verification steps to ensure file integrity and proper image format validation.

Progress tracking provides real-time feedback without overwhelming the user interface. The system displays individual file progress for active downloads while maintaining overall statistics for the entire operation.

### Cache and Storage

The caching system serves multiple purposes beyond preventing duplicate downloads. It tracks download history across sessions, maintains metadata about each repository, and supports cleanup operations to maintain consistency. The cache uses JSON format for human readability and easy debugging.

Storage organization follows platform conventions while maintaining logical groupings. Each repository creates its own subdirectory structure, preserving the original organization while preventing filename conflicts.

## Troubleshooting Common Issues

Understanding common issues and their solutions helps ensure smooth operation across different environments and use cases.

### Dependency Problems

If the automatic dependency installation fails, you can manually install required packages:

```bash
pip install requests tqdm pillow colorama
```

On systems with multiple Python versions, ensure you're using the correct pip command corresponding to your Python 3 installation. Some systems require `pip3` instead of `pip`.

### Network and API Issues

GitHub API rate limiting may affect download speed during intensive operations. The tool includes built-in delays and retry logic to handle these situations gracefully. If you encounter persistent rate limiting, consider reducing the number of worker threads or spacing out large download operations.

Network connectivity issues typically resolve automatically through the tool's retry mechanisms. However, persistent connectivity problems may require checking your internet connection or firewall settings.

### Storage and Permissions

Ensure adequate storage space before beginning large download operations. The tool provides warnings when storage space becomes limited, but cannot prevent all storage-related issues.

Permission errors typically occur when the chosen download directory is protected or when running the tool in restricted environments. Choose a directory with appropriate write permissions or run the tool with elevated privileges if necessary.

### Image Validation Failures

Occasional image validation failures are normal and typically indicate corrupted downloads or network issues. The tool automatically removes invalid files and continues operation. Persistent validation failures may indicate broader network problems or issues with specific repositories.

## Contributing and Development

WallPimp welcomes contributions from the community. The codebase is designed for maintainability and extensibility, making it straightforward to add new features or improve existing functionality.

### Code Organization

The tool follows object-oriented design principles with clear separation of concerns. The main `WallPimp` class encapsulates all functionality while maintaining clean interfaces for extension. Helper methods handle specific tasks like API interaction, file management, and progress tracking.

### Adding New Repositories

Adding new repositories requires updating the `REPOSITORIES` dictionary with appropriate metadata. Each repository entry includes display information, GitHub URLs, and descriptive text. The tool automatically handles the technical aspects of repository integration.

### Performance Optimization

Performance improvements can focus on several areas including download parallelization, caching efficiency, and memory usage optimization. The current implementation balances performance with resource consumption for broad compatibility.

### Testing and Quality Assurance

Comprehensive error handling and logging support debugging and quality assurance efforts. The tool generates detailed logs for troubleshooting while providing user-friendly error messages for common issues.

## License and Acknowledgments

WallPimp builds upon the excellent work of repository maintainers who curate high-quality wallpaper collections. The tool serves as a bridge between these collections and end users, making quality wallpapers more accessible while respecting the original creators' work.

The implementation uses established Python libraries and follows community best practices for code organization, error handling, and user interface design. This approach ensures reliability while maintaining compatibility across different environments and use cases.

---

*WallPimp Version 0.0.1 - Making quality wallpapers accessible to everyone*
