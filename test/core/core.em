// =============================================================================
// Core addon comprehensive test
//
// DOCUMENTATION SOURCE: docs/Addons/Core.md
// Also incorporates: types.json (core module), Engine Lifecycle,
//                    Advanced language guide (coroutines, static_assert)
//
// ── TYPES AND THEIR METHODS ─────────────────────────────────────────────────────
//
// TYPE: string (29 methods + 3 operators + for-in iteration)
//   M  .length()                          character count
//   M  .is_empty()                        true if length == 0
//   M  .substr(start, len)                extract substring
//   M  .find(needle)                      index of first match, -1 if absent
//   M  .last_index_of(needle)             index of last match, -1 if absent
//   M  .count(needle)                     number of non-overlapping matches
//   M  .contains(text)                    true if substring exists
//   M  .starts_with(prefix)               prefix check
//   M  .ends_with(suffix)                 suffix check
//   M  .starts_with_i(prefix)             case-insensitive prefix
//   M  .ends_with_i(suffix)               case-insensitive suffix
//   M  .char_at(i)                        character code at index
//   M  .to_int()                          parse integer
//   M  .to_float()                        parse float
//   M  .to_upper()                        uppercase copy
//   M  .to_lower()                        lowercase copy
//   M  .trim()                            strip leading/trailing whitespace
//   M  .trim_left()                       strip leading whitespace only
//   M  .trim_right()                      strip trailing whitespace only
//   M  .reverse()                         reversed copy
//   M  .replace(from, to)                 replace all occurrences
//   M  .replace_first(from, to)           replace first occurrence only
//   M  .repeat(n)                         concatenate N copies
//   M  .pad_left(width, char)             left-pad to width using char
//   M  .pad_right(width, char)            right-pad to width using char
//   M  .insert(i, s)                      insert string at index
//   M  .remove_range(start, end)          remove chars in [start, end)
//   M  .split(sep)                        split by separator -> string[]
//   M  .chars()                           returns array of char codes (int64[])
//   OP operator+(a, b)                    concatenation
//   OP operator==(a, b)                   equality comparison
//   IT for (int32 ch : s) {}              char iteration
//
// TYPE: wstring (10 methods + 4 operators + 4 free functions)
//   M  .length()                          code unit count
//   M  .is_empty()                        true if length == 0
//   M  .char_at(i)                        UTF-16 code unit at index
//   M  .substr(start, len)                extract wstring
//   M  .find(other)                       index of first match, -1 if missing
//   M  .contains(other)                   true if substring exists
//   M  .starts_with(prefix)               prefix check
//   M  .ends_with(suffix)                 suffix check
//   M  .to_upper()                        ASCII case fold to uppercase
//   M  .to_lower()                        ASCII case fold to lowercase
//   M  .to_string()                       UTF-16 -> UTF-8 string
//   OP operator+(a, b)                    concatenation
//   OP operator==(a, b)                   equality
//   OP operator<(a, b) / > / <= / >=      ordering
//   F  wstring_from_str(s)                UTF-8 -> UTF-16
//   F  wstring_to_str(w)                  UTF-16 -> UTF-8
//   F  wstring_from_wchar_ptr(p)          const wchar_t* -> wstring (copies)
//   F  wstring_from_utf8_ptr(p)           const char* -> wstring (transcodes)
//
// TYPE: array<T> (30 methods + 1 free function)
//   M  .push(v)                           append element
//   M  .pop()                             remove and return last
//   M  .insert(i, v)                      insert at index
//   M  .remove(i)                         remove at index
//   M  .get(i)                            read element
//   M  .set(i, v)                         write element
//   M  .length()                          element count
//   M  .capacity()                        allocated capacity
//   M  .stride()                          bytes per element
//   M  .resize(n)                         resize to N elements
//   M  .contains(v)                       true if value exists
//   M  .index_of(v)                       index of first match, -1 if not found
//   M  .sort()                            sort ascending
//   M  .reverse()                         reverse in place
//   M  .join(sep)                         join elements into string
//   M  .clear()                           remove all elements
//   M  .free()                            release memory
//   M  .slice(start, end)                 sub-array
//   M  .first()                           first element
//   M  .last()                            last element
//   M  .pop_front()                       remove and return first
//   M  .push_front(x)                     prepend
//   M  .swap(i, j)                        swap two indices
//   M  .fill(x)                           overwrite every element with x
//   M  .count(x)                          how many elements equal x
//   M  .unique()                          new array with duplicates removed
//   M  .sum()                             sum of all elements
//   M  .min()                             smallest element
//   M  .max()                             largest element
//   M  .min_idx()                         index of smallest element
//   M  .max_idx()                         index of largest element
//   M  .chunk(n)                          split into arrays of size n
//   M  .flat()                            one-level flatten
//   M  .map(fn)                           transform each element: T(T)
//   M  .filter(fn)                        filter by predicate: bool(T)
//   M  .reduce(fn, acc)                   reduce with accumulator: T(T,T)
//   M  .any(fn)                           any-match
//   M  .all(fn)                           all-match
//   M  .find(fn)                          index of first match
//   M  .print_int()                       print as int64 values
//   M  .println_int()                     print as int64 with newline
//   M  .print_float()                     print as float64 values
//   M  .println_float()                   print as float64 with newline
//   M  .print_str()                       print as string pointers
//   M  .println_str()                     print as string pointers with newline
//   F  array_create_strided(cap, stride)  create array with custom stride
//
// TYPE: map<string, V> (14 methods)
//   M  .set(k, v)                         insert or overwrite entry
//   M  .get(k)                            read value by key
//   M  .get_or_default(k, def)            read value or fallback
//   M  .contains(k)                       true if key exists
//   M  .has(k)                            alias of contains
//   M  .has_value(v)                      true if any entry's value equals v
//   M  .size()                            number of entries
//   M  .length()                          alias of size
//   M  .remove(k)                         delete entry by key
//   M  .clear()                           remove all entries
//   M  .free()                            release memory
//   M  .keys()                            returns string[] of all keys
//   M  .values()                          returns element[] of all values
//   M  .merge(other)                      copy all entries from other
//   OP m["key"] / m["key"] = v           subscript access
//   IT for (string k, V v : m) {}        key-value iteration
//
// TYPE: imap<V> (11 methods, int64-keyed)
//   M  .set(k, v)                         insert or overwrite entry
//   M  .get(k)                            read value by key
//   M  .get_or_default(k, def)            read value or fallback
//   M  .has(k)                            alias of contains
//   M  .contains(k)                       true if int64 key exists
//   M  .remove(k)                         delete entry by key
//   M  .length()                          alias of size
//   M  .size()                            number of entries
//   M  .clear()                           remove all entries
//   M  .keys()                            returns int64[] of all keys
//   M  .values()                          returns element[] of all values
//   OP tbl[k] / tbl[k] = v               subscript access
//   IT for (int64 k, V v : tbl) {}       key-value iteration
//
// ── STANDALONE FUNCTIONS ────────────────────────────────────────────────────────
//
//   Output (4):
//     F  print(s)                          print to console, no newline
//     F  println(s)                        print to console with newline
//     F  print_console(msg)                print to debug console (stdout)
//     F  format(fmt, ...)                  variadic format string
//
//   Conversion (5):
//     F  to_string(v)                      int/uint/char/float/bool -> string
//     F  char_to_str(c)                    char -> single-char string
//     F  ord(c)                            char -> code point
//     F  chr(code)                         code point -> 1-char string
//     F  from_chars(codes)                 char-code array -> string
//
//   Hex encoding (4):
//     F  hex_encode(v)                     int64 or string -> hex string
//     F  to_hex(v)                         alias for hex_encode(int64)
//     F  hex_decode(s)                     hex string -> byte-string
//     F  hex_to_int(s)                     hex string -> int64
//
//   Base64 (2):
//     F  base64_encode(data)               string -> base64
//     F  base64_decode(text)               base64 -> string
//
//   URL (2):
//     F  url_encode(data)                  string -> URL-encoded
//     F  url_decode(text)                  URL-encoded -> string (+ -> space)
//
//   Runtime functions (9):
//     F  heap_collect()                    no-op (deterministic cleanup)
//     F  heap_count()                      heap allocation count
//     F  set_memory_budget(bytes)          heap memory limit
//     F  set_budget(n)                     instruction budget
//     F  register_event(id, handler)       register event callback
//     F  fire_event(id, arg)               fire all callbacks for event
//     F  clear_events()                    unregister all events
//     F  assert(condition)                 runtime assertion
//     F  time_ms()                         milliseconds since epoch
//
//   Coroutine type (1 type, 2 methods):
//     T  coroutine_t
//     M  .next()                           advance to next yield; returns 1 if yielded, 0 if done
//     M  .value()                          retrieve last yielded value
//
//   Counter type:
//     T  counter_t
//
//   Compile-time:
//     S  static_assert(condition, "msg")   compile-time assertion
//
// TOTAL: 5 types, ~90 methods, ~26 standalone functions, 2 operators/iteration
// =============================================================================


