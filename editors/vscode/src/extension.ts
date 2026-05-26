import * as path from 'path';
import { ExtensionContext, workspace } from 'vscode';
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
}

export function deactivate(): Thenable<void> | undefined {
  return client?.stop();
}
