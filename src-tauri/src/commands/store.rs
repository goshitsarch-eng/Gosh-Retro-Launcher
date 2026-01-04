use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::fs;
use tauri::AppHandle;
use tauri_plugin_dialog::DialogExt;
use tauri_plugin_store::StoreExt;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowState {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    pub minimized: bool,
    pub maximized: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProgramItem {
    pub id: String,
    pub name: String,
    pub path: String,
    pub icon: String,
    pub working_dir: String,
    pub shortcut_key: String,
    pub launch_group: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProgramGroup {
    pub id: String,
    pub name: String,
    pub icon: String,
    pub window_state: WindowState,
    pub items: Vec<ProgramItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    pub auto_arrange: bool,
    pub minimize_on_use: bool,
    pub save_settings_on_exit: bool,
    pub launch_delay: u64,
    pub tray_on_close: bool,
    pub group_chrome_scale: f64,
    pub theme: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoreData {
    pub groups: Vec<ProgramGroup>,
    pub settings: AppSettings,
}

#[derive(Debug, Serialize)]
pub struct ImportResult {
    pub success: bool,
    pub error: Option<String>,
}

const STORE_FILE: &str = "program-manager-data.json";

fn get_default_settings() -> AppSettings {
    AppSettings {
        auto_arrange: true,
        minimize_on_use: false,
        save_settings_on_exit: true,
        launch_delay: 500,
        tray_on_close: true,
        group_chrome_scale: 1.0,
        theme: "light".to_string(),
    }
}

#[tauri::command]
pub async fn store_get(app: AppHandle, key: String) -> Result<Value, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    Ok(store.get(&key).unwrap_or(Value::Null))
}

#[tauri::command]
pub async fn store_set(app: AppHandle, key: String, value: Value) -> Result<(), String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    store.set(key, value);
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub async fn store_get_all(app: AppHandle) -> Result<StoreData, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;

    let groups: Vec<ProgramGroup> = store
        .get("groups")
        .and_then(|v| serde_json::from_value(v).ok())
        .unwrap_or_default();

    let settings: AppSettings = store
        .get("settings")
        .and_then(|v| serde_json::from_value(v).ok())
        .unwrap_or_else(get_default_settings);

    Ok(StoreData { groups, settings })
}

#[tauri::command]
pub async fn store_export(app: AppHandle) -> Result<bool, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;

    let file_path = app
        .dialog()
        .file()
        .set_title("Export Settings")
        .set_file_name("program-manager-backup.json")
        .add_filter("JSON Files", &["json"])
        .blocking_save_file();

    match file_path {
        Some(file_path) => {
            let groups = store.get("groups").unwrap_or(json!([]));
            let settings = store
                .get("settings")
                .unwrap_or_else(|| serde_json::to_value(get_default_settings()).unwrap());

            let data = json!({
                "groups": groups,
                "settings": settings
            });

            let json_str =
                serde_json::to_string_pretty(&data).map_err(|e| e.to_string())?;

            let path = file_path.as_path().ok_or("Failed to get file path")?;
            fs::write(path, json_str).map_err(|e| e.to_string())?;
            Ok(true)
        }
        None => Ok(false),
    }
}

#[tauri::command]
pub async fn store_import(app: AppHandle) -> Result<ImportResult, String> {
    let file_path = app
        .dialog()
        .file()
        .set_title("Import Settings")
        .add_filter("JSON Files", &["json"])
        .blocking_pick_file();

    match file_path {
        Some(file_path) => {
            let path = file_path.as_path().ok_or("Failed to get file path")?;
            let content = fs::read_to_string(&path)
                .map_err(|e| format!("Failed to read file: {}", e))?;

            let data: Value =
                serde_json::from_str(&content).map_err(|e| format!("Invalid JSON format: {}", e))?;

            // Validate structure
            if !data.get("groups").map(|v| v.is_array()).unwrap_or(false)
                || !data.get("settings").map(|v| v.is_object()).unwrap_or(false)
            {
                return Ok(ImportResult {
                    success: false,
                    error: Some("Invalid file format: missing groups or settings".to_string()),
                });
            }

            let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;

            if let Some(groups) = data.get("groups") {
                store.set("groups".to_string(), groups.clone());
            }
            if let Some(settings) = data.get("settings") {
                store.set("settings".to_string(), settings.clone());
            }

            store.save().map_err(|e| e.to_string())?;

            Ok(ImportResult {
                success: true,
                error: None,
            })
        }
        None => Ok(ImportResult {
            success: false,
            error: Some("Cancelled".to_string()),
        }),
    }
}

// Helper function to get settings for tray-on-close behavior
pub fn get_tray_on_close_setting(app: &AppHandle) -> bool {
    if let Ok(store) = app.store(STORE_FILE) {
        if let Some(settings) = store.get("settings") {
            if let Some(tray_on_close) = settings.get("trayOnClose") {
                return tray_on_close.as_bool().unwrap_or(true);
            }
        }
    }
    true // Default to true
}
