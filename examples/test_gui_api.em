// =============================================================================
// GUI API surface demo — recreates the full host `test_element_group` UI
// (modular_ui.cpp lines 318-660) using the script-side sidebar_section_t
// surface, so we can exercise every widget builder + verify visual parity
// with the host's reference panel.
//
// What this exercises:
//   - create_sidebar_section + radio behavior (auto-deselect siblings)
//   - 23 widget builders on sidebar_section_t (label, button, checkbox,
//     slider, slider_icon, value_input, options, multi_options, dropdown,
//     multi_dropdown, list, inline_button, inline_text_input, tabs,
//     keybind, progress_bar, spinner, range_slider, table, text_input,
//     text_editor, colorpicker, plus separators)
//   - button.attach_to(button) for grouped rows
//   - menu_t with multiple items + separator + attach_to_button
//   - on_change callbacks via cast<int64>
//   - color() construction for colorpicker
//   - show_toast(toast_kind::*, ...) from button callbacks
//   - keybind.bind with keybind_mode enum
//
// Visibility is gated by the "demo" sidebar button automatically — clicking
// any other section (Test / Scripting) deselects this one and hides the
// panel via HOOK_SHOULD_RENDER. The element_group itself follows main_frame
// + sidebar geometry via the host's perception_main_relayout_hook.
// =============================================================================

sidebar_section_t g_sec;
menu_t            g_reset_menu;

// Keybind globals + last-active state for the polling routine.
keybind_t g_kb_aim;
keybind_t g_kb_esp;
keybind_t g_kb_panic;
bool g_aim_was_active   = false;
bool g_esp_was_active   = false;
bool g_panic_was_active = false;
int64 g_kb_routine = 0;

// Per-tab demo widgets — created up-front, visibility toggled by the tabs
// widget's on_change callback. Globals so the callback can reach them.
tabs_t       g_view_tabs;
label_t      g_t0_label; slider_t   g_t0_slider;
label_t      g_t1_label; checkbox_t g_t1_check;
label_t      g_t2_label; slider_t   g_t2_slider;
label_t      g_t3_label;

void on_apply(int64 _)  { print_console("[demo] Apply clicked"); }
void on_cancel(int64 _) { print_console("[demo] Cancel clicked"); }

void on_left_a(int64 _) { print_console("[demo] Left A clicked"); }
void on_left_b(int64 _) { print_console("[demo] Left B clicked"); }
void on_ctr_a(int64 _)  { print_console("[demo] Ctr A clicked"); }
void on_ctr_b(int64 _)  { print_console("[demo] Ctr B clicked"); }
void on_ctr_c(int64 _)  { print_console("[demo] Ctr C clicked"); }
void on_rt_a(int64 _)   { print_console("[demo] Rt A clicked"); }
void on_rt_b(int64 _)   { print_console("[demo] Rt B clicked"); }
void on_rt_c(int64 _)   { print_console("[demo] Rt C clicked"); }

// Value-changed callbacks: each receives the widget handle so we can read
// the new value back. Casting widget→typed handle is just the same int64.
// Each callback prints a "fired:" marker FIRST so you can tell whether
// it ran at all, separately from whether the .get() readback works.
void on_notif(int64 self)      { print_console("[fired] notif");      checkbox_t cb = cast<checkbox_t>(self); print_console("  Notifications -> "  + cast<string>(cb.get())); }
void on_dark_mode(int64 self)  { print_console("[fired] dark");       checkbox_t cb = cast<checkbox_t>(self); print_console("  Dark mode -> "      + cast<string>(cb.get())); }
void on_syntax(int64 self)     { print_console("[fired] syntax");     checkbox_t cb = cast<checkbox_t>(self); print_console("  Syntax hi -> "      + cast<string>(cb.get())); }
void on_verbose(int64 self)    { print_console("[fired] verbose");    checkbox_t cb = cast<checkbox_t>(self); print_console("  Verbose log -> "    + cast<string>(cb.get())); }