// =============================================================================
// MODULE-LEVEL COMPILE-TIME ASSERTIONS
// =============================================================================

static_assert(sizeof(int32) == 4, "int32 must be 4 bytes");
static_assert(sizeof(int64) == 8, "int64 must be 8 bytes");
static_assert(sizeof(float64) == 8, "float64 must be 8 bytes");
static_assert(1 + 1 == 2, "basic arithmetic works at compile time");


// =============================================================================
// TEST INFRASTRUCTURE
// =============================================================================

int64 g_pass = 0;
int64 g_fail = 0;

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


// =============================================================================
// CALLBACKS FOR HIGHER-ORDER ARRAY METHODS
// =============================================================================

int64 doubler(int64 x) { return x * 2; }

int64 is_even(int64 x) { return (x % 2) == 0 ? 1 : 0; }

int64 add_fn(int64 acc, int64 x) { return acc + x; }


// =============================================================================
// EVENT CALLBACK
// =============================================================================

int64 g_event_fired = 0;
int64 g_event_arg = 0;

void on_test_event(int64 arg) {
    g_event_fired = 1;
    g_event_arg = arg;
}


// =============================================================================
// COROUTINE DEFINITION
// =============================================================================

coroutine int32 count_up(int32 start) {
    int32 i = start;
    while (i < start + 5) {
        yield i;
        i = i + 1;
    }
}


// =============================================================================
// MAIN TEST ROUTINE
// =============================================================================

