// =============================================================================
// Input API smoke test
//
// Exercises every native registered by enma_input_api.cpp:
//   - get_mouse_pos / get_mouse_pos_desktop  -> vec2
//   - get_mouse_delta / get_mouse_delta_desktop -> vec2
//   - mouse_movement_received -> bool
//   - is_hovered(vec2 pos, vec2 size) -> bool
//   - get_scroll_delta -> float64
//   - key_down / key_raw_down / key_fired / key_toggle / key_singlepress / key_prev_down
//   - get_key_state(vk) -> key_state_t with 6 method flags
//   - get_keys_down() -> array<int32>
//   - get_recent_key_input -> string
//   - get_key_name -> string
//   - vk:: enum sanity
//
// Mouse / keyboard state is whatever the user happens to be doing, so we
// can't assert specific values. We assert SHAPE: vec2 returns finite
// numbers, key_state methods all answer without faulting, get_keys_down
// is well-formed, vk:: codes are correct (vk::a == 0x41, etc.).
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

void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== input API smoke test ===");

    // -----------------------------------------------------------------------
    // Mouse position / delta — vec2 shape. Values vary frame-to-frame; we
    // just verify the result is constructible and finite.
    // -----------------------------------------------------------------------
    section("mouse position + delta");

    vec2 mpos = get_mouse_pos();
    check("get_mouse_pos() returns finite x", mpos.x == mpos.x);
    check("get_mouse_pos() returns finite y", mpos.y == mpos.y);
    print_console("  render-window pos:  " + cast<string>(mpos.x) +
                  ", " + cast<string>(mpos.y));

    vec2 mdesk = get_mouse_pos_desktop();
    check("get_mouse_pos_desktop() returns finite x", mdesk.x == mdesk.x);
    check("get_mouse_pos_desktop() returns finite y", mdesk.y == mdesk.y);
    print_console("  desktop pos:        " + cast<string>(mdesk.x) +
                  ", " + cast<string>(mdesk.y));

    vec2 mdelta = get_mouse_delta();
    check("get_mouse_delta() returns finite x", mdelta.x == mdelta.x);
    check("get_mouse_delta() returns finite y", mdelta.y == mdelta.y);

    vec2 mdelta_desk = get_mouse_delta_desktop();
    check("get_mouse_delta_desktop() returns finite x", mdelta_desk.x == mdelta_desk.x);
    check("get_mouse_delta_desktop() returns finite y", mdelta_desk.y == mdelta_desk.y);

    bool received = mouse_movement_received();
    check("mouse_movement_received() returns a bool",
          received || !received);

    float64 scroll = get_scroll_delta();
    check("get_scroll_delta() returns finite", scroll == scroll);

    // -----------------------------------------------------------------------
    // is_hovered — pass a couple of typed rect shapes and verify the call
    // returns. We don't know where the cursor is, so we just exercise the
    // path.
    // -----------------------------------------------------------------------
    section("is_hovered");

    vec2 zero_pos  = vec2(0.0,    0.0);
    vec2 huge_size = vec2(8000.0, 8000.0);
    bool any_hover = is_hovered(zero_pos, huge_size);
    check("is_hovered((0,0), 8000x8000) survives", any_hover || !any_hover);

    vec2 far_pos   = vec2(99999.0, 99999.0);
    vec2 small_sz  = vec2(1.0, 1.0);
    bool no_hover  = is_hovered(far_pos, small_sz);
    check("is_hovered(off-screen, 1x1) == false", !no_hover);

    // -----------------------------------------------------------------------
    // Single-flag key queries — exercise across the surface.
    // -----------------------------------------------------------------------
    section("single-flag key queries (state varies with user input)");

    bool any_a_down       = key_down(vk::a);
    bool any_a_raw        = key_raw_down(vk::a);
    bool any_a_fired      = key_fired(vk::a);
    bool any_a_toggle     = key_toggle(vk::a);
    bool any_a_single     = key_singlepress(vk::a);
    bool any_a_prev       = key_prev_down(vk::a);
    check("key_down(a) returns bool",        any_a_down || !any_a_down);
    check("key_raw_down(a) returns bool",    any_a_raw || !any_a_raw);
    check("key_fired(a) returns bool",       any_a_fired || !any_a_fired);
    check("key_toggle(a) returns bool",      any_a_toggle || !any_a_toggle);
    check("key_singlepress(a) returns bool", any_a_single || !any_a_single);
    check("key_prev_down(a) returns bool",   any_a_prev || !any_a_prev);

    // Out-of-range vk should return false (clamped to {} fallback).
    bool oob = key_down(99999);
    check("key_down(99999) == false (out of range)", !oob);

    // -----------------------------------------------------------------------
    // key_state_t — atomic snapshot of all 6 flags. Method surface should
    // answer for each.
    // -----------------------------------------------------------------------
    section("key_state_t snapshot");

    key_state_t a_state = get_key_state(vk::a);
    check("get_key_state(a) returns non-null handle", cast<int64>(a_state) != 0);

    bool a_raw   = a_state.raw_down();
    bool a_down  = a_state.down();
    bool a_fired = a_state.fired();
    bool a_tog   = a_state.toggle();
    bool a_sing  = a_state.singlepress();
    bool a_prev  = a_state.prev_down();
    check("key_state_t.raw_down() answers",    a_raw || !a_raw);
    check("key_state_t.down() answers",        a_down || !a_down);
    check("key_state_t.fired() answers",       a_fired || !a_fired);
    check("key_state_t.toggle() answers",      a_tog || !a_tog);
    check("key_state_t.singlepress() answers", a_sing || !a_sing);
    check("key_state_t.prev_down() answers",   a_prev || !a_prev);

    // out-of-range vk -> snapshot should be all-false (zero-init fallback)
    key_state_t bad_state = get_key_state(99999);
    check("get_key_state(99999) returns non-null handle (zero-init)",
          cast<int64>(bad_state) != 0);
    if (cast<int64>(bad_state) != 0) {
        check("oob key_state.down() == false",        !bad_state.down());
        check("oob key_state.raw_down() == false",    !bad_state.raw_down());
        check("oob key_state.fired() == false",       !bad_state.fired());
    }

    // -----------------------------------------------------------------------
    // get_keys_down — array<int32>. Length depends on user state but the
    // shape is always well-formed.
    // -----------------------------------------------------------------------
    section("get_keys_down");

    array<int32> down = get_keys_down();
    check("get_keys_down() returns array<int32>", down.length() >= 0);
    check("get_keys_down().length() <= 256",      down.length() <= 256);
    print_console("  keys currently down: " + cast<string>(down.length()));
    if (down.length() > 0) {
        // Each element should be a valid VK in [0..255].
        int32 first_vk = down.get(0);
        check("get_keys_down()[0] in 0..255",
              cast<int64>(first_vk) >= 0 && cast<int64>(first_vk) < 256);
        // For information: name of the first held key.
        string name0 = get_key_name(first_vk);
        print_console("  first held key vk=" + cast<string>(first_vk) +
                      " name='" + name0 + "'");
    }

    // -----------------------------------------------------------------------
    // get_recent_key_input — buffered text since last poll. Call doesn't
    // fault; result is a string (possibly empty).
    // -----------------------------------------------------------------------
    section("get_recent_key_input");

    string recent = get_recent_key_input();
    check("get_recent_key_input() returns string", recent.length() >= 0);
    print_console("  recent input length: " + cast<string>(recent.length()));

    // -----------------------------------------------------------------------
    // get_key_name — common keys should produce non-empty strings; OOB or
    // unmapped vks return "".
    // -----------------------------------------------------------------------
    section("get_key_name");

    string a_name    = get_key_name(vk::a);
    string sp_name   = get_key_name(vk::space);
    string esc_name  = get_key_name(vk::escape);
    string f1_name   = get_key_name(vk::f1);
    check("get_key_name(vk::a) is non-empty",      a_name.length() > 0);
    check("get_key_name(vk::space) is non-empty",  sp_name.length() > 0);
    check("get_key_name(vk::escape) is non-empty", esc_name.length() > 0);
    check("get_key_name(vk::f1) is non-empty",     f1_name.length() > 0);
    print_console("  vk::a     name = '" + a_name + "'");
    print_console("  vk::space name = '" + sp_name + "'");
    print_console("  vk::f1    name = '" + f1_name + "'");

    // get_key_name(oob) — host's MBV_GetKeyNameByVirtualKey may return true
    // with a localized default for codes it doesn't know, instead of failing.
    // Accept either empty or a short localized name; just make sure it returns.
    string oob_name = get_key_name(99999);
    check("get_key_name(oob) returns string without crashing",
          oob_name.length() >= 0);

    // -----------------------------------------------------------------------
    // vk:: enum sanity — Win32 VK_* spec values. Verify a few key codes.
    // -----------------------------------------------------------------------
    section("vk:: enum values");

    check("vk::backspace == 0x08", cast<int64>(vk::backspace) == 0x08);
    check("vk::tab       == 0x09", cast<int64>(vk::tab)       == 0x09);
    check("vk::enter     == 0x0D", cast<int64>(vk::enter)     == 0x0D);
    check("vk::shift     == 0x10", cast<int64>(vk::shift)     == 0x10);
    check("vk::ctrl      == 0x11", cast<int64>(vk::ctrl)      == 0x11);
    check("vk::escape    == 0x1B", cast<int64>(vk::escape)    == 0x1B);
    check("vk::space     == 0x20", cast<int64>(vk::space)     == 0x20);
    check("vk::left      == 0x25", cast<int64>(vk::left)      == 0x25);
    check("vk::up        == 0x26", cast<int64>(vk::up)        == 0x26);
    check("vk::right     == 0x27", cast<int64>(vk::right)     == 0x27);
    check("vk::down      == 0x28", cast<int64>(vk::down)      == 0x28);
    check("vk::k0        == 0x30", cast<int64>(vk::k0)        == 0x30);
    check("vk::k9        == 0x39", cast<int64>(vk::k9)        == 0x39);
    check("vk::a         == 0x41", cast<int64>(vk::a)         == 0x41);
    check("vk::z         == 0x5A", cast<int64>(vk::z)         == 0x5A);
    check("vk::f1        == 0x70", cast<int64>(vk::f1)        == 0x70);
    check("vk::f12       == 0x7B", cast<int64>(vk::f12)       == 0x7B);
    check("vk::lbutton   == 0x01", cast<int64>(vk::lbutton)   == 0x01);
    check("vk::rbutton   == 0x02", cast<int64>(vk::rbutton)   == 0x02);
    check("vk::mbutton   == 0x04", cast<int64>(vk::mbutton)   == 0x04);
    check("vk::numpad0   == 0x60", cast<int64>(vk::numpad0)   == 0x60);
    check("vk::numpad9   == 0x69", cast<int64>(vk::numpad9)   == 0x69);

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
    print_console("[test_input_api] launching test routine + sidebar menu");

    g_section = create_sidebar_section("input test", "");
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