void on_volume(int64 self)     { print_console("[fired] volume");     slider_t sl = cast<slider_t>(self); print_console("  Volume -> "      + cast<string>(sl.get())); }
void on_brightness(int64 self) { print_console("[fired] brightness"); slider_t sl = cast<slider_t>(self); print_console("  Brightness -> "  + cast<string>(sl.get())); }
void on_threads(int64 self)    { print_console("[fired] threads");    slider_t sl = cast<slider_t>(self); print_console("  Threads -> "     + cast<string>(sl.get())); }
void on_gamma(int64 self)      { print_console("[fired] gamma");      slider_t sl = cast<slider_t>(self); print_console("  Gamma -> "       + cast<string>(sl.get())); }
void on_bias(int64 self)       { print_console("[fired] bias");       slider_t sl = cast<slider_t>(self); print_console("  Bias -> "        + cast<string>(sl.get())); }
void on_fov(int64 self)        { print_console("[fired] fov");        slider_t sl = cast<slider_t>(self); print_console("  FOV -> "         + cast<string>(sl.get())); }
void on_fps(int64 self)        { print_console("[fired] fps");        slider_t sl = cast<slider_t>(self); print_console("  FPS cap -> "     + cast<string>(sl.get())); }

void on_port(int64 self)       { print_console("[fired] port");       value_input_t vi = cast<value_input_t>(self); print_console("  Port -> "    + cast<string>(vi.get())); }
void on_timeout(int64 self)    { print_console("[fired] timeout");    value_input_t vi = cast<value_input_t>(self); print_console("  Timeout -> " + cast<string>(vi.get())); }

void on_eye(int64 self)        { print_console("[fired] eye-slider");    slider_icon_t si = cast<slider_icon_t>(self); print_console("  eye -> "    + cast<string>(si.get())); }
void on_folder(int64 self)     { print_console("[fired] folder-slider"); slider_icon_t si = cast<slider_icon_t>(self); print_console("  folder -> " + cast<string>(si.get())); }

void on_appearance(int64 self) { print_console("[fired] appearance"); options_t op = cast<options_t>(self); print_console("  Appearance idx -> " + cast<string>(op.get())); }
void on_scrollbars(int64 self) { print_console("[fired] scrollbars"); options_t op = cast<options_t>(self); print_console("  Scroll bars idx -> " + cast<string>(op.get())); }

void on_features(int64 self)   { print_console("[fired] features");   multi_options_t mo = cast<multi_options_t>(self); print_console("  features mask -> " + cast<string>(mo.get_mask())); }

void on_devices(int64 self)    { print_console("[fired] devices");    list_t l = cast<list_t>(self); print_console("  Devices sel -> " + cast<string>(l.get_selected())); }
void on_scripts(int64 self)    { print_console("[fired] scripts");    list_t l = cast<list_t>(self); print_console("  Scripts sel -> " + cast<string>(l.get_selected())); }

void on_highlight(int64 self)  { print_console("[fired] highlight");  dropdown_t dd = cast<dropdown_t>(self); print_console("  Highlight idx -> " + cast<string>(dd.get())); }
void on_iconsize(int64 self)   { print_console("[fired] iconsize");   dropdown_t dd = cast<dropdown_t>(self); print_console("  IconSize idx -> "  + cast<string>(dd.get())); }

void on_log_tags(int64 self)   { print_console("[fired] log_tags");   multi_dropdown_t md = cast<multi_dropdown_t>(self); print_console("  Log tags mask -> " + cast<string>(md.get_mask())); }

void on_username(int64 self)   { print_console("[fired] username");   text_input_t ti = cast<text_input_t>(self); print_console("  Username -> " + ti.get()); }
void on_snippet(int64 self)    { print_console("[fired] snippet");    text_editor_t te = cast<text_editor_t>(self); print_console("  Snippet length -> " + cast<string>(te.get().length())); }

void on_save(int64 _)          { print_console("[fired] Save clicked"); }
void on_load(int64 _)          { print_console("[fired] Load clicked"); }

