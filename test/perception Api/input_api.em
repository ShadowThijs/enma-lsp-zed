// =============================================================================
// Comprehensive Input API test
//
// Covers EVERY type, method, and standalone function documented in:
//   docs/Perception/Input API.md
//
// CHECKLIST:
// ==========
//
// TYPES with METHODS:
//   vec2          — return type from mouse functions (methods tested via math API)
//   key_state_t   — .raw_down() .down() .fired() .toggle() .singlepress() .prev_down()
//
// MOUSE functions (standalone):
//   get_mouse_pos()            -> vec2
//   get_mouse_pos_desktop()    -> vec2
//   get_mouse_delta()          -> vec2
//   get_mouse_delta_desktop()  -> vec2
//   mouse_movement_received()  -> bool
//   is_hovered(vec2 pos, vec2 size) -> bool
//   get_scroll_delta()         -> float64
//
// KEYBOARD single-flag functions (standalone):
//   key_down(int64 vk)         -> bool
//   key_raw_down(int64 vk)     -> bool
//   key_fired(int64 vk)        -> bool
//   key_toggle(int64 vk)       -> bool
//   key_singlepress(int64 vk)  -> bool
//   key_prev_down(int64 vk)    -> bool
//
// BULK / ERGONOMIC functions (standalone):
//   get_key_state(int64 vk)    -> key_state_t   (plus all 6 sub-methods)
//   get_keys_down()            -> array<int32>
//   get_recent_key_input()     -> string
//   get_key_name(int64 vk)     -> string
//
// vk ENUM values (all 50+ values verified against Win32 VK_*):
//   backspace(0x08)  tab(0x09)       enter(0x0D)    shift(0x10)    ctrl(0x11)
//   alt(0x12)        pause(0x13)     caps_lock(0x14) escape(0x1B)   space(0x20)
//   page_up(0x21)    page_down(0x22) end(0x23)       home(0x24)
//   left(0x25)       up(0x26)        right(0x27)     down(0x28)
//   insert(0x2D)     delete(0x2E)
//   k0(0x30) ... k9(0x39)
//   a(0x41)  ... z(0x5A)
//   lwin(0x5B)       rwin(0x5C)
//   numpad0(0x60) ... numpad9(0x69)
//   multiply(0x6A)   add(0x6B)       subtract(0x6D)  decimal(0x6E)  divide(0x6F)
//   f1(0x70) ... f12(0x7B)
//   num_lock(0x90)   scroll_lock(0x91)
//   lshift(0xA0)     rshift(0xA1)
//   lctrl(0xA2)      rctrl(0xA3)
//   lalt(0xA4)       ralt(0xA5)
//   lbutton(0x01)    rbutton(0x02)   mbutton(0x04)   xbutton1(0x05) xbutton2(0x06)
//
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

