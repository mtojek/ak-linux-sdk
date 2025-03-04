#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <sys/ioctl.h>
#include <string.h>

#include "lvgl/lvgl.h"
#include "lv_drivers/indev/evdev.h"
#include "lv_drivers/display/fbdev.h"

#include "ak_mem.h"
#include "ak_common_graphics.h"
#include "ak_tde.h"


void print_fb_var_screeninfo(struct fb_var_screeninfo vinfo) {
    printf("Framebuffer Variable Screen Information:\n");
    printf("-----------------------------------------\n");
    printf("Resolution:        %d x %d\n", vinfo.xres, vinfo.yres);
    printf("Virtual Resolution:%d x %d\n", vinfo.xres_virtual, vinfo.yres_virtual);
    printf("Offset:            %d x %d\n", vinfo.xoffset, vinfo.yoffset);
    printf("Bits per Pixel:    %d\n", vinfo.bits_per_pixel);
    printf("Grayscale:         %d\n", vinfo.grayscale);
    printf("\nColor Offsets and Lengths:\n");  
    printf("Red:    Offset=%d, Length=%d\n", vinfo.red.offset, vinfo.red.length);
    printf("Green:  Offset=%d, Length=%d\n", vinfo.green.offset, vinfo.green.length);
    printf("Blue:   Offset=%d, Length=%d\n", vinfo.blue.offset, vinfo.blue.length);
    printf("Transp: Offset=%d, Length=%d\n", vinfo.transp.offset, vinfo.transp.length);
    printf("\nMiscellaneous:\n");
    printf("Pixel Clock:       %d ps\n", vinfo.pixclock);
    printf("Refresh Rate:      %d Hz\n", vinfo.vmode);
    printf("Activate Flags:    %d\n", vinfo.activate);
    printf("Sync:              %d\n", vinfo.sync);
    printf("Rotate:            %d\n", vinfo.rotate);
    printf("Nonstandard:       %d\n", vinfo.nonstd);
    printf("\n");
}

// Placeholder for display buffer size (adjust based on available memory)
#define SCREEN_WIDTH 1024

// Stub function for initializing the display
void display_init(void) {
    printf("Initializing display...\n");
   
    int r = ak_tde_open();
    if (r != ERROR_TYPE_NO_ERROR) {
        perror("ak_tde_open failed");
        return;
    }

    fbdev_init();
}

void lvgl_port_init(void) {
    lv_init();
    display_init();
    evdev_init();

    static lv_disp_buf_t disp_buf;
    static lv_color_t buf1[SCREEN_WIDTH * 100];
    lv_disp_buf_init(&disp_buf, buf1, NULL, SCREEN_WIDTH * 100);

    lv_disp_drv_t disp_drv;
    lv_disp_drv_init(&disp_drv);
    disp_drv.buffer = &disp_buf;
    disp_drv.flush_cb = fbdev_flush;
    lv_disp_drv_register(&disp_drv);

    lv_indev_drv_t indev_drv;
    lv_indev_drv_init(&indev_drv);
    indev_drv.type = LV_INDEV_TYPE_POINTER;
    indev_drv.read_cb = evdev_read;  // Use evdev for touch input
    lv_indev_drv_register(&indev_drv);

    printf("LVGL initialized.\n");
}

