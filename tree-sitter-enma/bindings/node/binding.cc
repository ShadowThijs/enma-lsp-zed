#include <node_api.h>
#include <assert.h>
#include <string.h>
#include "tree_sitter/api.h"

extern "C" const TSLanguage *tree_sitter_enma(void);

static napi_value Language(napi_env env, napi_callback_info info) {
  napi_value result;
  const TSLanguage *lang = tree_sitter_enma();
  napi_create_external(env, (void *)lang, NULL, NULL, &result);
  return result;
}

static napi_value Init(napi_env env, napi_value exports) {
  napi_value lang;
  napi_create_function(env, NULL, NAPI_AUTO_LENGTH, Language, NULL, &lang);
  napi_set_named_property(env, exports, "language", lang);
  return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