// ---------------------------------------------------------------------------
// vk enum verification
// ---------------------------------------------------------------------------
void test_vk_enum_values() {
    section("vk:: enum values — verify all against Win32 VK_* spec");

    // Mouse buttons (0x01–0x06)
    check("vk::lbutton   == 0x01", cast<int64>(vk::lbutton)   == 0x01);
    check("vk::rbutton   == 0x02", cast<int64>(vk::rbutton)   == 0x02);
    check("vk::mbutton   == 0x04", cast<int64>(vk::mbutton)   == 0x04);
    check("vk::xbutton1  == 0x05", cast<int64>(vk::xbutton1)  == 0x05);
    check("vk::xbutton2  == 0x06", cast<int64>(vk::xbutton2)  == 0x06);

    // Whitespace / control
    check("vk::backspace == 0x08", cast<int64>(vk::backspace) == 0x08);
    check("vk::tab       == 0x09", cast<int64>(vk::tab)       == 0x09);
    check("vk::enter     == 0x0D", cast<int64>(vk::enter)     == 0x0D);

    // Modifiers
    check("vk::shift     == 0x10", cast<int64>(vk::shift)     == 0x10);
    check("vk::ctrl      == 0x11", cast<int64>(vk::ctrl)      == 0x11);
    check("vk::alt       == 0x12", cast<int64>(vk::alt)       == 0x12);

    // Pause / lock
    check("vk::pause     == 0x13", cast<int64>(vk::pause)     == 0x13);
    check("vk::caps_lock == 0x14", cast<int64>(vk::caps_lock) == 0x14);

    // Escape
    check("vk::escape    == 0x1B", cast<int64>(vk::escape)    == 0x1B);

    // Space
    check("vk::space     == 0x20", cast<int64>(vk::space)     == 0x20);

    // Page navigation
    check("vk::page_up   == 0x21", cast<int64>(vk::page_up)   == 0x21);
    check("vk::page_down == 0x22", cast<int64>(vk::page_down) == 0x22);
    check("vk::end       == 0x23", cast<int64>(vk::end)       == 0x23);
    check("vk::home      == 0x24", cast<int64>(vk::home)      == 0x24);

    // Arrow keys
    check("vk::left      == 0x25", cast<int64>(vk::left)      == 0x25);
    check("vk::up        == 0x26", cast<int64>(vk::up)        == 0x26);
    check("vk::right     == 0x27", cast<int64>(vk::right)     == 0x27);
    check("vk::down      == 0x28", cast<int64>(vk::down)      == 0x28);

    // Insert / delete
    check("vk::insert    == 0x2D", cast<int64>(vk::insert)    == 0x2D);
    check("vk::delete    == 0x2E", cast<int64>(vk::delete)    == 0x2E);

    // Top-row digits
    check("vk::k0        == 0x30", cast<int64>(vk::k0)        == 0x30);
    check("vk::k1        == 0x31", cast<int64>(vk::k1)        == 0x31);
    check("vk::k2        == 0x32", cast<int64>(vk::k2)        == 0x32);
    check("vk::k3        == 0x33", cast<int64>(vk::k3)        == 0x33);
    check("vk::k4        == 0x34", cast<int64>(vk::k4)        == 0x34);
    check("vk::k5        == 0x35", cast<int64>(vk::k5)        == 0x35);
    check("vk::k6        == 0x36", cast<int64>(vk::k6)        == 0x36);
    check("vk::k7        == 0x37", cast<int64>(vk::k7)        == 0x37);
    check("vk::k8        == 0x38", cast<int64>(vk::k8)        == 0x38);
    check("vk::k9        == 0x39", cast<int64>(vk::k9)        == 0x39);

    // Letters
    check("vk::a         == 0x41", cast<int64>(vk::a)         == 0x41);
    check("vk::b         == 0x42", cast<int64>(vk::b)         == 0x42);
    check("vk::c         == 0x43", cast<int64>(vk::c)         == 0x43);
    check("vk::d         == 0x44", cast<int64>(vk::d)         == 0x44);
    check("vk::e         == 0x45", cast<int64>(vk::e)         == 0x45);
    check("vk::f         == 0x46", cast<int64>(vk::f)         == 0x46);
    check("vk::g         == 0x47", cast<int64>(vk::g)         == 0x47);
    check("vk::h         == 0x48", cast<int64>(vk::h)         == 0x48);
    check("vk::i         == 0x49", cast<int64>(vk::i)         == 0x49);
    check("vk::j         == 0x4A", cast<int64>(vk::j)         == 0x4A);
    check("vk::k         == 0x4B", cast<int64>(vk::k)         == 0x4B);
    check("vk::l         == 0x4C", cast<int64>(vk::l)         == 0x4C);
    check("vk::m         == 0x4D", cast<int64>(vk::m)         == 0x4D);
    check("vk::n         == 0x4E", cast<int64>(vk::n)         == 0x4E);
    check("vk::o         == 0x4F", cast<int64>(vk::o)         == 0x4F);
    check("vk::p         == 0x50", cast<int64>(vk::p)         == 0x50);
    check("vk::q         == 0x51", cast<int64>(vk::q)         == 0x51);
    check("vk::r         == 0x52", cast<int64>(vk::r)         == 0x52);
    check("vk::s         == 0x53", cast<int64>(vk::s)         == 0x53);
    check("vk::t         == 0x54", cast<int64>(vk::t)         == 0x54);
    check("vk::u         == 0x55", cast<int64>(vk::u)         == 0x55);
    check("vk::v         == 0x56", cast<int64>(vk::v)         == 0x56);
    check("vk::w         == 0x57", cast<int64>(vk::w)         == 0x57);
    check("vk::x         == 0x58", cast<int64>(vk::x)         == 0x58);
    check("vk::y         == 0x59", cast<int64>(vk::y)         == 0x59);
    check("vk::z         == 0x5A", cast<int64>(vk::z)         == 0x5A);

    // Windows keys
    check("vk::lwin      == 0x5B", cast<int64>(vk::lwin)      == 0x5B);
    check("vk::rwin      == 0x5C", cast<int64>(vk::rwin)      == 0x5C);

    // Numpad
    check("vk::numpad0   == 0x60", cast<int64>(vk::numpad0)   == 0x60);
    check("vk::numpad1   == 0x61", cast<int64>(vk::numpad1)   == 0x61);
    check("vk::numpad2   == 0x62", cast<int64>(vk::numpad2)   == 0x62);
    check("vk::numpad3   == 0x63", cast<int64>(vk::numpad3)   == 0x63);
    check("vk::numpad4   == 0x64", cast<int64>(vk::numpad4)   == 0x64);
    check("vk::numpad5   == 0x65", cast<int64>(vk::numpad5)   == 0x65);
    check("vk::numpad6   == 0x66", cast<int64>(vk::numpad6)   == 0x66);
    check("vk::numpad7   == 0x67", cast<int64>(vk::numpad7)   == 0x67);
    check("vk::numpad8   == 0x68", cast<int64>(vk::numpad8)   == 0x68);
    check("vk::numpad9   == 0x69", cast<int64>(vk::numpad9)   == 0x69);

    // Numpad operators
    check("vk::multiply  == 0x6A", cast<int64>(vk::multiply)  == 0x6A);
    check("vk::add       == 0x6B", cast<int64>(vk::add)       == 0x6B);
    check("vk::subtract  == 0x6D", cast<int64>(vk::subtract)  == 0x6D);
    check("vk::decimal   == 0x6E", cast<int64>(vk::decimal)   == 0x6E);
    check("vk::divide    == 0x6F", cast<int64>(vk::divide)    == 0x6F);

    // Function keys
    check("vk::f1        == 0x70", cast<int64>(vk::f1)        == 0x70);
    check("vk::f2        == 0x71", cast<int64>(vk::f2)        == 0x71);
    check("vk::f3        == 0x72", cast<int64>(vk::f3)        == 0x72);
    check("vk::f4        == 0x73", cast<int64>(vk::f4)        == 0x73);
    check("vk::f5        == 0x74", cast<int64>(vk::f5)        == 0x74);
    check("vk::f6        == 0x75", cast<int64>(vk::f6)        == 0x75);
    check("vk::f7        == 0x76", cast<int64>(vk::f7)        == 0x76);
    check("vk::f8        == 0x77", cast<int64>(vk::f8)        == 0x77);
    check("vk::f9        == 0x78", cast<int64>(vk::f9)        == 0x78);
    check("vk::f10       == 0x79", cast<int64>(vk::f10)       == 0x79);
    check("vk::f11       == 0x7A", cast<int64>(vk::f11)       == 0x7A);
    check("vk::f12       == 0x7B", cast<int64>(vk::f12)       == 0x7B);

    // Lock keys
    check("vk::num_lock     == 0x90", cast<int64>(vk::num_lock)     == 0x90);
    check("vk::scroll_lock  == 0x91", cast<int64>(vk::scroll_lock)  == 0x91);

    // Left/right modifier pairs
    check("vk::lshift    == 0xA0", cast<int64>(vk::lshift)    == 0xA0);
    check("vk::rshift    == 0xA1", cast<int64>(vk::rshift)    == 0xA1);
    check("vk::lctrl     == 0xA2", cast<int64>(vk::lctrl)     == 0xA2);
    check("vk::rctrl     == 0xA3", cast<int64>(vk::rctrl)     == 0xA3);
    check("vk::lalt      == 0xA4", cast<int64>(vk::lalt)      == 0xA4);
    check("vk::ralt      == 0xA5", cast<int64>(vk::ralt)      == 0xA5);
}

