use std::path::Path;
use tauri::AppHandle;
use tauri_plugin_dialog::DialogExt;

#[tauri::command]
pub async fn select_executable(app: AppHandle) -> Result<Option<String>, String> {
    let extensions = get_executable_extensions();

    let file_path = app
        .dialog()
        .file()
        .set_title("Select Program")
        .add_filter("Executables", &extensions)
        .add_filter("All Files", &["*"])
        .blocking_pick_file();

    match file_path {
        Some(file_path) => {
            match file_path.as_path() {
                Some(path) => Ok(Some(path.to_string_lossy().to_string())),
                None => Err("Failed to get file path".to_string()),
            }
        }
        None => Ok(None),
    }
}

#[tauri::command]
pub async fn select_icon(app: AppHandle) -> Result<Option<String>, String> {
    let file_path = app
        .dialog()
        .file()
        .set_title("Select Icon")
        .add_filter("Images", &["png", "jpg", "jpeg", "gif", "ico", "svg", "icns", "bmp"])
        .add_filter("All Files", &["*"])
        .blocking_pick_file();

    match file_path {
        Some(file_path) => {
            match file_path.as_path() {
                Some(path) => Ok(Some(path.to_string_lossy().to_string())),
                None => Err("Failed to get file path".to_string()),
            }
        }
        None => Ok(None),
    }
}

#[tauri::command]
pub fn file_exists(path: String) -> bool {
    Path::new(&path).exists()
}

fn get_executable_extensions() -> Vec<&'static str> {
    #[cfg(target_os = "windows")]
    {
        vec!["exe", "bat", "cmd", "msi", "lnk"]
    }

    #[cfg(target_os = "macos")]
    {
        vec!["app", "sh"]
    }

    #[cfg(target_os = "linux")]
    {
        vec!["desktop", "sh", "AppImage"]
    }

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        vec!["*"]
    }
}