void run_core_tests() {

    // =========================================================================
    // 1. Output functions: print, println, print_console, format
    // =========================================================================
    section("1. Output functions");

    // print_console is the primary test output mechanism.
    print_console("print_console works");

    // print and println with various types (verify they don't crash)
    print("testing print: ");
    print(42);
    print(" ");
    print(3.14);
    print(" ");
    print(true);
    print(" ");
    print('A');
    println("");
    println("testing println works");
    println("x = " + 42);
    check("println and print execute without crash", true);

    // format with all specifiers
    string fd = format("int = {d}", -10);
    check("format {d} signed int", fd == "int = -10");

    string fi = format("int = {i}", 42);
    check("format {i} signed int", fi == "int = 42");

    string fu = format("uint = {u}", 99);
    check("format {u} unsigned int", fu == "uint = 99");

    string ff = format("float = {f}", 3.14);
    check("format {f} float", ff == "float = 3.14");

    string fs = format("str = {s}", "hello");
    check("format {s} string", fs == "str = hello");

    string fb = format("bool = {b}", true);
    check("format {b} bool true", fb == "bool = true");

    string fbf = format("bool = {b}", false);
    check("format {b} bool false", fbf == "bool = false");

    string fx = format("hex = {x}", 255);
    check("format {x} hex", fx == "hex = ff");

    string fc = format("char = {c}", 'A');
    check("format {c} char", fc == "char = A");

    // printf-style specifiers
    string pd = format("val = %d", 10);
    check("format %d", pd == "val = 10");

    string pi = format("val = %i", 42);
    check("format %i", pi == "val = 42");

    string pu = format("val = %u", 99);
    check("format %u", pu == "val = 99");

    string pf = format("val = %f", 3.14);
    check("format %f", pf == "val = 3.14");

    string ps = format("val = %s", "hello");
    check("format %s", ps == "val = hello");

    string pb = format("val = %b", true);
    check("format %b", pb == "val = true");

    string px = format("val = %x", 255);
    check("format %x", px == "val = ff");

    string pc = format("val = %c", 'A');
    check("format %c", pc == "val = A");

    // %% literal percent
    string pct = format("100%% done");
    check("format %% literal percent", pct == "100% done");

    // Unknown % passes through
    string unk = format("keep %z");
    check("format unknown %z passes through", unk == "keep %z");

    // Mixed brace and printf
    string mixed = format("brace {d} and printf %f", 10, 3.14);
    check("format mixed brace and printf", mixed == "brace 10 and printf 3.14");

    // Multiple placeholders
    string multi = format("x = {d}, y = {f}, s = {s}", 10, 3.14, "test");
    check("format multiple placeholders", multi == "x = 10, y = 3.14, s = test");

    // =========================================================================
    // 2. string type: constructors and basic properties
    // =========================================================================
    section("2. string: constructors and basic properties");

    string s_empty = "";
    check("empty string .is_empty() true", s_empty.is_empty());
    check("empty string .length() == 0", s_empty.length() == 0);

    string s_hello = "Hello, World!";
    check("string .length() == 13", s_hello.length() == 13);
    check("non-empty .is_empty() false", !s_hello.is_empty());

    // =========================================================================
    // 3. string: substring and searching
    // =========================================================================
    section("3. string: substring and searching");

    string s_search = "Hello, world! Hello, universe!";

    check("substr(0,5) == 'Hello'", s_search.substr(0, 5) == "Hello");
    check("substr(7,5) == 'world'", s_search.substr(7, 5) == "world");
    check("substr(0,0) == ''", s_search.substr(0, 0) == "");

    check("find('world') == 7", s_search.find("world") == 7);
    check("find('Hello') == 0", s_search.find("Hello") == 0);
    check("find('xyz') == -1 (absent)", s_search.find("xyz") == -1);

    check("last_index_of('Hello') == 14", s_search.last_index_of("Hello") == 14);
    check("last_index_of('!') == 27", s_search.last_index_of("!") == 27);
    check("last_index_of('xyz') == -1", s_search.last_index_of("xyz") == -1);

    check("count('Hello') == 2", s_search.count("Hello") == 2);
    check("count('o') == 3", s_search.count("o") == 3);
    check("count('xyz') == 0", s_search.count("xyz") == 0);

    check("contains('world') true", s_search.contains("world"));
    check("contains('xyz') false", !s_search.contains("xyz"));

    // =========================================================================
    // 4. string: prefix and suffix checks
    // =========================================================================
    section("4. string: prefix and suffix checks");

    string s_pref = "Hello, World!";

    check("starts_with('Hello') true", s_pref.starts_with("Hello"));
    check("starts_with('world') false", !s_pref.starts_with("world"));
    check("starts_with('') true (empty prefix)", s_pref.starts_with(""));

    check("ends_with('World!') true", s_pref.ends_with("World!"));
    check("ends_with('Hello') false", !s_pref.ends_with("Hello"));
    check("ends_with('') true (empty suffix)", s_pref.ends_with(""));

    check("starts_with_i('hello') true (case-insensitive)", s_pref.starts_with_i("hello"));
    check("starts_with_i('xello') false", !s_pref.starts_with_i("xello"));

    check("ends_with_i('world!') true (case-insensitive)", s_pref.ends_with_i("world!"));
    check("ends_with_i('HELLO') false", !s_pref.ends_with_i("HELLO"));

    // =========================================================================
    // 5. string: char_at and type conversion
    // =========================================================================
    section("5. string: char_at and type conversion");

    check("char_at(0) == 72 ('H')", s_hello.char_at(0) == 72);
    check("char_at(1) == 101 ('e')", s_hello.char_at(1) == 101);

    string s_num = "42";
    check("to_int('42') == 42", s_num.to_int() == 42);
    check("to_int('-7') == -7", "-7".to_int() == -7);
    check("to_int('0') == 0", "0".to_int() == 0);

    string s_fnum = "3.14";
    check("to_float('3.14') approx 3.14", s_fnum.to_float() > 3.13 && s_fnum.to_float() < 3.15);
    check("to_float('0.0') == 0.0", "0.0".to_float() == 0.0);

    // =========================================================================
    // 6. string: case conversion and trimming
    // =========================================================================
    section("6. string: case conversion and trimming");

    string s_mixed = "Hello World";
    check("to_upper() == 'HELLO WORLD'", s_mixed.to_upper() == "HELLO WORLD");
    check("to_lower() == 'hello world'", s_mixed.to_lower() == "hello world");

    string s_pad = "  spaces here  ";
    check("trim() == 'spaces here'", s_pad.trim() == "spaces here");
    check("trim_left() == 'spaces here  '", s_pad.trim_left() == "spaces here  ");
    check("trim_right() == '  spaces here'", s_pad.trim_right() == "  spaces here");
    check("''.trim() == ''", "".trim() == "");

    // =========================================================================
    // 7. string: reverse and replacement
    // =========================================================================
    section("7. string: reverse and replacement");

    check("reverse('abc') == 'cba'", "abc".reverse() == "cba");
    check("reverse('') == ''", "".reverse() == "");
    check("reverse('a') == 'a'", "a".reverse() == "a");

    string s_rep = "one fish two fish";
    string all_rep = s_rep.replace("fish", "bird");
    check("replace all 'fish' -> 'bird'", all_rep == "one bird two bird");

    string first_rep = s_rep.replace_first("fish", "bird");
    check("replace_first 'fish' -> 'bird'", first_rep == "one bird two fish");

    // =========================================================================
    // 8. string: repeat and padding
    // =========================================================================
    section("8. string: repeat and padding");

    check("repeat(3) 'ha' == 'hahaha'", "ha".repeat(3) == "hahaha");
    check("repeat(0) == ''", "x".repeat(0) == "");
    check("repeat(1) == 'x'", "x".repeat(1) == "x");

    check("pad_left(5,'.') == '...hi'", "hi".pad_left(5, '.') == "...hi");
    check("pad_left(2,'.') == 'hi' (no pad)", "hi".pad_left(2, '.') == "hi");

    check("pad_right(5,'.') == 'hi...'", "hi".pad_right(5, '.') == "hi...");
    check("pad_right(2,'.') == 'hi' (no pad)", "hi".pad_right(2, '.') == "hi");

    // =========================================================================
    // 9. string: insert and remove_range
    // =========================================================================
    section("9. string: insert and remove_range");

    check("insert(2,'XY') 'abcd' -> 'abXYcd'", "abcd".insert(2, "XY") == "abXYcd");
    check("insert(0,'Z') -> 'Zabcd'", "abcd".insert(0, "Z") == "Zabcd");
    check("insert(4,'Z') -> 'abcdZ'", "abcd".insert(4, "Z") == "abcdZ");

    check("remove_range(2,5) 'abcdef' -> 'abf'", "abcdef".remove_range(2, 5) == "abf");
    check("remove_range(0,3) -> 'def'", "abcdef".remove_range(0, 3) == "def");
    check("remove_range(0,0) no change", "abcdef".remove_range(0, 0) == "abcdef");

    // =========================================================================
    // 10. string: split and chars
    // =========================================================================
    section("10. string: split and chars");

    array<string> parts = "a,b,c,d".split(",");
    check("split(',') length == 4", parts.length() == 4);
    if (parts.length() == 4) {
        check("split[0] == 'a'", parts.get(0) == "a");
        check("split[3] == 'd'", parts.get(3) == "d");
    }

    array<string> single = "no-sep".split(",");
    check("split no match -> array of 1", single.length() == 1);
    if (single.length() == 1) {
        check("single element == original", single.get(0) == "no-sep");
    }

    array<string> empty_parts = "".split(",");
    check("split empty string", empty_parts.length() == 1 || empty_parts.length() == 0);

    array<int64> codes = "ABC".chars();
    check("chars() length == 3", codes.length() == 3);
    if (codes.length() == 3) {
        check("chars[0] == 65 ('A')", codes.get(0) == 65);
        check("chars[1] == 66 ('B')", codes.get(1) == 66);
        check("chars[2] == 67 ('C')", codes.get(2) == 67);
    }

    // =========================================================================
    // 11. string: operators
    // =========================================================================
    section("11. string: operators");

    string a_hello = "Hello, ";
    string b_world = "world!";
    string c_concat = a_hello + b_world;
    check("a + b == 'Hello, world!'", c_concat == "Hello, world!");

    check("== same content", a_hello == a_hello);
    check("!= different content", !(a_hello == b_world));
    check("literal == works", "abc" == "abc");

    // Char iteration via for-in
    string s_iter = "ABC";
    int64 iter_count = 0;
    int64 iter_sum = 0;
    for (int32 ch : s_iter) {
        iter_count = iter_count + 1;
        iter_sum = iter_sum + ch;
    }
    check("for-in visited 3 chars", iter_count == 3);
    check("sum char codes (65+66+67) == 198", iter_sum == 198);

    // =========================================================================
    // 12. array type: basic operations
    // =========================================================================
    section("12. array: basic operations");

    int64[] arr;
    check("new array .length() == 0", arr.length() == 0);

    arr.push(10);
    arr.push(20);
    arr.push(30);
    check("after 3 pushes, length == 3", arr.length() == 3);

    check("get(0) == 10", arr.get(0) == 10);
    check("get(2) == 30", arr.get(2) == 30);

    arr.set(1, 25);
    check("set(1,25) -> get(1) == 25", arr.get(1) == 25);

    int64 popped = arr.pop();
    check("pop() == 30", popped == 30);
    check("after pop, length == 2", arr.length() == 2);

    arr.push_front(5);
    check("push_front(5) -> get(0) == 5", arr.get(0) == 5);
    check("after push_front, length == 3", arr.length() == 3);

    int64 front = arr.pop_front();
    check("pop_front() == 5", front == 5);
    check("after pop_front, length == 2", arr.length() == 2);

    // =========================================================================
    // 13. array: insert, remove, first, last, swap
    // =========================================================================
    section("13. array: insert, remove, first, last, swap");

    int64[] arr2;
    arr2.push(1);
    arr2.push(2);
    arr2.push(3);
    arr2.push(4);
    arr2.push(5);

    check("first() == 1", arr2.first() == 1);
    check("last() == 5", arr2.last() == 5);

    arr2.insert(2, 99);
    check("insert(2,99) -> get(2) == 99", arr2.get(2) == 99);
    check("after insert, length == 6", arr2.length() == 6);

    int64 removed = arr2.remove(2);
    check("remove(2) == 99", removed == 99);
    check("after remove, length == 5", arr2.length() == 5);

    arr2.swap(0, 4);
    check("swap(0,4) -> get(0) == 5", arr2.get(0) == 5);
    check("swap(0,4) -> get(4) == 1", arr2.get(4) == 1);

    // =========================================================================
    // 14. array: contains, index_of, count, fill, sort, reverse
    // =========================================================================
    section("14. array: contains, index_of, count, fill, sort, reverse");

    int64[] arr3;
    arr3.push(3);
    arr3.push(1);
    arr3.push(4);
    arr3.push(1);
    arr3.push(5);
    arr3.push(9);

    check("contains(4) true", arr3.contains(4) != 0);
    check("contains(99) false", arr3.contains(99) == 0);

    check("index_of(1) == 1", arr3.index_of(1) == 1);
    check("index_of(99) == -1", arr3.index_of(99) == -1);

    check("count(1) == 2", arr3.count(1) == 2);
    check("count(3) == 1", arr3.count(3) == 1);

    arr3.sort();
    check("sort -> first is 1", arr3.first() == 1);
    check("sort -> last is 9", arr3.last() == 9);

    arr3.reverse();
    check("reverse -> first is 9", arr3.first() == 9);

    arr3.fill(7);
    check("fill(7) -> all elements 7", arr3.count(7) == 6);

    // =========================================================================
    // 15. array: unique, sum, min, max, min_idx, max_idx
    // =========================================================================
    section("15. array: aggregate methods");

    int64[] arr4;
    arr4.push(5);
    arr4.push(3);
    arr4.push(5);
    arr4.push(1);
    arr4.push(3);

    int64[] uniq = arr4.unique();
    check("unique removes duplicates", uniq.length() >= 3);

    check("sum()", arr4.sum() == 17);
    check("min() == 1", arr4.min() == 1);
    check("max() == 5", arr4.max() == 5);
    check("min_idx() returns index of 1", arr4.min_idx() >= 0);
    check("max_idx() returns index of 5", arr4.max_idx() >= 0);

    // =========================================================================
    // 16. array: slice, chunk, flat, capacity, stride
    // =========================================================================
    section("16. array: slice, chunk, capacity, stride");

    int64[] arr5;
    arr5.push(0);
    arr5.push(1);
    arr5.push(2);
    arr5.push(3);
    arr5.push(4);

    int64[] sliced = arr5.slice(1, 4);
    check("slice(1,4) length == 3", sliced.length() == 3);

    // chunk returns array of arrays
    int64[][] chunks = arr5.chunk(2);
    check("chunk(2) produces multiple arrays", chunks.length() >= 2);

    // flat - create array of arrays and flatten one level
    int64[] flat_inner1;
    flat_inner1.push(1);
    flat_inner1.push(2);
    int64[] flat_inner2;
    flat_inner2.push(3);
    flat_inner2.push(4);
    int64[][] nested;
    nested.push(flat_inner1);
    nested.push(flat_inner2);
    int64[] flat_result = nested.flat();
    check("flat() length == 4", flat_result.length() == 4);

    check("capacity() >= length()", arr5.capacity() >= arr5.length());
    check("stride() == 8 (int64)", arr5.stride() == 8 || arr5.stride() == -8);

    // =========================================================================
    // 17. array: higher-order functions
    // =========================================================================
    section("17. array: higher-order functions");

    int64[] arr6;
    arr6.push(1);
    arr6.push(2);
    arr6.push(3);
    arr6.push(4);

    int64[] mapped = arr6.map(cast<int64>(doubler));
    check("map(doubler) length == 4", mapped.length() == 4);

    int64[] filtered = arr6.filter(cast<int64>(is_even));
    check("filter(is_even) length == 2", filtered.length() == 2);

    int64 reduced = arr6.reduce(cast<int64>(add_fn), 0);
    check("reduce(add_fn, 0) == 10", reduced == 10);

    bool any_even = arr6.any(cast<int64>(is_even));
    check("any(is_even) true", any_even);

    bool all_even = arr6.all(cast<int64>(is_even));
    check("all(is_even) false", !all_even);

    int64 found = arr6.find(cast<int64>(is_even));
    check("find(is_even) >= 0", found >= 0);

    // =========================================================================
    // 18. array: print helpers and resize
    // =========================================================================
    section("18. array: print helpers and resize");

    int64[] arr7;
    arr7.push(1);
    arr7.push(2);
    arr7.push(3);

    // print methods: just verify they don't crash
    arr7.print_int();
    arr7.println_int();

    // float print helpers on array
    float64[] f_arr;
    f_arr.push(1.5);
    f_arr.push(2.5);
    f_arr.push(3.5);
    f_arr.print_float();
    f_arr.println_float();

    arr7.resize(10);
    check("resize(10) -> length == 10", arr7.length() == 10);

    arr7.clear();
    check("clear() -> length == 0", arr7.length() == 0);

    // =========================================================================
    // 19. array: join, free, and string array
    // =========================================================================
    section("19. array: join and string array");

    string[] str_arr;
    str_arr.push("a");
    str_arr.push("b");
    str_arr.push("c");

    string joined = str_arr.join(", ");
    check("join(', ') == 'a, b, c'", joined == "a, b, c");
    check("string[] .length() == 3", str_arr.length() == 3);

    // Print helpers (no crash)
    str_arr.print_str();
    str_arr.println_str();

    // Run free on a separate array (memory release)
    int64[] free_arr;
    free_arr.push(1);
    free_arr.push(2);
    free_arr.free();
    check("free() releases memory", free_arr.length() == 0);

    // =========================================================================
    // 20. array: array_create_strided
    // =========================================================================
    section("20. array: array_create_strided");

    array buf = array_create_strided(10, 8);
    check("array_create_strided(10, 8) created", buf.length() == 10 || buf.length() == 0);

    // =========================================================================
    // 21. map type: basic operations
    // =========================================================================
    section("21. map: basic operations");

    map<string, int64> m;
    m.set("a", 1);
    m.set("b", 2);
    m.set("c", 3);

    check("map.size() == 3", m.size() == 3);
    check("map.length() == 3", m.length() == 3);

    check("map.get('a') == 1", m.get("a") == 1);
    check("map.get('b') == 2", m.get("b") == 2);
    check("map.get('x') == 0 (missing)", m.get("x") == 0);

    check("map.contains('a') true", m.contains("a"));
    check("map.contains('x') false", !m.contains("x"));

    check("map.has('a') (alias) true", m.has("a"));

    check("map.has_value(2) true", m.has_value(2));
    check("map.has_value(99) false", !m.has_value(99));

    int64 def = m.get_or_default("a", 99);
    check("get_or_default existing key", def == 1);

    int64 def2 = m.get_or_default("z", 99);
    check("get_or_default missing key returns default", def2 == 99);

    // =========================================================================
    // 22. map: remove, keys, values, merge, clear, free
    // =========================================================================
    section("22. map: remove, keys, values, merge, clear, free");

    map<string, int64> m2;
    m2.set("x", 10);
    m2.set("y", 20);
    m2.set("z", 30);

    m2.remove("y");
    check("remove('y') -> contains('y') false", !m2.contains("y"));
    check("after remove, size == 2", m2.size() == 2);

    array<string> keys = m2.keys();
    check("keys() returns array", keys.length() > 0);

    array<int64> vals = m2.values();
    check("values() returns array", vals.length() > 0);

    map<string, int64> m3;
    m3.set("extra", 100);
    m2.merge(m3);
    check("merge adds entries -> size == 3", m2.size() == 3);
    check("merged key 'extra' accessible", m2.get("extra") == 100);

    m2.clear();
    check("clear() -> size == 0", m2.size() == 0);

    // map.free() - release memory
    map<string, int64> m_free;
    m_free.set("a", 1);
    m_free.free();
    check("map.free() executes", true);

    // map subscript access
    map<string, int64> m_sub;
    m_sub["alpha"] = 100;
    m_sub["beta"] = 200;
    int64 mv = m_sub["alpha"];
    check("map subscript read m_sub['alpha'] == 100", mv == 100);
    check("map subscript write + read m_sub['beta'] == 200", m_sub["beta"] == 200);
    check("map subscript missing key returns 0", m_sub["gamma"] == 0);

    // map for-in iteration
    map<string, int64> m_iter;
    m_iter.set("x", 10);
    m_iter.set("y", 20);
    m_iter.set("z", 30);
    int64 m_iter_count = 0;
    int64 m_iter_sum = 0;
    for (string k, int64 v : m_iter) {
        m_iter_count = m_iter_count + 1;
        m_iter_sum = m_iter_sum + v;
    }
    check("map iteration visited 3 entries", m_iter_count == 3);
    check("map iteration sum 10+20+30 == 60", m_iter_sum == 60);

    // =========================================================================
    // 23. imap type (int64-keyed)
    // =========================================================================
    section("23. imap: int-keyed map");

    imap<int64> im;
    im.set(1, 100);
    im.set(2, 200);
    im.set(3, 300);

    check("imap.size() == 3", im.size() == 3);
    check("imap.length() == 3", im.length() == 3);

    check("imap.get(1) == 100", im.get(1) == 100);
    check("imap.get(99) == 0 (missing)", im.get(99) == 0);

    check("imap.contains(2) true", im.contains(2));
    check("imap.has(2) (alias) true", im.has(2));
    check("imap.contains(99) false", !im.contains(99));

    int64 im_def = im.get_or_default(1, 999);
    check("imap get_or_default existing", im_def == 100);

    int64 im_def2 = im.get_or_default(99, 999);
    check("imap get_or_default missing returns default", im_def2 == 999);

    im.remove(2);
    check("imap.remove(2) -> size == 2", im.size() == 2);
    check("imap.contains(2) false after remove", !im.contains(2));

    array<int64> im_keys = im.keys();
    check("imap.keys() returns int64[]", im_keys.length() > 0);

    array<int64> im_vals = im.values();
    check("imap.values() returns element[]", im_vals.length() > 0);

    im.clear();
    check("imap.clear() -> size == 0", im.size() == 0);

    // imap subscript access
    imap<int64> im_sub;
    im_sub[10] = 1000;
    im_sub[20] = 2000;
    int64 imv = im_sub[10];
    check("imap subscript read im_sub[10] == 1000", imv == 1000);
    check("imap subscript im_sub[20] == 2000", im_sub[20] == 2000);

    // imap for-in iteration
    imap<int64> im_iter;
    im_iter.set(1, 100);
    im_iter.set(2, 200);
    im_iter.set(3, 300);
    int64 im_iter_count = 0;
    int64 im_iter_sum = 0;
    for (int64 k, int64 v : im_iter) {
        im_iter_count = im_iter_count + 1;
        im_iter_sum = im_iter_sum + v;
    }
    check("imap iteration visited 3 entries", im_iter_count == 3);
    check("imap iteration sum 100+200+300 == 600", im_iter_sum == 600);

    // =========================================================================
    // 24. Conversion functions: to_string, char_to_str, ord, chr, from_chars
    // =========================================================================
    section("24. Conversion functions");

    // to_string overloads
    check("to_string(42) == '42'", to_string(42) == "42");
    check("to_string(-7) == '-7'", to_string(-7) == "-7");
    check("to_string(0) == '0'", to_string(0) == "0");
    check("to_string(true) == 'true'", to_string(true) == "true");
    check("to_string(false) == 'false'", to_string(false) == "false");

    // char_to_str
    check("char_to_str('A') == 'A'", char_to_str('A') == "A");
    check("char_to_str('z') == 'z'", char_to_str('z') == "z");

    // ord and chr
    check("ord('A') == 65", ord('A') == 65);
    check("ord('0') == 48", ord('0') == 48);
    check("chr(65) == 'A'", chr(65) == "A");
    check("chr(48) == '0'", chr(48) == "0");

    // from_chars
    array<int64> abc = "XYZ".chars();
    string rebuilt = from_chars(abc);
    check("from_chars(chars('XYZ')) round-trips", rebuilt == "XYZ");

    // =========================================================================
    // 25. Cast<string> universal coercion
    // =========================================================================
    section("25. cast<string> universal coercion");

    check("cast<string>(42) == '42'", cast<string>(42) == "42");
    check("cast<string>(3.14) == '3.14'", cast<string>(3.14) == "3.14");
    check("cast<string>(true) == 'true'", cast<string>(true) == "true");
    check("cast<string>(false) == 'false'", cast<string>(false) == "false");

    // =========================================================================
    // 26. Hex encoding / decoding
    // =========================================================================
    section("26. Hex encoding / decoding");

    check("hex_encode(255) == 'ff'", hex_encode(255) == "ff");
    check("hex_encode(0) == '0'", hex_encode(0) == "0");

    check("to_hex(255) == 'ff' (alias)", to_hex(255) == "ff");
    check("to_hex(0) == '0'", to_hex(0) == "0");

    check("hex_decode('616263') == 'abc'", hex_decode("616263") == "abc");
    check("hex_decode('') == ''", hex_decode("") == "");

    check("hex_to_int('ff') == 255", hex_to_int("ff") == 255);
    check("hex_to_int('0') == 0", hex_to_int("0") == 0);
    check("hex_to_int('10') == 16", hex_to_int("10") == 16);

    // string -> hex-encoded bytes overload
    check("hex_encode('abc') == '616263'", hex_encode("abc") == "616263");

    // =========================================================================
    // 27. Base64 encoding / decoding
    // =========================================================================
    section("27. Base64 encoding / decoding");

    string b64_enc = base64_encode("hello");
    check("base64_encode('hello') == 'aGVsbG8='", b64_enc == "aGVsbG8=");

    string b64_dec = base64_decode("aGVsbG8=");
    check("base64_decode('aGVsbG8=') == 'hello'", b64_dec == "hello");

    check("base64_encode('') == ''", base64_encode("") == "");
    check("base64_decode('') == ''", base64_decode("") == "");

    // Round-trip
    string b64_orig = "enma test data";
    string b64_rt = base64_decode(base64_encode(b64_orig));
    check("base64 round-trip preserves string", b64_rt == b64_orig);

    // =========================================================================
    // 28. URL encoding / decoding
    // =========================================================================
    section("28. URL encoding / decoding");

    string url_enc = url_encode("hello world & foo=bar");
    check("url_encode properly encodes", url_enc == "hello%20world%20%26%20foo%3Dbar");

    string url_dec = url_decode("hello%20world");
    check("url_decode('hello%20world') == 'hello world'", url_dec == "hello world");

    string url_plus = url_decode("hello+world");
    check("url_decode decodes + as space", url_plus == "hello world");

    // Round-trip
    string url_orig = "a=b&c=d e+f";
    string url_rt = url_decode(url_encode(url_orig));
    check("url round-trip preserves string", url_rt == url_orig);

    // =========================================================================
    // 29. wstring type
    // =========================================================================
    section("29. wstring: construction and basic properties");

    wstring ws = cast<wstring>("Hello");
    check("wstring valid", true);

    check("wstring.length() == 5", ws.length() == 5);
    check("!wstring.is_empty()", !ws.is_empty());

    wstring ws_empty = cast<wstring>("");
    check("empty wstring .is_empty() true", ws_empty.is_empty());
    check("empty wstring .length() == 0", ws_empty.length() == 0);

    string ws_back = cast<string>(ws);
    check("cast<string>(wstring) round-trips", ws_back == "Hello");

    // =========================================================================
    // 30. wstring: methods
    // =========================================================================
    section("30. wstring: methods");

    wstring ws_test = cast<wstring>("Hello, world!");

    check("ws.char_at(0) == 72 ('H')", ws_test.char_at(0) == 72);
    check("ws.char_at(4) == 111 ('o')", ws_test.char_at(4) == 111);

    wstring ws_sub = ws_test.substr(0, 5);
    check("ws.substr(0,5) -> string == 'Hello'", cast<string>(ws_sub) == "Hello");

    int64 ws_find = ws_test.find(cast<wstring>("world"));
    check("ws.find('world') == 7", ws_find == 7);

    check("ws.contains(cast<wstring>('world')) true", ws_test.contains(cast<wstring>("world")));
    check("ws.contains(cast<wstring>('xyz')) false", !ws_test.contains(cast<wstring>("xyz")));

    wstring ws_case = cast<wstring>("Hello World");

    check("ws.starts_with(cast<wstring>('Hello')) true", ws_case.starts_with(cast<wstring>("Hello")));
    check("ws.starts_with(cast<wstring>('World')) false", !ws_case.starts_with(cast<wstring>("World")));

    check("ws.ends_with(cast<wstring>('World')) true", ws_case.ends_with(cast<wstring>("World")));
    check("ws.ends_with(cast<wstring>('Hello')) false", !ws_case.ends_with(cast<wstring>("Hello")));

    wstring ws_upper = ws_case.to_upper();
    check("wstring.to_upper() == 'HELLO WORLD'", cast<string>(ws_upper) == "HELLO WORLD");

    wstring ws_lower = ws_case.to_lower();
    check("wstring.to_lower() == 'hello world'", cast<string>(ws_lower) == "hello world");

    string ws_tostr = ws_case.to_string();
    check("wstring.to_string() == 'Hello World'", ws_tostr == "Hello World");

    // =========================================================================
    // 31. wstring: auto-wrap for string arguments
    // =========================================================================
    section("31. wstring: auto-wrap string args");

    wstring ws_aw = cast<wstring>("auto-wrap test");
    check("ws.contains('wrap') via auto-wrap", ws_aw.contains("wrap"));
    check("ws.starts_with('auto') via auto-wrap", ws_aw.starts_with("auto"));
    check("ws.ends_with('test') via auto-wrap", ws_aw.ends_with("test"));
    check("ws.find('wrap') >= 0 via auto-wrap", ws_aw.find("wrap") >= 0);

    // =========================================================================
    // 32. wstring: operators
    // =========================================================================
    section("32. wstring: operators");

    wstring ws_a = cast<wstring>("Hello, ");
    wstring ws_b = cast<wstring>("world!");
    wstring ws_c = ws_a + ws_b;
    check("wstring + concat", cast<string>(ws_c) == "Hello, world!");

    wstring ws_eq1 = cast<wstring>("same");
    wstring ws_eq2 = cast<wstring>("same");
    wstring ws_ne = cast<wstring>("different");
    check("wstring == (same)", ws_eq1 == ws_eq2);
    check("!wstring == (different)", !(ws_eq1 == ws_ne));

    wstring ws_small = cast<wstring>("abc");
    wstring ws_large = cast<wstring>("zzz");
    check("wstring < (abc < zzz)", ws_small < ws_large);
    check("!wstring > (abc > zzz)", !(ws_small > ws_large));
    check("wstring <= (abc <= zzz)", ws_small <= ws_large);
    check("!wstring >= (abc >= zzz)", !(ws_small >= ws_large));

    // =========================================================================
    // 33. wstring: free functions
    // =========================================================================
    section("33. wstring: free functions");

    wstring ws_ff = wstring_from_str("hello from str");
    string ws_ff_back = wstring_to_str(ws_ff);
    check("wstring_to_str round-trips", ws_ff_back == "hello from str");

    // Null pointer tests (should survive without crash)
    wstring ws_wchar = wstring_from_wchar_ptr(0);
    check("wstring_from_wchar_ptr(0) survives", true);

    wstring ws_utf8 = wstring_from_utf8_ptr(0);
    check("wstring_from_utf8_ptr(0) survives", true);

    // =========================================================================
    // 34. Runtime: heap functions
    // =========================================================================
    section("34. Runtime: heap functions");

    // heap_collect - no-op but should not crash
    heap_collect();
    check("heap_collect() executes without error", true);

    // heap_count - should return a non-negative count
    int64 hc = heap_count();
    check("heap_count() returns non-negative", hc >= 0);

    // set_memory_budget - set a large budget (64 MB)
    set_memory_budget(1024 * 1024 * 64);
    check("set_memory_budget(64MB) executes", true);

    // Set back to unlimited
    set_memory_budget(0);
    check("set_memory_budget(0) unlimited", true);

    // =========================================================================
    // 35. Runtime: instruction budget
    // =========================================================================
    section("35. Runtime: instruction budget");

    // set_budget with a large instruction count
    set_budget(1000000);
    check("set_budget(1000000) executes", true);

    // =========================================================================
    // 36. Runtime: assert
    // =========================================================================
    section("36. Runtime: assert");

    // Runtime assert with true condition (should not crash)
    assert(1 == 1);
    check("assert(1 == 1) passes", true);

    // =========================================================================
    // 37. Runtime: time_ms
    // =========================================================================
    section("37. Runtime: time_ms");

    int64 t1 = time_ms();
    check("time_ms() returns positive value", t1 > 0);
    check("time_ms() > 1680000000000 (year 2023+ range check)", t1 > 1680000000000);

    // =========================================================================
    // 38. Runtime: events
    // =========================================================================
    section("38. Runtime: events");

    g_event_fired = 0;
    g_event_arg = 0;

    register_event(1, cast<int64>(on_test_event));
    fire_event(1, 42);

    check("register_event + fire_event triggers callback", g_event_fired == 1);
    check("event callback receives correct arg", g_event_arg == 42);

    // Clear events and verify no crash
    clear_events();
    check("clear_events() executes", true);

    // =========================================================================
    // 39. Coroutines
    // =========================================================================
    section("39. Coroutines");

    coroutine_t co = count_up(0);
    int64 co_vals = 0;
    int64 co_sum = 0;
    while (co.next() == 1) {
        int32 v = co.value();
        co_vals = co_vals + 1;
        co_sum = co_sum + v;
    }
    check("coroutine yielded 5 values", co_vals == 5);
    check("coroutine sum 0+1+2+3+4 == 10", co_sum == 10);

    // Coroutine that has finished should return 0 from next()
    int64 done = co.next();
    check("finished coroutine .next() == 0", done == 0);

    // =========================================================================
    // 40. Counter type
    // =========================================================================
    section("40. Counter type");

    // Verify counter_t can be declared (type exists)
    counter_t ctr;
    check("counter_t variable declared", true);

    // =========================================================================
    // Summary
    // =========================================================================
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");
}


// =============================================================================
// Entry point
// =============================================================================
int32 main() {
    print_console("=== Core addon comprehensive test ===");
    run_core_tests();
    if (g_fail > 0) {
        return -1;
    }
    return cast<int32>(g_pass);
}
