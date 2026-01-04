use serde::{Deserialize, Serialize};
use std::process::Command;
use tauri::AppHandle;
use tauri_plugin_opener::OpenerExt;

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

#[derive(Debug, Serialize)]
pub struct LaunchResult {
    pub success: bool,
    pub error: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct BatchLaunchResult {
    pub id: String,
    pub success: bool,
    pub error: Option<String>,
}

#[tauri::command]
pub async fn launch_program(app: AppHandle, item: ProgramItem) -> Result<LaunchResult, String> {
    let path = &item.path;

    // Handle URLs
    if path.starts_with("http://") || path.starts_with("https://") {
        return match app.opener().open_url(path, None::<&str>) {
            Ok(_) => Ok(LaunchResult {
                success: true,
                error: None,
            }),
            Err(e) => Ok(LaunchResult {
                success: false,
                error: Some(e.to_string()),
            }),
        };
    }

    // Platform-specific launching
    let result = launch_platform_specific(&item);
    Ok(result)
}

#[tauri::command]
pub async fn launch_batch(
    app: AppHandle,
    items: Vec<ProgramItem>,
    delay: u64,
) -> Result<Vec<BatchLaunchResult>, String> {
    let mut results = Vec::new();

    for (i, item) in items.iter().enumerate() {
        let result = launch_program(app.clone(), item.clone()).await?;
        results.push(BatchLaunchResult {
            id: item.id.clone(),
            success: result.success,
            error: result.error,
        });

        // Delay between launches (except last)
        if i < items.len() - 1 && delay > 0 {
            tokio::time::sleep(tokio::time::Duration::from_millis(delay)).await;
        }
    }

    Ok(results)
}

#[tauri::command]
pub async fn open_external(app: AppHandle, url: String) -> Result<LaunchResult, String> {
    match app.opener().open_url(&url, None::<&str>) {
        Ok(_) => Ok(LaunchResult {
            success: true,
            error: None,
        }),
        Err(e) => Ok(LaunchResult {
            success: false,
            error: Some(e.to_string()),
        }),
    }
}

fn launch_platform_specific(item: &ProgramItem) -> LaunchResult {
    #[cfg(target_os = "windows")]
    {
        launch_windows(item)
    }

    #[cfg(target_os = "macos")]
    {
        launch_macos(item)
    }

    #[cfg(target_os = "linux")]
    {
        launch_linux(item)
    }

    #[cfg(not(any(target_os = "windows", target_os = "macos", target_os = "linux")))]
    {
        LaunchResult {
            success: false,
            error: Some("Unsupported platform".to_string()),
        }
    }
}

#[cfg(target_os = "windows")]
fn launch_windows(item: &ProgramItem) -> LaunchResult {
    use std::os::windows::process::CommandExt;
    const DETACHED_PROCESS: u32 = 0x00000008;
    const CREATE_NO_WINDOW: u32 = 0x08000000;

    let path = &item.path;
    let path_lower = path.to_lowercase();

    // Handle .lnk shortcuts
    if path_lower.ends_with(".lnk") {
        match lnk::ShellLink::open(path) {
            Ok(link) => {
                if let Some(target) = link.link_info().clone().and_then(|i| i.local_base_path().clone()) {
                    let mut cmd = Command::new(target);
                    cmd.creation_flags(DETACHED_PROCESS | CREATE_NO_WINDOW);

                    if let Some(working_dir) = link.working_dir() {
                        cmd.current_dir(working_dir);
                    } else if !item.working_dir.is_empty() {
                        cmd.current_dir(&item.working_dir);
                    }

                    if let Some(args) = link.arguments() {
                        for arg in args.split_whitespace() {
                            cmd.arg(arg);
                        }
                    }

                    match cmd.spawn() {
                        Ok(_) => {
                            return LaunchResult {
                                success: true,
                                error: None,
                            }
                        }
                        Err(e) => {
                            return LaunchResult {
                                success: false,
                                error: Some(e.to_string()),
                            }
                        }
                    }
                }
            }
            Err(e) => {
                return LaunchResult {
                    success: false,
                    error: Some(format!("Failed to parse .lnk file: {:?}", e)),
                }
            }
        }
    }

    // Regular executable - use cmd /C start for proper detaching
    let mut cmd = Command::new("cmd");
    cmd.args(["/C", "start", "", path]);
    cmd.creation_flags(DETACHED_PROCESS | CREATE_NO_WINDOW);

    if !item.working_dir.is_empty() {
        cmd.current_dir(&item.working_dir);
    }

    match cmd.spawn() {
        Ok(_) => LaunchResult {
            success: true,
            error: None,
        },
        Err(e) => LaunchResult {
            success: false,
            error: Some(e.to_string()),
        },
    }
}

#[cfg(target_os = "macos")]
fn launch_macos(item: &ProgramItem) -> LaunchResult {
    let path = &item.path;

    if path.ends_with(".app") {
        match Command::new("open").args(["-a", path]).spawn() {
            Ok(_) => LaunchResult {
                success: true,
                error: None,
            },
            Err(e) => LaunchResult {
                success: false,
                error: Some(e.to_string()),
            },
        }
    } else {
        let mut cmd = Command::new(path);
        if !item.working_dir.is_empty() {
            cmd.current_dir(&item.working_dir);
        }
        match cmd.spawn() {
            Ok(_) => LaunchResult {
                success: true,
                error: None,
            },
            Err(e) => LaunchResult {
                success: false,
                error: Some(e.to_string()),
            },
        }
    }
}

#[cfg(target_os = "linux")]
fn launch_linux(item: &ProgramItem) -> LaunchResult {
    let path = &item.path;

    if path.ends_with(".desktop") {
        // Parse .desktop file
        match freedesktop_entry_parser::parse_entry(path) {
            Ok(entry) => {
                if let Some(exec) = entry.section("Desktop Entry").attr("Exec") {
                    // Remove field codes like %f, %u, etc.
                    let exec_clean = exec
                        .replace("%f", "")
                        .replace("%F", "")
                        .replace("%u", "")
                        .replace("%U", "")
                        .replace("%d", "")
                        .replace("%D", "")
                        .replace("%n", "")
                        .replace("%N", "")
                        .replace("%i", "")
                        .replace("%c", "")
                        .replace("%k", "")
                        .replace("%v", "")
                        .replace("%m", "")
                        .trim()
                        .to_string();

                    let parts: Vec<&str> = exec_clean.split_whitespace().collect();
                    if let Some((program, args)) = parts.split_first() {
                        let mut cmd = Command::new(program);
                        cmd.args(args);

                        if !item.working_dir.is_empty() {
                            cmd.current_dir(&item.working_dir);
                        }

                        match cmd.spawn() {
                            Ok(_) => {
                                return LaunchResult {
                                    success: true,
                                    error: None,
                                }
                            }
                            Err(e) => {
                                return LaunchResult {
                                    success: false,
                                    error: Some(e.to_string()),
                                }
                            }
                        }
                    }
                }
                LaunchResult {
                    success: false,
                    error: Some("No Exec in .desktop file".to_string()),
                }
            }
            Err(e) => LaunchResult {
                success: false,
                error: Some(e.to_string()),
            },
        }
    } else {
        let mut cmd = Command::new(path);
        if !item.working_dir.is_empty() {
            cmd.current_dir(&item.working_dir);
        }
        match cmd.spawn() {
            Ok(_) => LaunchResult {
                success: true,
                error: None,
            },
            Err(e) => LaunchResult {
                success: false,
                error: Some(e.to_string()),
            },
        }
    }
}
