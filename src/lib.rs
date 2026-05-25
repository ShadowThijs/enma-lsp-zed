use zed_extension_api::{self as zed, Worktree, LanguageServerId};
use zed_extension_api::settings::LspSettings;
use zed_extension_api::serde_json;

struct EnmaExtension;

impl zed::Extension for EnmaExtension {
    fn new() -> Self {
        Self
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
