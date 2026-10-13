//! Galaxy-only commands.
//!
//! `galaxy_download_to_temp` downloads a file from CurseForge's or FTB's CDN into a
//! temporary folder, so the existing `instance_add_project_from_path` command can
//! copy it into an instance. Only a short list of download hosts is allowed, so the
//! page can't be used to download from arbitrary sites.

use crate::api::Result;
use tauri::Runtime;
use tauri_plugin_http::reqwest;

pub fn init<R: Runtime>() -> tauri::plugin::TauriPlugin<R> {
    tauri::plugin::Builder::new("galaxy")
        .invoke_handler(tauri::generate_handler![galaxy_download_to_temp])
        .build()
}

const ALLOWED_HOST_SUFFIXES: &[&str] = &[
    "forgecdn.net",
    "curseforge.com",
    "modpacks.ch",
    "feed-the-beast.com",
];

fn other_error(message: impl Into<String>) -> crate::api::TheseusSerializableError {
    theseus::Error::from(theseus::ErrorKind::OtherError(message.into())).into()
}

fn host_allowed(host: &str) -> bool {
    let host = host.to_ascii_lowercase();
    ALLOWED_HOST_SUFFIXES
        .iter()
        .any(|suffix| host == *suffix || host.ends_with(&format!(".{suffix}")))
}

fn safe_file_name(name: &str) -> String {
    let cleaned: String = name
        .chars()
        .map(|c| match c {
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '_',
            c if c.is_control() => '_',
            c => c,
        })
        .collect();
    let cleaned = cleaned.trim().trim_start_matches('.').to_string();
    if cleaned.is_empty() {
        "download.jar".to_string()
    } else {
        cleaned
    }
}

/// Downloads `url` into `<temp>/galaxy-downloads/<file_name>` and returns the full path.
#[tauri::command]
pub async fn galaxy_download_to_temp(url: String, file_name: String) -> Result<String> {
    let parsed = url::Url::parse(&url).map_err(|_| other_error("Invalid download link"))?;
    if parsed.scheme() != "https" {
        return Err(other_error("Only https downloads are allowed"));
    }
    match parsed.host_str() {
        Some(host) if host_allowed(host) => {}
        _ => return Err(other_error("Downloads are only allowed from CurseForge or FTB")),
    }

    let client = reqwest::Client::builder()
        .user_agent(theseus::launcher_user_agent())
        .build()
        .map_err(|e| other_error(format!("Could not start download: {e}")))?;

    let response = client
        .get(parsed.as_str())
        .send()
        .await
        .map_err(|e| other_error(format!("Download failed: {e}")))?;

    if !response.status().is_success() {
        return Err(other_error(format!(
            "Download failed with status {}",
            response.status()
        )));
    }

    let bytes = response
        .bytes()
        .await
        .map_err(|e| other_error(format!("Download failed: {e}")))?;

    let dir = std::env::temp_dir().join("galaxy-downloads");
    tokio::fs::create_dir_all(&dir).await?;
    let path = dir.join(safe_file_name(&file_name));
    tokio::fs::write(&path, &bytes).await?;

    Ok(path.to_string_lossy().to_string())
}
