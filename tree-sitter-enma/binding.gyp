{
  "targets": [
    {
      "target_name": "tree_sitter_enma_binding",
      "sources": [
        "bindings/node/binding.cc",
        "src/parser.c",
        "src/scanner.c"
      ],
      "include_dirs": [
        "<!(node -p \"require('node-addon-api').include_dir\")"
      ],
      "cflags!": ["-fno-exceptions"],
      "cflags_cc!": ["-fno-exceptions"],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES"
      },
      "msvs_settings": {
        "VCCLCompilerTool": {
          "ExceptionHandling": 1
        }
      },
      "conditions": [
        ["OS=='mac'", {
          "cflags+": ["-std=c11"],
          "xcode_settings": {
            "OTHER_CFLAGS": ["-std=c11"]
          }
        }]
      ]
    }
  ]
}