// Keybind config-change callbacks (fire when binding added / removed,
// mode changed, etc.). Distinct from the "key currently held" check —
// that's polled from the routine below.
void on_kb_aim_changed(int64 self) {
    print_console("[fired] aim keybind config changed");
    keybind_t kb = cast<keybind_t>(self);
    print_console("  bindings -> " + cast<string>(kb.binding_count()));
}
void on_kb_esp_changed(int64 self) {
    print_console("[fired] esp keybind config changed");
    keybind_t kb = cast<keybind_t>(self);
    print_console("  bindings -> " + cast<string>(kb.binding_count()));
}
void on_kb_panic_changed(int64 self) {
    print_console("[fired] panic keybind config changed");
    keybind_t kb = cast<keybind_t>(self);
    print_console("  bindings -> " + cast<string>(kb.binding_count()));
}

// Routine: poll each keybind's is_active() every tick, log press / release
// transitions. Modular_ui doesn't fire a callback when the bound HARDWARE
// key activates — only when the binding/mode CONFIG changes — so polling
// is the canonical way to observe key activation in scripts.
void kb_poll_routine(int64 _data) {
    bool aim_now = g_kb_aim.is_active();
    if (aim_now != g_aim_was_active) {
        print_console(aim_now ? "[kb] Aimbot ACTIVE" : "[kb] Aimbot inactive");
        g_aim_was_active = aim_now;
    }
    bool esp_now = g_kb_esp.is_active();
    if (esp_now != g_esp_was_active) {
        print_console(esp_now ? "[kb] ESP ACTIVE" : "[kb] ESP inactive");
        g_esp_was_active = esp_now;
    }
    bool panic_now = g_kb_panic.is_active();
    if (panic_now != g_panic_was_active) {
        print_console(panic_now ? "[kb] Panic ACTIVE" : "[kb] Panic inactive");
        g_panic_was_active = panic_now;
    }
}
void on_view_tabs(int64 self) {
    tabs_t t = cast<tabs_t>(self);
    int64 sel = t.get();
    print_console("[demo] view tab idx -> " + cast<string>(sel));

    // Mirror host behaviour: each tab owns a fixed set of widgets, only
    // the selected tab's widgets are active.
    g_t0_label.set_active (sel == 0);
    g_t0_slider.set_active(sel == 0);
    g_t1_label.set_active (sel == 1);
    g_t1_check.set_active (sel == 1);
    g_t2_label.set_active (sel == 2);
    g_t2_slider.set_active(sel == 2);
    g_t3_label.set_active (sel == 3);
}
void on_freq(int64 self) {
    print_console("[fired] freq");
    range_slider_t rs = cast<range_slider_t>(self);
    print_console("  Frequency lo/hi -> " +
        cast<string>(rs.get_lo()) + " / " + cast<string>(rs.get_hi()));
}
void on_price(int64 self) {
    print_console("[fired] price");
    range_slider_t rs = cast<range_slider_t>(self);
    print_console("  Price lo/hi -> " +
        cast<string>(rs.get_lo()) + " / " + cast<string>(rs.get_hi()));
}

// Color callbacks share a helper.
void cp_log(string label, int64 self) {
    colorpicker_t cp = cast<colorpicker_t>(self);
    color c = cp.get();
    print_console("  " + label + " rgba -> " +
        cast<string>(c.r()) + ", " + cast<string>(c.g()) + ", " +
        cast<string>(c.b()) + ", " + cast<string>(c.a()));
}
void on_accent(int64 self)       { print_console("[fired] accent");    cp_log("Accent",    self); }
void on_theme_cp(int64 self)     { print_console("[fired] theme cp");  cp_log("Theme",     self); }
void on_primary_cp(int64 self)   { print_console("[fired] primary");   cp_log("Primary",   self); }
void on_secondary_cp(int64 self) { print_console("[fired] secondary"); cp_log("Secondary", self); }
void on_kw_cp(int64 self)        { print_console("[fired] keywords");  cp_log("Keywords",  self); }
void on_str_cp(int64 self)       { print_console("[fired] strings");   cp_log("Strings",   self); }

