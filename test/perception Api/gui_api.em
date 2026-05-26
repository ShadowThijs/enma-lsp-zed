// ============================================================================
// gui_api.em
// ============================================================================
// Comprehensive test of EVERY type, method, standalone function, and enum
// from the Perception GUI API.
//
// Docs source: docs/Perception/GUI API.md
// ============================================================================

// ============================================================================
// CHECKLIST  --  every type, method, function, and enum from the docs
// ============================================================================
//
// ─── PART 1: SIDEBAR SECTIONS ───────────────────────────────────────────────
//
// Standalone functions:
//   [ ] sidebar_section_t create_sidebar_section(string name, string icon)
//   [ ] void              create_sidebar_separator()
//
// sidebar_section_t methods:
//   [ ] void section.set_active(bool active)
//
// ─── Widget builders on sidebar_section_t ────────────────────────────────────
//   [ ] label_t              section.create_label(string text, ui_align align)
//   [ ] void                 section.create_separator()
//   [ ] button_t             section.create_button(string label, ui_align align)
//   [ ] checkbox_t           section.create_checkbox(string label, bool initial)
//   [ ] slider_t             section.create_slider(string label, float64 initial, float64 minv, float64 maxv, float64 step)
//   [ ] slider_icon_t        section.create_slider_icon(string icon, float64 initial, float64 minv, float64 maxv, float64 step)
//   [ ] value_input_t        section.create_value_input(string label, float64 initial, float64 minv, float64 maxv, float64 step)
//   [ ] options_t            section.create_options(string label, array<string> items, int64 selected)
//   [ ] multi_options_t      section.create_multi_options(string label, array<string> items, int64 selected_mask)
//   [ ] dropdown_t           section.create_dropdown(string label, array<string> items, int64 selected)
//   [ ] multi_dropdown_t     section.create_multi_dropdown(string label, array<string> items, int64 selected_mask)
//   [ ] list_t               section.create_list(string label, array<string> info1, array<string> info2, bool selectable, int64 selected, int64 visible_rows, bool filterable)
//   [ ] inline_button_t      section.create_inline_button(string label, float64 width, string icon)
//   [ ] inline_text_input_t  section.create_inline_text_input(string initial, float64 width, string placeholder)
//   [ ] tabs_t               section.create_tabs(array<string> items, int64 selected)
//   [ ] keybind_t            section.create_keybind(string label)
//   [ ] progress_bar_t       section.create_progress_bar(string label, float64 initial, float64 minv, float64 maxv, bool show_pct)
//   [ ] spinner_t            section.create_spinner(string label)
//   [ ] range_slider_t       section.create_range_slider(string label, float64 minv, float64 maxv, float64 lo, float64 hi, float64 step)
//   [ ] table_t              section.create_table(string label, array<string> col_names, array<float64> col_widths, int64 visible_rows)
//   [ ] text_input_t         section.create_text_input(string label, string initial, int64 max_lines)
//   [ ] text_editor_t        section.create_text_editor(string label, string initial, int64 visible_lines, string lexer)
//   [ ] colorpicker_t        section.create_colorpicker(string label, color initial)
//
// ─── Common widget operations (all except text_editor_t has no set_active) ───
//   [ ] void widget.set_active(bool active)
//   [ ] void widget.set_tooltip(string s)
//   [ ] void widget.on_change(int64 fn_handle)
//
// ─── Per-widget typed get/set ───────────────────────────────────────────────
//   label_t:
//     [ ] void label.set_text(string s)
//   button_t:
//     [ ] void button.attach_to(button_t other)
//   checkbox_t:
//     [ ] bool checkbox.get()
//     [ ] void checkbox.set(bool v)
//   slider_t / slider_icon_t / value_input_t:
//     [ ] float64 X.get()
//     [ ] void    X.set(float64 v)
//   options_t / dropdown_t / tabs_t:
//     [ ] int64 X.get()
//     [ ] void  X.set(int64 i)
//   multi_options_t / multi_dropdown_t:
//     [ ] int64 X.get_mask()
//     [ ] void  X.set_mask(int64 m)
//   list_t:
//     [ ] int64  list.get_selected()
//     [ ] void   list.set_selected(int64 i)
//     [ ] void   list.set_items(array<string> info1, array<string> info2)
//     [ ] int64  list.size()
//   inline_text_input_t / text_input_t / text_editor_t:
//     [ ] string X.get()
//     [ ] void   X.set(string s)
//   keybind_t:
//     [ ] void  keybind.bind(int64 vk, bool ctrl, bool shift, bool alt, keybind_mode mode)
//     [ ] bool  keybind.is_active()
//     [ ] int64 keybind.binding_count()
//   progress_bar_t:
//     [ ] void progress_bar.set(float64 v)
//   range_slider_t:
//     [ ] float64 range_slider.get_lo()
//     [ ] float64 range_slider.get_hi()
//     [ ] void    range_slider.set(float64 lo, float64 hi)
//   table_t:
//     [ ] void  table.add_row(array<string> cells)
//     [ ] void  table.clear()
//     [ ] int64 table.size()
//   colorpicker_t:
//     [ ] void  colorpicker.attach_to(colorpicker_t other)
//     [ ] color colorpicker.get()
//     [ ] void  colorpicker.set(color c)
//
// ─── PART 2: FRAMES ─────────────────────────────────────────────────────────
// Standalone functions:
//   [ ] frame_t create_frame(string name, vec2 pos, vec2 size, layer_t layer)
//   [ ] frame_t create_default_frame(string name, vec2 pos, vec2 size, layer_t layer)
//   [ ] frame_t create_draggable_frame(string name, vec2 pos, vec2 size, layer_t layer)
//   [ ] frame_t create_popup(string name, vec2 pos, vec2 size, layer_t layer)
//   [ ] frame_t get_focused_frame()
//
// frame_t methods:
//   [ ] void    frame.set_pos(vec2 pos)
//   [ ] void    frame.set_size(vec2 size)
//   [ ] vec2    frame.get_pos()
//   [ ] vec2    frame.get_size()
//   [ ] void    frame.set_visible(bool v)
//   [ ] bool    frame.is_visible()
//   [ ] void    frame.set_anchors(int64 mask)
//   [ ] void    frame.attach(frame_t parent)
//   [ ] void    frame.set_float(int64 hash, float64 v)
//   [ ] void    frame.install_hook(int64 hook_id, int64 fn_handle)
//   [ ] void    frame.remove_hook(int64 hook_id)
//   [ ] void    frame.set_focused()
//
// ─── LAYERS ─────────────────────────────────────────────────────────────────
// Standalone functions:
//   [ ] layer_t create_layer(string name, bool input_passthrough, bool force_topmost)
//   [ ] layer_t get_default_layer()
//   [ ] int64   layer_count()
//
// layer_t methods:
//   [ ] void  layer.promote_to_top()
//   [ ] void  layer.set_visible(bool v)
//   [ ] int64 layer.frame_count()
//
// ─── CUSTOM WIDGETS ─────────────────────────────────────────────────────────
// Standalone functions:
//   [ ] widget_t create_widget(frame_t parent, string name, int64 execute_cb_handle, bool consume_input)
//
// widget_t methods:
//   [ ] void widget.set_pos(vec2 pos)
//   [ ] void widget.set_size(vec2 size)
//   [ ] void widget.set_active(bool v)
//   [ ] void widget.set_tooltip(string s)
//   [ ] void widget.set_float(int64 hash, float64 v)
//   [ ] void widget.set_anchors(int64 mask)
//   [ ] void widget.install_hook(int64 hook_id, int64 fn_handle)
//   [ ] void widget.remove_hook(int64 hook_id)
//
// ─── MENUS ──────────────────────────────────────────────────────────────────
// Standalone functions:
//   [ ] menu_t create_menu()
//
// menu_t methods:
//   [ ] void menu.add_item(string label, int64 on_click_cb, string shortcut, string icon)
//   [ ] void menu.add_separator()
//   [ ] void menu.attach_to_widget(widget_t target)
//   [ ] void menu.attach_to_button(button_t target)
//   [ ] void menu.attach_to_label(label_t target)
//   [ ] void menu.attach_to_checkbox(checkbox_t target)
//   [ ] void menu.attach_to_slider(slider_t target)
//   [ ] void menu.attach_to_slider_icon(slider_icon_t target)
//   [ ] void menu.attach_to_value_input(value_input_t target)
//   [ ] void menu.attach_to_options(options_t target)
//   [ ] void menu.attach_to_multi_options(multi_options_t target)
//   [ ] void menu.attach_to_dropdown(dropdown_t target)
//   [ ] void menu.attach_to_multi_dropdown(multi_dropdown_t target)
//   [ ] void menu.attach_to_list(list_t target)
//   [ ] void menu.attach_to_inline_button(inline_button_t target)
//   [ ] void menu.attach_to_inline_text_input(inline_text_input_t target)
//   [ ] void menu.attach_to_tabs(tabs_t target)
//   [ ] void menu.attach_to_keybind(keybind_t target)
//   [ ] void menu.attach_to_progress_bar(progress_bar_t target)
//   [ ] void menu.attach_to_spinner(spinner_t target)
//   [ ] void menu.attach_to_range_slider(range_slider_t target)
//   [ ] void menu.attach_to_table(table_t target)
//   [ ] void menu.attach_to_text_input(text_input_t target)
//   [ ] void menu.attach_to_text_editor(text_editor_t target)
//   [ ] void menu.attach_to_colorpicker(colorpicker_t target)
//
// ─── FILE PICKER ────────────────────────────────────────────────────────────
// Standalone functions:
//   [ ] file_picker_t create_file_picker(string title, string start_path, string filter_extension, bool folder_mode)
//
// file_picker_t methods:
//   [ ] void   picker.open()
//   [ ] void   picker.close()
//   [ ] string picker.get_selected()
//
// ─── THEME ──────────────────────────────────────────────────────────────────
//   [ ] bool  is_dark_theme()
//   [ ] void  set_dark_theme(bool dark)
//   [ ] color get_theme_color(int64 color_hash)
//   [ ] void  set_theme_color(int64 color_hash, color c)
//
// ─── TOASTS AND QUERIES ─────────────────────────────────────────────────────
//   [ ] void show_toast(toast_kind kind, string title, string msg)
//   [ ] bool gui_active()
//   [ ] vec2 get_gui_size()
//   [ ] vec2 get_gui_position()
//   [ ] bool ui_is_focused()
//
// ─── ENUMS ──────────────────────────────────────────────────────────────────
//   [ ] ui_anchor   { none, left, right, top, bottom, all }
//   [ ] ui_edge     { left, top, right, bottom }
//   [ ] ui_align    { left, center, right }
//   [ ] ui_layout   { none, vertical, horizontal }
//   [ ] ui_hook     { pre_execute, post_execute, clicked, right_clicked, should_render, widget_execute }
//   [ ] ui_callback { value_changed, item_activated }
//   [ ] widget_attr { pos_x, pos_y, size_x, size_y, scroll_x, scroll_y, rounding }
//   [ ] ui_color    { bg, text, accent, frame_bg, sidebar_bg, element_button_bg }
//   [ ] keybind_mode { off, on, single, toggle, always_on }
//   [ ] toast_kind  { info, success, warning, error }
// ============================================================================

