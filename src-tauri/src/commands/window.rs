use tauri::{AppHandle, WebviewWindow};

#[tauri::command]
pub async fn minimize_window(window: WebviewWindow) -> Result<(), String> {
    window.minimize().map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn maximize_window(window: WebviewWindow) -> Result<(), String> {
    if window.is_maximized().unwrap_or(false) {
        window.unmaximize().map_err(|e| e.to_string())
    } else {
        window.maximize().map_err(|e| e.to_string())
    }
}

#[tauri::command]
pub async fn close_window(window: WebviewWindow) -> Result<(), String> {
    // Hide instead of close (minimize to tray behavior)
    window.hide().map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn quit_app(app: AppHandle) -> Result<(), String> {
    app.exit(0);
    Ok(())
}

#[tauri::command]
pub async fn is_maximized(window: WebviewWindow) -> Result<bool, String> {
    window.is_maximized().map_err(|e| e.to_string())
}
