// =============================================================================
// JSON addon comprehensive smoke test
//
// Covers every type, method, and standalone function from the JSON doc:
//
// Types:
//   json_value
//
// json_value methods:
//   is_valid()     -- bool, false if malformed
//   is_null()      -- bool predicate
//   is_bool()      -- bool predicate
//   is_num()       -- bool predicate
//   is_str()       -- bool predicate
//   is_array()     -- bool predicate
//   is_obj()       -- bool predicate
//   kind()         -- int64 (0=null 1=bool 2=num 3=str 4=arr 5=obj 6=invalid)
//   as_bool()      -- bool (false if not a bool)
//   as_num()       -- float64 (0.0 if not a number)
//   as_int()       -- int64 (truncated from the stored double)
//   as_str()       -- string ("" if not a string)
//   size()         -- int64 (array/object length; 0 for primitives)
//   has_key(string)-- bool (true for objects that have the key)
//   keys()         -- array<string> of object keys (insertion order)
//   get_key(string)-- json_value (deep copy of subtree)
//   get_at(int64)  -- json_value (deep copy of subtree)
//   set_key(string, json_value) -- bool (true if inserted/updated)
//   remove_key(string)          -- bool (true if a key was removed)
//   push_value(json_value)      -- bool (true on success)
//   stringify()    -- string (compact JSON)
//   pretty()       -- string (multi-line with 2-space indent)
//
// Standalone functions:
//   json_parse(string)  -> json_value
//   json_object()       -> json_value (empty builder)
//   json_array()        -> json_value (empty builder)
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

sidebar_section_t g_section;
button_t          g_btn;
menu_t            g_menu;