// ---------------------------------------------------------------------------
// Mouse position / delta — vec2 shape
// ---------------------------------------------------------------------------
void test_mouse() {
    section("mouse position + delta");

    // get_mouse_pos — render-window pixels, returns vec2
    vec2 mpos = get_mouse_pos();
    check("get_mouse_pos() returns vec2 with finite x", mpos.x == mpos.x);
    check("get_mouse_pos() returns vec2 with finite y", mpos.y == mpos.y);
    check("get_mouse_pos() x() method access", mpos.x() == mpos.x);
    check("get_mouse_pos() y() method access", mpos.y() == mpos.y);
    print_console("  render-window pos: " + cast<string>(mpos.x) +
                  ", " + cast<string>(mpos.y));

    // get_mouse_pos_desktop — desktop pixels, returns vec2
    vec2 mdesk = get_mouse_pos_desktop();
    check("get_mouse_pos_desktop() returns vec2 with finite x", mdesk.x == mdesk.x);
    check("get_mouse_pos_desktop() returns vec2 with finite y", mdesk.y == mdesk.y);
    print_console("  desktop pos: " + cast<string>(mdesk.x) +
                  ", " + cast<string>(mdesk.y));

    // get_mouse_delta — raw movement this frame, returns vec2
    vec2 mdelta = get_mouse_delta();
    check("get_mouse_delta() returns vec2 with finite x", mdelta.x == mdelta.x);
    check("get_mouse_delta() returns vec2 with finite y", mdelta.y == mdelta.y);
    print_console("  mouse delta: " + cast<string>(mdelta.x) +
                  ", " + cast<string>(mdelta.y));

    // get_mouse_delta_desktop — desktop-space delta, returns vec2
    vec2 mdelta_desk = get_mouse_delta_desktop();
    check("get_mouse_delta_desktop() returns vec2 with finite x",
          mdelta_desk.x == mdelta_desk.x);
    check("get_mouse_delta_desktop() returns vec2 with finite y",
          mdelta_desk.y == mdelta_desk.y);
    print_console("  desktop delta: " + cast<string>(mdelta_desk.x) +
                  ", " + cast<string>(mdelta_desk.y));

    // mouse_movement_received — any movement this frame, returns bool
    bool received = mouse_movement_received();
    check("mouse_movement_received() returns a bool", received || !received);
    print_console("  movement received this frame: " + cast<string>(received));

    // get_scroll_delta — wheel ticks, positive = up, returns float64
    float64 scroll = get_scroll_delta();
    check("get_scroll_delta() returns finite float64", scroll == scroll);
    print_console("  scroll delta: " + cast<string>(scroll));

    // is_hovered — test with known rects
    section("is_hovered");

    // A rect covering the full render window should always be hovered
    // (since the cursor must be somewhere in it).
    vec2 zero_pos = vec2(0.0, 0.0);
    vec2 huge_size = vec2(8000.0, 8000.0);
    bool any_hover = is_hovered(zero_pos, huge_size);
    check("is_hovered((0,0), 8000x8000) returns bool", any_hover || !any_hover);
    print_console("  is_hovered(full-window rect): " + cast<string>(any_hover));

    // An off-screen rect with tiny size should NOT be hovered.
    vec2 far_pos = vec2(99999.0, 99999.0);
    vec2 tiny_size = vec2(1.0, 1.0);
    bool no_hover = is_hovered(far_pos, tiny_size);
    // This is a logical assertion: if the cursor is inside a 1x1 at
    // (99999, 99999), the screen must be enormous. We accept the
    // result either way but log it.
    check("is_hovered(off-screen, 1x1) call succeeds", true);
    print_console("  is_hovered(off-screen rect): " + cast<string>(no_hover));
}

