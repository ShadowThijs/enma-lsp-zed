use zed_extension_api::{self as zed, Worktree, LanguageServerId, Command};
use zed_extension_api::settings::LspSettings;
use zed_extension_api::serde_json;

struct EnmaExtension;

impl zed::Extension for EnmaExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _server_id: &LanguageServerId,
        _worktree: &Worktree,
    ) -> zed::Result<Command> {
        // Look for the LSP binary in the extension directory
        let extension_dir = std::env::current_dir()
            .map_err(|e| format!("Failed to get current directory: {}", e))?;
        let lsp_path = extension_dir
            .join("enma-lsp")
            .join("target")
            .join("release")
            .join("enma-lsp");

        if lsp_path.exists() {
            return Ok(Command {
                command: lsp_path.to_string_lossy().into_owned(),
                args: Vec::new(),
                env: Vec::new(),
            });
        }

        // Fallback: try debug build
        let debug_path = extension_dir
            .join("enma-lsp")
            .join("target")
            .join("debug")
            .join("enma-lsp");

        if debug_path.exists() {
            return Ok(Command {
                command: debug_path.to_string_lossy().into_owned(),
                args: Vec::new(),
                env: Vec::new(),
            });
        }

        Err(format!(
            "enma-lsp binary not found at {} or {}. Run `cargo build --release` in the enma-lsp/ directory.",
            lsp_path.display(),
            debug_path.display()
        ))
    }

    fn language_server_workspace_configuration(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> zed::Result<Option<serde_json::Value>> {
        let settings = LspSettings::for_worktree(server_id.as_ref(), worktree)
            .ok()
            .and_then(|s| s.settings)
            .unwrap_or_default();
        Ok(Some(settings))
    }
}

zed::register_extension!(EnmaExtension);
