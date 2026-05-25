// 3dgame/main.em
//
// Entry point for "Voxlands" -- a procedurally generated voxel sandbox.
// All game code lives under voxlands/ and is pulled in via import.  This
// file just wires the modules together: state -> world -> gpu -> gui ->
// register routine.

import "C:/Users/senti/Documents/My Games/3dgame/voxlands/state.em";
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/world.em";
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/camera.em";
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/render.em";
import "C:/Users/senti/Documents/My Games/3dgame/voxlands/gui.em";

void render(int64 data) {
    int64 now = time_ms();
    update_input(now);
    render_scene();
    draw_crosshair();
    draw_hud();
}

int64 main() {
    init_state();
    generate_world();
    rebuild_world_cb();
    init_gpu();
    init_gui();

    register_routine(cast<int64>(render), 0);
    println("[voxlands] running -- WASD move, Space up, LCtrl down, LShift sprint, mouse look");
    return 1;
}