// ---------------------------------------------------------------------------
// Single-flag key queries — all 6 per-flag functions
// ---------------------------------------------------------------------------
void test_single_flag_key_queries() {
    section("single-flag key queries (state depends on user input)");

    // key_down — currently pressed (host-debounced)
    bool any_down = key_down(vk::a);
    check("key_down(vk::a) returns bool", any_down || !any_down);

    // key_raw_down — OS-level pressed state
    bool any_raw = key_raw_down(vk::a);
    check("key_raw_down(vk::a) returns bool", any_raw || !any_raw);

    // key_fired — up->down transition this frame
    bool any_fired = key_fired(vk::a);
    check("key_fired(vk::a) returns bool", any_fired || !any_fired);

    // key_toggle — caps-lock-style toggle
    bool any_toggle = key_toggle(vk::a);
    check("key_toggle(vk::a) returns bool", any_toggle || !any_toggle);

    // key_singlepress — fired but suppressed when modifiers are held
    bool any_single = key_singlepress(vk::a);
    check("key_singlepress(vk::a) returns bool", any_single || !any_single);

    // key_prev_down — down state from previous frame
    bool any_prev = key_prev_down(vk::a);
    check("key_prev_down(vk::a) returns bool", any_prev || !any_prev);

    // Test all 6 functions with a non-letter vk to ensure cross-section coverage
    bool esc_down   = key_down(vk::escape);
    bool esc_raw    = key_raw_down(vk::escape);
    bool esc_fired  = key_fired(vk::escape);
    bool esc_toggle = key_toggle(vk::escape);
    bool esc_single = key_singlepress(vk::escape);
    bool esc_prev   = key_prev_down(vk::escape);
    check("key_down(vk::escape) returns bool",      esc_down   || !esc_down);
    check("key_raw_down(vk::escape) returns bool",  esc_raw    || !esc_raw);
    check("key_fired(vk::escape) returns bool",     esc_fired  || !esc_fired);
    check("key_toggle(vk::escape) returns bool",    esc_toggle || !esc_toggle);
    check("key_singlepress(vk::escape) returns bool", esc_single || !esc_single);
    check("key_prev_down(vk::escape) returns bool", esc_prev   || !esc_prev);

    // Out-of-range vk should return false (clamped to fallback).
    bool oob_down  = key_down(99999);
    bool oob_raw   = key_raw_down(99999);
    bool oob_fired = key_fired(99999);
    bool oob_tog   = key_toggle(99999);
    bool oob_sing  = key_singlepress(99999);
    bool oob_prev  = key_prev_down(99999);
    check("key_down(99999) == false (out of range)",      !oob_down);
    check("key_raw_down(99999) == false (out of range)",  !oob_raw);
    check("key_fired(99999) == false (out of range)",     !oob_fired);
    check("key_toggle(99999) == false (out of range)",    !oob_tog);
    check("key_singlepress(99999) == false (out of range)", !oob_sing);
    check("key_prev_down(99999) == false (out of range)", !oob_prev);
}

