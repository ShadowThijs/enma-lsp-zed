// voxlands/camera.em
//
// Camera basis derivation from yaw/pitch + per-frame input integration
// (mouse-look, WASD/Space/Ctrl movement, Shift sprint).

#pragma once
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/state.em";

vec3 cam_forward() {
    return vec3(cos(g_pitch) * sin(g_yaw),
                -sin(g_pitch),
                cos(g_pitch) * cos(g_yaw));
}
vec3 cam_right() { return vec3(cos(g_yaw), 0.0, -sin(g_yaw)); }
vec3 cam_up()    { vec3 f = cam_forward(); vec3 r = cam_right(); return f.cross(r); }

void update_input(int64 now) {
    if (g_t_prev == 0) g_t_prev = now;
    float64 dt = cast<float64>(now - g_t_prev) * 0.001;
    g_t_prev = now;
    if (dt > 0.1) dt = 0.1;

    // ---- mouse-look ----
    vec2 d = get_mouse_delta();
    float64 sx = -1.0;
    if (g_inv_x == 1) sx = 1.0;
    float64 sy = -1.0;
    if (g_inv_y == 1) sy = 1.0;
    float64 step = g_sens_base * g_sens_mult;
    g_yaw   = g_yaw   + d.x * step * sx;
    g_pitch = g_pitch + d.y * step * sy;
    if (g_pitch >  1.45) g_pitch =  1.45;
    if (g_pitch < -1.45) g_pitch = -1.45;

    // ---- movement ----
    vec3 fwd   = cam_forward();
    vec3 right = cam_right();
    float64 fx = fwd.x;
    float64 fz = fwd.z;
    float64 hlen = sqrt(fx * fx + fz * fz);
    if (hlen > 0.001) { fx = fx / hlen; fz = fz / hlen; }

    float64 mx = 0.0;
    float64 my = 0.0;
    float64 mz = 0.0;
    if (key_down(vk::w))     { mx = mx + fx;       mz = mz + fz; }
    if (key_down(vk::s))     { mx = mx - fx;       mz = mz - fz; }
    if (key_down(vk::a))     { mx = mx - right.x;  mz = mz - right.z; }
    if (key_down(vk::d))     { mx = mx + right.x;  mz = mz + right.z; }
    if (key_down(vk::space)) my = my + 1.0;
    if (key_down(vk::lctrl)) my = my - 1.0;

    float64 hl = sqrt(mx * mx + mz * mz);
    if (hl > 0.001) { mx = mx / hl; mz = mz / hl; }

    float64 spd = g_move_speed;
    if (key_down(vk::lshift)) spd = spd * 2.5;

    g_cam_x = g_cam_x + mx * spd * dt;
    g_cam_y = g_cam_y + my * spd * dt;
    g_cam_z = g_cam_z + mz * spd * dt;
}
