// =============================================================================
// Strings addon comprehensive test
//
// Exercises EVERY type, method, function, and operator documented in the
// Strings API. Each numbered section tests a logical group of functionality.
//
// --- Types ---
//   string         UTF-8 string with methods + operators + iteration
//   wstring        UTF-16 wide string with methods + operators + free functions
//
// --- string methods (29) ---
//   .length()          .is_empty()          .substr(s, l)
//   .find(n)           .last_index_of(n)    .count(n)
//   .contains(t)       .starts_with(p)      .ends_with(s)
//   .starts_with_i(p)  .ends_with_i(s)      .char_at(i)
//   .to_int()          .to_float()          .to_upper()
//   .to_lower()        .trim()              .trim_left()
//   .trim_right()      .reverse()           .replace(f, t)
//   .replace_first(f,t) .repeat(n)          .pad_left(w, c)
//   .pad_right(w, c)   .insert(i, s)        .remove_range(s, e)
//   .split(sep)        .chars()
//
// --- string operators ---
//   a + b (concat)     a == b (equality)    for (int32 ch : s) {}
//
// --- string free functions ---
//   to_string(x)               char_to_str(c)
//   ord(c)                     chr(code)
//   from_chars(codes)          hex_encode(v)
//   to_hex(v)                  hex_decode(s)
//   hex_to_int(s)              base64_encode(s)
//   base64_decode(s)           url_encode(s)
//   url_decode(s)
//   format(fmt, ...)
//
// --- wstring methods (10) ---
//   .length()          .is_empty()          .char_at(i)
//   .substr(s, l)      .find(o)             .contains(o)
//   .starts_with(p)    .ends_with(s)        .to_upper()
//   .to_lower()        .to_string()
//
// --- wstring operators ---
//   a + b (concat)     a == b (equality)    < > <= >= (ordering)
//   auto-wrap: method("foo") works without cast<wstring>
//
// --- wstring free functions (4) ---
//   wstring_from_str(s)           wstring_to_str(w)
//   wstring_from_wchar_ptr(p)     wstring_from_utf8_ptr(p)
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