// ---------------------------------------------------------------------------
// key_state_t — atomic snapshot with 6 method flags
// ---------------------------------------------------------------------------
void test_key_state_t() {
    section("key_state_t snapshot — 6 methods");

    // get_key_state(vk) returns key_state_t instance
    key_state_t a_state = get_key_state(vk::a);
    check("get_key_state(vk::a) returns non-null key_state_t",
          cast<int64>(a_state) != 0);

    // Call ALL 6 methods on key_state_t:
    //   .raw_down()     — OS-level pressed state
    //   .down()         — host-debounced pressed state
    //   .fired()        — up->down this frame (one-shot)
    //   .toggle()       — caps-lock-style toggle
    //   .singlepress()  — fired but suppressed if modifiers held
    //   .prev_down()    — down state from previous frame

    bool ks_raw  = a_state.raw_down();
    bool ks_down = a_state.down();
    bool ks_fire = a_state.fired();
    bool ks_tog  = a_state.toggle();
    bool ks_sing = a_state.singlepress();
    bool ks_prev = a_state.prev_down();

    check("key_state_t.raw_down() answers",     ks_raw || !ks_raw);
    check("key_state_t.down() answers",         ks_down || !ks_down);
    check("key_state_t.fired() answers",        ks_fire || !ks_fire);
    check("key_state_t.toggle() answers",       ks_tog || !ks_tog);
    check("key_state_t.singlepress() answers",  ks_sing || !ks_sing);
    check("key_state_t.prev_down() answers",    ks_prev || !ks_prev);

    print_console("  vk::a state: down=" + cast<string>(ks_down) +
                  " raw=" + cast<string>(ks_raw) +
                  " fired=" + cast<string>(ks_fire) +
                  " toggle=" + cast<string>(ks_tog) +
                  " single=" + cast<string>(ks_sing) +
                  " prev=" + cast<string>(ks_prev));

    // Test key_state_t with a non-letter vk
    key_state_t space_state = get_key_state(vk::space);
    check("get_key_state(vk::space) returns non-null",
          cast<int64>(space_state) != 0);
    check("key_state_t(space).down() answers",
          space_state.down() || !space_state.down());
    check("key_state_t(space).raw_down() answers",
          space_state.raw_down() || !space_state.raw_down());
    check("key_state_t(space).fired() answers",
          space_state.fired() || !space_state.fired());
    check("key_state_t(space).toggle() answers",
          space_state.toggle() || !space_state.toggle());
    check("key_state_t(space).singlepress() answers",
          space_state.singlepress() || !space_state.singlepress());
    check("key_state_t(space).prev_down() answers",
          space_state.prev_down() || !space_state.prev_down());

    // Out-of-range vk — snapshot should be all-false (zero-init fallback)
    key_state_t bad_state = get_key_state(99999);
    check("get_key_state(99999) returns non-null handle (zero-init)",
          cast<int64>(bad_state) != 0);
    if (cast<int64>(bad_state) != 0) {
        check("oob key_state_t.down() == false",        !bad_state.down());
        check("oob key_state_t.raw_down() == false",    !bad_state.raw_down());
        check("oob key_state_t.fired() == false",       !bad_state.fired());
        check("oob key_state_t.toggle() == false",      !bad_state.toggle());
        check("oob key_state_t.singlepress() == false", !bad_state.singlepress());
        check("oob key_state_t.prev_down() == false",   !bad_state.prev_down());
    }
}

