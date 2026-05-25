// voxlands/gui.em
//
// Sidebar widgets and their callbacks.  Imports world.em so the
// "Regenerate world" button can rebuild terrain + reupload the CB.

#pragma once
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/state.em";
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/world.em";

void on_sens_change(int64 w)  { g_sens_mult  = g_sens_slider.get(); }
void on_speed_change(int64 w) { g_move_speed = g_speed_slider.get(); }
void on_invx_change(int64 w)  { if (g_invert_x_cb.get()) g_inv_x = 1; else g_inv_x = 0; }
void on_invy_change(int64 w)  { if (g_invert_y_cb.get()) g_inv_y = 1; else g_inv_y = 0; }
void on_regen_click(int64 w)  {
    g_seed = cast<float64>(time_ms() % 1000000);
    generate_world();
    rebuild_world_cb();
    g_cam_x = cast<float64>(WORLD_X) * 0.5;
    g_cam_z = cast<float64>(WORLD_Z) * 0.5;
    g_cam_y = cast<float64>(WORLD_Y) + 4.0;
    g_yaw   = 0.0;
    g_pitch = 1.0;       // ~57 deg looking down -- terrain dominates the view
}

void init_gui() {
    sidebar_section_t sec = create_sidebar_section("Voxlands", "");

    g_sens_slider = sec.create_slider("Sensitivity", 1.0, 0.1, 5.0, 0.05);
    g_sens_slider.set_tooltip("Mouse sensitivity multiplier");
    g_sens_slider.on_change(cast<int64>(on_sens_change));
    g_sens_mult = g_sens_slider.get();

    g_invert_x_cb = sec.create_checkbox("Invert X", false);
    g_invert_x_cb.on_change(cast<int64>(on_invx_change));
    g_invert_y_cb = sec.create_checkbox("Invert Y", false);
    g_invert_y_cb.on_change(cast<int64>(on_invy_change));

    sec.create_separator();

    g_speed_slider = sec.create_slider("Move speed", 6.0, 1.0, 24.0, 0.5);
    g_speed_slider.set_tooltip("Walking speed in blocks per second (Shift = sprint).");
    g_speed_slider.on_change(cast<int64>(on_speed_change));
    g_move_speed = g_speed_slider.get();

    sec.create_separator();

    button_t regen_btn = sec.create_button("Regenerate world", ui_align::center);
    regen_btn.on_change(cast<int64>(on_regen_click));
}
