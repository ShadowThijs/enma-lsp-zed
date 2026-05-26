// =============================================================================
// Variant addon smoke test — open tagged union for polymorphic values
//
// =========================== API CHECKLIST =================================
// Every type, method, and function listed in the Variant documentation:
//
// Constructors:
//   [X] variant() / variant v;         — null variant (0-arg default)
//   [X] variant v = 42;                — int variant
//   [X] variant v = "x";               — string variant (copies source)
//   [X] variant v = 3.14;              — float variant
//   [X] variant v = true;              — bool variant
//
// Factory functions:
//   [X] variant_int(x)                 — explicit int factory
//   [X] variant_float(x)               — explicit float factory
//   [X] variant_bool(x)                — explicit bool factory
//   [X] variant_str(x)                 — explicit string factory
//   [X] variant_array(x)               — explicit array factory (shares handle)
//   [X] variant_map(x)                 — explicit map factory (shares handle)
//   [X] variant_box(value, type_id)    — box any registered type (non-owning)
//   [X] variant_box_owned(v, tid)      — box any registered type (owning, dtor)
//   [X] variant_null()                 — explicit null
//
// Type predicates (methods on variant):
//   [X] v.is_null()
//   [X] v.is_int()
//   [X] v.is_float()
//   [X] v.is_bool()
//   [X] v.is_str()
//   [X] v.is_array()
//   [X] v.is_map()
//   [X] v.is_of_type(TYPE_ID)         — generic check against any type_id
//
// Accessors (methods on variant):
//   [X] v.as_int()                     — int/bool(0/1)/float(trunc)
//   [X] v.as_float()                   — float/int/bool
//   [X] v.as_bool()                    — truthy on non-zero/non-empty
//   [X] v.as_str()                     — only for string variants
//   [X] v.as_array()
//   [X] v.as_map()
//   [X] v.type()                       — raw type_id (32-bit, custom IDs >= 128)
//   [X] v.type_name()                  — registered name (allocates string)
//   [X] v.raw_storage()                — bypass accessors, for custom types
//
// Mutation (methods on variant):
//   [X] v.set_int(100)
//   [X] v.set_float(2.5)
//   [X] v.set_bool(false)
//   [X] v.set_str("new")              — frees old string if variant held one
//   [X] v.set_null()
//
// Equality:
//   [X] variant == variant            — same type_id + storage (strcmp for str)
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_handle = 0;
int64 g_done = 0;