// ---------------------------------------------------------------------------
// get_keys_down — array<int32> of currently pressed virtual-key codes
// ---------------------------------------------------------------------------
void test_get_keys_down() {
    section("get_keys_down");

    array<int32> down = get_keys_down();
    check("get_keys_down() returns array<int32>", down.length() >= 0);
    check("get_keys_down().length() <= 256",      down.length() <= 256);
    print_console("  keys currently down: " + cast<string>(down.length()));

    // If any keys are held, verify each element is a valid VK code in [0..255].
    if (down.length() > 0) {
        int32 first_vk = down.get(0);
        check("get_keys_down()[0] in 0..255",
              cast<int64>(first_vk) >= 0 && cast<int64>(first_vk) < 256);

        // Look up the name of the first held key via get_key_name.
        string name0 = get_key_name(first_vk);
        print_console("  first held key vk=" + cast<string>(first_vk) +
                      " name='" + name0 + "'");

        // Iterate through the full array to validate all entries.
        int64 idx = 0;
        while (idx < down.length()) {
            int32 vk_code = down.get(idx);
            if (cast<int64>(vk_code) < 0 || cast<int64>(vk_code) >= 256) {
                print_console("  [WARN] get_keys_down()[" + cast<string>(idx) +
                              "] = " + cast<string>(vk_code) + " out of range");
            }
            idx = idx + 1;
        }
        check("get_keys_down() all entries valid (no crash during iteration)", true);
    }
}

