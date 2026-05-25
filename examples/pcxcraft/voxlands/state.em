// voxlands/state.em
//
// Shared globals, constants, and one-time state init.
// Every other voxlands module imports this.

#pragma once

// ----------------------------- constants -----------------------------

int64 WORLD_X      = 16;
int64 WORLD_Y      = 8;
int64 WORLD_Z      = 16;
int64 WORLD_TOTAL  = 2048;       // WORLD_X * WORLD_Y * WORLD_Z
int64 WORLD_CB_V4  = 512;        // WORLD_TOTAL / 4

// World-gen biome thresholds (in voxel y).
int64 SEA_LEVEL    = 2;          // water fills empty cells up to here
int64 SNOW_LEVEL   = 6;          // peaks at or above here cap with snow

// ----------------------------- world data -----------------------------

int64[]   g_world;               // block IDs, length WORLD_TOTAL
float32[] g_world_cb_data;       // packed for the WorldCB upload (8192 floats)
float64   g_seed = 0.0;

// ----------------------------- camera -----------------------------

float64 g_cam_x  = 8.0;
float64 g_cam_y  = 12.0;
float64 g_cam_z  = 8.0;
float64 g_yaw    = 0.0;
float64 g_pitch  = 1.0;
float64 g_tan_half;

// ----------------------------- settings -----------------------------

float64 g_sens_base   = 0.0025;
float64 g_sens_mult   = 1.0;
float64 g_move_speed  = 6.0;
int64   g_inv_x       = 0;
int64   g_inv_y       = 0;

// ----------------------------- timing -----------------------------

int64 g_t_app_start;
int64 g_t_prev = 0;

// ----------------------------- gpu resources -----------------------------

int64 g_shader;
int64 g_vb;
int64 g_cb;

// ----------------------------- widgets -----------------------------

slider_t   g_sens_slider;
slider_t   g_speed_slider;
checkbox_t g_invert_x_cb;
checkbox_t g_invert_y_cb;

void init_state() {
    g_t_app_start = time_ms();
    g_t_prev      = g_t_app_start;
    g_tan_half    = tan(40.0 * 3.14159265 / 180.0);   // 80 deg vFOV
    g_seed        = cast<float64>(time_ms() % 1000000);
}
