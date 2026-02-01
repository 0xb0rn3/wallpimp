#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <signal.h>

#define MAX_PATH 4096
#define MAX_FILES 10000
#define CONFIG_PATH "/.config/wallpimp/config.json"

typedef struct {
    char path[MAX_PATH];
} WallpaperFile;

typedef struct {
    char wallpaper_dir[MAX_PATH];
    int interval;
    char desktop_env[32];
} Config;

static volatile int running = 1;

void signal_handler(int sig) {
    running = 0;
}

int is_image_file(const char *filename) {
    const char *ext = strrchr(filename, '.');
    if (!ext) return 0;
    
    const char *valid_exts[] = {
        ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".tiff", ".svg", NULL
    };
    
    for (int i = 0; valid_exts[i] != NULL; i++) {
        if (strcasecmp(ext, valid_exts[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

void scan_directory(const char *dir_path, WallpaperFile *files, int *count, int max_files) {
    DIR *dir = opendir(dir_path);
    if (!dir) return;
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL && *count < max_files) {
        if (entry->d_name[0] == '.') continue;
        
        char full_path[MAX_PATH];
        snprintf(full_path, MAX_PATH, "%s/%s", dir_path, entry->d_name);
        
        struct stat st;
        if (stat(full_path, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                scan_directory(full_path, files, count, max_files);
            } else if (S_ISREG(st.st_mode) && is_image_file(entry->d_name)) {
                strncpy(files[*count].path, full_path, MAX_PATH);
                (*count)++;
            }
        }
    }
    closedir(dir);
}

int load_config(Config *config) {
    char config_file[MAX_PATH];
    snprintf(config_file, MAX_PATH, "%s%s", getenv("HOME"), CONFIG_PATH);
    
    FILE *f = fopen(config_file, "r");
    if (!f) {
        fprintf(stderr, "Error: Cannot open config file\n");
        return 0;
    }
    
    char line[MAX_PATH];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"wallpaper_dir\"")) {
            char *start = strchr(line, ':');
            if (start) {
                start = strchr(start, '"');
                if (start) {
                    start++;
                    char *end = strchr(start, '"');
                    if (end) {
                        int len = end - start;
                        strncpy(config->wallpaper_dir, start, len);
                        config->wallpaper_dir[len] = '\0';
                    }
                }
            }
        } else if (strstr(line, "\"slideshow_interval\"")) {
            char *start = strchr(line, ':');
            if (start) {
                config->interval = atoi(start + 1);
            }
        }
    }
    
    fclose(f);
    return 1;
}

const char* detect_desktop_env() {
    const char *de = getenv("XDG_CURRENT_DESKTOP");
    if (de) {
        if (strcasestr(de, "xfce")) return "xfce";
        if (strcasestr(de, "gnome")) return "gnome";
        if (strcasestr(de, "kde") || strcasestr(de, "plasma")) return "kde";
        if (strcasestr(de, "mate")) return "mate";
        if (strcasestr(de, "cinnamon")) return "cinnamon";
    }
    
    de = getenv("DESKTOP_SESSION");
    if (de) {
        if (strcasestr(de, "xfce")) return "xfce";
        if (strcasestr(de, "gnome")) return "gnome";
        if (strcasestr(de, "kde") || strcasestr(de, "plasma")) return "kde";
        if (strcasestr(de, "i3")) return "i3";
        if (strcasestr(de, "sway")) return "sway";
    }
    
    return "unknown";
}

void set_xfce_wallpaper(const char *path) {
    char cmd[MAX_PATH * 2];
    
    FILE *fp = popen("xfconf-query -c xfce4-desktop -l | grep last-image", "r");
    if (!fp) return;
    
    char property[MAX_PATH];
    while (fgets(property, sizeof(property), fp)) {
        property[strcspn(property, "\n")] = 0;
        snprintf(cmd, sizeof(cmd), "xfconf-query -c xfce4-desktop -p '%s' -s '%s' 2>/dev/null", 
                 property, path);
        system(cmd);
    }
    pclose(fp);
}

void set_gnome_wallpaper(const char *path) {
    char cmd[MAX_PATH * 2];
    snprintf(cmd, sizeof(cmd), 
             "gsettings set org.gnome.desktop.background picture-uri 'file://%s' 2>/dev/null", path);
    system(cmd);
    
    snprintf(cmd, sizeof(cmd), 
             "gsettings set org.gnome.desktop.background picture-uri-dark 'file://%s' 2>/dev/null", path);
    system(cmd);
}

void set_kde_wallpaper(const char *path) {
    char cmd[MAX_PATH * 2];
    snprintf(cmd, sizeof(cmd),
             "qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
             "\"var d=desktops();for(i=0;i<d.length;i++){d[i].wallpaperPlugin='org.kde.image';"
             "d[i].currentConfigGroup=Array('Wallpaper','org.kde.image','General');"
             "d[i].writeConfig('Image','file://%s')}\" 2>/dev/null", path);
    system(cmd);
}

void set_feh_wallpaper(const char *path) {
    char cmd[MAX_PATH * 2];
    snprintf(cmd, sizeof(cmd), "feh --bg-fill '%s' 2>/dev/null", path);
    system(cmd);
}

void set_wallpaper(const char *path, const char *de) {
    printf("Setting wallpaper: %s\n", path);
    
    if (strcmp(de, "xfce") == 0) {
        set_xfce_wallpaper(path);
    } else if (strcmp(de, "gnome") == 0) {
        set_gnome_wallpaper(path);
    } else if (strcmp(de, "kde") == 0) {
        set_kde_wallpaper(path);
    } else {
        set_feh_wallpaper(path);
    }
}

int main(int argc, char *argv[]) {
    Config config = {0};
    config.interval = 300; // Default 5 minutes
    
    // Load configuration
    if (!load_config(&config)) {
        fprintf(stderr, "Failed to load config, using defaults\n");
        snprintf(config.wallpaper_dir, MAX_PATH, "%s/Pictures/Wallpapers", getenv("HOME"));
    }
    
    // Detect desktop environment
    const char *de = detect_desktop_env();
    strncpy(config.desktop_env, de, sizeof(config.desktop_env) - 1);
    
    printf("WallPimp Slideshow Daemon\n");
    printf("Directory: %s\n", config.wallpaper_dir);
    printf("Interval: %d seconds\n", config.interval);
    printf("Desktop: %s\n", config.desktop_env);
    
    // Setup signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Scan for wallpapers
    WallpaperFile *files = malloc(sizeof(WallpaperFile) * MAX_FILES);
    if (!files) {
        fprintf(stderr, "Memory allocation failed\n");
        return 1;
    }
    
    int file_count = 0;
    scan_directory(config.wallpaper_dir, files, &file_count, MAX_FILES);
    
    if (file_count == 0) {
        fprintf(stderr, "No wallpapers found in %s\n", config.wallpaper_dir);
        free(files);
        return 1;
    }
    
    printf("Found %d wallpapers\n", file_count);
    
    // Initialize random seed
    srand(time(NULL));
    
    // Main slideshow loop
    while (running) {
        int index = rand() % file_count;
        set_wallpaper(files[index].path, config.desktop_env);
        
        // Sleep in small intervals to allow clean shutdown
        for (int i = 0; i < config.interval && running; i++) {
            sleep(1);
        }
    }
    
    printf("Slideshow stopped\n");
    free(files);
    return 0;
}