void on_toast_info(int64 _) {
    show_toast(toast_kind::info, "Heads up",
        "This is an informational notification.");
}
void on_toast_success(int64 _) {
    show_toast(toast_kind::success, "Saved",
        "Configuration saved successfully.");
}
void on_toast_warning(int64 _) {
    show_toast(toast_kind::warning, "Careful",
        "Some scripts failed to verify.");
}
void on_toast_error(int64 _) {
    show_toast(toast_kind::error, "Failure",
        "Could not reach the server. Retry or check your connection.");
}

void on_menu_copy(int64 _)   { print_console("[demo] Copy settings"); }
void on_menu_paste(int64 _)  { print_console("[demo] Paste settings"); }
void on_menu_export(int64 _) { print_console("[demo] Export to file"); }
void on_menu_import(int64 _) { print_console("[demo] Import from file"); }
void on_menu_reset(int64 _)  { print_console("[demo] Reset all"); }

void build_ui() {
    g_sec = create_sidebar_section("demo", "");

    // --- intro + button row ---
    g_sec.create_label(
        "These preferences apply to the current profile. Changes take effect immediately, no restart required.",
        ui_align::left);
    g_sec.create_separator();

    button_t apply  = g_sec.create_button("Apply",  ui_align::right);
    button_t cancel = g_sec.create_button("Cancel", ui_align::right);
    cancel.attach_to(apply);
    apply.set_tooltip("Apply the current changes");
    cancel.set_tooltip("Discard changes");
    apply.on_change(cast<int64>(on_apply));
    cancel.on_change(cast<int64>(on_cancel));

    // Left-grouped row.
    button_t L1 = g_sec.create_button("Left A", ui_align::left);
    button_t L2 = g_sec.create_button("Left B", ui_align::left);
    L2.attach_to(L1);
    L1.on_change(cast<int64>(on_left_a));
    L2.on_change(cast<int64>(on_left_b));

    // Centered row.
    button_t C1 = g_sec.create_button("Ctr A", ui_align::center);
    button_t C2 = g_sec.create_button("Ctr B", ui_align::center);
    button_t C3 = g_sec.create_button("Ctr C", ui_align::center);
    C2.attach_to(C1);
    C3.attach_to(C1);
    C1.on_change(cast<int64>(on_ctr_a));
    C2.on_change(cast<int64>(on_ctr_b));
    C3.on_change(cast<int64>(on_ctr_c));

    // Right-grouped row.
    button_t R1 = g_sec.create_button("Rt A", ui_align::right);
    button_t R2 = g_sec.create_button("Rt B", ui_align::right);
    button_t R3 = g_sec.create_button("Rt C", ui_align::right);
    R2.attach_to(R1);
    R3.attach_to(R1);
    R1.on_change(cast<int64>(on_rt_a));
    R2.on_change(cast<int64>(on_rt_b));
    R3.on_change(cast<int64>(on_rt_c));

    // --- reset button with attached context menu ---
    button_t reset_btn = g_sec.create_button("Reset", ui_align::center);
    reset_btn.set_tooltip("Restore all settings to defaults");
    g_reset_menu = create_menu();
    g_reset_menu.add_item("Copy settings",     cast<int64>(on_menu_copy),   "Ctrl+C", "");
    g_reset_menu.add_item("Paste settings",    cast<int64>(on_menu_paste),  "Ctrl+V", "");
    g_reset_menu.add_separator();
    g_reset_menu.add_item("Export to file...", cast<int64>(on_menu_export), "", "");
    g_reset_menu.add_item("Import from file...",cast<int64>(on_menu_import),"", "");
    g_reset_menu.add_separator();
    g_reset_menu.add_item("Reset all",         cast<int64>(on_menu_reset),  "", "");
    g_reset_menu.attach_to_button(reset_btn);

    // --- checkboxes ---
    g_sec.create_separator();
    checkbox_t cb_notif = g_sec.create_checkbox("Notifications", true);
    checkbox_t cb_dark  = g_sec.create_checkbox("Dark mode",     true);
    cb_notif.on_change(cast<int64>(on_notif));
    cb_dark.on_change (cast<int64>(on_dark_mode));

    // --- sliders ---
    g_sec.create_separator();
    slider_t vol = g_sec.create_slider("Volume",     0.6,    0.0,   1.0,  0.0);
    vol.set_tooltip("System output volume");
    vol.on_change(cast<int64>(on_volume));
    slider_t bri = g_sec.create_slider("Brightness", 0.8,   0.0,    1.0,  0.0);
    bri.on_change(cast<int64>(on_brightness));
    slider_t thr = g_sec.create_slider("Threads",    4.0,   1.0,   16.0,  1.0);
    thr.on_change(cast<int64>(on_threads));
    slider_t gamma = g_sec.create_slider("Gamma", 1.00,  0.50, 2.50, 0.01);
    gamma.on_change(cast<int64>(on_gamma));
    slider_t bias  = g_sec.create_slider("Bias", -0.250, -1.0, 1.0,  0.001);
    bias.on_change(cast<int64>(on_bias));

    // --- value inputs ---
    g_sec.create_separator();
    value_input_t port = g_sec.create_value_input("Port",    8080.0, 1.0, 65535.0, 1.0);
    value_input_t to_  = g_sec.create_value_input("Timeout",    2.50, 0.0,    60.0, 0.25);
    port.on_change(cast<int64>(on_port));
    to_.on_change (cast<int64>(on_timeout));

    // --- slider icons (UTF-8 codicon byte sequences match the host's
    //     CODICON_* defines from modular_ui_config.h) ---
    g_sec.create_separator();
    string codicon_eye    = "\xEE\xA9\xB0";   // CODICON_EYE
    string codicon_folder = "\xEE\xAB\xB7";   // CODICON_FOLDER
    slider_icon_t si_eye = g_sec.create_slider_icon(codicon_eye, 0.75, 0.0, 1.0, 0.0);
    si_eye.on_change(cast<int64>(on_eye));
    slider_icon_t si_fld = g_sec.create_slider_icon(codicon_folder, 0.35, 0.0, 1.0, 0.0);
    si_fld.on_change(cast<int64>(on_folder));

    // --- options ---
    g_sec.create_separator();
    array<string> appearance;
    appearance.push("Light"); appearance.push("Dark"); appearance.push("Auto");
    options_t app = g_sec.create_options("Appearance", appearance, 1);
    app.on_change(cast<int64>(on_appearance));

    array<string> scroll_items;
    scroll_items.push("Auto");
    scroll_items.push("When scrolling");
    scroll_items.push("Always");
    options_t sb_opt = g_sec.create_options("Scroll bars", scroll_items, 0);
    sb_opt.on_change(cast<int64>(on_scrollbars));

    // --- multi options ---
    g_sec.create_separator();
    array<string> features;
    features.push("Autosave");
    features.push("Spell check");
    features.push("Auto-complete");
    features.push("Line numbers");
    // 0b1101 = bits 0,2,3 set (Autosave, Auto-complete, Line numbers).
    multi_options_t mo = g_sec.create_multi_options("Editor features", features, 13);
    mo.on_change(cast<int64>(on_features));

    // --- lists (info1 / info2 parallel arrays) ---
    g_sec.create_separator();
    array<string> sys_n; array<string> sys_v;
    sys_n.push("Wi-Fi");      sys_v.push("Connected");
    sys_n.push("Bluetooth");  sys_v.push("On");
    sys_n.push("Battery");    sys_v.push("87%");
    sys_n.push("Storage");    sys_v.push("312 GB free");
    sys_n.push("Updates");    sys_v.push("Up to date");
    g_sec.create_list("System", sys_n, sys_v, false, -1, 0, false);

    array<string> dev_n; array<string> dev_v;
    dev_n.push("AirPods Pro");    dev_v.push("Connected");
    dev_n.push("Magic Mouse");    dev_v.push("Paired");
    dev_n.push("Studio Display"); dev_v.push("Connected");
    dev_n.push("iPad Air");       dev_v.push("Idle");
    list_t devices = g_sec.create_list("Devices", dev_n, dev_v, true, -1, 0, false);
    devices.on_change(cast<int64>(on_devices));

    array<string> sn; array<string> sv;
    sn.push("aimbot.lua");        sv.push("idle");
    sn.push("esp.lua");           sv.push("running");
    sn.push("triggerbot.lua");    sv.push("idle");
    sn.push("bunnyhop.lua");      sv.push("running");
    sn.push("radar.lua");         sv.push("idle");
    sn.push("spectator_list.lua");sv.push("idle");
    sn.push("anti_aim.lua");      sv.push("running");
    sn.push("chams.lua");         sv.push("idle");
    sn.push("autoaccept.lua");    sv.push("running");
    sn.push("clantag.lua");       sv.push("idle");
    sn.push("skinchanger.lua");   sv.push("idle");
    sn.push("inventory.lua");     sv.push("idle");
    sn.push("autobuy.lua");       sv.push("running");
    sn.push("noflash.lua");       sv.push("idle");
    sn.push("glow.lua");          sv.push("idle");
    sn.push("crosshair.lua");     sv.push("running");
    sn.push("viewmodel.lua");     sv.push("idle");
    sn.push("legit_aa.lua");      sv.push("idle");
    list_t scripts_list = g_sec.create_list("Scripts", sn, sv, true, -1, 6, true);
    scripts_list.on_change(cast<int64>(on_scripts));

    // --- dropdowns ---
    g_sec.create_separator();
    array<string> theme_items;
    theme_items.push("Graphite"); theme_items.push("Blue");
    theme_items.push("Purple");   theme_items.push("Pink");
    theme_items.push("Red");      theme_items.push("Orange");
    theme_items.push("Yellow");   theme_items.push("Green");
    dropdown_t hl = g_sec.create_dropdown("Highlight colour", theme_items, 0);
    hl.on_change(cast<int64>(on_highlight));

    array<string> size_items;
    size_items.push("Small"); size_items.push("Medium"); size_items.push("Large");
    dropdown_t sz_dd = g_sec.create_dropdown("Sidebar icon size", size_items, 1);
    sz_dd.on_change(cast<int64>(on_iconsize));

    array<string> tag_items;
    tag_items.push("Critical"); tag_items.push("Warning"); tag_items.push("Info");
    tag_items.push("Debug");    tag_items.push("Trace");   tag_items.push("Verbose");
    // 0b000111 = bits 0,1,2 set (Critical, Warning, Info).
    multi_dropdown_t log_md = g_sec.create_multi_dropdown("Log tags", tag_items, 7);
    log_md.on_change(cast<int64>(on_log_tags));

    // --- text inputs ---
    g_sec.create_separator();
    text_input_t un = g_sec.create_text_input("Username", "deadlock", 1);
    un.on_change(cast<int64>(on_username));
    g_sec.create_text_input("Bio",
        "Hello world. Feel free to type more and the row will grow.", 4);
    g_sec.create_text_input("Numeric test", "34 + 34", 1);

    // --- text editor (no host-side lexer wired through enma yet — pass "") ---
    g_sec.create_separator();
    string snippet =
        "#include <stdio.h>\n\n" +
        "// Fibonacci example\n" +
        "int fib(int n) {\n" +
        "    if (n <= 1) return n;\n" +
        "    return fib(n - 1) + fib(n - 2);\n" +
        "}\n\n" +
        "int main() {\n" +
        "    for (int i = 0; i < 10; ++i) {\n" +
        "        printf(\"fib(%d) = %d\\n\", i, fib(i));\n" +
        "    }\n" +
        "    return 0;\n" +
        "}\n";
    text_editor_t snippet_te = g_sec.create_text_editor("Snippet", snippet, 10, "");
    snippet_te.on_change(cast<int64>(on_snippet));

    // --- inline buttons ---
    g_sec.create_separator();
    inline_button_t save_btn = g_sec.create_inline_button("Save", 0.0, "");
    inline_button_t load_btn = g_sec.create_inline_button("Load", 0.0, "\xEE\xAB\xB7");   // CODICON_FOLDER
    save_btn.on_change(cast<int64>(on_save));
    load_btn.on_change(cast<int64>(on_load));

    // --- keybinds ---
    g_sec.create_separator();
    g_kb_aim = g_sec.create_keybind("Aimbot");
    g_kb_aim.bind(0x01, false, false, false, keybind_mode::on);       // VK_LBUTTON
    g_kb_aim.on_change(cast<int64>(on_kb_aim_changed));

    g_kb_esp = g_sec.create_keybind("ESP toggle");
    g_kb_esp.bind(0x45, false, false, false, keybind_mode::toggle);   // 'E'
    g_kb_esp.on_change(cast<int64>(on_kb_esp_changed));

    g_kb_panic = g_sec.create_keybind("Panic");
    g_kb_panic.on_change(cast<int64>(on_kb_panic_changed));

    // --- inline tabs widget ---
    g_sec.create_separator();
    array<string> tab_items;
    tab_items.push("Overview"); tab_items.push("Logs");
    tab_items.push("Performance"); tab_items.push("About");
    g_view_tabs = g_sec.create_tabs(tab_items, 0);
    g_view_tabs.on_change(cast<int64>(on_view_tabs));

    // Per-tab content (matches host test_element_group). All 7 widgets are
    // created at build time; the tabs callback toggles set_active so only
    // the selected tab's widgets render.
    g_t0_label  = g_sec.create_label("Overview: top-line system status for the session.", ui_align::left);
    g_t0_slider = g_sec.create_slider("FOV",     90.0,  60.0, 120.0, 1.0);
    g_t0_slider.on_change(cast<int64>(on_fov));

    g_t1_label  = g_sec.create_label("Logs: the verbosity knob controls rolling log output.", ui_align::left);
    g_t1_check  = g_sec.create_checkbox("Verbose logging", false);
    g_t1_check.on_change(cast<int64>(on_verbose));

    g_t2_label  = g_sec.create_label("Performance: profiling and frame pacing knobs.", ui_align::left);
    g_t2_slider = g_sec.create_slider("FPS cap", 144.0, 30.0, 240.0, 1.0);
    g_t2_slider.on_change(cast<int64>(on_fps));

    g_t3_label  = g_sec.create_label("About: build 2026.04, modular UI demo.", ui_align::left);

    // Tab 0 visible by default — hide the rest.
    g_t1_label.set_active(false);
    g_t1_check.set_active(false);
    g_t2_label.set_active(false);
    g_t2_slider.set_active(false);
    g_t3_label.set_active(false);

    // --- progress / spinner ---
    g_sec.create_separator();
    progress_bar_t pd = g_sec.create_progress_bar("Download", 0.35, 0.0, 1.0, true);
    progress_bar_t pi = g_sec.create_progress_bar("Install",  0.80, 0.0, 1.0, true);
    g_sec.create_spinner("Loading");

    // --- range sliders ---
    g_sec.create_separator();
    range_slider_t freq = g_sec.create_range_slider("Frequency", 20.0, 20000.0, 200.0, 8000.0, 1.0);
    freq.on_change(cast<int64>(on_freq));
    range_slider_t price = g_sec.create_range_slider("Price", 0.0, 500.0, 50.0, 250.0, 1.0);
    price.on_change(cast<int64>(on_price));

    // --- table ---
    g_sec.create_separator();
    array<string> col_names;  col_names.push("User"); col_names.push("IP"); col_names.push("Latency");
    array<float64> col_widths; col_widths.push(0.35); col_widths.push(0.40); col_widths.push(0.25);
    table_t tbl = g_sec.create_table("Connected clients", col_names, col_widths, 5);

    array<string> r1; r1.push("deadlock"); r1.push("192.168.1.10"); r1.push("12 ms");
    array<string> r2; r2.push("nullref");  r2.push("192.168.1.22"); r2.push("34 ms");
    array<string> r3; r3.push("segfault"); r3.push("10.0.0.4");     r3.push("8 ms");
    array<string> r4; r4.push("stackovf"); r4.push("172.16.0.99");  r4.push("120 ms");
    array<string> r5; r5.push("heapfree"); r5.push("192.168.1.55"); r5.push("47 ms");
    array<string> r6; r6.push("raceyman"); r6.push("10.0.0.7");     r6.push("71 ms");
    array<string> r7; r7.push("dangling"); r7.push("192.168.1.2");  r7.push("22 ms");
    array<string> r8; r8.push("uninit");   r8.push("10.0.0.15");    r8.push("95 ms");
    tbl.add_row(r1); tbl.add_row(r2); tbl.add_row(r3); tbl.add_row(r4);
    tbl.add_row(r5); tbl.add_row(r6); tbl.add_row(r7); tbl.add_row(r8);

    // --- toast trigger row ---
    g_sec.create_separator();
    inline_button_t b_info = g_sec.create_inline_button("Info",    0.0, "\xEE\xAB\x9A"); // CODICON_INFO
    inline_button_t b_ok   = g_sec.create_inline_button("Success", 0.0, "\xEE\xAA\xB2"); // CODICON_CHECK
    inline_button_t b_warn = g_sec.create_inline_button("Warning", 0.0, "\xEE\xAB\x9C"); // CODICON_WARNING
    inline_button_t b_err  = g_sec.create_inline_button("Error",   0.0, "\xEE\xA9\xB6"); // CODICON_CLOSE
    b_info.on_change(cast<int64>(on_toast_info));
    b_ok.on_change  (cast<int64>(on_toast_success));
    b_warn.on_change(cast<int64>(on_toast_warning));
    b_err.on_change (cast<int64>(on_toast_error));

    // --- colorpickers ---
    g_sec.create_separator();
    colorpicker_t accent = g_sec.create_colorpicker("Accent color", color(180, 180, 180, 255));
    accent.on_change(cast<int64>(on_accent));

    colorpicker_t theme_cp = g_sec.create_colorpicker("Theme",     color(120, 120, 120, 255));
    colorpicker_t primary  = g_sec.create_colorpicker("Primary",   color( 80,  80,  80, 255));
    colorpicker_t secondary= g_sec.create_colorpicker("Secondary", color(200, 200, 200, 255));
    primary.attach_to(theme_cp);
    secondary.attach_to(theme_cp);
    theme_cp.on_change (cast<int64>(on_theme_cp));
    primary.on_change  (cast<int64>(on_primary_cp));
    secondary.on_change(cast<int64>(on_secondary_cp));

    checkbox_t syntax = g_sec.create_checkbox("Syntax highlighting", true);
    syntax.on_change(cast<int64>(on_syntax));
    colorpicker_t kw  = g_sec.create_colorpicker("Keywords", color(235,  40,  40, 255));
    colorpicker_t str = g_sec.create_colorpicker("Strings",  color( 40,  60, 235, 255));
    kw.on_change (cast<int64>(on_kw_cp));
    str.on_change(cast<int64>(on_str_cp));
    // Note: kw / str are attached to a checkbox, not another colorpicker —
    // the host's __element_colorpicker_data_t.attach_to has a checkbox
    // overload. Script side only exposes attach_to(colorpicker_t), so for
    // now they sit at top level. (Future: add attach_to(checkbox_t).)
}

int32 main() {
    print_console("[test_gui_api] building demo UI in sidebar section");
    build_ui();

    // Spin up a routine that polls keybind activation state and logs
    // press / release transitions. Cheap — three is_active() reads per tick.
    g_kb_routine = register_routine(cast<int64>(kb_poll_routine), 0);
    if (g_kb_routine == 0) {
        print_console("[test_gui_api] failed to register kb_poll_routine");
    }

    return 1;   // keep loaded so the section stays interactive
}
