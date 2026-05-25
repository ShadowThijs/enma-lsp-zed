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
        // CARGO_MANIFEST_DIR = extension root at compile time.
        // The WASM sandbox can't access the host filesystem to check exists(),
        // so we construct the path and let Zed handle execution errors.
        let manifest = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let lsp_path = manifest.join("enma-lsp/target/release/enma-lsp");

        Ok(Command {
            command: lsp_path.to_string_lossy().into_owned(),
            args: Vec::new(),
            env: Vec::new(),
        })
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
