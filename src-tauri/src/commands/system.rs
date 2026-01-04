#[tauri::command]
pub fn get_platform() -> String {
    #[cfg(target_os = "windows")]
    {
        "win32".to_string()
    }

    #[cfg(target_os = "macos")]
    {
        "darwin".to_string()
    }

    #[cfg(target_os = "linux")]
    {
        "linux".to_string()
    }

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        "unknown".to_string()
    }
}
