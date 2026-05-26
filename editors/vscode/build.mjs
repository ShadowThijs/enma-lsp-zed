import * as esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["src/extension.ts"],
  bundle: true,
  outfile: "out/extension.js",
  external: ["vscode"],
  platform: "node",
  target: "node18",
  format: "cjs",
  minify: false,
  sourcemap: true,
  logLevel: "info",
});