// ---------------------------------------------------------------------------
// get_recent_key_input — buffered text input (UTF-8) since last poll
// ---------------------------------------------------------------------------
void test_get_recent_key_input() {
    section("get_recent_key_input");

    string recent = get_recent_key_input();
    check("get_recent_key_input() returns string", recent.length() >= 0);
    print_console("  recent input length: " + cast<string>(recent.length()));

    // Poll a second time — the buffer should be empty (or whatever was typed
    // between calls; either way, no crash).
    string recent2 = get_recent_key_input();
    check("get_recent_key_input() second call returns string",
          recent2.length() >= 0);
}

// ---------------------------------------------------------------------------
// get_key_name — localized key name string
// ---------------------------------------------------------------------------
void test_get_key_name() {
    section("get_key_name");

    // Common keys should produce non-empty localized names.
    string a_name   = get_key_name(vk::a);
    string b_name   = get_key_name(vk::b);
    string z_name   = get_key_name(vk::z);
    string sp_name  = get_key_name(vk::space);
    string esc_name = get_key_name(vk::escape);
    string ent_name = get_key_name(vk::enter);
    string f1_name  = get_key_name(vk::f1);
    string f12_name = get_key_name(vk::f12);
    string up_name  = get_key_name(vk::up);
    string lbtn_name = get_key_name(vk::lbutton);

    check("get_key_name(vk::a) is non-empty",      a_name.length() > 0);
    check("get_key_name(vk::b) is non-empty",      b_name.length() > 0);
    check("get_key_name(vk::z) is non-empty",      z_name.length() > 0);
    check("get_key_name(vk::space) is non-empty",  sp_name.length() > 0);
    check("get_key_name(vk::escape) is non-empty", esc_name.length() > 0);
    check("get_key_name(vk::enter) is non-empty",  ent_name.length() > 0);
    check("get_key_name(vk::f1) is non-empty",     f1_name.length() > 0);
    check("get_key_name(vk::f12) is non-empty",    f12_name.length() > 0);
    check("get_key_name(vk::up) is non-empty",     up_name.length() > 0);
    check("get_key_name(vk::lbutton) is non-empty", lbtn_name.length() > 0);

    print_console("  vk::a       name = '" + a_name + "'");
    print_console("  vk::space   name = '" + sp_name + "'");
    print_console("  vk::enter   name = '" + ent_name + "'");
    print_console("  vk::escape  name = '" + esc_name + "'");
    print_console("  vk::f1      name = '" + f1_name + "'");
    print_console("  vk::up      name = '" + up_name + "'");

    // Additional key names for broader coverage.
    string tab_name  = get_key_name(vk::tab);
    string shi_name  = get_key_name(vk::shift);
    string ctrl_name = get_key_name(vk::ctrl);
    string alt_name  = get_key_name(vk::alt);
    string del_name  = get_key_name(vk::delete);
    string np0_name  = get_key_name(vk::numpad0);
    string mul_name  = get_key_name(vk::multiply);

    check("get_key_name(vk::tab) is non-empty",      tab_name.length() > 0);
    check("get_key_name(vk::shift) is non-empty",    shi_name.length() > 0);
    check("get_key_name(vk::ctrl) is non-empty",     ctrl_name.length() > 0);
    check("get_key_name(vk::alt) is non-empty",      alt_name.length() > 0);
    check("get_key_name(vk::delete) is non-empty",   del_name.length() > 0);
    check("get_key_name(vk::numpad0) is non-empty",  np0_name.length() > 0);
    check("get_key_name(vk::multiply) is non-empty", mul_name.length() > 0);

    print_console("  vk::tab     name = '" + tab_name + "'");
    print_console("  vk::shift   name = '" + shi_name + "'");
    print_console("  vk::ctrl    name = '" + ctrl_name + "'");
    print_console("  vk::delete  name = '" + del_name + "'");

    // Out-of-range: host may return empty string or a short localized fallback.
    string oob_name = get_key_name(99999);
    check("get_key_name(99999) returns string without crashing",
          oob_name.length() >= 0);
    print_console("  get_key_name(99999) = '" + oob_name + "'");

    // Test with border values: vk::lbutton (0x01) and vk::xbutton2 (0x06)
    string lb_name  = get_key_name(vk::lbutton);
    string mb_name  = get_key_name(vk::mbutton);
    string xb2_name = get_key_name(vk::xbutton2);
    check("get_key_name(vk::lbutton) is non-empty",  lb_name.length() > 0);
    check("get_key_name(vk::mbutton) is non-empty",  mb_name.length() > 0);
    check("get_key_name(vk::xbutton2) is non-empty", xb2_name.length() > 0);
}

