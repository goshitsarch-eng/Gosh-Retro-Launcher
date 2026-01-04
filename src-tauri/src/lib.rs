mod commands;
mod tray;

use tauri::{Emitter, Manager, RunEvent};
use tauri_plugin_global_shortcut::{Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut builder = tauri::Builder::default();

    // Add plugins
    builder = builder
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            // Focus existing window on second instance
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.unminimize();
                let _ = window.show();
                let _ = window.set_focus();
            }
        }));

    // Add global shortcut plugin
    #[cfg(desktop)]
    {
        builder = builder.plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(move |app, shortcut, event| {
                    if event.state() == ShortcutState::Pressed {
                        // Check if it's our quick search shortcut
                        let ctrl_shift_space = Shortcut::new(
                            Some(Modifiers::CONTROL | Modifiers::SHIFT),
                            Code::Space,
                        );

                        #[cfg(target_os = "macos")]
                        let cmd_shift_space = Shortcut::new(
                            Some(Modifiers::META | Modifiers::SHIFT),
                            Code::Space,
                        );

                        let is_quick_search = shortcut == &ctrl_shift_space;

                        #[cfg(target_os = "macos")]
                        let is_quick_search = is_quick_search || shortcut == &cmd_shift_space;

                        if is_quick_search {
                            if let Some(window) = app.get_webview_window("main") {
                                // Show window if hidden
                                if !window.is_visible().unwrap_or(false) {
                                    let _ = window.show();
                                    let _ = window.set_focus();
                                }
                                // Emit toggle event
                                let _ = window.emit("quick-search:toggle", ());
                            }
                        }
                    }
                })
                .build(),
        );
    }

    builder
        .setup(|app| {
            // Register global shortcuts
            #[cfg(desktop)]
            {
                // Ctrl+Shift+Space for Windows/Linux
                let ctrl_shift_space = Shortcut::new(
                    Some(Modifiers::CONTROL | Modifiers::SHIFT),
                    Code::Space,
                );
                let _ = app.global_shortcut().register(ctrl_shift_space);

                // Cmd+Shift+Space for macOS
                #[cfg(target_os = "macos")]
                {
                    let cmd_shift_space = Shortcut::new(
                        Some(Modifiers::META | Modifiers::SHIFT),
                        Code::Space,
                    );
                    let _ = app.global_shortcut().register(cmd_shift_space);
                }
            }

            // Setup system tray
            if let Err(e) = tray::create_tray(app.handle()) {
                eprintln!("Failed to create tray: {}", e);
            }

            // Show window when ready
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Window commands
            commands::window::minimize_window,
            commands::window::maximize_window,
            commands::window::close_window,
            commands::window::quit_app,
            commands::window::is_maximized,
            // File commands
            commands::file::select_executable,
            commands::file::select_icon,
            commands::file::file_exists,
            // Launch commands
            commands::launch::launch_program,
            commands::launch::launch_batch,
            commands::launch::open_external,
            // Store commands
            commands::store::store_get,
            commands::store::store_set,
            commands::store::store_get_all,
            commands::store::store_export,
            commands::store::store_import,
            // System commands
            commands::system::get_platform,
        ])
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app, event| {
            if let RunEvent::ExitRequested { api, .. } = event {
                // Check if we should minimize to tray instead of exiting
                let tray_on_close = commands::store::get_tray_on_close_setting(app);
                if tray_on_close {
                    api.prevent_exit();
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.hide();
                    }
                }
            }
        });
}
