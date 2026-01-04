use serde_json::Value;
use tauri::{
    image::Image,
    menu::{MenuBuilder, MenuItemBuilder, SubmenuBuilder},
    tray::{MouseButton, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, Runtime, Emitter,
};
use tauri_plugin_store::StoreExt;

const STORE_FILE: &str = "program-manager-data.json";

pub fn create_tray<R: Runtime>(app: &AppHandle<R>) -> Result<(), Box<dyn std::error::Error>> {
    let menu = build_tray_menu(app)?;

    let _tray = TrayIconBuilder::new()
        .icon(get_tray_icon()?)
        .menu(&menu)
        .tooltip("Program Manager")
        .on_menu_event(|app, event| {
            handle_menu_event(app, event.id.as_ref());
        })
        .on_tray_icon_event(|tray, event| {
            // Double-click to show window (Windows/Linux behavior)
            if let TrayIconEvent::DoubleClick {
                button: MouseButton::Left,
                ..
            } = event
            {
                show_main_window(tray.app_handle());
            }
        })
        .build(app)?;

    Ok(())
}

fn build_tray_menu<R: Runtime>(
    app: &AppHandle<R>,
) -> Result<tauri::menu::Menu<R>, Box<dyn std::error::Error>> {
    let mut builder = MenuBuilder::new(app);

    // Show Program Manager item
    let show_item = MenuItemBuilder::with_id("show", "Show Program Manager").build(app)?;
    builder = builder.item(&show_item).separator();

    // Add program groups as submenus
    if let Ok(store) = app.store(STORE_FILE) {
        if let Some(groups) = store.get("groups") {
            if let Value::Array(groups_arr) = groups {
                for group in groups_arr {
                    if let (Some(name), Some(items)) = (
                        group.get("name").and_then(|n| n.as_str()),
                        group.get("items").and_then(|i| i.as_array()),
                    ) {
                        if !items.is_empty() {
                            let group_id = group
                                .get("id")
                                .and_then(|i| i.as_str())
                                .unwrap_or("unknown");
                            let mut submenu =
                                SubmenuBuilder::with_id(app, format!("group_{}", group_id), name);

                            for item in items {
                                if let (Some(id), Some(item_name)) = (
                                    item.get("id").and_then(|i| i.as_str()),
                                    item.get("name").and_then(|n| n.as_str()),
                                ) {
                                    let menu_item = MenuItemBuilder::with_id(
                                        format!("launch_{}", id),
                                        item_name,
                                    )
                                    .build(app)?;
                                    submenu = submenu.item(&menu_item);
                                }
                            }

                            builder = builder.item(&submenu.build()?);
                        }
                    }
                }
                builder = builder.separator();
            }
        }
    }

    // Exit item
    let exit_item = MenuItemBuilder::with_id("exit", "Exit").build(app)?;
    builder = builder.item(&exit_item);

    Ok(builder.build()?)
}

fn handle_menu_event<R: Runtime>(app: &AppHandle<R>, id: &str) {
    match id {
        "show" => show_main_window(app),
        "exit" => app.exit(0),
        id if id.starts_with("launch_") => {
            let item_id = id.strip_prefix("launch_").unwrap();
            // Emit event to frontend to handle launch
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.emit("tray-launch-item", item_id);
            }
        }
        _ => {}
    }
}

fn show_main_window<R: Runtime>(app: &AppHandle<R>) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
    }
}

fn get_tray_icon() -> Result<Image<'static>, Box<dyn std::error::Error>> {
    // Create a simple 16x16 teal RGBA image as fallback
    // This is raw RGBA data (not PNG encoded)
    let width: u32 = 16;
    let height: u32 = 16;
    let teal_color: [u8; 4] = [0x00, 0x80, 0x80, 0xFF]; // RGBA for teal

    let mut rgba_data: Vec<u8> = Vec::with_capacity((width * height * 4) as usize);
    for _ in 0..(width * height) {
        rgba_data.extend_from_slice(&teal_color);
    }

    Ok(Image::new_owned(rgba_data, width, height))
}