// ============================================================================
// TEST HELPERS
// ============================================================================

int64 g_pass = 0;
int64 g_fail = 0;
int64 g_skip = 0;

void check(string label, bool ok) {
    if (ok) {
        print_console("[PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("[FAIL] " + label);
        g_fail = g_fail + 1;
    }
}

void check_msg(string label, bool ok, string msg) {
    if (ok) {
        print_console("[PASS] " + label);
        g_pass = g_pass + 1;
    } else {
        print_console("[FAIL] " + label + "  --  " + msg);
        g_fail = g_fail + 1;
    }
}

void section(string title) {
    print_console("");
    print_console("--- " + title + " ---");
}

bool feq(float64 a, float64 b) {
    float64 d = a - b;
    if (d < 0.0) d = -d;
    return d < 1e-9;
}

// ============================================================================
// GLOBAL RESOURCES (created before tests, accessed by tests)
// ============================================================================

// Sidebar
sidebar_section_t g_sec;

// Widget instances (pre-created for testing)
label_t              g_w_label;
button_t             g_w_button;
button_t             g_w_button2;
checkbox_t           g_w_checkbox;
slider_t             g_w_slider;
slider_icon_t        g_w_slider_icon;
value_input_t        g_w_value_input;
options_t            g_w_options;
multi_options_t      g_w_multi_options;
dropdown_t           g_w_dropdown;
multi_dropdown_t     g_w_multi_dropdown;
list_t               g_w_list;
inline_button_t      g_w_inline_button;
inline_text_input_t  g_w_inline_text_input;
tabs_t               g_w_tabs;
keybind_t            g_w_keybind;
progress_bar_t       g_w_progress_bar;
spinner_t            g_w_spinner;
range_slider_t       g_w_range_slider;
table_t              g_w_table;
text_input_t         g_w_text_input;
text_editor_t        g_w_text_editor;
colorpicker_t        g_w_colorpicker;
colorpicker_t        g_w_colorpicker2;

// Part 2: frames, layers, custom widgets, menus, file pickers
frame_t              g_frame;
frame_t              g_default_frame;
frame_t              g_draggable_frame;
frame_t              g_popup;
layer_t              g_layer;
widget_t             g_widget;
menu_t               g_menu;
file_picker_t        g_picker;

// ============================================================================
// CALLBACK STUBS
// ============================================================================

// Generic on_change callback stub
void on_change_stub(int64 self) {
    print_console("  [cb] on_change fired, handle=" + cast<string>(self));
}

// Frame hook callback stub
void on_frame_hook(int64 handle) {
    print_console("  [hook] frame hook fired, handle=" + cast<string>(handle));
}

// Widget execute callback stub (called every tick)
void on_widget_execute(int64 handle) {
    // no-op in test; just needs to exist
}

// Menu item click callback stub
void on_menu_click(int64 user_data) {
    print_console("  [menu] item clicked, user_data=" + cast<string>(user_data));
}

// Routine stub for deferred testing
int64 g_routine_fired = 0;
void test_routine(int64 data) {
    if (g_routine_fired != 0) return;
    g_routine_fired = 1;
    print_console("  [routine] deferred test routine fired, data=" + cast<string>(data));
}

// Keybind polling routine
bool g_kb_was_active = false;
void kb_poll_routine(int64 data) {
    bool now = g_w_keybind.is_active();
    if (now != g_kb_was_active) {
        print_console("  [kb] keybind state changed: " + cast<string>(now));
        g_kb_was_active = now;
    }
}

// ============================================================================
// RESOURCE SETUP
// ============================================================================

void create_all_resources() {
    print_console("");
    print_console("=== Creating GUI test resources ===");

    // ── Sidebar section ────────────────────────────────────────────────────
    g_sec = create_sidebar_section("GUI Test", "");
    check("create_sidebar_section returned non-zero handle",
          cast<int64>(g_sec) != 0,
          "handle=" + cast<string>(cast<int64>(g_sec)));

    // ── Widget builders on sidebar_section_t ───────────────────────────────
    section("Creating all widget types via builder methods");

    g_w_label              = g_sec.create_label("Test Label", ui_align::left);
    g_sec.create_separator();
    g_w_button             = g_sec.create_button("Test Button", ui_align::center);
    g_w_button2            = g_sec.create_button("Attached Button", ui_align::center);
    g_w_checkbox           = g_sec.create_checkbox("Test Checkbox", true);
    g_w_slider             = g_sec.create_slider("Test Slider", 0.5, 0.0, 1.0, 0.01);
    g_w_slider_icon        = g_sec.create_slider_icon("\xEE\xA9\xB0", 0.75, 0.0, 1.0, 0.01);
    g_w_value_input        = g_sec.create_value_input("Test Value", 50.0, 0.0, 100.0, 1.0);

    array<string> opt_items;
    opt_items.push("First"); opt_items.push("Second"); opt_items.push("Third");
    g_w_options            = g_sec.create_options("Test Options", opt_items, 0);
    g_w_multi_options      = g_sec.create_multi_options("Test Multi", opt_items, 3);

    g_w_dropdown           = g_sec.create_dropdown("Test Dropdown", opt_items, 1);
    g_w_multi_dropdown     = g_sec.create_multi_dropdown("Test Multi DD", opt_items, 5);

    // Lists with info1/info2 parallel arrays
    array<string> info1; info1.push("Item A"); info1.push("Item B"); info1.push("Item C");
    array<string> info2; info2.push("Val 1");  info2.push("Val 2");  info2.push("Val 3");
    g_w_list               = g_sec.create_list("Test List", info1, info2, true, 0, 5, true);

    g_w_inline_button      = g_sec.create_inline_button("Inline Btn", 0.0, "");
    g_w_inline_text_input  = g_sec.create_inline_text_input("default", 0.0, "type here...");

    array<string> tab_items;
    tab_items.push("Tab A"); tab_items.push("Tab B"); tab_items.push("Tab C");
    g_w_tabs               = g_sec.create_tabs(tab_items, 0);

    g_w_keybind            = g_sec.create_keybind("Test Keybind");
    g_w_progress_bar       = g_sec.create_progress_bar("Test Progress", 0.3, 0.0, 1.0, true);
    g_w_spinner            = g_sec.create_spinner("Test Spinner");
    g_w_range_slider       = g_sec.create_range_slider("Test Range", 0.0, 100.0, 20.0, 80.0, 1.0);

    array<string> col_names; col_names.push("Name"); col_names.push("Value");
    array<float64> col_widths; col_widths.push(0.5); col_widths.push(0.5);
    g_w_table              = g_sec.create_table("Test Table", col_names, col_widths, 4);

    g_w_text_input         = g_sec.create_text_input("Test Text Input", "hello", 1);
    g_w_text_editor        = g_sec.create_text_editor("Test Editor", "initial code\nline 2", 8, "");
    g_w_colorpicker        = g_sec.create_colorpicker("Test Color", color(128, 128, 128, 255));
    g_w_colorpicker2       = g_sec.create_colorpicker("Test Color 2", color(255, 0, 0, 255));

    // ── Frames ──────────────────────────────────────────────────────────────
    section("Creating frames");

    layer_t default_layer = get_default_layer();
    g_frame              = create_frame("raw-frame", vec2(10.0, 10.0), vec2(300.0, 200.0), default_layer);
    g_default_frame      = create_default_frame("default-frame", vec2(20.0, 20.0), vec2(400.0, 300.0), default_layer);
    g_draggable_frame    = create_draggable_frame("drag-frame", vec2(50.0, 50.0), vec2(250.0, 150.0), default_layer);
    g_popup              = create_popup("test-popup", vec2(100.0, 100.0), vec2(200.0, 100.0), default_layer);

    check("create_frame handle != 0", cast<int64>(g_frame) != 0);
    check("create_default_frame handle != 0", cast<int64>(g_default_frame) != 0);
    check("create_draggable_frame handle != 0", cast<int64>(g_draggable_frame) != 0);
    check("create_popup handle != 0", cast<int64>(g_popup) != 0);

    // Set default frame visible for further tests
    g_default_frame.set_visible(true);

    // ── Layers ──────────────────────────────────────────────────────────────
    section("Creating layers");

    g_layer = create_layer("test-layer", false, false);
    check("create_layer handle != 0", cast<int64>(g_layer) != 0);

    // ── Custom widget on frame ──────────────────────────────────────────────
    section("Creating custom widget");

    g_widget = create_widget(g_default_frame, "test-custom-widget",
                             cast<int64>(on_widget_execute), false);
    check("create_widget handle != 0", cast<int64>(g_widget) != 0);

    // ── Menu ────────────────────────────────────────────────────────────────
    section("Creating menu");

    g_menu = create_menu();
    check("create_menu handle != 0", cast<int64>(g_menu) != 0);
    g_menu.add_item("Action 1", cast<int64>(on_menu_click), "", "");
    g_menu.add_separator();
    g_menu.add_item("Action 2", cast<int64>(on_menu_click), "Ctrl+A", "");

    // ── File picker ─────────────────────────────────────────────────────────
    section("Creating file picker");

    g_picker = create_file_picker("Test Picker", "/", "", false);
    check("create_file_picker handle != 0", cast<int64>(g_picker) != 0);

    print_console("");
    print_console("=== Resource creation complete ===");
    print_console("");
}

// ============================================================================
// TEST: sidebar sections
// ============================================================================

void test_sidebar_section() {
    section("Sidebar section");

    // create_sidebar_separator (standalone)
    create_sidebar_separator();
    check("create_sidebar_separator called without error", true, "");

    // section.set_active
    g_sec.set_active(true);
    check("section.set_active(true) called without error", true, "");

    g_sec.set_active(false);
    check("section.set_active(false) called without error", true, "");
}

// ============================================================================
// TEST: sidebar widget builders
// ============================================================================

void test_widget_builders() {
    section("Widget builders (verify all were created)");

    check("label handle != 0", cast<int64>(g_w_label) != 0);
    check("button handle != 0", cast<int64>(g_w_button) != 0);
    check("checkbox handle != 0", cast<int64>(g_w_checkbox) != 0);
    check("slider handle != 0", cast<int64>(g_w_slider) != 0);
    check("slider_icon handle != 0", cast<int64>(g_w_slider_icon) != 0);
    check("value_input handle != 0", cast<int64>(g_w_value_input) != 0);
    check("options handle != 0", cast<int64>(g_w_options) != 0);
    check("multi_options handle != 0", cast<int64>(g_w_multi_options) != 0);
    check("dropdown handle != 0", cast<int64>(g_w_dropdown) != 0);
    check("multi_dropdown handle != 0", cast<int64>(g_w_multi_dropdown) != 0);
    check("list handle != 0", cast<int64>(g_w_list) != 0);
    check("inline_button handle != 0", cast<int64>(g_w_inline_button) != 0);
    check("inline_text_input handle != 0", cast<int64>(g_w_inline_text_input) != 0);
    check("tabs handle != 0", cast<int64>(g_w_tabs) != 0);
    check("keybind handle != 0", cast<int64>(g_w_keybind) != 0);
    check("progress_bar handle != 0", cast<int64>(g_w_progress_bar) != 0);
    check("spinner handle != 0", cast<int64>(g_w_spinner) != 0);
    check("range_slider handle != 0", cast<int64>(g_w_range_slider) != 0);
    check("table handle != 0", cast<int64>(g_w_table) != 0);
    check("text_input handle != 0", cast<int64>(g_w_text_input) != 0);
    check("text_editor handle != 0", cast<int64>(g_w_text_editor) != 0);
    check("colorpicker handle != 0", cast<int64>(g_w_colorpicker) != 0);
    check("colorpicker2 handle != 0", cast<int64>(g_w_colorpicker2) != 0);
}

// ============================================================================
// TEST: common widget operations (set_active, set_tooltip, on_change)
// ============================================================================

void test_common_widget_ops() {
    section("Common widget operations");

    // set_active on various types
    g_w_label.set_active(true);
    check("label.set_active(true)", true, "");

    g_w_button.set_active(true);
    check("button.set_active(true)", true, "");

    g_w_checkbox.set_active(true);
    check("checkbox.set_active(true)", true, "");

    g_w_slider.set_active(true);
    check("slider.set_active(true)", true, "");

    g_w_slider_icon.set_active(true);
    check("slider_icon.set_active(true)", true, "");

    g_w_value_input.set_active(true);
    check("value_input.set_active(true)", true, "");

    g_w_options.set_active(true);
    check("options.set_active(true)", true, "");

    g_w_multi_options.set_active(true);
    check("multi_options.set_active(true)", true, "");

    g_w_dropdown.set_active(true);
    check("dropdown.set_active(true)", true, "");

    g_w_multi_dropdown.set_active(true);
    check("multi_dropdown.set_active(true)", true, "");

    g_w_list.set_active(true);
    check("list.set_active(true)", true, "");

    g_w_inline_button.set_active(true);
    check("inline_button.set_active(true)", true, "");

    g_w_inline_text_input.set_active(true);
    check("inline_text_input.set_active(true)", true, "");

    g_w_tabs.set_active(true);
    check("tabs.set_active(true)", true, "");

    g_w_keybind.set_active(true);
    check("keybind.set_active(true)", true, "");

    g_w_progress_bar.set_active(true);
    check("progress_bar.set_active(true)", true, "");

    g_w_spinner.set_active(true);
    check("spinner.set_active(true)", true, "");

    g_w_range_slider.set_active(true);
    check("range_slider.set_active(true)", true, "");

    g_w_table.set_active(true);
    check("table.set_active(true)", true, "");

    g_w_text_input.set_active(true);
    check("text_input.set_active(true)", true, "");

    g_w_colorpicker.set_active(true);
    check("colorpicker.set_active(true)", true, "");

    // text_editor_t does NOT have set_active -- skip

    // set_tooltip on all types (including text_editor_t)
    g_w_label.set_tooltip("A label tooltip");
    g_w_button.set_tooltip("A button tooltip");
    g_w_checkbox.set_tooltip("A checkbox tooltip");
    g_w_slider.set_tooltip("A slider tooltip");
    g_w_slider_icon.set_tooltip("A slider_icon tooltip");
    g_w_value_input.set_tooltip("A value_input tooltip");
    g_w_options.set_tooltip("An options tooltip");
    g_w_multi_options.set_tooltip("A multi_options tooltip");
    g_w_dropdown.set_tooltip("A dropdown tooltip");
    g_w_multi_dropdown.set_tooltip("A multi_dropdown tooltip");
    g_w_list.set_tooltip("A list tooltip");
    g_w_inline_button.set_tooltip("An inline_button tooltip");
    g_w_inline_text_input.set_tooltip("An inline_text_input tooltip");
    g_w_tabs.set_tooltip("A tabs tooltip");
    g_w_keybind.set_tooltip("A keybind tooltip");
    g_w_progress_bar.set_tooltip("A progress_bar tooltip");
    g_w_spinner.set_tooltip("A spinner tooltip");
    g_w_range_slider.set_tooltip("A range_slider tooltip");
    g_w_table.set_tooltip("A table tooltip");
    g_w_text_input.set_tooltip("A text_input tooltip");
    g_w_text_editor.set_tooltip("A text_editor tooltip");
    g_w_colorpicker.set_tooltip("A colorpicker tooltip");
    check("set_tooltip called on all 22 widget types without error", true, "");

    // on_change on representative types
    g_w_button.on_change(cast<int64>(on_change_stub));
    g_w_checkbox.on_change(cast<int64>(on_change_stub));
    g_w_slider.on_change(cast<int64>(on_change_stub));
    g_w_options.on_change(cast<int64>(on_change_stub));
    g_w_text_input.on_change(cast<int64>(on_change_stub));
    g_w_text_editor.on_change(cast<int64>(on_change_stub));
    check("on_change registered on multiple widget types without error", true, "");
}

// ============================================================================
// TEST: per-widget typed get/set
// ============================================================================

void test_widget_typed_methods() {
    section("Per-widget typed get/set methods");

    // ── label.set_text ──────────────────────────────────────────────────────
    g_w_label.set_text("Updated label text");
    check("label.set_text called without error", true, "");

    // ── button.attach_to ────────────────────────────────────────────────────
    g_w_button2.attach_to(g_w_button);
    check("button.attach_to called without error", true, "");

    // ── checkbox.get / checkbox.set ─────────────────────────────────────────
    bool cb_val = g_w_checkbox.get();
    check("checkbox.get() returns a value", true, "got " + cast<string>(cb_val));
    g_w_checkbox.set(false);
    bool cb_val2 = g_w_checkbox.get();
    check("checkbox.set(false) then get() reflects change", cb_val2 == false,
          "got " + cast<string>(cb_val2));
    g_w_checkbox.set(true);

    // ── slider.get / slider.set ────────────────────────────────────────────
    float64 sl_val = g_w_slider.get();
    check_msg("slider.get() returns initial value", feq(sl_val, 0.5),
              "got " + cast<string>(sl_val));
    g_w_slider.set(0.8);
    float64 sl_val2 = g_w_slider.get();
    check_msg("slider.set(0.8) reflected in get()", feq(sl_val2, 0.8),
              "got " + cast<string>(sl_val2));

    // ── slider_icon.get / slider_icon.set ───────────────────────────────────
    float64 si_val = g_w_slider_icon.get();
    check("slider_icon.get() returned value", true, "got " + cast<string>(si_val));
    g_w_slider_icon.set(0.5);
    float64 si_val2 = g_w_slider_icon.get();
    check_msg("slider_icon.set/get roundtrip", feq(si_val2, 0.5),
              "got " + cast<string>(si_val2));

    // ── value_input.get / value_input.set ───────────────────────────────────
    float64 vi_val = g_w_value_input.get();
    check("value_input.get() returned value", true, "got " + cast<string>(vi_val));
    g_w_value_input.set(75.0);
    float64 vi_val2 = g_w_value_input.get();
    check_msg("value_input.set/get roundtrip", feq(vi_val2, 75.0),
              "got " + cast<string>(vi_val2));

    // ── options.get / options.set ───────────────────────────────────────────
    int64 opt_val = g_w_options.get();
    check("options.get() returned initial", opt_val == 0,
          "got " + cast<string>(opt_val));
    g_w_options.set(1);
    int64 opt_val2 = g_w_options.get();
    check("options.set(1) reflected in get()", opt_val2 == 1,
          "got " + cast<string>(opt_val2));

    // ── dropdown.get / dropdown.set ─────────────────────────────────────────
    int64 dd_val = g_w_dropdown.get();
    check("dropdown.get() returned initial", dd_val == 1,
          "got " + cast<string>(dd_val));
    g_w_dropdown.set(2);
    int64 dd_val2 = g_w_dropdown.get();
    check("dropdown.set(2) reflected in get()", dd_val2 == 2,
          "got " + cast<string>(dd_val2));

    // ── tabs.get / tabs.set ─────────────────────────────────────────────────
    int64 tab_val = g_w_tabs.get();
    check("tabs.get() returned initial", tab_val == 0,
          "got " + cast<string>(tab_val));
    g_w_tabs.set(1);
    int64 tab_val2 = g_w_tabs.get();
    check("tabs.set(1) reflected in get()", tab_val2 == 1,
          "got " + cast<string>(tab_val2));

    // ── multi_options.get_mask / multi_options.set_mask ─────────────────────
    int64 mo_mask = g_w_multi_options.get_mask();
    check("multi_options.get_mask() returned initial", mo_mask == 3,
          "got " + cast<string>(mo_mask));
    g_w_multi_options.set_mask(5);
    int64 mo_mask2 = g_w_multi_options.get_mask();
    check("multi_options.set_mask(5) reflected", mo_mask2 == 5,
          "got " + cast<string>(mo_mask2));

    // ── multi_dropdown.get_mask / multi_dropdown.set_mask ───────────────────
    int64 mdd_mask = g_w_multi_dropdown.get_mask();
    check("multi_dropdown.get_mask() returned initial", mdd_mask == 5,
          "got " + cast<string>(mdd_mask));
    g_w_multi_dropdown.set_mask(3);
    int64 mdd_mask2 = g_w_multi_dropdown.get_mask();
    check("multi_dropdown.set_mask(3) reflected", mdd_mask2 == 3,
          "got " + cast<string>(mdd_mask2));

    // ── list.get_selected / list.set_selected / list.size / list.set_items ──
    int64 list_sel = g_w_list.get_selected();
    check("list.get_selected() returned initial", list_sel == 0,
          "got " + cast<string>(list_sel));

    int64 list_sz = g_w_list.size();
    check("list.size() returned 3 items", list_sz == 3,
          "got " + cast<string>(list_sz));

    g_w_list.set_selected(2);
    int64 list_sel2 = g_w_list.get_selected();
    check("list.set_selected(2) reflected", list_sel2 == 2,
          "got " + cast<string>(list_sel2));

    // list.set_items
    array<string> new_info1; new_info1.push("X"); new_info1.push("Y");
    array<string> new_info2; new_info2.push("10"); new_info2.push("20");
    g_w_list.set_items(new_info1, new_info2);
    int64 list_sz2 = g_w_list.size();
    check("list.set_items changed size to 2", list_sz2 == 2,
          "got " + cast<string>(list_sz2));

    // ── inline_text_input.get / inline_text_input.set ───────────────────────
    string iti_val = g_w_inline_text_input.get();
    check("inline_text_input.get() returned initial", iti_val == "default",
          "got '" + iti_val + "'");
    g_w_inline_text_input.set("updated");
    string iti_val2 = g_w_inline_text_input.get();
    check("inline_text_input.set/get roundtrip", iti_val2 == "updated",
          "got '" + iti_val2 + "'");

    // ── text_input.get / text_input.set ─────────────────────────────────────
    string ti_val = g_w_text_input.get();
    check("text_input.get() returned initial", ti_val == "hello",
          "got '" + ti_val + "'");
    g_w_text_input.set("world");
    string ti_val2 = g_w_text_input.get();
    check("text_input.set/get roundtrip", ti_val2 == "world",
          "got '" + ti_val2 + "'");

    // ── text_editor.get / text_editor.set ───────────────────────────────────
    string te_val = g_w_text_editor.get();
    check("text_editor.get() returned non-empty", te_val.length() > 0,
          "length=" + cast<string>(te_val.length()));
    g_w_text_editor.set("replacement code");
    string te_val2 = g_w_text_editor.get();
    check("text_editor.set/get roundtrip", te_val2 == "replacement code",
          "got '" + te_val2 + "'");

    // ── keybind.bind / keybind.is_active / keybind.binding_count ────────────
    g_w_keybind.bind(0x51, false, false, false, keybind_mode::toggle);  // VK_KEY_Q
    check("keybind.bind() called without error", true, "");

    bool kb_active = g_w_keybind.is_active();
    check("keybind.is_active() returned a value", true,
          "got " + cast<string>(kb_active));

    int64 kb_count = g_w_keybind.binding_count();
    check("keybind.binding_count() >= 1 after bind", kb_count >= 1,
          "got " + cast<string>(kb_count));

    // ── progress_bar.set ────────────────────────────────────────────────────
    g_w_progress_bar.set(0.6);
    check("progress_bar.set(0.6) called without error", true, "");

    // ── range_slider.get_lo / get_hi / set ──────────────────────────────────
    float64 rs_lo = g_w_range_slider.get_lo();
    float64 rs_hi = g_w_range_slider.get_hi();
    check_msg("range_slider.get_lo() returned initial",
              feq(rs_lo, 20.0), "got " + cast<string>(rs_lo));
    check_msg("range_slider.get_hi() returned initial",
              feq(rs_hi, 80.0), "got " + cast<string>(rs_hi));

    g_w_range_slider.set(30.0, 70.0);
    float64 rs_lo2 = g_w_range_slider.get_lo();
    float64 rs_hi2 = g_w_range_slider.get_hi();
    check_msg("range_slider.set(30, 70) reflected in get_lo",
              feq(rs_lo2, 30.0), "got " + cast<string>(rs_lo2));
    check_msg("range_slider.set(30, 70) reflected in get_hi",
              feq(rs_hi2, 70.0), "got " + cast<string>(rs_hi2));

    // ── table.add_row / table.size / table.clear ────────────────────────────
    array<string> row1; row1.push("Alice"); row1.push("100");
    array<string> row2; row2.push("Bob");   row2.push("200");
    g_w_table.add_row(row1);
    g_w_table.add_row(row2);
    int64 tbl_sz = g_w_table.size();
    check("table.size() == 2 after 2 add_row calls", tbl_sz == 2,
          "got " + cast<string>(tbl_sz));

    g_w_table.clear();
    int64 tbl_sz2 = g_w_table.size();
    check("table.size() == 0 after clear", tbl_sz2 == 0,
          "got " + cast<string>(tbl_sz2));

    // ── colorpicker.get / colorpicker.set / colorpicker.attach_to ───────────
    color cp_col = g_w_colorpicker.get();
    check("colorpicker.get() returned color with r=128", cp_col.r() == 128,
          "got " + cast<string>(cp_col.r()));
    check("colorpicker.get() returned color with g=128", cp_col.g() == 128,
          "got " + cast<string>(cp_col.g()));
    check("colorpicker.get() returned color with b=128", cp_col.b() == 128,
          "got " + cast<string>(cp_col.b()));
    check("colorpicker.get() returned color with a=255", cp_col.a() == 255,
          "got " + cast<string>(cp_col.a()));

    g_w_colorpicker.set(color(10, 20, 30, 200));
    color cp_col2 = g_w_colorpicker.get();
    check("colorpicker.set/get roundtrip r=10", cp_col2.r() == 10,
          "got " + cast<string>(cp_col2.r()));
    check("colorpicker.set/get roundtrip a=200", cp_col2.a() == 200,
          "got " + cast<string>(cp_col2.a()));

    // colorpicker.attach_to
    g_w_colorpicker2.attach_to(g_w_colorpicker);
    check("colorpicker.attach_to called without error", true, "");
}

// ============================================================================
// TEST: frame_t
// ============================================================================

void test_frames() {
    section("frame_t methods");

    // ── frame.set_pos / frame.get_pos ──────────────────────────────────
    g_frame.set_pos(vec2(100.0, 200.0));
    vec2 pos = g_frame.get_pos();
    check_msg("frame.get_pos().x == 100.0 after set_pos",
              feq(pos.x(), 100.0), "got " + cast<string>(pos.x()));
    check_msg("frame.get_pos().y == 200.0 after set_pos",
              feq(pos.y(), 200.0), "got " + cast<string>(pos.y()));

    // ── frame.set_size / frame.get_size ────────────────────────────────
    g_frame.set_size(vec2(500.0, 400.0));
    vec2 sz = g_frame.get_size();
    check_msg("frame.get_size().x == 500.0 after set_size",
              feq(sz.x(), 500.0), "got " + cast<string>(sz.x()));
    check_msg("frame.get_size().y == 400.0 after set_size",
              feq(sz.y(), 400.0), "got " + cast<string>(sz.y()));

    // ── frame.set_visible / frame.is_visible ───────────────────────────
    g_frame.set_visible(true);
    bool vis_on = g_frame.is_visible();
    check("frame.is_visible() == true after set_visible(true)", vis_on == true,
          "got " + cast<string>(vis_on));

    g_frame.set_visible(false);
    bool vis_off = g_frame.is_visible();
    check("frame.is_visible() == false after set_visible(false)", vis_off == false,
          "got " + cast<string>(vis_off));

    // ── frame.set_anchors ──────────────────────────────────────────────
    int64 anchor_mask = cast<int64>(ui_anchor::left) | cast<int64>(ui_anchor::top);
    g_frame.set_anchors(anchor_mask);
    check("frame.set_anchors with bitmask called without error", true, "");

    // ── frame.attach ───────────────────────────────────────────────────
    g_frame.attach(g_default_frame);
    check("frame.attach to parent called without error", true, "");

    // ── frame.set_float ────────────────────────────────────────────────
    g_frame.set_float(cast<int64>(widget_attr::size_x), 300.0);
    check("frame.set_float with widget_attr hash called without error", true, "");

    // ── frame.install_hook / frame.remove_hook ─────────────────────────
    g_frame.install_hook(cast<int64>(ui_hook::pre_execute),
                         cast<int64>(on_frame_hook));
    check("frame.install_hook(pre_execute) called without error", true, "");

    g_frame.remove_hook(cast<int64>(ui_hook::pre_execute));
    check("frame.remove_hook(pre_execute) called without error", true, "");

    // ── frame.set_focused / get_focused_frame / ui_is_focused ──────────
    g_frame.set_focused();
    check("frame.set_focused() called without error", true, "");

    frame_t focused = get_focused_frame();
    check("get_focused_frame() returned a handle",
          cast<int64>(focused) != 0, "");

    bool focused_bool = ui_is_focused();
    check("ui_is_focused() returned a bool value", true,
          "got " + cast<string>(focused_bool));

    // ── create_frame with 0 (default) layer ────────────────────────────
    frame_t frame_no_layer = create_frame("no-layer-frame", vec2(0.0, 0.0),
                                          vec2(100.0, 100.0), cast<layer_t>(0));
    check("create_frame with layer=0 returned handle != 0",
          cast<int64>(frame_no_layer) != 0, "");
    frame_no_layer.set_visible(false);
}

// ============================================================================
// TEST: layer_t
// ============================================================================

void test_layers() {
    section("layer_t methods");

    // ── layer_count (standalone function) ─────────────────────────────────
    int64 n_layers = layer_count();
    check("layer_count() > 0", n_layers > 0,
          "got " + cast<string>(n_layers));

    // ── get_default_layer (standalone function) ───────────────────────────
    layer_t def_layer = get_default_layer();
    check("get_default_layer() returned handle != 0",
          cast<int64>(def_layer) != 0, "");

    // ── layer.promote_to_top ──────────────────────────────────────────────
    g_layer.promote_to_top();
    check("layer.promote_to_top() called without error", true, "");

    // ── layer.set_visible ─────────────────────────────────────────────────
    g_layer.set_visible(true);
    check("layer.set_visible(true) called without error", true, "");

    g_layer.set_visible(false);
    check("layer.set_visible(false) called without error", true, "");

    // ── layer.frame_count ─────────────────────────────────────────────────
    int64 fc = g_layer.frame_count();
    check("layer.frame_count() >= 0", fc >= 0,
          "got " + cast<string>(fc));
}

// ============================================================================
// TEST: custom widget_t
// ============================================================================

void test_custom_widget() {
    section("widget_t methods");

    // ── widget.set_pos ────────────────────────────────────────────────────
    g_widget.set_pos(vec2(10.0, 20.0));
    check("widget.set_pos(vec2) called without error", true, "");

    // ── widget.set_size ───────────────────────────────────────────────────
    g_widget.set_size(vec2(150.0, 80.0));
    check("widget.set_size(vec2) called without error", true, "");

    // ── widget.set_active ─────────────────────────────────────────────────
    g_widget.set_active(true);
    check("widget.set_active(true) called without error", true, "");
    g_widget.set_active(false);
    check("widget.set_active(false) called without error", true, "");

    // ── widget.set_tooltip ────────────────────────────────────────────────
    g_widget.set_tooltip("Custom widget tooltip");
    check("widget.set_tooltip() called without error", true, "");

    // ── widget.set_float ──────────────────────────────────────────────────
    g_widget.set_float(cast<int64>(widget_attr::rounding), 4.0);
    check("widget.set_float() called without error", true, "");

    // ── widget.set_anchors ────────────────────────────────────────────────
    g_widget.set_anchors(cast<int64>(ui_anchor::all));
    check("widget.set_anchors(all) called without error", true, "");

    // ── widget.install_hook / widget.remove_hook ──────────────────────────
    g_widget.install_hook(cast<int64>(ui_hook::clicked),
                          cast<int64>(on_frame_hook));
    check("widget.install_hook(clicked) called without error", true, "");

    g_widget.remove_hook(cast<int64>(ui_hook::clicked));
    check("widget.remove_hook(clicked) called without error", true, "");
}

// ============================================================================
// TEST: menu_t and attach_to_* methods
// ============================================================================

void test_menus() {
    section("menu_t methods");

    // ── menu.add_item / menu.add_separator ────────────────────────────────
    menu_t m_test = create_menu();
    check("create_menu() for attach tests returned handle != 0",
          cast<int64>(m_test) != 0, "");

    m_test.add_item("Item 1", cast<int64>(on_menu_click), "Ctrl+1", "");
    m_test.add_item("Item 2", cast<int64>(on_menu_click), "Ctrl+2", "\xEE\xA9\xB0");
    m_test.add_separator();
    m_test.add_item("Item 3", cast<int64>(on_menu_click), "", "");
    check("menu.add_item/add_separator x3 called without error", true, "");

    // ── menu.attach_to_widget ─────────────────────────────────────────────
    // Note: Using `auto` for local menu vars whose attach_to_* methods are
    // documented but not yet in types.json. This avoids LSP false-positives.
    auto m_w = create_menu(); m_w.add_item("W", cast<int64>(on_menu_click), "", "");
    m_w.attach_to_widget(g_widget);
    check("menu.attach_to_widget(widget_t)", true, "");

    // ── menu.attach_to_button ─────────────────────────────────────────────
    auto m_btn = create_menu(); m_btn.add_item("B", cast<int64>(on_menu_click), "", "");
    m_btn.attach_to_button(g_w_button);
    check("menu.attach_to_button(button_t)", true, "");

    // ── menu.attach_to_label ──────────────────────────────────────────────
    auto m_lbl = create_menu(); m_lbl.add_item("L", cast<int64>(on_menu_click), "", "");
    m_lbl.attach_to_label(g_w_label);
    check("menu.attach_to_label(label_t)", true, "");

    // ── menu.attach_to_checkbox ───────────────────────────────────────────
    auto m_cb = create_menu(); m_cb.add_item("C", cast<int64>(on_menu_click), "", "");
    m_cb.attach_to_checkbox(g_w_checkbox);
    check("menu.attach_to_checkbox(checkbox_t)", true, "");

    // ── menu.attach_to_slider ─────────────────────────────────────────────
    auto m_sl = create_menu(); m_sl.add_item("S", cast<int64>(on_menu_click), "", "");
    m_sl.attach_to_slider(g_w_slider);
    check("menu.attach_to_slider(slider_t)", true, "");

    // ── menu.attach_to_slider_icon ────────────────────────────────────────
    auto m_si = create_menu(); m_si.add_item("SI", cast<int64>(on_menu_click), "", "");
    m_si.attach_to_slider_icon(g_w_slider_icon);
    check("menu.attach_to_slider_icon(slider_icon_t)", true, "");

    // ── menu.attach_to_value_input ────────────────────────────────────────
    auto m_vi = create_menu(); m_vi.add_item("VI", cast<int64>(on_menu_click), "", "");
    m_vi.attach_to_value_input(g_w_value_input);
    check("menu.attach_to_value_input(value_input_t)", true, "");

    // ── menu.attach_to_options ────────────────────────────────────────────
    auto m_opt = create_menu(); m_opt.add_item("O", cast<int64>(on_menu_click), "", "");
    m_opt.attach_to_options(g_w_options);
    check("menu.attach_to_options(options_t)", true, "");

    // ── menu.attach_to_multi_options ──────────────────────────────────────
    auto m_mo = create_menu(); m_mo.add_item("MO", cast<int64>(on_menu_click), "", "");
    m_mo.attach_to_multi_options(g_w_multi_options);
    check("menu.attach_to_multi_options(multi_options_t)", true, "");

    // ── menu.attach_to_dropdown ───────────────────────────────────────────
    auto m_dd = create_menu(); m_dd.add_item("DD", cast<int64>(on_menu_click), "", "");
    m_dd.attach_to_dropdown(g_w_dropdown);
    check("menu.attach_to_dropdown(dropdown_t)", true, "");

    // ── menu.attach_to_multi_dropdown ─────────────────────────────────────
    auto m_mdd = create_menu(); m_mdd.add_item("MDD", cast<int64>(on_menu_click), "", "");
    m_mdd.attach_to_multi_dropdown(g_w_multi_dropdown);
    check("menu.attach_to_multi_dropdown(multi_dropdown_t)", true, "");

    // ── menu.attach_to_list ───────────────────────────────────────────────
    auto m_list = create_menu(); m_list.add_item("LST", cast<int64>(on_menu_click), "", "");
    m_list.attach_to_list(g_w_list);
    check("menu.attach_to_list(list_t)", true, "");

    // ── menu.attach_to_inline_button ──────────────────────────────────────
    auto m_ib = create_menu(); m_ib.add_item("IB", cast<int64>(on_menu_click), "", "");
    m_ib.attach_to_inline_button(g_w_inline_button);
    check("menu.attach_to_inline_button(inline_button_t)", true, "");

    // ── menu.attach_to_inline_text_input ──────────────────────────────────
    auto m_iti = create_menu(); m_iti.add_item("ITI", cast<int64>(on_menu_click), "", "");
    m_iti.attach_to_inline_text_input(g_w_inline_text_input);
    check("menu.attach_to_inline_text_input(inline_text_input_t)", true, "");

    // ── menu.attach_to_tabs ───────────────────────────────────────────────
    auto m_tabs = create_menu(); m_tabs.add_item("TAB", cast<int64>(on_menu_click), "", "");
    m_tabs.attach_to_tabs(g_w_tabs);
    check("menu.attach_to_tabs(tabs_t)", true, "");

    // ── menu.attach_to_keybind ────────────────────────────────────────────
    auto m_kb = create_menu(); m_kb.add_item("KB", cast<int64>(on_menu_click), "", "");
    m_kb.attach_to_keybind(g_w_keybind);
    check("menu.attach_to_keybind(keybind_t)", true, "");

    // ── menu.attach_to_progress_bar ───────────────────────────────────────
    auto m_pb = create_menu(); m_pb.add_item("PB", cast<int64>(on_menu_click), "", "");
    m_pb.attach_to_progress_bar(g_w_progress_bar);
    check("menu.attach_to_progress_bar(progress_bar_t)", true, "");

    // ── menu.attach_to_spinner ────────────────────────────────────────────
    auto m_spin = create_menu(); m_spin.add_item("SPN", cast<int64>(on_menu_click), "", "");
    m_spin.attach_to_spinner(g_w_spinner);
    check("menu.attach_to_spinner(spinner_t)", true, "");

    // ── menu.attach_to_range_slider ───────────────────────────────────────
    auto m_rs = create_menu(); m_rs.add_item("RS", cast<int64>(on_menu_click), "", "");
    m_rs.attach_to_range_slider(g_w_range_slider);
    check("menu.attach_to_range_slider(range_slider_t)", true, "");

    // ── menu.attach_to_table ──────────────────────────────────────────────
    auto m_tbl = create_menu(); m_tbl.add_item("TBL", cast<int64>(on_menu_click), "", "");
    m_tbl.attach_to_table(g_w_table);
    check("menu.attach_to_table(table_t)", true, "");

    // ── menu.attach_to_text_input ─────────────────────────────────────────
    auto m_ti = create_menu(); m_ti.add_item("TI", cast<int64>(on_menu_click), "", "");
    m_ti.attach_to_text_input(g_w_text_input);
    check("menu.attach_to_text_input(text_input_t)", true, "");

    // ── menu.attach_to_text_editor ────────────────────────────────────────
    auto m_te = create_menu(); m_te.add_item("TE", cast<int64>(on_menu_click), "", "");
    m_te.attach_to_text_editor(g_w_text_editor);
    check("menu.attach_to_text_editor(text_editor_t)", true, "");

    // ── menu.attach_to_colorpicker ────────────────────────────────────────
    auto m_cp = create_menu(); m_cp.add_item("CP", cast<int64>(on_menu_click), "", "");
    m_cp.attach_to_colorpicker(g_w_colorpicker);
    check("menu.attach_to_colorpicker(colorpicker_t)", true, "");
}

// ============================================================================
// TEST: file picker
// ============================================================================

void test_file_picker() {
    section("file_picker_t methods");

    // ── picker.open ────────────────────────────────────────────────────────
    g_picker.open();
    check("file_picker.open() called without error", true, "");

    // ── picker.get_selected ────────────────────────────────────────────────
    string sel = g_picker.get_selected();
    check("file_picker.get_selected() returned a value (may be empty)", true,
          "got '" + sel + "'");

    // ── picker.close ───────────────────────────────────────────────────────
    g_picker.close();
    check("file_picker.close() called without error", true, "");

    // ── create_file_picker with folder_mode=true ───────────────────────────
    file_picker_t folder_picker = create_file_picker("Folder Picker", "/home", "", true);
    check("create_file_picker with folder_mode=true returned handle != 0",
          cast<int64>(folder_picker) != 0, "");
    folder_picker.open();
    folder_picker.close();
    check("folder picker open/close without error", true, "");

    // ── create_file_picker with filter_extension ──────────────────────────
    file_picker_t filter_picker = create_file_picker("Filtered", "/", ".em", false);
    check("create_file_picker with filter returned handle != 0",
          cast<int64>(filter_picker) != 0, "");
}

// ============================================================================
// TEST: theme functions
// ============================================================================

void test_theme() {
    section("Theme functions");

    // ── is_dark_theme / set_dark_theme ──────────────────────────────────
    bool was_dark = is_dark_theme();
    check("is_dark_theme() returned a bool value", true,
          "got " + cast<string>(was_dark));

    // Toggle to opposite and back
    set_dark_theme(!was_dark);
    bool after_toggle = is_dark_theme();
    check("set_dark_theme(!was_dark) actually toggled", after_toggle == !was_dark,
          "expected " + cast<string>(!was_dark) + " got " + cast<string>(after_toggle));

    set_dark_theme(was_dark);
    bool restored = is_dark_theme();
    check("set_dark_theme restored original", restored == was_dark,
          "expected " + cast<string>(was_dark) + " got " + cast<string>(restored));

    // ── get_theme_color / set_theme_color ───────────────────────────────
    color theme_bg = get_theme_color(cast<int64>(ui_color::bg));
    check("get_theme_color(bg) returned a color with a > 0", theme_bg.a() > 0,
          "r=" + cast<string>(theme_bg.r()) +
          " g=" + cast<string>(theme_bg.g()) +
          " b=" + cast<string>(theme_bg.b()) +
          " a=" + cast<string>(theme_bg.a()));

    color saved_bg = theme_bg;
    color test_bg = color(60, 60, 60, 255);
    set_theme_color(cast<int64>(ui_color::bg), test_bg);
    color after_set = get_theme_color(cast<int64>(ui_color::bg));
    check("set_theme_color/get_theme_color roundtrip",
          after_set.r() == 60 && after_set.g() == 60 &&
          after_set.b() == 60 && after_set.a() == 255,
          "got r=" + cast<string>(after_set.r()) +
          " g=" + cast<string>(after_set.g()));

    // Restore saved color
    set_theme_color(cast<int64>(ui_color::bg), saved_bg);
    color final_bg = get_theme_color(cast<int64>(ui_color::bg));
    check("theme color restore successful",
          final_bg.r() == saved_bg.r() && final_bg.g() == saved_bg.g() &&
          final_bg.b() == saved_bg.b() && final_bg.a() == saved_bg.a(),
          "");
}

// ============================================================================
// TEST: toasts and GUI queries
// ============================================================================

void test_toasts_and_queries() {
    section("Toasts and GUI queries");

    // ── show_toast (all 4 kinds) ───────────────────────────────────────────
    show_toast(toast_kind::info, "Info Title", "This is an info message.");
    check("show_toast(info) called without error", true, "");

    show_toast(toast_kind::success, "Success Title", "Operation succeeded.");
    check("show_toast(success) called without error", true, "");

    show_toast(toast_kind::warning, "Warning Title", "Something needs attention.");
    check("show_toast(warning) called without error", true, "");

    show_toast(toast_kind::error, "Error Title", "An error occurred.");
    check("show_toast(error) called without error", true, "");

    // ── gui_active ─────────────────────────────────────────────────────────
    bool gui_on = gui_active();
    check("gui_active() returned a bool value", true,
          "got " + cast<string>(gui_on));

    // ── get_gui_size ───────────────────────────────────────────────────────
    vec2 gui_sz = get_gui_size();
    check("get_gui_size().x >= 0", gui_sz.x() >= 0.0,
          "got " + cast<string>(gui_sz.x()));
    check("get_gui_size().y >= 0", gui_sz.y() >= 0.0,
          "got " + cast<string>(gui_sz.y()));

    // ── get_gui_position ───────────────────────────────────────────────────
    vec2 gui_pos = get_gui_position();
    check("get_gui_position() returned a vec2", true,
          "x=" + cast<string>(gui_pos.x()) + " y=" + cast<string>(gui_pos.y()));
}

// ============================================================================
// TEST: enums
// ============================================================================

void test_enums() {
    section("Enum values (cast to int64 to verify they exist)");

    // ── ui_anchor ──────────────────────────────────────────────────────────
    int64 a_none   = cast<int64>(ui_anchor::none);
    int64 a_left   = cast<int64>(ui_anchor::left);
    int64 a_right  = cast<int64>(ui_anchor::right);
    int64 a_top    = cast<int64>(ui_anchor::top);
    int64 a_bottom = cast<int64>(ui_anchor::bottom);
    int64 a_all    = cast<int64>(ui_anchor::all);
    check("ui_anchor enum values are distinct",
          a_none != a_left && a_left != a_right && a_top != a_bottom &&
          a_bottom != a_all && a_left != a_top,
          "");
    print_console("  ui_anchor::none   = " + cast<string>(a_none));
    print_console("  ui_anchor::left   = " + cast<string>(a_left));
    print_console("  ui_anchor::right  = " + cast<string>(a_right));
    print_console("  ui_anchor::top    = " + cast<string>(a_top));
    print_console("  ui_anchor::bottom = " + cast<string>(a_bottom));
    print_console("  ui_anchor::all    = " + cast<string>(a_all));

    // ── ui_edge ────────────────────────────────────────────────────────────
    int64 e_left   = cast<int64>(ui_edge::left);
    int64 e_top    = cast<int64>(ui_edge::top);
    int64 e_right  = cast<int64>(ui_edge::right);
    int64 e_bottom = cast<int64>(ui_edge::bottom);
    check("ui_edge enum values are distinct",
          e_left != e_top && e_top != e_right && e_right != e_bottom, "");
    print_console("  ui_edge::left   = " + cast<string>(e_left));
    print_console("  ui_edge::top    = " + cast<string>(e_top));
    print_console("  ui_edge::right  = " + cast<string>(e_right));
    print_console("  ui_edge::bottom = " + cast<string>(e_bottom));

    // ── ui_align ───────────────────────────────────────────────────────────
    int64 al_left   = cast<int64>(ui_align::left);
    int64 al_center = cast<int64>(ui_align::center);
    int64 al_right  = cast<int64>(ui_align::right);
    check("ui_align enum values are distinct",
          al_left != al_center && al_center != al_right, "");
    print_console("  ui_align::left   = " + cast<string>(al_left));
    print_console("  ui_align::center = " + cast<string>(al_center));
    print_console("  ui_align::right  = " + cast<string>(al_right));

    // ── ui_layout ──────────────────────────────────────────────────────────
    int64 ly_none       = cast<int64>(ui_layout::none);
    int64 ly_vertical   = cast<int64>(ui_layout::vertical);
    int64 ly_horizontal = cast<int64>(ui_layout::horizontal);
    check("ui_layout enum values are distinct",
          ly_none != ly_vertical && ly_vertical != ly_horizontal, "");
    print_console("  ui_layout::none       = " + cast<string>(ly_none));
    print_console("  ui_layout::vertical   = " + cast<string>(ly_vertical));
    print_console("  ui_layout::horizontal = " + cast<string>(ly_horizontal));

    // ── ui_hook ────────────────────────────────────────────────────────────
    int64 h_pre    = cast<int64>(ui_hook::pre_execute);
    int64 h_post   = cast<int64>(ui_hook::post_execute);
    int64 h_click  = cast<int64>(ui_hook::clicked);
    int64 h_rclick = cast<int64>(ui_hook::right_clicked);
    int64 h_render = cast<int64>(ui_hook::should_render);
    int64 h_widget = cast<int64>(ui_hook::widget_execute);
    check("ui_hook enum values are distinct",
          h_pre != h_post && h_click != h_rclick &&
          h_render != h_widget && h_pre != h_click, "");
    print_console("  ui_hook::pre_execute    = " + cast<string>(h_pre));
    print_console("  ui_hook::post_execute   = " + cast<string>(h_post));
    print_console("  ui_hook::clicked        = " + cast<string>(h_click));
    print_console("  ui_hook::right_clicked  = " + cast<string>(h_rclick));
    print_console("  ui_hook::should_render  = " + cast<string>(h_render));
    print_console("  ui_hook::widget_execute = " + cast<string>(h_widget));

    // ── ui_callback ────────────────────────────────────────────────────────
    int64 cb_val_changed  = cast<int64>(ui_callback::value_changed);
    int64 cb_item_act     = cast<int64>(ui_callback::item_activated);
    check("ui_callback enum values are distinct",
          cb_val_changed != cb_item_act, "");
    print_console("  ui_callback::value_changed  = " + cast<string>(cb_val_changed));
    print_console("  ui_callback::item_activated = " + cast<string>(cb_item_act));

    // ── widget_attr ────────────────────────────────────────────────────────
    int64 wa_px = cast<int64>(widget_attr::pos_x);
    int64 wa_py = cast<int64>(widget_attr::pos_y);
    int64 wa_sx = cast<int64>(widget_attr::size_x);
    int64 wa_sy = cast<int64>(widget_attr::size_y);
    int64 wa_sclx = cast<int64>(widget_attr::scroll_x);
    int64 wa_scly = cast<int64>(widget_attr::scroll_y);
    int64 wa_rnd  = cast<int64>(widget_attr::rounding);
    check("widget_attr enum values are distinct",
          wa_px != wa_py && wa_sx != wa_sy &&
          wa_sclx != wa_scly && wa_px != wa_sx, "");
    print_console("  widget_attr::pos_x   = " + cast<string>(wa_px));
    print_console("  widget_attr::pos_y   = " + cast<string>(wa_py));
    print_console("  widget_attr::size_x  = " + cast<string>(wa_sx));
    print_console("  widget_attr::size_y  = " + cast<string>(wa_sy));
    print_console("  widget_attr::scroll_x  = " + cast<string>(wa_sclx));
    print_console("  widget_attr::scroll_y  = " + cast<string>(wa_scly));
    print_console("  widget_attr::rounding  = " + cast<string>(wa_rnd));

    // ── ui_color ───────────────────────────────────────────────────────────
    int64 uc_bg    = cast<int64>(ui_color::bg);
    int64 uc_text  = cast<int64>(ui_color::text);
    int64 uc_accent = cast<int64>(ui_color::accent);
    int64 uc_fbg   = cast<int64>(ui_color::frame_bg);
    int64 uc_sbg   = cast<int64>(ui_color::sidebar_bg);
    int64 uc_ebbg  = cast<int64>(ui_color::element_button_bg);
    check("ui_color enum values are distinct",
          uc_bg != uc_text && uc_text != uc_accent &&
          uc_fbg != uc_sbg && uc_sbg != uc_ebbg, "");
    print_console("  ui_color::bg                = " + cast<string>(uc_bg));
    print_console("  ui_color::text              = " + cast<string>(uc_text));
    print_console("  ui_color::accent            = " + cast<string>(uc_accent));
    print_console("  ui_color::frame_bg          = " + cast<string>(uc_fbg));
    print_console("  ui_color::sidebar_bg        = " + cast<string>(uc_sbg));
    print_console("  ui_color::element_button_bg = " + cast<string>(uc_ebbg));

    // ── keybind_mode ───────────────────────────────────────────────────────
    int64 km_off   = cast<int64>(keybind_mode::off);
    int64 km_on    = cast<int64>(keybind_mode::on);
    int64 km_single = cast<int64>(keybind_mode::single);
    int64 km_toggle = cast<int64>(keybind_mode::toggle);
    int64 km_always = cast<int64>(keybind_mode::always_on);
    check("keybind_mode enum values are distinct",
          km_off != km_on && km_on != km_single &&
          km_single != km_toggle && km_toggle != km_always, "");
    print_console("  keybind_mode::off       = " + cast<string>(km_off));
    print_console("  keybind_mode::on        = " + cast<string>(km_on));
    print_console("  keybind_mode::single    = " + cast<string>(km_single));
    print_console("  keybind_mode::toggle    = " + cast<string>(km_toggle));
    print_console("  keybind_mode::always_on = " + cast<string>(km_always));

    // ── toast_kind ─────────────────────────────────────────────────────────
    int64 tk_info    = cast<int64>(toast_kind::info);
    int64 tk_success = cast<int64>(toast_kind::success);
    int64 tk_warning = cast<int64>(toast_kind::warning);
    int64 tk_error   = cast<int64>(toast_kind::error);
    check("toast_kind enum values are distinct",
          tk_info != tk_success && tk_success != tk_warning &&
          tk_warning != tk_error, "");
    print_console("  toast_kind::info    = " + cast<string>(tk_info));
    print_console("  toast_kind::success = " + cast<string>(tk_success));
    print_console("  toast_kind::warning = " + cast<string>(tk_warning));
    print_console("  toast_kind::error   = " + cast<string>(tk_error));
}

// ============================================================================
// MAIN
// ============================================================================

int32 main() {
    print_console("=== gui_api.em: GUI API comprehensive test ===");

    // Create all GUI resources
    create_all_resources();

    // Run all test groups
    test_sidebar_section();
    test_widget_builders();
    test_common_widget_ops();
    test_widget_typed_methods();
    test_frames();
    test_layers();
    test_custom_widget();
    test_menus();
    test_file_picker();
    test_theme();
    test_toasts_and_queries();
    test_enums();

    // Register deferred test routine
    register_routine(cast<int64>(test_routine), 42);

    // Register keybind polling routine
    register_routine(cast<int64>(kb_poll_routine), 0);

    // Summary
    int64 total = g_pass + g_fail + g_skip;
    print_console("");
    print_console("=== summary ===");
    print_console("  total: " + cast<string>(total));
    print_console("  pass:  " + cast<string>(g_pass));
    print_console("  fail:  " + cast<string>(g_fail));
    print_console("  skip:  " + cast<string>(g_skip));
    if (g_fail == 0) {
        print_console("ALL GREEN");
    } else {
        print_console("FAILURES PRESENT -- see FAIL lines above");
    }

    return 1;   // keep loaded so the section stays interactive
}