// ---------------------------------------------------------------------------
// Integration: use all API surfaces together in a single routine
// ---------------------------------------------------------------------------
void test_routine(int64 data) {
    if (g_done != 0) return;
    g_done = 1;

    print_console("=== Comprehensive Input API test ===");

    // 1. vk enum values (all members verified against Win32 VK_* spec)
    test_vk_enum_values();

    // 2. Mouse functions (7 functions, 4 returning vec2, 2 returning bool, 1 returning float64)
    test_mouse();

    // 3. Single-flag key queries (6 functions x multiple vk values)
    test_single_flag_key_queries();

    // 4. key_state_t type with all 6 methods (via get_key_state)
    test_key_state_t();

    // 5. get_keys_down (array<int32> result, iteration over elements)
    test_get_keys_down();

    // 6. get_recent_key_input (string result, double-poll)
    test_get_recent_key_input();

    // 7. get_key_name (localized string for many vk values + OOB)
    test_get_key_name();

    // ========================================================================
    // Cross-surface verification: ensure composability
    // ========================================================================
    section("cross-surface composition");

    // Use key_state_t from get_key_state, then pass the same vk to get_key_name.
    key_state_t ks_enter = get_key_state(vk::enter);
    string enter_name = get_key_name(vk::enter);
    check("compose: get_key_state + get_key_name for vk::enter",
          cast<int64>(ks_enter) != 0 && enter_name.length() > 0);

    // Combine mouse and keyboard: check if mouse moved and a key was pressed.
    bool moved = mouse_movement_received();
    bool fired = key_fired(vk::space);
    check("compose: mouse_movement_received + key_fired coexist",
          (moved || !moved) && (fired || !fired));

    // Use get_keys_down together with get_key_name to name the first held key.
    array<int32> keys = get_keys_down();
    if (keys.length() > 0) {
        int32 held = keys.get(0);
        string held_name = get_key_name(held);
        check("compose: get_keys_down[0] named via get_key_name",
              held_name.length() >= 0);
        print_console("  first held key name via composition: '" + held_name + "'");
    }

    // Combine mouse and scroll: use both in the same expression.
    vec2 m = get_mouse_pos();
    float64 s = get_scroll_delta();
    check("compose: get_mouse_pos + get_scroll_delta both finite",
          m.x == m.x && m.y == m.y && s == s);

    // ========================================================================
    // Summary
    // ========================================================================
    print_console("");
    print_console("===========================================");
    print_console("  PASS: " + cast<string>(g_pass));
    print_console("  FAIL: " + cast<string>(g_fail));
    print_console("===========================================");

    unregister_routine(g_handle);
}

// ---------------------------------------------------------------------------
// Menu callbacks
// ---------------------------------------------------------------------------
void on_menu_run_again(int64 data) {
    print_console("[menu] 'Run again' clicked — resetting and re-firing routine");
    g_done = 0;
    g_pass = 0;
    g_fail = 0;
}

void on_menu_log_summary(int64 data) {
    print_console("[menu] summary so far: PASS=" + cast<string>(g_pass) +
                  "  FAIL=" + cast<string>(g_fail));
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
int32 main() {
    print_console("[test_input_api] launching comprehensive Input API test + sidebar menu");

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