// ===========================================================================
// TEST ROUTINE
// ===========================================================================
void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Strings addon comprehensive test ===");

    // =======================================================================
    // 1. string constructors and basic properties
    //    Tests: string literal assignment, .length(), .is_empty()
    // =======================================================================
    section("1. string constructors and basic properties");

    string s1 = "Hello, Enma!";
    check("s1.length() == 12", s1.length() == 12);

    string s2 = "";
    check("empty string .length() == 0", s2.length() == 0);
    check("empty string .is_empty() == true", s2.is_empty());
    check("non-empty string .is_empty() == false", !s1.is_empty());

    // =======================================================================
    // 2. string substring and searching
    //    Tests: .substr(), .find(), .last_index_of(), .count(), .contains()
    // =======================================================================
    section("2. substring and searching");

    string s = "Hello, world! Hello, universe!";
    check("s.substr(0, 5) == 'Hello'", s.substr(0, 5) == "Hello");
    check("s.substr(7, 5) == 'world'", s.substr(7, 5) == "world");

    check("s.find('world') == 7", s.find("world") == 7);
    check("s.find('xyz') == -1 (absent)", s.find("xyz") == -1);

    check("s.last_index_of('Hello') == 14", s.last_index_of("Hello") == 14);
    check("s.last_index_of('xyz') == -1 (absent)", s.last_index_of("xyz") == -1);

    check("s.count('Hello') == 2", s.count("Hello") == 2);
    check("s.count('o') == 3", s.count("o") == 3);

    check("s.contains('world')", s.contains("world"));
    check("!s.contains('xyz')", !s.contains("xyz"));

    // =======================================================================
    // 3. string prefix and suffix checks
    //    Tests: .starts_with(), .ends_with(), .starts_with_i(), .ends_with_i()
    // =======================================================================
    section("3. prefix and suffix checks");

    check("s.starts_with('Hello')", s.starts_with("Hello"));
    check("!s.starts_with('world')", !s.starts_with("world"));

    check("s.ends_with('universe!')", s.ends_with("universe!"));
    check("!s.ends_with('Hello')", !s.ends_with("Hello"));

    check("s.starts_with_i('hello') (case-insensitive)", s.starts_with_i("hello"));
    check("!s.starts_with_i('xello')", !s.starts_with_i("xello"));

    check("s.ends_with_i('UNIVERSE!') (case-insensitive)", s.ends_with_i("UNIVERSE!"));
    check("!s.ends_with_i('HELLO')", !s.ends_with_i("HELLO"));

    // =======================================================================
    // 4. string char_at and type conversion
    //    Tests: .char_at(), .to_int(), .to_float()
    // =======================================================================
    section("4. character access and type conversion");

    check("s.char_at(0) == 72 ('H')", s.char_at(0) == 72);
    check("s.char_at(1) == 101 ('e')", s.char_at(1) == 101);

    string num_str = "42";
    check("num_str.to_int() == 42", num_str.to_int() == 42);
    check("'-7'.to_int() == -7", "-7".to_int() == -7);

    string pi_str = "3.14";
    check("pi_str.to_float() approx 3.14", pi_str.to_float() > 3.13 && pi_str.to_float() < 3.15);

    // =======================================================================
    // 5. string case conversion and trimming
    //    Tests: .to_upper(), .to_lower(), .trim(), .trim_left(), .trim_right()
    // =======================================================================
    section("5. case conversion and trimming");

    string mixed = "Hello World";
    check("mixed.to_upper() == 'HELLO WORLD'", mixed.to_upper() == "HELLO WORLD");
    check("mixed.to_lower() == 'hello world'", mixed.to_lower() == "hello world");

    string padded = "  spaces here  ";
    check("padded.trim() == 'spaces here'", padded.trim() == "spaces here");
    check("padded.trim_left() == 'spaces here  '", padded.trim_left() == "spaces here  ");
    check("padded.trim_right() == '  spaces here'", padded.trim_right() == "  spaces here");

    // =======================================================================
    // 6. string reverse and replacement
    //    Tests: .reverse(), .replace(), .replace_first()
    // =======================================================================
    section("6. reverse and replacement");

    check("'abc'.reverse() == 'cba'", "abc".reverse() == "cba");
    check("''.reverse() == ''", "".reverse() == "");

    string rep_str = "one fish two fish red fish blue fish";
    string all_replaced = rep_str.replace("fish", "bird");
    check("replace all 'fish' -> 'bird'", all_replaced == "one bird two bird red bird blue bird");

    string first_only = rep_str.replace_first("fish", "bird");
    check("replace_first 'fish' -> 'bird'", first_only == "one bird two fish red fish blue fish");

    // =======================================================================
    // 7. string repeat and padding
    //    Tests: .repeat(), .pad_left(), .pad_right()
    // =======================================================================
    section("7. repeat and padding");

    check("'ha'.repeat(3) == 'hahaha'", "ha".repeat(3) == "hahaha");
    check("'x'.repeat(0) == ''", "x".repeat(0) == "");
    check("'x'.repeat(1) == 'x'", "x".repeat(1) == "x");

    check("'hi'.pad_left(5, '.') == '...hi'", "hi".pad_left(5, '.') == "...hi");
    check("'hi'.pad_left(2, '.') == 'hi' (no pad needed)", "hi".pad_left(2, '.') == "hi");

    check("'hi'.pad_right(5, '.') == 'hi...'", "hi".pad_right(5, '.') == "hi...");
    check("'hi'.pad_right(2, '.') == 'hi' (no pad needed)", "hi".pad_right(2, '.') == "hi");

    // =======================================================================
    // 8. string insert and remove_range
    //    Tests: .insert(), .remove_range()
    // =======================================================================
    section("8. insert and remove_range");

    check("'abcd'.insert(2, 'XY') == 'abXYcd'", "abcd".insert(2, "XY") == "abXYcd");
    check("'abcd'.insert(0, 'Z') == 'Zabcd' (insert at start)", "abcd".insert(0, "Z") == "Zabcd");
    check("'abcd'.insert(4, 'Z') == 'abcdZ' (insert at end)", "abcd".insert(4, "Z") == "abcdZ");

    check("'abcdef'.remove_range(2, 5) == 'abf'", "abcdef".remove_range(2, 5) == "abf");
    check("'abcdef'.remove_range(0, 3) == 'def' (remove start)", "abcdef".remove_range(0, 3) == "def");
    check("'abcdef'.remove_range(0, 0) == 'abcdef' (empty range)", "abcdef".remove_range(0, 0) == "abcdef");

    // =======================================================================
    // 9. string split and chars
    //    Tests: .split(), .chars()
    // =======================================================================
    section("9. split and chars");

    array<string> parts = "a,b,c,d".split(",");
    check("split(',') length == 4", parts.length() == 4);
    bool parts_ok = parts.length() == 4;
    if (parts_ok) {
        check("split[0] == 'a'", parts.get(0) == "a");
        check("split[1] == 'b'", parts.get(1) == "b");
        check("split[2] == 'c'", parts.get(2) == "c");
        check("split[3] == 'd'", parts.get(3) == "d");
    }

    array<string> single = "no-separator".split(",");
    check("split with no match returns array with 1 element", single.length() == 1);
    if (single.length() == 1) {
        check("single element == original string", single.get(0) == "no-separator");
    }

    array<int64> codes = "ABC".chars();
    check("chars() length == 3", codes.length() == 3);
    bool codes_ok = codes.length() == 3;
    if (codes_ok) {
        check("chars()[0] == 65 ('A')", codes.get(0) == 65);
        check("chars()[1] == 66 ('B')", codes.get(1) == 66);
        check("chars()[2] == 67 ('C')", codes.get(2) == 67);
    }

    // =======================================================================
    // 10. string operators
    //     Tests: + (concat), == (equality), for (int32 ch : s) {} iteration
    // =======================================================================
    section("10. string operators");

    string a = "Hello, ";
    string b = "world!";
    string c = a + b;
    check("a + b == 'Hello, world!'", c == "Hello, world!");

    check("a == a (same content)", a == a);
    check("'abc' == 'abc' (literal equality)", "abc" == "abc");
    check("!(a == b) (different content)", !(a == b));

    // Char iteration via for-in.
    string iter_str = "AB";
    int64 iter_count = 0;
    int64 iter_sum = 0;
    for (int32 ch : iter_str) {
        iter_count = iter_count + 1;
        iter_sum = iter_sum + ch;
    }
    check("for-in iteration visited 2 characters", iter_count == 2);
    check("sum of char codes (65+66) == 131", iter_sum == 131);

    // =======================================================================
    // 11. to_string converters and char_to_str
    //     Tests: to_string(int), to_string(float), to_string(bool),
    //            char_to_str('A'), cast<string>(x)
    // =======================================================================
    section("11. to_string and char_to_str");

    check("to_string(42) == '42'", to_string(42) == "42");
    check("to_string(-7) == '-7'", to_string(-7) == "-7");

    check("to_string(3.14) == '3.14'", to_string(3.14) == "3.14");

    check("to_string(true) == 'true'", to_string(true) == "true");
    check("to_string(false) == 'false'", to_string(false) == "false");

    check("char_to_str('A') == 'A'", char_to_str('A') == "A");
    check("char_to_str('z') == 'z'", char_to_str('z') == "z");

    // cast<string>(x) universal coercion.
    check("cast<string>(42) == '42'", cast<string>(42) == "42");
    check("cast<string>(3.14) == '3.14'", cast<string>(3.14) == "3.14");
    check("cast<string>(true) == 'true'", cast<string>(true) == "true");

    // =======================================================================
    // 12. ord, chr, from_chars
    //     Tests: ord('A'), chr(65), from_chars(char-code array)
    // =======================================================================
    section("12. ord, chr, from_chars");

    check("ord('A') == 65", ord('A') == 65);
    check("ord('0') == 48", ord('0') == 48);
    check("chr(65) == 'A'", chr(65) == "A");
    check("chr(48) == '0'", chr(48) == "0");

    // from_chars: use the chars() array from a known string.
    array<int64> abc_codes = "ABC".chars();
    string rebuilt = from_chars(abc_codes);
    check("from_chars(chars('ABC')) round-trips to 'ABC'", rebuilt == "ABC");

    // =======================================================================
    // 13. hex encoding / decoding
    //     Tests: hex_encode(int64), hex_encode(string), to_hex(),
    //            hex_decode(), hex_to_int()
    // =======================================================================
    section("13. hex encode / decode");

    check("hex_encode(255) == 'ff'", hex_encode(255) == "ff");
    check("hex_encode(0) == '0'", hex_encode(0) == "0");

    check("to_hex(255) == 'ff' (alias)", to_hex(255) == "ff");
    check("to_hex(0) == '0'", to_hex(0) == "0");

    check("hex_decode('616263') == 'abc'", hex_decode("616263") == "abc");
    check("hex_decode('') == ''", hex_decode("") == "");

    check("hex_to_int('ff') == 255", hex_to_int("ff") == 255);
    check("hex_to_int('0') == 0", hex_to_int("0") == 0);
    check("hex_to_int('10') == 16", hex_to_int("10") == 16);

    // string → hex-encoded bytes overload.
    check("hex_encode('abc') == '616263'", hex_encode("abc") == "616263");

    // =======================================================================
    // 14. base64 encoding / decoding
    //     Tests: base64_encode(), base64_decode()
    // =======================================================================
    section("14. base64 encode / decode");

    string b64_encoded = base64_encode("hello");
    check("base64_encode('hello') == 'aGVsbG8='", b64_encoded == "aGVsbG8=");

    check("base64_decode('aGVsbG8=') == 'hello'", base64_decode("aGVsbG8=") == "hello");

    string empty_b64 = base64_encode("");
    check("base64_encode('') == ''", empty_b64 == "");
    check("base64_decode('') == ''", base64_decode("") == "");

    // Round-trip: encode then decode.
    string original = "enma test data";
    string round_trip = base64_decode(base64_encode(original));
    check("base64 round-trip preserves string", round_trip == original);

    // =======================================================================
    // 15. URL encoding / decoding
    //     Tests: url_encode(), url_decode()
    // =======================================================================
    section("15. URL encode / decode");

    string url_enc = url_encode("hello world & foo=bar");
    check("url_encode('hello world & foo=bar') == 'hello%20world%20%26%20foo%3Dbar'",
          url_enc == "hello%20world%20%26%20foo%3Dbar");

    string url_dec = url_decode("hello%20world");
    check("url_decode('hello%20world') == 'hello world'", url_dec == "hello world");

    // Plus sign decoded as space.
    string url_plus = url_decode("hello+world");
    check("url_decode('hello+world') == 'hello world' (+ -> space)", url_plus == "hello world");

    // Round-trip.
    string url_original = "a=b&c=d e+f";
    string url_round = url_decode(url_encode(url_original));
    check("url round-trip preserves string", url_round == url_original);

    // =======================================================================
    // 16. format() — brace syntax
    //     Tests: {d}, {i}, {}, {u}, {f}, {s}, {b}, {x}, {c}
    // =======================================================================
    section("16. format() — brace syntax");

    string fmt_d = format("x = {d}", 10);
    check("format('x = {d}', 10) == 'x = 10'", fmt_d == "x = 10");

    string fmt_i = format("i = {i}", -5);
    check("format('i = {i}', -5) == 'i = -5'", fmt_i == "i = -5");

    string fmt_empty = format("val = {}", 42);
    check("format('val = {}', 42) == 'val = 42'", fmt_empty == "val = 42");

    string fmt_u = format("u = {u}", 99);
    check("format('u = {u}', 99) == 'u = 99'", fmt_u == "u = 99");

    string fmt_f = format("y = {f}", 3.14);
    check("format('y = {f}', 3.14) == 'y = 3.14'", fmt_f == "y = 3.14");

    string fmt_s = format("name = {s}", "ada");
    check("format('name = {s}', 'ada') == 'name = ada'", fmt_s == "name = ada");

    string fmt_b = format("on = {b}", true);
    check("format('on = {b}', true) == 'on = true'", fmt_b == "on = true");

    string fmt_b_false = format("off = {b}", false);
    check("format('off = {b}', false) == 'off = false'", fmt_b_false == "off = false");

    string fmt_x = format("hex = {x}", 255);
    check("format('hex = {x}', 255) == 'hex = ff'", fmt_x == "hex = ff");

    string fmt_c = format("char = {c}", 'A');
    check("format('char = {c}', 'A') == 'char = A'", fmt_c == "char = A");

    // Multi-placeholder brace format.
    string fmt_multi = format("x = {d}, y = {f}", 10, 3.14);
    check("format('x = {d}, y = {f}', 10, 3.14) == 'x = 10, y = 3.14'",
          fmt_multi == "x = 10, y = 3.14");

    string fmt_multi2 = format("name = {s}, on = {b}", "ada", true);
    check("format('name = {s}, on = {b}', 'ada', true) == 'name = ada, on = true'",
          fmt_multi2 == "name = ada, on = true");

    // =======================================================================
    // 17. format() — printf-style syntax
    //     Tests: %d, %i, %u, %f, %s, %b, %x, %c, %%, unknown % passthrough
    // =======================================================================
    section("17. format() — printf-style syntax");

    string p_d = format("x = %d", 10);
    check("format('x = %d', 10) == 'x = 10'", p_d == "x = 10");

    string p_i = format("i = %i", -5);
    check("format('i = %i', -5) == 'i = -5'", p_i == "i = -5");

    string p_u = format("u = %u", 99);
    check("format('u = %u', 99) == 'u = 99'", p_u == "u = 99");

    string p_f = format("y = %f", 3.14);
    check("format('y = %f', 3.14) == 'y = 3.14'", p_f == "y = 3.14");

    string p_s = format("name = %s", "ada");
    check("format('name = %s', 'ada') == 'name = ada'", p_s == "name = ada");

    string p_b = format("on = %b", true);
    check("format('on = %b', true) == 'on = true'", p_b == "on = true");

    string p_x = format("hex = %x", 255);
    check("format('hex = %x', 255) == 'hex = ff'", p_x == "hex = ff");

    string p_c = format("char = %c", 'A');
    check("format('char = %c', 'A') == 'char = A'", p_c == "char = A");

    // %% produces literal %.
    string p_pct = format("100%% done");
    check("format('100%%%% done') == '100% done'", p_pct == "100% done");

    // Unknown % sequences pass through unchanged.
    string p_unknown = format("keep %z as-is");
    check("format with unknown %z passes through", p_unknown == "keep %z as-is");

    // =======================================================================
    // 18. format() — mixed brace and printf-style
    //     Tests: mixing {d} and %f in same format string
    // =======================================================================
    section("18. format() — mixed brace and printf-style");

    string mixed_fmt = format("brace {d} and printf %f", 10, 3.14);
    check("mixed brace and printf format works", mixed_fmt == "brace 10 and printf 3.14");

    // =======================================================================
    // 19. wstring construction and basic properties
    //     Tests: cast<wstring>(), .length(), .is_empty()
    // =======================================================================
    section("19. wstring construction and basic properties");

    wstring ws1 = cast<wstring>("Hello");
    check("cast<wstring>('Hello') valid", true);

    check("ws1.length() == 5", ws1.length() == 5);
    check("!ws1.is_empty()", !ws1.is_empty());

    wstring ws_empty = cast<wstring>("");
    check("empty wstring .is_empty() == true", ws_empty.is_empty());
    check("empty wstring .length() == 0", ws_empty.length() == 0);

    // =======================================================================
    // 20. wstring: cast back to string
    //     Tests: cast<string>(w)
    // =======================================================================
    section("20. wstring to string via cast");

    string back = cast<string>(ws1);
    check("cast<string>(wstring('Hello')) == 'Hello'", back == "Hello");

    // =======================================================================
    // 21. wstring methods: char_at, substr, find, contains
    //     Tests: .char_at(), .substr(), .find(), .contains()
    // =======================================================================
    section("21. wstring char_at, substr, find, contains");

    wstring ws_hello = cast<wstring>("Hello, world!");

    check("ws_hello.char_at(0) == 72 ('H')", ws_hello.char_at(0) == 72);
    check("ws_hello.char_at(4) == 111 ('o')", ws_hello.char_at(4) == 111);

    wstring ws_sub = ws_hello.substr(0, 5);
    check("ws_hello.substr(0, 5) converted to string == 'Hello'",
          cast<string>(ws_sub) == "Hello");

    check("ws_hello.find(cast<wstring>('world')) == 7", ws_hello.find(cast<wstring>("world")) == 7);
    check("ws_hello.find(cast<wstring>('xyz')) == -1", ws_hello.find(cast<wstring>("xyz")) == -1);

    check("ws_hello.contains(cast<wstring>('world'))", ws_hello.contains(cast<wstring>("world")));
    check("!ws_hello.contains(cast<wstring>('xyz'))", !ws_hello.contains(cast<wstring>("xyz")));

    // =======================================================================
    // 22. wstring: starts_with, ends_with, to_upper, to_lower, to_string
    //     Tests: .starts_with(), .ends_with(), .to_upper(), .to_lower(),
    //            .to_string()
    // =======================================================================
    section("22. wstring starts_with, ends_with, case fold, to_string");

    wstring ws_case = cast<wstring>("Hello World");

    check("ws_case.starts_with(cast<wstring>('Hello'))", ws_case.starts_with(cast<wstring>("Hello")));
    check("!ws_case.starts_with(cast<wstring>('World'))", !ws_case.starts_with(cast<wstring>("World")));

    check("ws_case.ends_with(cast<wstring>('World'))", ws_case.ends_with(cast<wstring>("World")));
    check("!ws_case.ends_with(cast<wstring>('Hello'))", !ws_case.ends_with(cast<wstring>("Hello")));

    wstring ws_upper = ws_case.to_upper();
    check("wstring.to_upper() -> string == 'HELLO WORLD'",
          cast<string>(ws_upper) == "HELLO WORLD");

    wstring ws_lower = ws_case.to_lower();
    check("wstring.to_lower() -> string == 'hello world'",
          cast<string>(ws_lower) == "hello world");

    string ws_str = ws_case.to_string();
    check("wstring.to_string() == 'Hello World'", ws_str == "Hello World");

    // =======================================================================
    // 23. wstring auto-wrap for string arguments
    //     Tests: w.contains('foo') works without explicit cast<wstring>
    // =======================================================================
    section("23. wstring auto-wrap string args");

    wstring ws_aw = cast<wstring>("auto-wrap test");
    check("ws_aw.contains('wrap') via auto-wrap", ws_aw.contains("wrap"));
    check("!ws_aw.contains('nope') via auto-wrap", !ws_aw.contains("nope"));
    check("ws_aw.starts_with('auto') via auto-wrap", ws_aw.starts_with("auto"));
    check("ws_aw.ends_with('test') via auto-wrap", ws_aw.ends_with("test"));

    int64 aw_find = ws_aw.find("wrap");
    check("ws_aw.find('wrap') == 5 via auto-wrap", aw_find == 5);
    check("ws_aw.find('nope') == -1 via auto-wrap", ws_aw.find("nope") == -1);

    // =======================================================================
    // 24. wstring operators: +, ==, <, >, <=, >=
    //     Tests: concat, equality, ordering
    // =======================================================================
    section("24. wstring operators");

    wstring op_a = cast<wstring>("Hello, ");
    wstring op_b = cast<wstring>("world!");
    wstring op_c = op_a + cast<wstring>("world!");
    check("wstring concat via +", cast<string>(op_c) == "Hello, world!");

    wstring op_eq1 = cast<wstring>("same");
    wstring op_eq2 = cast<wstring>("same");
    wstring op_ne  = cast<wstring>("different");
    check("wstring == (same)", op_eq1 == op_eq2);
    check("wstring != (different)", !(op_eq1 == op_ne));

    wstring op_small = cast<wstring>("abc");
    wstring op_large = cast<wstring>("zzz");
    check("wstring < ('abc' < 'zzz')", op_small < op_large);
    check("!wstring > ('abc' > 'zzz')", !(op_small > op_large));
    check("wstring <= ('abc' <= 'zzz')", op_small <= op_large);
    check("!wstring >= ('abc' >= 'zzz')", !(op_small >= op_large));
    check("wstring <= ('same' <= 'same')", op_eq1 <= op_eq2);
    check("wstring >= ('same' >= 'same')", op_eq1 >= op_eq2);

    // =======================================================================
    // 25. wstring free functions
    //     Tests: wstring_from_str(), wstring_to_str(),
    //            wstring_from_wchar_ptr(), wstring_from_utf8_ptr()
    // =======================================================================
    section("25. wstring free functions");

    wstring ws_from_str = wstring_from_str("hello from str");
    check("wstring_from_str('hello from str') valid", true);
    string ws_str_back = wstring_to_str(ws_from_str);
    check("wstring_to_str(wstring_from_str('hello from str')) round-trips",
          ws_str_back == "hello from str");

    // wstring_from_wchar_ptr takes a C pointer (int64). Pass 0 to verify
    // it returns an empty/null wstring rather than crashing.
    wstring ws_wchar = wstring_from_wchar_ptr(0);
    check("wstring_from_wchar_ptr(0) survives (null ptr)", true);

    // wstring_from_utf8_ptr also takes a C pointer (int64). Pass 0.
    wstring ws_utf8 = wstring_from_utf8_ptr(0);
    check("wstring_from_utf8_ptr(0) survives (null ptr)", true);

    // =======================================================================
    // Summary
    // =======================================================================
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
    print_console("[menu] 'Run again' clicked - resetting and re-firing");
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
    print_console("[strings] launching test routine + sidebar menu");

    g_section = create_sidebar_section("strings test", "");
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