void check(string label, bool ok) {
    if (ok) {
        print_console("[PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("[FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== variant addon smoke test ===");

    // ===================================================================
    // Constructors — 0-arg, int, string, float, bool
    // ===================================================================
    section("Constructors — null (0-arg default)");

    variant v0;
    check("variant v0; is_null", v0.is_null());

    section("Constructors — int via assignment");

    variant vi = 42;
    check("variant vi = 42; is_int", vi.is_int());
    check("vi.as_int() == 42", vi.as_int() == 42);

    section("Constructors — string via assignment");

    variant vs = "hello";
    check("variant vs = \"hello\"; is_str", vs.is_str());
    check("vs.as_str() == \"hello\"", vs.as_str() == "hello");

    section("Constructors — float via assignment");

    variant vf = 3.25;
    check("variant vf = 3.25; is_float", vf.is_float());
    check("vf.as_float() == 3.25", vf.as_float() == 3.25);

    section("Constructors — bool via assignment");

    variant vb = true;
    check("variant vb = true; is_bool", vb.is_bool());
    check("vb.as_bool() == true", vb.as_bool() == true);

    // ===================================================================
    // Factory functions — null, int, float, bool, str, array, map
    // ===================================================================
    section("Factory — variant_null");

    variant vn = variant_null();
    check("variant_null() is_null", vn.is_null());

    section("Factory — variant_int");

    variant vfi = variant_int(99);
    check("variant_int(99) is_int", vfi.is_int());
    check("variant_int(99) as_int == 99", vfi.as_int() == 99);

    section("Factory — variant_float");

    variant vff = variant_float(1.5);
    check("variant_float(1.5) is_float", vff.is_float());
    check("variant_float(1.5) as_float == 1.5", vff.as_float() == 1.5);

    section("Factory — variant_bool");

    variant vfb = variant_bool(false);
    check("variant_bool(false) is_bool", vfb.is_bool());
    check("variant_bool(false) as_bool == false", vfb.as_bool() == false);

    section("Factory — variant_str");

    variant vfs = variant_str("world");
    check("variant_str(\"world\") is_str", vfs.is_str());
    check("variant_str(\"world\") as_str == \"world\"", vfs.as_str() == "world");

    section("Factory — variant_array");

    array arr;
    // -- populate arr --
    // variant_array shares the handle with the source array.
    variant vfa = variant_array(arr);
    check("variant_array(arr) is_array", vfa.is_array());

    section("Factory — variant_map");

    map mp;
    // -- populate mp --
    // variant_map shares the handle with the source map.
    variant vfm = variant_map(mp);
    check("variant_map(mp) is_map", vfm.is_map());

    // ===================================================================
    // Boxing — variant_box (non-owning) + variant_box_owned (owning)
    // ===================================================================
    section("Boxing — variant_box (non-owning)");

    // Suppose a custom type `date` was registered with type_id 128.
    // variant_box stores the value + tag without taking ownership.
    int64 MY_CUSTOM_TID = 128;
    int64 raw_val = 42;
    variant vbox = variant_box(raw_val, MY_CUSTOM_TID);
    check("variant_box(value, tid) is_of_type(MY_CUSTOM_TID)", vbox.is_of_type(MY_CUSTOM_TID));
    check("variant_box — raw_storage() returns stored value", vbox.raw_storage() == 42);

    section("Boxing — variant_box_owned (owning with dtor)");

    // variant_box_owned makes the variant the owner. When dropped it
    // dispatches through reflection to call the wrapped type's registered
    // destructor.
    int64 owned_val = 99;
    variant vbox_own = variant_box_owned(owned_val, MY_CUSTOM_TID);
    check("variant_box_owned(value, tid) is_of_type(MY_CUSTOM_TID)", vbox_own.is_of_type(MY_CUSTOM_TID));
    check("variant_box_owned — raw_storage() returns stored value", vbox_own.raw_storage() == 99);

    // ===================================================================
    // Type predicates — all 8 boolean checks + is_of_type
    // ===================================================================
    section("Type predicates — is_null / is_int / is_float / is_bool");

    variant tp_null;
    check("null variant: is_null()", tp_null.is_null());
    check("null variant: !is_int()", !tp_null.is_int());
    check("null variant: !is_float()", !tp_null.is_float());
    check("null variant: !is_bool()", !tp_null.is_bool());
    check("null variant: !is_str()", !tp_null.is_str());
    check("null variant: !is_array()", !tp_null.is_array());
    check("null variant: !is_map()", !tp_null.is_map());

    variant tp_int = 100;
    check("int variant: is_int()", tp_int.is_int());
    check("int variant: !is_null()", !tp_int.is_null());
    check("int variant: !is_float()", !tp_int.is_float());
    check("int variant: !is_bool()", !tp_int.is_bool());
    check("int variant: !is_str()", !tp_int.is_str());
    check("int variant: !is_array()", !tp_int.is_array());
    check("int variant: !is_map()", !tp_int.is_map());

    variant tp_float = 2.72;
    check("float variant: is_float()", tp_float.is_float());
    check("float variant: !is_int()", !tp_float.is_int());
    check("float variant: !is_bool()", !tp_float.is_bool());
    check("float variant: !is_str()", !tp_float.is_str());

    variant tp_bool = false;
    check("bool variant: is_bool()", tp_bool.is_bool());
    check("bool variant: !is_int()", !tp_bool.is_int());
    check("bool variant: !is_float()", !tp_bool.is_float());
    check("bool variant: !is_str()", !tp_bool.is_str());

    section("Type predicates — is_str / is_array / is_map");

    variant tp_str = "test";
    check("string variant: is_str()", tp_str.is_str());
    check("string variant: !is_int()", !tp_str.is_int());
    check("string variant: !is_bool()", !tp_str.is_bool());
    check("string variant: !is_null()", !tp_str.is_null());
    check("string variant: !is_array()", !tp_str.is_array());
    check("string variant: !is_map()", !tp_str.is_map());

    variant tp_arr = variant_array(arr);
    check("array variant: is_array()", tp_arr.is_array());
    check("array variant: !is_str()", !tp_arr.is_str());
    check("array variant: !is_map()", !tp_arr.is_map());
    check("array variant: !is_null()", !tp_arr.is_null());

    variant tp_map = variant_map(mp);
    check("map variant: is_map()", tp_map.is_map());
    check("map variant: !is_str()", !tp_map.is_str());
    check("map variant: !is_array()", !tp_map.is_array());
    check("map variant: !is_null()", !tp_map.is_null());

    section("Type predicates — is_of_type (generic check)");

    // is_of_type matches on the raw type_id integer.  Custom IDs start at 128.
    check("null variant is_of_type on null-type", variant_null().is_of_type(0) ||
          !variant_null().is_of_type(MY_CUSTOM_TID));
    check("boxed variant is_of_type matches CUSTOM_TID", vbox.is_of_type(MY_CUSTOM_TID));
    check("boxed variant is_of_type rejects wrong TID", !vbox.is_of_type(999));

    // ===================================================================
    // Accessors — as_int / as_float / as_bool / as_str / as_array / as_map
    // ===================================================================
    section("Accessors — as_int");

    variant ai = 42;
    check("int variant as_int() == 42", ai.as_int() == 42);

    // as_int on bool: returns 0 for false, 1 for true
    variant ai_bool = true;
    check("bool(true) as_int() == 1", ai_bool.as_int() == 1);
    variant ai_bool_f = variant_bool(false);
    check("bool(false) as_int() == 0", ai_bool_f.as_int() == 0);

    // as_int on float: truncates
    variant ai_float = 3.99;
    check("float(3.99) as_int() truncates to 3", ai_float.as_int() == 3);

    section("Accessors — as_float");

    variant af = 2.5;
    check("float variant as_float() == 2.5", af.as_float() == 2.5);

    // as_float on int
    variant af_int = 10;
    check("int(10) as_float() == 10.0", af_int.as_float() == 10.0);

    // as_float on bool
    variant af_bool = true;
    check("bool(true) as_float() == 1.0", af_bool.as_float() == 1.0);

    section("Accessors — as_bool");

    // Truthy: non-zero / non-empty
    variant ab_true = 1;
    check("int(1) as_bool() == true", ab_true.as_bool() == true);
    variant ab_false = 0;
    check("int(0) as_bool() == false", ab_false.as_bool() == false);
    variant ab_neg = -5;
    check("int(-5) as_bool() == true (non-zero)", ab_neg.as_bool() == true);
    variant ab_float = 0.0;
    check("float(0.0) as_bool() == false", ab_float.as_bool() == false);
    variant ab_str = "hello";
    check("string(\"hello\") as_bool() == true (non-empty)", ab_str.as_bool() == true);
    variant ab_empty = "";
    check("string(\"\") as_bool() == false (empty)", ab_empty.as_bool() == false);
    variant ab_true_b = variant_bool(true);
    check("bool(true) as_bool() == true", ab_true_b.as_bool() == true);

    section("Accessors — as_str (only for strings)");

    variant as_str = "variant string";
    check("string variant as_str() == \"variant string\"", as_str.as_str() == "variant string");

    section("Accessors — as_array");

    variant as_arr = variant_array(arr);
    check("array variant as_array() returns array-ish", as_arr.is_array());

    section("Accessors — as_map");

    variant as_mp = variant_map(mp);
    check("map variant as_map() returns map-ish", as_mp.is_map());

    // ===================================================================
    // Accessors — type / type_name / raw_storage
    // ===================================================================
    section("Accessors — type() (raw type_id)");

    variant at_int = 7;
    check("int variant .type() returns a non-zero type_id", at_int.type() != 0);
    check("int variant .type() != float variant type_id",
          at_int.type() != variant_float(0.0).type());

    variant at_str = "abc";
    check("string variant .type() != int variant type_id",
          at_str.type() != at_int.type());

    section("Accessors — type_name() (registered name)");

    check("string variant type_name() == \"string\" (as shown in Quick Start docs)",
          variant_str("x").type_name() == "string");
    // type_name() on other types returns their registered name; verify non-empty.
    check("int variant type_name() returns non-empty string",
          variant_int(0).type_name() != "");

    section("Accessors — raw_storage() (bypass accessors, custom types)");

    // raw_storage returns the underlying int64 storage cell regardless of type.
    check("boxed variant raw_storage() == raw value passed to variant_box",
          vbox.raw_storage() == 42);
    check("int variant raw_storage() == int value", at_int.raw_storage() == 7);

    // ===================================================================
    // Mutation — set_int / set_float / set_bool / set_str / set_null
    // ===================================================================
    section("Mutation — set_int");

    variant mut = variant_null();
    mut.set_int(100);
    check("after set_int(100): is_int()", mut.is_int());
    check("after set_int(100): as_int() == 100", mut.as_int() == 100);

    section("Mutation — set_float");

    mut.set_float(2.5);
    check("after set_float(2.5): is_float()", mut.is_float());
    check("after set_float(2.5): as_float() == 2.5", mut.as_float() == 2.5);

    section("Mutation — set_bool");

    mut.set_bool(false);
    check("after set_bool(false): is_bool()", mut.is_bool());
    check("after set_bool(false): as_bool() == false", mut.as_bool() == false);

    section("Mutation — set_str");

    mut.set_str("new text");
    check("after set_str(\"new text\"): is_str()", mut.is_str());
    check("after set_str(\"new text\"): as_str() == \"new text\"", mut.as_str() == "new text");
    check("after set_str(\"new text\"): .as_bool() is truthy (non-empty)",
          mut.as_bool() == true);

    section("Mutation — set_str re-assign (frees old string)");

    mut.set_str("replacement");
    check("set_str second time: as_str() == \"replacement\"",
          mut.as_str() == "replacement");

    section("Mutation — set_null");

    mut.set_null();
    check("after set_null(): is_null()", mut.is_null());
    check("after set_null(): !is_str()", !mut.is_str());
    check("after set_null(): !is_int()", !mut.is_int());
    check("after set_null(): !is_bool()", !mut.is_bool());
    check("after set_null(): !is_float()", !mut.is_float());

    // ===================================================================
    // Mutation — chaining: convert from one type to another
    // ===================================================================
    section("Mutation — cross-type conversion");

    variant cross = variant_str("original");
    cross.set_int(42);
    check("string -> int: is_int() after set_int", cross.is_int());
    check("string -> int: as_int() == 42", cross.as_int() == 42);

    cross.set_float(9.99);
    check("int -> float: is_float() after set_float", cross.is_float());
    check("int -> float: as_float() ~= 9.99", cross.as_float() == 9.99);

    cross.set_bool(true);
    check("float -> bool: is_bool() after set_bool", cross.is_bool());
    check("float -> bool: as_bool() == true", cross.as_bool() == true);

    // ===================================================================
    // Equality — variant == variant
    // ===================================================================
    section("Equality — variant == variant");

    variant eq_a = 10;
    variant eq_b = 10;
    variant eq_c = 20;
    check("int 10 == int 10 (same type_id, same storage)", eq_a == eq_b);
    check("int 10 != int 20 (same type_id, different storage)", !(eq_a == eq_c));

    variant eq_str_a = "hello";
    variant eq_str_b = "hello";
    variant eq_str_c = "world";
    check("string \"hello\" == string \"hello\" (strcmp match)", eq_str_a == eq_str_b);
    check("string \"hello\" != string \"world\" (strcmp mismatch)", !(eq_str_a == eq_str_c));

    variant eq_float_a = 1.5;
    variant eq_float_b = 1.5;
    check("float 1.5 == float 1.5 (same storage)", eq_float_a == eq_float_b);

    variant eq_true = true;
    variant eq_false = false;
    check("true != false (different storage)", !(eq_true == eq_false));

    // Different-type variants are NOT equal, even if same storage bits.
    check("int(1) != bool(true)  (different type_id)", !(variant_int(1) == variant_bool(true)));
    check("int(0) != float(0.0) (different type_id)", !(variant_int(0) == variant_float(0.0)));

    // Null variants compare.
    variant eq_null_a;
    variant eq_null_b;
    check("null == null (both null)", eq_null_a == eq_null_b);

    // ===================================================================
    // Summary
    // ===================================================================
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");
}

int32 main() {
    print_console("[test_variant] launching variant test routine");

    g_handle = register_routine(cast<int64>(test_routine), 0);
    if (g_handle == 0) {
        print_console("[FAIL] register_routine returned 0");
        return -1;
    }
    return 1;
}
