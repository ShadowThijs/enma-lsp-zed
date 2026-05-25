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
        // Use compile-time manifest dir for dev extensions.
        // In production, the binary would be bundled with the extension.
        let base = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));

        let release_path = base.join("enma-lsp/target/release/enma-lsp");
        if release_path.exists() {
            return Ok(Command {
                command: release_path.to_string_lossy().into_owned(),
                args: Vec::new(),
                env: Vec::new(),
            });
        }

        let debug_path = base.join("enma-lsp/target/debug/enma-lsp");
        if debug_path.exists() {
            return Ok(Command {
                command: debug_path.to_string_lossy().into_owned(),
                args: Vec::new(),
                env: Vec::new(),
            });
        }

        Err(format!(
            "enma-lsp binary not found. Run: cd enma-lsp && cargo build --release"
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
