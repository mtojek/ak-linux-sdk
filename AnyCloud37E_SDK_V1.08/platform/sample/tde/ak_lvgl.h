#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <sys/ioctl.h>
#include <string.h>

#include "lvgl/lvgl.h"
#include "lv_drivers/indev/evdev.h"

#include "ak_mem.h"
#include "ak_common_graphics.h"
#include "ak_tde.h"

extern void *osal_fb_mmap_viraddr(int fb_len, int fb_fd);
extern int osal_fb_munmap_viraddr(void *addr, int fb_len);

#define FBIOGET_CUS_LCDBUSY (0x4680)

#define BITS_PER_PIXEL 24              
#define LEN_COLOR      8
 
enum color_offset {
    OFFSET_RED = 16,                                                                        
    OFFSET_GREEN = 8,                                                                   
    OFFSET_BLUE = 0,                                                                         
};                   

#define DUAL_FB_FIX finfo.reserved[0]
#define DUAL_FB_VAR vinfo.reserved[0]

static void * fbp;
                                                                                                 
static int fbfd = -1;
static struct fb_fix_screeninfo finfo;
static struct fb_var_screeninfo vinfo;

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
#define LV_BUF_SIZE (1024 * 600)

static lv_color_t buf1[LV_BUF_SIZE];

static lv_disp_buf_t draw_buf;

// Stub function for initializing the display
void display_init(void) {
    printf("Initializing display...\n");
   
    int r = ak_tde_open();
    if (r != ERROR_TYPE_NO_ERROR) {
        perror("ak_tde_open failed");
        return;
    }

    fbfd = open("/dev/fb0", O_RDWR);

    if (fbfd == -1) {
        perror("Error: cannot open framebuffer device");
        return;
    }

    if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo) == -1) {
        perror("Error reading fixed information");
        close(fbfd);
        return;
    }

    if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) == -1) {
        perror("Error reading variable information");
        close(fbfd);
        return;
    }

    // mmap
    int screensize = vinfo.yres_virtual * finfo.line_length;
    //fbp = mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);	    
    fbp = osal_fb_mmap_viraddr(finfo.smem_len, fbfd);
    if (fbp == MAP_FAILED) {
        perror("Failed to mmap framebuffer");
        close(fbfd);
        return;
    }

    vinfo.activate |= FB_ACTIVATE_FORCE;
    vinfo.activate |= FB_ACTIVATE_NOW;
    vinfo.xres = vinfo.xres_virtual;
    vinfo.yres = vinfo.yres_virtual;
    vinfo.bits_per_pixel = BITS_PER_PIXEL;
    vinfo.red.offset = OFFSET_RED;
    vinfo.red.length = LEN_COLOR;
    vinfo.green.offset = OFFSET_GREEN;
    vinfo.green.length = LEN_COLOR;
    vinfo.blue.offset = OFFSET_BLUE;
    vinfo.blue.length = LEN_COLOR;

    print_fb_var_screeninfo(vinfo);
    
    if (ioctl(fbfd, FBIOPUT_VSCREENINFO, &vinfo) == -1) {
        perror("Failed to put framebuffer");
        close(fbfd);
        return;
    }

    memset(fbp, 0, finfo.smem_len); // Clear screen
}

// Stub function for flushing the display
void display_flush(lv_disp_drv_t *disp_drv, const lv_area_t *area, lv_color_t *color_p) {
    unsigned long x = 0, y = 0;
    uint8_t *fb = (uint8_t *)fbp;

    unsigned long stat = 1;
    while (stat) {
	int ret = ioctl(fbfd, FBIOGET_CUS_LCDBUSY, &stat);
	if (ret < 0) {
		perror("lcdbusy failed");
	}
	if (stat > 0) {
	   printf("busy stat: %lu\n", stat);
	}
	ak_sleep_ms(1);
    }

    for (y = 0; y < 600; y++) {
        for (x = 0; x < 1024; x++) {
            long location = y * 3072 + x * 3;

            fb[location] = color_p[y * 1024 + x].ch.red;
            fb[location + 1] = color_p[y * 1024 + x].ch.green;
            fb[location + 2] = color_p[y * 1024 + x].ch.blue;
        }
    }

    ak_sleep_ms(4);

    lv_disp_flush_ready(disp_drv);
}

void lvgl_port_init(void) {
    lv_init();
    display_init();
    evdev_init();

    lv_disp_buf_init(&draw_buf, buf1, NULL, LV_BUF_SIZE);

    lv_disp_drv_t disp_drv;
    lv_disp_drv_init(&disp_drv);
    disp_drv.buffer = &draw_buf;
    disp_drv.flush_cb = display_flush;
    disp_drv.hor_res = 1024; // Adjust based on actual resolution
    disp_drv.ver_res = 600; // Adjust based on actual resolution
    lv_disp_drv_register(&disp_drv);

    lv_indev_drv_t indev_drv;
    lv_indev_drv_init(&indev_drv);
    indev_drv.type = LV_INDEV_TYPE_POINTER;
    indev_drv.read_cb = evdev_read;  // Use evdev for touch input
    lv_indev_drv_register(&indev_drv);

    printf("LVGL initialized.\n");
}

