import * as path from 'path';
import { commands, ExtensionContext, window, workspace } from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
  const serverPath = context.asAbsolutePath(
    path.join('enma-lsp' + (process.platform === 'win32' ? '.exe' : ''))
  );

  const serverOptions: ServerOptions = {
    run: { command: serverPath, transport: TransportKind.stdio },
    debug: { command: serverPath, transport: TransportKind.stdio },
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'enma' }],
    synchronize: {
      fileEvents: workspace.createFileSystemWatcher('**/*.em'),
    },
  };

  client = new LanguageClient(
    'enma-lsp',
    'Enma LSP',
    serverOptions,
    clientOptions
  );
  client.start();

  // ── Bundle command ──
  context.subscriptions.push(
    commands.registerCommand('enma.bundleFile', async () => {
      const editor = window.activeTextEditor;
      if (!editor || editor.document.languageId !== 'enma') {
        window.showWarningMessage('Enma Bundle: open an .em file first.');
        return;
      }

      const workspaceRoot = workspace.workspaceFolders?.[0]?.uri.fsPath || '';
      const defaultOutput = path.join(workspaceRoot, 'output', 'bundled.em');

      const outputPath = await window.showInputBox({
        prompt: 'Output path for the bundled file',
        value: defaultOutput,
      });
      if (!outputPath) { return; }

      const stripChoice = await window.showQuickPick(['No', 'Yes'], {
        placeHolder: 'Strip comments from source files?',
      });
      if (!stripChoice) { return; }

      const stripComments = stripChoice === 'Yes';

      try {
        const result: any = await client.sendRequest('workspace/executeCommand', {
          command: 'enma.bundle',
          arguments: [
            editor.document.uri.toString(),
            stripComments,
            outputPath,
          ],
        });

        const warningCount = result?.warnings?.length || 0;
        if (warningCount > 0) {
          window.showWarningMessage(
            `Enma Bundle: wrote ${outputPath} with ${warningCount} warning(s). ` +
            'Check output for WARNING comments.'
          );
        } else {
          window.showInformationMessage(`Enma Bundle: wrote ${outputPath}`);
        }
      } catch (e: any) {
        window.showErrorMessage(`Enma Bundle failed: ${e.message || e}`);
      }
    })
  );
}

export function deactivate(): Thenable<void> | undefined {
  return client?.stop();
}