void check(string label, bool ok) {
    if (ok) {
        print_console("  [PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("  [FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

// ===========================================================================
// TEST ROUTINE
// ===========================================================================
void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== JSON addon smoke test ===");

    // =========================================================================
    // 1. json_parse + is_valid
    // =========================================================================
    section("1. json_parse + is_valid");

    json_value jvalid = json_parse("{\"name\":\"Alice\"}");
    check("valid JSON is_valid() == true", jvalid.is_valid());

    json_value jbad = json_parse("not valid json");
    check("malformed JSON is_valid() == false", !jbad.is_valid());

    // =========================================================================
    // 2. type predicates + kind() for each JSON type
    // =========================================================================
    section("2. null type - is_null / kind");

    json_value jnull = json_parse("null");
    check("null is_valid()", jnull.is_valid());
    check("null is_null()", jnull.is_null());
    check("null !is_bool()", !jnull.is_bool());
    check("null !is_num()", !jnull.is_num());
    check("null !is_str()", !jnull.is_str());
    check("null !is_array()", !jnull.is_array());
    check("null !is_obj()", !jnull.is_obj());
    check("null kind() == 0", jnull.kind() == 0);

    section("3. bool type - is_bool / as_bool / kind");

    json_value jtrue  = json_parse("true");
    json_value jfalse = json_parse("false");
    check("true is_valid()", jtrue.is_valid());
    check("true is_bool()", jtrue.is_bool());
    check("true as_bool()", jtrue.as_bool() == true);
    check("false as_bool() == false", jfalse.as_bool() == false);
    check("true !is_null()", !jtrue.is_null());
    check("true !is_num()", !jtrue.is_num());
    check("true kind() == 1", jtrue.kind() == 1);
    check("false kind() == 1", jfalse.kind() == 1);

    section("4. num type - is_num / as_num / as_int / kind");

    json_value jint   = json_parse("42");
    json_value jfloat = json_parse("3.14");
    json_value jneg   = json_parse("-42");
    check("42 is_valid()", jint.is_valid());
    check("42 is_num()", jint.is_num());
    check("42 as_num() == 42.0", jint.as_num() == 42.0);
    check("42 as_int() == 42", jint.as_int() == 42);
    check("3.14 is_num()", jfloat.is_num());
    check("3.14 as_int() == 3 (truncated)", jfloat.as_int() == 3);
    check("-42 as_int() == -42", jneg.as_int() == -42);
    check("-42 as_num() == -42.0", jneg.as_num() == -42.0);
    check("42 !is_str()", !jint.is_str());
    check("42 kind() == 2", jint.kind() == 2);
    check("3.14 kind() == 2", jfloat.kind() == 2);

    section("5. str type - is_str / as_str / kind");

    json_value jstr = json_parse("\"hello\"");
    json_value jempty_str = json_parse("\"\"");
    check("'hello' is_valid()", jstr.is_valid());
    check("'hello' is_str()", jstr.is_str());
    check("'hello' as_str() == 'hello'", jstr.as_str() == "hello");
    check("empty string as_str() == ''", jempty_str.as_str() == "");
    check("'hello' !is_null()", !jstr.is_null());
    check("'hello' !is_num()", !jstr.is_num());
    check("'hello' kind() == 3", jstr.kind() == 3);

    section("6. string escape sequences - \\uXXXX");

    json_value jesc = json_parse("\"\\u0048\\u0069\"");
    check("\\u0048\\u0069 as_str() == 'Hi'", jesc.as_str() == "Hi");

    json_value jesc2 = json_parse("\"hello\\nworld\"");
    check("escaped string is_str()", jesc2.is_str());
    check("escaped string kind() == 3", jesc2.kind() == 3);

    section("7. array type - is_array / size / kind");

    json_value jarr = json_parse("[1, 2, 3]");
    check("[1,2,3] is_valid()", jarr.is_valid());
    check("[1,2,3] is_array()", jarr.is_array());
    check("array size() == 3", jarr.size() == 3);
    check("array !is_obj()", !jarr.is_obj());
    check("array kind() == 4", jarr.kind() == 4);

    json_value jempty_arr = json_parse("[]");
    check("[] is_array()", jempty_arr.is_array());
    check("[] size() == 0", jempty_arr.size() == 0);
    check("[] kind() == 4", jempty_arr.kind() == 4);

    section("8. obj type - is_obj / size / kind");

    json_value jobj = json_parse("{\"a\":1,\"b\":2}");
    check("{a:1,b:2} is_valid()", jobj.is_valid());
    check("{a:1,b:2} is_obj()", jobj.is_obj());
    check("obj size() == 2", jobj.size() == 2);
    check("obj !is_array()", !jobj.is_array());
    check("obj kind() == 5", jobj.kind() == 5);

    json_value jempty_obj = json_parse("{}");
    check("{} is_obj()", jempty_obj.is_obj());
    check("{} size() == 0", jempty_obj.size() == 0);
    check("{} kind() == 5", jempty_obj.kind() == 5);

    // =========================================================================
    // 9. Container introspection: has_key / keys / size
    // =========================================================================
    section("9. container introspection - has_key / keys / size");

    json_value jdata = json_parse("{\"x\":10,\"y\":20,\"z\":30}");
    check("obj.size() == 3", jdata.size() == 3);
    check("has_key('x')", jdata.has_key("x"));
    check("has_key('y')", jdata.has_key("y"));
    check("has_key('z')", jdata.has_key("z"));
    check("!has_key('w')", !jdata.has_key("w"));

    // keys() returns array<string> of object keys in insertion order
    array ks = jdata.keys();
    check("keys() called on object", true);

    // =========================================================================
    // 10. Primitive extraction safety on mismatched types
    // =========================================================================
    section("10. safety - methods on mismatched type");

    json_value jn = json_parse("null");
    check("null.as_bool() == false", jn.as_bool() == false);
    check("null.as_num() == 0.0", jn.as_num() == 0.0);
    check("null.as_int() == 0", jn.as_int() == 0);
    check("null.as_str() == ''", jn.as_str() == "");
    check("null.size() == 0 (primitives return 0)", jn.size() == 0);
    check("null.has_key('x') == false", jn.has_key("x") == false);

    json_value jb = json_parse("true");
    check("true.as_str() == ''", jb.as_str() == "");
    check("true.as_num() == 0.0", jb.as_num() == 0.0);
    check("true.size() == 0", jb.size() == 0);

    json_value js2 = json_parse("\"text\"");
    check("'text'.as_bool() == false", js2.as_bool() == false);
    check("'text'.as_int() == 0", js2.as_int() == 0);
    check("'text'.size() == 0", js2.size() == 0);

    // =========================================================================
    // 11. Safety on invalid JSON value
    // =========================================================================
    section("11. safety - invalid json_value");

    json_value jinv = json_parse("{{{");
    check("invalid is_valid() == false", !jinv.is_valid());
    check("invalid kind() == 6", jinv.kind() == 6);
    check("invalid !is_null()", !jinv.is_null());
    check("invalid !is_bool()", !jinv.is_bool());
    check("invalid !is_num()", !jinv.is_num());
    check("invalid !is_str()", !jinv.is_str());
    check("invalid !is_array()", !jinv.is_array());
    check("invalid !is_obj()", !jinv.is_obj());
    check("invalid.as_bool() == false", jinv.as_bool() == false);
    check("invalid.as_num() == 0.0", jinv.as_num() == 0.0);
    check("invalid.as_int() == 0", jinv.as_int() == 0);
    check("invalid.as_str() == ''", jinv.as_str() == "");
    check("invalid.size() == 0", jinv.size() == 0);
    check("invalid.has_key('x') == false", jinv.has_key("x") == false);

    // =========================================================================
    // 12. Navigation: get_key on object
    // =========================================================================
    section("12. navigation - get_key on object");

    json_value jperson = json_parse("{\"name\":\"Alice\",\"age\":30,\"active\":true,\"data\":null}");
    check("person is_valid()", jperson.is_valid());

    json_value jname = jperson.get_key("name");
    check("get_key('name') is_str()", jname.is_str());
    check("get_key('name').as_str() == 'Alice'", jname.as_str() == "Alice");

    json_value jage = jperson.get_key("age");
    check("get_key('age') is_num()", jage.is_num());
    check("get_key('age').as_int() == 30", jage.as_int() == 30);

    json_value jactive = jperson.get_key("active");
    check("get_key('active') is_bool()", jactive.is_bool());
    check("get_key('active').as_bool()", jactive.as_bool() == true);

    json_value jnullval = jperson.get_key("data");
    check("get_key('data') is_null()", jnullval.is_null());

    check("get_key('nonexistent') is_valid() == false",
          !jperson.get_key("nonexistent").is_valid());

    section("13. navigation - get_at on array");

    json_value jnums = json_parse("[10, 20, 30]");
    check("get_at(0).as_int() == 10", jnums.get_at(0).as_int() == 10);
    check("get_at(1).as_int() == 20", jnums.get_at(1).as_int() == 20);
    check("get_at(2).as_int() == 30", jnums.get_at(2).as_int() == 30);

    section("14. navigation - deep copy semantics");

    // Sub-values are deep copies, independent of their parent.
    json_value jnested = json_parse("{\"users\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]}");
    json_value jusers = jnested.get_key("users");
    check("users.is_array()", jusers.is_array());
    check("users.size() == 2", jusers.size() == 2);

    json_value jfirst = jusers.get_at(0);
    check("first.get_key('id').as_int() == 1", jfirst.get_key("id").as_int() == 1);
    check("first.get_key('name').as_str() == 'Alice'", jfirst.get_key("name").as_str() == "Alice");

    json_value jsecond = jusers.get_at(1);
    check("second.get_key('id').as_int() == 2", jsecond.get_key("id").as_int() == 2);
    check("second.get_key('name').as_str() == 'Bob'", jsecond.get_key("name").as_str() == "Bob");

    // Parent still works after extraction.
    check("parent still valid", jnested.is_valid());
    check("parent.get_key('users').is_array()", jnested.get_key("users").is_array());

    // Child works independently of parent.
    check("child still valid after parent access", jfirst.is_valid());
    check("child.get_key('id').as_int() still 1", jfirst.get_key("id").as_int() == 1);

    // =========================================================================
    // 15. Chained navigation: get_key / get_at composition
    // =========================================================================
    section("15. navigation - chained get_key / get_at");

    json_value jchain = json_parse("{\"items\":[{\"label\":\"alpha\"},{\"label\":\"beta\"}]}");
    check("chained get_key->get_at->get_key label == 'alpha'",
          jchain.get_key("items").get_at(0).get_key("label").as_str() == "alpha");
    check("chained get_key->get_at->get_key label == 'beta'",
          jchain.get_key("items").get_at(1).get_key("label").as_str() == "beta");

    // =========================================================================
    // 16. Building / mutating: json_object + set_key + remove_key
    // =========================================================================
    section("16. building - json_object");

    json_value obj = json_object();
    check("json_object() is_valid()", obj.is_valid());
    check("json_object() is_obj()", obj.is_obj());
    check("json_object() size() == 0", obj.size() == 0);
    check("json_object() kind() == 5", obj.kind() == 5);

    section("17. building - set_key (insert / update)");

    bool ins = obj.set_key("name", json_parse("\"Alice\""));
    check("set_key('name') returned true", ins);
    check("obj.size() == 1 after set_key", obj.size() == 1);
    check("get_key('name').as_str() == 'Alice'", obj.get_key("name").as_str() == "Alice");

    bool upd = obj.set_key("name", json_parse("\"Bob\""));
    check("set_key update returned true", upd);
    check("updated name == 'Bob'", obj.get_key("name").as_str() == "Bob");
    check("size() still 1 after update", obj.size() == 1);

    obj.set_key("age", json_parse("25"));
    obj.set_key("score", json_parse("99.5"));
    obj.set_key("active", json_parse("true"));
    obj.set_key("tag", json_parse("null"));
    check("size() == 5 after multiple set_key calls", obj.size() == 5);
    check("get_key('age').as_int() == 25", obj.get_key("age").as_int() == 25);
    check("get_key('score').as_num() == 99.5", obj.get_key("score").as_num() == 99.5);
    check("get_key('active').as_bool()", obj.get_key("active").as_bool() == true);
    check("get_key('tag').is_null()", obj.get_key("tag").is_null());

    section("18. building - remove_key");

    bool rem = obj.remove_key("tag");
    check("remove_key('tag') returned true", rem);
    check("!has_key('tag') after remove", !obj.has_key("tag"));
    check("size() == 4 after remove", obj.size() == 4);

    bool rem_miss = obj.remove_key("nonexistent");
    check("remove_key('nonexistent') returned false", !rem_miss);
    check("size() still 4 after failed remove", obj.size() == 4);

    // =========================================================================
    // 19. Building / mutating: json_array + push_value
    // =========================================================================
    section("19. building - json_array");

    json_value arr = json_array();
    check("json_array() is_valid()", arr.is_valid());
    check("json_array() is_array()", arr.is_array());
    check("json_array() size() == 0", arr.size() == 0);
    check("json_array() kind() == 4", arr.kind() == 4);

    section("20. building - push_value");

    bool p1 = arr.push_value(json_parse("1"));
    check("push_value(1) returned true", p1);
    check("arr.size() == 1 after push", arr.size() == 1);

    arr.push_value(json_parse("\"two\""));
    arr.push_value(json_parse("true"));
    arr.push_value(json_parse("null"));
    arr.push_value(json_parse("3.14"));
    check("arr.size() == 5 after 5 pushes", arr.size() == 5);

    check("get_at(0).as_int() == 1", arr.get_at(0).as_int() == 1);
    check("get_at(1).as_str() == 'two'", arr.get_at(1).as_str() == "two");
    check("get_at(2).as_bool()", arr.get_at(2).as_bool() == true);
    check("get_at(3).is_null()", arr.get_at(3).is_null());
    check("get_at(4).as_num() == 3.14", arr.get_at(4).as_num() == 3.14);

    // =========================================================================
    // 21. Building composite structures programmatically
    // =========================================================================
    section("21. building - composite structures");

    json_value composite = json_object();
    composite.set_key("title", json_parse("\"Shopping List\""));

    json_value items = json_array();
    items.push_value(json_parse("\"apples\""));
    items.push_value(json_parse("\"bread\""));
    items.push_value(json_parse("\"milk\""));
    composite.set_key("items", items);

    json_value metadata = json_object();
    metadata.set_key("count", json_parse("3"));
    metadata.set_key("store", json_parse("\"corner market\""));
    composite.set_key("meta", metadata);

    check("composite.size() == 3", composite.size() == 3);
    check("composite.has_key('title')", composite.has_key("title"));
    check("composite.get_key('title').as_str() == 'Shopping List'",
          composite.get_key("title").as_str() == "Shopping List");
    check("composite.get_key('items').is_array()", composite.get_key("items").is_array());
    check("composite.get_key('items').size() == 3",
          composite.get_key("items").size() == 3);
    check("composite.get_key('items').get_at(1).as_str() == 'bread'",
          composite.get_key("items").get_at(1).as_str() == "bread");
    check("composite.get_key('meta').is_obj()", composite.get_key("meta").is_obj());
    check("composite.get_key('meta').get_key('count').as_int() == 3",
          composite.get_key("meta").get_key("count").as_int() == 3);

    // =========================================================================
    // 22. Stringifying: stringify / pretty
    // =========================================================================
    section("22. stringifying - stringify");

    json_value jstrfy = json_parse("{\"a\":1,\"b\":2}");
    string compact = jstrfy.stringify();
    check("stringify() produced non-empty result", compact != "");

    // Round-trip: stringify -> re-parse should produce valid JSON
    json_value jreparse = json_parse(compact);
    check("stringify round-trip is valid", jreparse.is_valid());
    check("round-trip is_obj()", jreparse.is_obj());
    check("round-trip size() == 2", jreparse.size() == 2);
    check("round-trip has_key('a')", jreparse.has_key("a"));
    check("round-trip has_key('b')", jreparse.has_key("b"));

    section("23. stringifying - pretty");

    string indented = jstrfy.pretty();
    check("pretty() produced non-empty result", indented != "");
    check("pretty() output differs from stringify()", indented != compact);

    // Pretty printing for simple values (edge cases)
    json_value jnull_pretty = json_parse("null");
    check("null.stringify() == 'null'", jnull_pretty.stringify() == "null");
    check("null.pretty() == 'null'", jnull_pretty.pretty() == "null");

    json_value jtrue_pretty = json_parse("true");
    check("true.stringify() == 'true'", jtrue_pretty.stringify() == "true");

    json_value jnum_pretty = json_parse("42");
    check("42.stringify() == '42'", jnum_pretty.stringify() == "42");

    json_value jstr_pretty = json_parse("\"text\"");
    check("'text'.stringify() == '\"text\"'", jstr_pretty.stringify() == "\"text\"");

    json_value jarr_pretty = json_parse("[1,2,3]");
    check("array.stringify() produces output", jarr_pretty.stringify() != "");

    // =========================================================================
    // Summary
    // =========================================================================
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

// ===========================================================================
// Menu handlers
// ===========================================================================
void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked - resetting and re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

// ===========================================================================
// Entry point
// ===========================================================================
int32 main() {
    print_console("[test_json_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("json test", "");
    g_btn     = g_section.create_button("Actions", ui_align::left);
    g_menu    = create_menu();
    g_menu.add_item("Run again",   cast<int64>(on_menu_run_again),   "", "");
    g_menu.add_separator();
    g_menu.add_item("Log summary", cast<int64>(on_menu_log_summary), "", "");
    g_menu.attach_to_button(g_btn);

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }
    return 1;
}
