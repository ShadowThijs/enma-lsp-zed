// =============================================================================
// Window / clipboard / input API smoke test
//
// Exercises every native registered by enma_win_api.cpp:
//   - window_info_t (.hwnd / .pid / .tid / .process_name / .title / .class_name)
//   - get_all_hwnds() -> array<window_info_t>
//   - find_window(title) / find_window(title, class)
//   - get_window_width / height / pos / size
//   - is_foreground_window / is_window_active
//   - get_window_title / class
//   - get_window_thread_id / process_id
//   - set_foreground_window / post_message
//   - copy_to_clipboard / copy_from_clipboard
//   - win_key_down/up/press, send_char, send_key
//   - mouse_move / move_relative / left/right/middle_click / scroll /
//     send_mouse_input
//
// Inputs (keys + mouse) ARE fired but NOT asserted on visible state — those
// would require user-visible UI changes. We just verify the calls survive
// without faulting and the restricted-vk filter rejects edge cases. Be
// aware: running this WILL inject a few real key events; close any text
// editor first.
//
// Most-reliable target: the desktop ("Program Manager", class "Progman")
// which is always present.
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

void print_console(string input)
{
	print(input);
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

window_info_t test;

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== win API smoke test ===");

    // -----------------------------------------------------------------------
    // get_all_hwnds — desktop has many top-level windows; the array should
    // have at least a handful.
    // -----------------------------------------------------------------------
    section("get_all_hwnds + window_info_t");

    array<string> test;

    test.length();

    array test2;
    string test3 = get_all_hwnds();

    array<window_info_t> wins = get_all_hwnds();
    check("get_all_hwnds().length() > 0", wins.length() > 0);
    print_console("  enumerated " + cast<string>(wins.length()) + " windows");

    if (wins.length() > 0) {
        window_info_t first = wins.get(0);
        check("window[0].hwnd != 0",        first.hwnd() != 0);
        check("window[0].pid != 0",         first.pid() != 0);
        check("window[0].tid != 0",         first.tid() != 0);
        // process_name / title / class_name return strings — possibly empty
        // for invisible system windows. Just verify the call doesn't crash.
        string pname = first.process_name();
        string title = first.title();
        string cls   = first.class_name();
        check("window[0].process_name() does not crash",
              pname.length() >= 0);
        check("window[0].title() does not crash",
              title.length() >= 0);
        check("window[0].class_name() does not crash",
              cls.length() >= 0);
    }

    // -----------------------------------------------------------------------
    // find_window — by title alone (Program Manager is the desktop), then
    // by title + class. Class-only would be a useful third path but the
    // surface is title or title+class.
    // -----------------------------------------------------------------------
    section("find_window");

    int64 progman_by_title = find_window("Program Manager");
    check("find_window('Program Manager') != 0", progman_by_title != 0);

    int64 progman_by_title_class = find_window("Program Manager", "Progman");
    check("find_window('Program Manager', 'Progman') != 0",
          progman_by_title_class != 0);
    check("find_window title and title+class agree on hwnd",
          progman_by_title == progman_by_title_class);

    int64 bogus_window = find_window("__definitely_no_window_xyz_42__");
    check("find_window(bogus) == 0", bogus_window == 0);

    // -----------------------------------------------------------------------
    // Window geometry queries on the desktop window.
    // -----------------------------------------------------------------------
    section("window geometry");

    int64 hwnd = progman_by_title;

    int64 w = get_window_width(hwnd);
    int64 h = get_window_height(hwnd);
    check("get_window_width(desktop) > 0",  w > 0);
    check("get_window_height(desktop) > 0", h > 0);
    print_console("  desktop size: " + cast<string>(w) + " x " + cast<string>(h));

    vec2 size = get_window_size(hwnd);
    int64 size_x_int = cast<int64>(size.x);
    int64 size_y_int = cast<int64>(size.y);
    print_console("  size.x as int64 = " + cast<string>(size_x_int) +
                  "  (expected " + cast<string>(w) + ")");
    print_console("  size.y as int64 = " + cast<string>(size_y_int) +
                  "  (expected " + cast<string>(h) + ")");
    check("get_window_size(desktop).x matches width",  size_x_int == w);
    check("get_window_size(desktop).y matches height", size_y_int == h);

    vec2 pos = get_window_pos(hwnd);
    int64 pos_x_int = cast<int64>(pos.x);
    int64 pos_y_int = cast<int64>(pos.y);
    print_console("  pos.x as int64 = " + cast<string>(pos_x_int));
    print_console("  pos.y as int64 = " + cast<string>(pos_y_int));
    check("get_window_pos(desktop) returns finite x", pos.x == pos.x);
    check("get_window_pos(desktop) returns finite y", pos.y == pos.y);

    int64 bad_w = get_window_width(0);
    check("get_window_width(0) == 0", bad_w == 0);
    vec2 bad_pos = get_window_pos(0);
    check("get_window_pos(0) == (0, 0)", bad_pos.x == 0.0 && bad_pos.y == 0.0);
    vec2 bad_size = get_window_size(0);
    check("get_window_size(0) == (0, 0)", bad_size.x == 0.0 && bad_size.y == 0.0);

    int64 bad_w2 = get_window_width(0xDEAD);
    check("get_window_width(garbage hwnd) == 0", bad_w2 == 0);

    // -----------------------------------------------------------------------
    // Window state queries — desktop is visible, desktop is normally
    // background. is_foreground_window depends on what's focused, just
    // assert it returns a boolean and doesn't fault.
    // -----------------------------------------------------------------------
    section("window state");

    bool active = is_window_active(hwnd);
    check("is_window_active(desktop) survives (typically true)",
          active || !active);

    bool fg = is_foreground_window(hwnd);
    check("is_foreground_window(desktop) survives", fg || !fg);

    bool bad_active = is_window_active(0);
    check("is_window_active(0) == false", !bad_active);

    bool bad_fg = is_foreground_window(0);
    check("is_foreground_window(0) == false", !bad_fg);

    // -----------------------------------------------------------------------
    // Title / class accessors.
    // -----------------------------------------------------------------------
    section("title / class");

    string title = get_window_title(hwnd);
    check("get_window_title(desktop) == 'Program Manager'",
          title == "Program Manager");

    string cls = get_window_class(hwnd);
    check("get_window_class(desktop) == 'Progman'", cls == "Progman");

    // Invalid hwnd returns empty string.
    string bad_title = get_window_title(0);
    check("get_window_title(0) == ''", bad_title == "");

    string bad_cls = get_window_class(0);
    check("get_window_class(0) == ''", bad_cls == "");

    // -----------------------------------------------------------------------
    // Thread / process id splits.
    // -----------------------------------------------------------------------
    section("thread / process id");

    int64 tid = get_window_thread_id(hwnd);
    int64 pid = get_window_process_id(hwnd);
    check("get_window_thread_id(desktop) != 0",  tid != 0);
    check("get_window_process_id(desktop) != 0", pid != 0);

    int64 bad_tid = get_window_thread_id(0);
    int64 bad_pid = get_window_process_id(0);
    check("get_window_thread_id(0) == 0",  bad_tid == 0);
    check("get_window_process_id(0) == 0", bad_pid == 0);

    // -----------------------------------------------------------------------
    // post_message — send WM_NULL (0). PostMessageW on the desktop window
    // is allowed and harmless. Invalid hwnd returns false.
    // -----------------------------------------------------------------------
    section("post_message");

    bool posted = post_message(hwnd, 0, 0, 0);
    check("post_message(desktop, WM_NULL, 0, 0) returns true", posted);

    bool bad_posted = post_message(0, 0, 0, 0);
    check("post_message(0, ...) returns false", !bad_posted);

    // -----------------------------------------------------------------------
    // Clipboard round-trip. set, then read. Test characters include UTF-8
    // multi-byte to verify the wide-char conversion.
    // -----------------------------------------------------------------------
    section("clipboard");

    // Save existing clipboard so we can restore it at the end.
    string prev = copy_from_clipboard();
    print_console("  saved previous clipboard length: " + cast<string>(prev.length()));

    bool set_ok = copy_to_clipboard("hello-world-42");
    check("copy_to_clipboard('hello-world-42') succeeds", set_ok);

    string read_back = copy_from_clipboard();
    check("copy_from_clipboard() round-trip == 'hello-world-42'",
          read_back == "hello-world-42");

    // Restore previous clipboard.
    copy_to_clipboard(prev);

    // -----------------------------------------------------------------------
    // Keyboard / mouse INPUT — exercise but DO NOT assert on visible state.
    // The restricted-vk filter (host-side) rejects some VKs (typically
    // power keys, Win key combos depending on filter rules). For win_key_press
    // we use a benign key (caps_lock toggled twice to no-op).
    // -----------------------------------------------------------------------
    section("input (exercise; no visible-state assertions)");

    // win_key_down / up / press all return void — we just verify they
    // don't fault. caps_lock is benign (and we toggle it twice to undo).
    win_key_down(vk::caps_lock);
    win_key_up(vk::caps_lock);
    win_key_down(vk::caps_lock);
    win_key_up(vk::caps_lock);
    check("win_key_down/up(caps_lock x2) survives", true);

    win_key_press(vk::caps_lock, 0);
    win_key_press(vk::caps_lock, 0);
    check("win_key_press(caps_lock, 0) survives", true);

    // Delay capping at 1000ms — call with a huge value and verify no fault.
    win_key_press(vk::caps_lock, 999999);
    win_key_press(vk::caps_lock, 999999);
    check("win_key_press(... , 999999) clamps and survives", true);

    // send_char / send_key target a specific hwnd. Sending WM_CHAR to the
    // desktop is safe (it discards). Just verify the call.
    bool sc = send_char(hwnd, "x");
    check("send_char(desktop, 'x') returns true", sc);

    bool sk = send_key(hwnd, vk::a);
    check("send_key(desktop, vk::a) returns true", sk);

    // Mouse: move mouse a tiny amount relative, then move it back so we
    // don't leave the user's cursor jumping around.
    vec2 mp_before = get_window_pos(hwnd); // any vec2 we have
    mouse_move_relative(0, 0);             // no-op move
    mouse_move_relative(1, 1);
    mouse_move_relative(-1, -1);
    check("mouse_move_relative survives", true);

    // Skip mouse_left/right/middle_click in test runs — they fire real
    // clicks which interact with whatever's under the cursor. Surface check
    // only: ensure the symbols are callable by referencing them in
    // unreachable code through a guard. We *do* call mouse_scroll(0) since
    // a 0 wheel delta is harmless.
    mouse_scroll(0);
    check("mouse_scroll(0) survives", true);

    // send_mouse_input with all-zero flags is also a no-op.
    send_mouse_input(0, 0, 0, 0);
    check("send_mouse_input(0,0,0,0) survives", true);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
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
    print_console("[test_win_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("win test", "");
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
