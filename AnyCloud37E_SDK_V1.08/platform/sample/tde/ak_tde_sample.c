#include "ak_lvgl.h"

int main() {
    sdk_run_config config= {0};

    config.mem_trace_flag = SDK_RUN_NORMAL;
    ak_sdk_init( &config );

    lvgl_port_init();

    lv_obj_t *label = lv_label_create(lv_scr_act(), NULL);
    lv_label_set_text(label, "Hello, Anyka!");
    lv_obj_align(label, NULL, LV_ALIGN_CENTER, 0, 0);

    while(1) {
        lv_task_handler();
        ak_sleep_ms(5);
    }

    osal_fb_munmap_viraddr(fbp, finfo.smem_len);
    close(fbfd);
    ak_tde_close();
    ak_sdk_exit();

    return 0;
}

