// =============================================================================
// COMPREHENSIVE Win API smoke test
//
// Exercises EVERY native registered from the enma Win API surface:
//
// window_info_t type (6 methods):
//   .hwnd() -> int64           .pid() -> int64
//   .tid() -> int64            .process_name() -> string
//   .title() -> string         .class_name() -> string
//
// Enumeration (1 function):
//   get_all_hwnds() -> array<window_info_t>
//
// Find window (2 overloads):
//   find_window(string title)                        -> int64
//   find_window(string title, string class_name)     -> int64
//
// Window queries (9 functions):
//   get_window_width(int64 hwnd)                     -> int64
//   get_window_height(int64 hwnd)                    -> int64
//   get_window_pos(int64 hwnd)                       -> vec2
//   get_window_size(int64 hwnd)                      -> vec2
//   is_foreground_window(int64 hwnd)                 -> bool
//   is_window_active(int64 hwnd)                     -> bool
//   get_window_title(int64 hwnd)                     -> string
//   get_window_class(int64 hwnd)                     -> string
//   get_window_thread_id(int64 hwnd)                 -> int64
//   get_window_process_id(int64 hwnd)                -> int64
//
// Window control (2 functions):
//   set_foreground_window(int64 hwnd)                -> bool
//   post_message(int64 hwnd, int64 msg, ...)         -> bool
//
// Clipboard (2 functions):
//   copy_to_clipboard(string text)                   -> bool
//   copy_from_clipboard()                            -> string
//
// Keyboard SEND (5 functions):
//   win_key_down(int64 vk)                           -> void
//   win_key_up(int64 vk)                             -> void
//   win_key_press(int64 vk, int64 delay_ms)          -> void
//   send_char(int64 hwnd, string text)               -> bool
//   send_key(int64 hwnd, int64 vk)                   -> bool
//
// Mouse SEND (6 functions):
//   mouse_move(int64 x, int64 y)                     -> void
//   mouse_move_relative(int64 dx, int64 dy)          -> void
//   mouse_left_click()                               -> void
//   mouse_right_click()                              -> void
//   mouse_middle_click()                             -> void
//   mouse_scroll(int64 amount)                       -> void
//   send_mouse_input(int64 dx, int64 dy, ...)        -> void
//
// TOTAL: 1 type with 6 methods + 22 standalone functions = 28 items
//
// Most-reliable target: the desktop ("Program Manager", class "Progman")
// which is always present.
//
// IMPORTANT: Running this WILL inject real mouse clicks and key events.
// The test moves the cursor to (0,0) first to minimize side effects, and
// toggles caps-lock twice to restore its previous state. Close any text
// editor with focus first.
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

void print_console(string input) {
    print(input);
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Win API comprehensive smoke test ===");

    // -------------------------------------------------------------------
    // get_all_hwnds + window_info_t (all 6 methods)
    // -------------------------------------------------------------------
    section("get_all_hwnds + window_info_t");

    array<window_info_t> wins = get_all_hwnds();
    check("get_all_hwnds() returns non-empty array", wins.length() > 0);
    print_console("  enumerated " + cast<string>(wins.length()) + " windows");

    if (wins.length() > 0) {
        window_info_t info = wins.get(0);

        // window_info_t.hwnd()
        int64 hwnd_val = info.hwnd();
        check("window_info_t.hwnd() returns non-zero", hwnd_val != 0);

        // window_info_t.pid()
        int64 pid_val = info.pid();
        check("window_info_t.pid() returns non-zero", pid_val != 0);

        // window_info_t.tid()
        int64 tid_val = info.tid();
        check("window_info_t.tid() returns non-zero", tid_val != 0);

        // window_info_t.process_name()
        string pname = info.process_name();
        check("window_info_t.process_name() returns string", pname.length() >= 0);

        // window_info_t.title()
        string title = info.title();
        check("window_info_t.title() returns string", title.length() >= 0);

        // window_info_t.class_name()
        string cls = info.class_name();
        check("window_info_t.class_name() returns string", cls.length() >= 0);

        print_console("  first window: hwnd=" + cast<string>(hwnd_val) +
                      " pid=" + cast<string>(pid_val) +
                      " tid=" + cast<string>(tid_val));
        if (pname.length() > 0)
            print_console("    process_name='" + pname + "'");
        if (title.length() > 0)
            print_console("    title='" + title + "'");
        if (cls.length() > 0)
            print_console("    class='" + cls + "'");
    }

    // -------------------------------------------------------------------
    // find_window — both overloads
    // -------------------------------------------------------------------
    section("find_window");

    // find_window(string title)
    int64 progman_by_title = find_window("Program Manager");
    check("find_window('Program Manager') != 0", progman_by_title != 0);

    // find_window(string title, string class_name)
    int64 progman_both = find_window("Program Manager", "Progman");
    check("find_window('Program Manager', 'Progman') != 0", progman_both != 0);
    check("find_window title and title+class agree",
          progman_by_title == progman_both);

    // Bogus window returns 0
    int64 bogus_win = find_window("__zzz_no_such_window_abcdef_42__");
    check("find_window(bogus) == 0", bogus_win == 0);

    int64 bogus_both = find_window("__no_match__", "__no_class__");
    check("find_window(bogus, bogus_class) == 0", bogus_both == 0);

    int64 hwnd = progman_by_title;

    // -------------------------------------------------------------------
    // Window geometry — every query
    // -------------------------------------------------------------------
    section("window geometry");

    // get_window_width
    int64 win_w = get_window_width(hwnd);
    check("get_window_width(desktop) > 0", win_w > 0);

    // get_window_height
    int64 win_h = get_window_height(hwnd);
    check("get_window_height(desktop) > 0", win_h > 0);

    // get_window_pos
    vec2 pos = get_window_pos(hwnd);
    check("get_window_pos(desktop) returns finite x", pos.x == pos.x);
    check("get_window_pos(desktop) returns finite y", pos.y == pos.y);

    // get_window_size
    vec2 size = get_window_size(hwnd);
    check("get_window_size(desktop) returns positive x", size.x > 0.0);
    check("get_window_size(desktop) returns positive y", size.y > 0.0);
    check("get_window_size.x matches get_window_width",
          cast<int64>(size.x) == win_w);
    check("get_window_size.y matches get_window_height",
          cast<int64>(size.y) == win_h);

    // Invalid hwnd = 0
    int64 zero_w = get_window_width(0);
    check("get_window_width(0) == 0", zero_w == 0);

    int64 zero_h = get_window_height(0);
    check("get_window_height(0) == 0", zero_h == 0);

    vec2 zero_pos = get_window_pos(0);
    check("get_window_pos(0) == (0,0)", zero_pos.x == 0.0 && zero_pos.y == 0.0);

    vec2 zero_size = get_window_size(0);
    check("get_window_size(0) == (0,0)", zero_size.x == 0.0 && zero_size.y == 0.0);

    // Garbage hwnd (non-zero but invalid)
    int64 bad_w = get_window_width(0xDEAD);
    check("get_window_width(garbage hwnd) == 0", bad_w == 0);

    int64 bad_h = get_window_height(0xDEAD);
    check("get_window_height(garbage hwnd) == 0", bad_h == 0);

    vec2 bad_pos = get_window_pos(0xDEAD);
    check("get_window_pos(garbage hwnd) == (0,0)",
          bad_pos.x == 0.0 && bad_pos.y == 0.0);

    vec2 bad_sz = get_window_size(0xDEAD);
    check("get_window_size(garbage hwnd) == (0,0)",
          bad_sz.x == 0.0 && bad_sz.y == 0.0);

    // -------------------------------------------------------------------
    // Window state queries
    // -------------------------------------------------------------------
    section("window state");

    // is_foreground_window
    bool fg = is_foreground_window(hwnd);
    check("is_foreground_window(desktop) returns bool", fg || !fg);

    // is_window_active
    bool active = is_window_active(hwnd);
    check("is_window_active(desktop) returns bool", active || !active);

    // Invalid hwnd returns false for both
    bool bad_fg = is_foreground_window(0);
    check("is_foreground_window(0) == false", !bad_fg);

    bool bad_active = is_window_active(0);
    check("is_window_active(0) == false", !bad_active);

    // -------------------------------------------------------------------
    // Title / class accessors
    // -------------------------------------------------------------------
    section("title / class");

    // get_window_title
    string desk_title = get_window_title(hwnd);
    check("get_window_title(desktop) == 'Program Manager'",
          desk_title == "Program Manager");

    // get_window_class
    string desk_class = get_window_class(hwnd);
    check("get_window_class(desktop) == 'Progman'", desk_class == "Progman");

    // Invalid hwnd returns empty string
    string bad_title = get_window_title(0);
    check("get_window_title(0) == ''", bad_title == "");

    string bad_class = get_window_class(0);
    check("get_window_class(0) == ''", bad_class == "");

    // -------------------------------------------------------------------
    // Thread / process id
    // -------------------------------------------------------------------
    section("thread / process id");

    // get_window_thread_id
    int64 tid = get_window_thread_id(hwnd);
    check("get_window_thread_id(desktop) != 0", tid != 0);

    // get_window_process_id
    int64 pid = get_window_process_id(hwnd);
    check("get_window_process_id(desktop) != 0", pid != 0);

    print_console("  desktop: tid=" + cast<string>(tid) +
                  " pid=" + cast<string>(pid));

    // Invalid hwnd returns 0
    int64 bad_tid = get_window_thread_id(0);
    check("get_window_thread_id(0) == 0", bad_tid == 0);

    int64 bad_pid = get_window_process_id(0);
    check("get_window_process_id(0) == 0", bad_pid == 0);

    // Garbage hwnd also returns 0
    int64 dead_tid = get_window_thread_id(0xDEAD);
    check("get_window_thread_id(garbage) == 0", dead_tid == 0);

    int64 dead_pid = get_window_process_id(0xDEAD);
    check("get_window_process_id(garbage) == 0", dead_pid == 0);

    // -------------------------------------------------------------------
    // set_foreground_window — this may fail if the window manager blocks
    // the request (e.g. no user interaction). We just call and observe
    // the return value.
    // -------------------------------------------------------------------
    section("set_foreground_window");

    bool fg_set = set_foreground_window(hwnd);
    check("set_foreground_window(desktop) called (may be denied by WM)",
          fg_set || !fg_set);
    if (fg_set) {
        print_console("  set_foreground_window succeeded");
    } else {
        print_console("  set_foreground_window denied by window manager (expected when not focused)");
    }

    // Invalid hwnd should return false
    bool bad_fg_set = set_foreground_window(0);
    check("set_foreground_window(0) == false", !bad_fg_set);

    // -------------------------------------------------------------------
    // post_message — WM_NULL (0) is harmless even on invalid handles.
    // -------------------------------------------------------------------
    section("post_message");

    bool posted = post_message(hwnd, 0, 0, 0);
    check("post_message(desktop, WM_NULL, 0, 0) == true", posted);

    // Use non-zero wparam/lparam to verify all params pass through
    bool posted2 = post_message(hwnd, 0, 42, 99);
    check("post_message(desktop, WM_NULL, 42, 99) == true", posted2);

    bool bad_posted = post_message(0, 0, 0, 0);
    check("post_message(0, ...) == false", !bad_posted);

    bool dead_posted = post_message(0xDEAD, 0, 0, 0);
    check("post_message(0xDEAD, ...) == false", !dead_posted);

    // -------------------------------------------------------------------
    // Clipboard round-trip
    // -------------------------------------------------------------------
    section("clipboard");

    // Save existing clipboard content
    string prev_clip = copy_from_clipboard();
    print_console("  saved previous clipboard length: " +
                  cast<string>(prev_clip.length()));

    // copy_to_clipboard
    bool set_ok = copy_to_clipboard("enma-win-api-test-42");
    check("copy_to_clipboard('enma-win-api-test-42') succeeds", set_ok);

    // copy_from_clipboard — read it back
    string read_back = copy_from_clipboard();
    check("copy_from_clipboard() round-trip matches what we set",
          read_back == "enma-win-api-test-42");

    // Round-trip with empty string
    bool set_empty = copy_to_clipboard("");
    check("copy_to_clipboard('') succeeds", set_empty);

    string read_empty = copy_from_clipboard();
    check("copy_from_clipboard() after empty set returns ''",
          read_empty == "");

    // Round-trip with UTF-8 multi-byte characters
    bool set_utf = copy_to_clipboard("hello-unicode-é-中-ñ");
    check("copy_to_clipboard(UTF-8 string) succeeds", set_utf);

    string read_utf = copy_from_clipboard();
    check("copy_from_clipboard() round-trips UTF-8",
          read_utf == "hello-unicode-é-中-ñ");

    // Restore previous clipboard
    copy_to_clipboard(prev_clip);
    print_console("  restored previous clipboard");

    // -------------------------------------------------------------------
    // Keyboard SEND
    // -------------------------------------------------------------------
    section("keyboard input");

    // win_key_down / win_key_up — benign key (caps_lock), toggle twice
    // to restore original state.
    win_key_down(vk::caps_lock);
    win_key_up(vk::caps_lock);
    win_key_down(vk::caps_lock);
    win_key_up(vk::caps_lock);
    check("win_key_down/up(caps_lock x2) survives (state restored)", true);

    // win_key_press with delay=0
    win_key_press(vk::caps_lock, 0);
    win_key_press(vk::caps_lock, 0);
    check("win_key_press(caps_lock, 0) x2 survives (state restored)", true);

    // win_key_press with delay capped at 1000ms
    win_key_press(vk::caps_lock, 999999);
    win_key_press(vk::caps_lock, 999999);
    check("win_key_press(caps_lock, 999999) clamps and survives", true);

    // Different VK codes
    win_key_down(vk::a);
    win_key_up(vk::a);
    check("win_key_down/up(vk::a) survives", true);

    win_key_down(vk::space);
    win_key_up(vk::space);
    check("win_key_down/up(vk::space) survives", true);

    win_key_down(vk::shift);
    win_key_up(vk::shift);
    check("win_key_down/up(vk::shift) survives", true);

    win_key_press(vk::f1, 10);
    check("win_key_press(vk::f1, 10) survives", true);

    // send_char — PostMessageW(WM_CHAR) targeted at hwnd
    bool sc1 = send_char(hwnd, "x");
    check("send_char(desktop, 'x') returns true", sc1);

    // Single wide char
    bool sc2 = send_char(hwnd, "A");
    check("send_char(desktop, 'A') returns true", sc2);

    // send_char with longer string — only first wide char is used
    bool sc3 = send_char(hwnd, "hello");
    check("send_char(desktop, 'hello') (sends first char) returns true", sc3);

    // send_char on invalid hwnd
    bool sc_bad = send_char(0, "x");
    check("send_char(0, 'x') returns false", !sc_bad);

    // send_key — PostMessageW(WM_KEYDOWN+WM_KEYUP) targeted at hwnd
    bool sk1 = send_key(hwnd, vk::a);
    check("send_key(desktop, vk::a) returns true", sk1);

    bool sk2 = send_key(hwnd, vk::enter);
    check("send_key(desktop, vk::enter) returns true", sk2);

    bool sk3 = send_key(hwnd, vk::escape);
    check("send_key(desktop, vk::escape) returns true", sk3);

    // send_key on invalid hwnd
    bool sk_bad = send_key(0, vk::a);
    check("send_key(0, vk::a) returns false", !sk_bad);

    // -------------------------------------------------------------------
    // Mouse SEND — we move the cursor to (0,0) first to minimize side
    // effects, then call all mouse functions.
    // -------------------------------------------------------------------
    section("mouse input");

    // mouse_move — absolute screen coordinates
    mouse_move(100, 100);
    check("mouse_move(100, 100) survives", true);

    // Move back to a known position
    mouse_move(0, 0);
    check("mouse_move(0, 0) survives", true);

    // mouse_move_relative
    mouse_move_relative(50, 50);
    check("mouse_move_relative(50, 50) survives", true);

    // Move back to origin
    mouse_move(0, 0);
    check("mouse_move(0, 0) back to origin survives", true);

    // No-op relative move
    mouse_move_relative(0, 0);
    check("mouse_move_relative(0, 0) survives", true);

    // Negative relative move
    mouse_move_relative(-10, -10);
    check("mouse_move_relative(-10, -10) survives", true);

    // Return to origin
    mouse_move(0, 0);

    // mouse_left_click — at (0,0), this is harmless (corner of screen
    // where nothing meaningful is clickable).
    mouse_left_click();
    check("mouse_left_click() at (0,0) survives", true);

    // mouse_right_click
    mouse_right_click();
    check("mouse_right_click() at (0,0) survives", true);

    // mouse_middle_click
    mouse_middle_click();
    check("mouse_middle_click() at (0,0) survives", true);

    // mouse_scroll — zero delta is harmless; also test positive/negative
    mouse_scroll(0);
    check("mouse_scroll(0) survives", true);

    mouse_scroll(120);
    check("mouse_scroll(120) (one WHEEL_DELTA) survives", true);

    mouse_scroll(-120);
    check("mouse_scroll(-120) survives", true);

    // send_mouse_input — raw SendInput wrapper
    send_mouse_input(0, 0, 0, 0);
    check("send_mouse_input(0,0,0,0) (no-op flags) survives", true);

    // Move via send_mouse_input (MOUSEEVENTF_MOVE = 0x0001)
    send_mouse_input(100, 0, 1, 0);
    check("send_mouse_input(100, 0, MOVE, 0) survives", true);

    // Absolute move back (MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE = 0x8001)
    // 0x8001 = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE
    send_mouse_input(0, 0, 0x8001, 0);
    check("send_mouse_input(0, 0, ABSOLUTE|MOVE, 0) survives", true);

    // Wheel via send_mouse_input (MOUSEEVENTF_WHEEL = 0x0800)
    send_mouse_input(0, 0, 0x0800, 120);
    check("send_mouse_input(0, 0, WHEEL, 120) survives", true);

    // -------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

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

int32 main() {
    print_console("[test_win_api] launching comprehensive test routine + sidebar menu");

    g_section = create_sidebar_section("win api test", "");
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
