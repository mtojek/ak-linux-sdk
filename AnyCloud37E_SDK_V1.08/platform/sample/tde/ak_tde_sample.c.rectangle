#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>
#include <linux/fb.h>
#include <sys/ioctl.h>
#include <string.h>

#define BITS_PER_PIXEL              24
#define LEN_COLOR                   8

enum color_offset {
        OFFSET_RED = 16,
        OFFSET_GREEN = 8,
        OFFSET_BLUE = 0,
};

#define DUAL_FB_FIX                 finfo.reserved[ 0 ]
#define DUAL_FB_VAR                 vinfo.reserved[ 0 ]

//#include "ak37e/base.h"
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

static struct ak_tde_layer tde_layer_screen = { 0 , 0 , 0 , 0 , 0 , 0 , 0 , GP_FORMAT_RGB888 } ;
static struct ak_tde_layer tde_layer_bg = { 0 , 0 , 0 , 0 , 0 , 0 , 0 , GP_FORMAT_RGB888 } ;
												 
static int fbfd = -1;

static struct fb_fix_screeninfo finfo;
static struct fb_var_screeninfo vinfo;

static void * fbp;

int main() {
    sdk_run_config config= {0};

    config.mem_trace_flag = SDK_RUN_NORMAL;
    ak_sdk_init( &config );

    int r = ak_tde_open();
    if (r != ERROR_TYPE_NO_ERROR) {
        perror("ak_tde_open failed");
        return 1;
    }

    fbfd = open("/dev/fb0", O_RDWR);

    if (fbfd == -1) {
        perror("Error: cannot open framebuffer device");
        return 1;
    }

    if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo) == -1) {
        perror("Error reading fixed information");
        close(fbfd);
        return 1;
    }

    if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo) == -1) {
        perror("Error reading variable information");
        close(fbfd);
        return 1;
    }


    if ( DUAL_FB_FIX == AK_TRUE )  {
	    printf("dual fb mode\n");
    }

    tde_layer_bg.width = 1024;
    tde_layer_bg.height = 600;
    tde_layer_bg.pos_left = 0;
    tde_layer_bg.pos_top = 0;
    tde_layer_bg.pos_width = 1024;
    tde_layer_bg.pos_height = 600;                  

    extern void *osal_fb_mmap_viraddr(int fb_len, int fb_fd);
    extern int osal_fb_munmap_viraddr(void *addr, int fb_len);

    fbp = osal_fb_mmap_viraddr(finfo.smem_len, fbfd);
    if (fbp == MAP_FAILED) {
        perror("Failed to mmap framebuffer");
        close(fbfd);
        return 1;
    }

    printf("vinfo.xres_virtual = %d, vinfo.yres_virtual = %d\n", vinfo.xres_virtual, vinfo.yres_virtual);

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
        return 1;
    }

    // Clear screen (black)
    memset(fbp, 0, finfo.smem_len);

    tde_layer_screen.width      = vinfo.xres;
    tde_layer_screen.height     = vinfo.yres;
    tde_layer_screen.pos_left   = 0;
    tde_layer_screen.pos_top    = 0;
    tde_layer_screen.pos_width  = vinfo.xres;
    tde_layer_screen.pos_height = vinfo.yres;

    if ( DUAL_FB_FIX == AK_TRUE )  {
        DUAL_FB_VAR ^= 1;
        tde_layer_screen.phyaddr = finfo.smem_start + DUAL_FB_VAR * tde_layer_screen.width * tde_layer_screen.height * 3;
    } else {
        tde_layer_screen.phyaddr  = finfo.smem_start;
    }

    void * p_vaddr_bg = ak_mem_dma_alloc(1, tde_layer_screen.width * tde_layer_screen.height * 3);
    ak_mem_dma_vaddr2paddr( p_vaddr_bg , ( unsigned long * )&tde_layer_bg.phyaddr );

    printf("finfo.smem_start = %lu\n", finfo.smem_start);
    printf("tde_layer_screen.phyaddr = %lu\n", tde_layer_screen.phyaddr);

    // Draw a red rectangle
    printf("vinfo.yres: %d\n", vinfo.yres);
    printf("vinfo.xres: %d\n", vinfo.xres);
    printf("finfo.line_length: %d\n", finfo.line_length);
    printf("vinfo_bits_per_pixel: %d\n", vinfo.bits_per_pixel);
 
    unsigned long x = 0, y = 0;
    for (y = 0; y < 600; y++) {
    for (x = 0; x < 1024; x++) {
        char *location = ((char *) p_vaddr_bg) + (y * 3072) + (x * 3);  // Ensure correct pointer arithmetic

        if (y <= 600 / 4 || x <= 1024 / 4 || y >= (3 * 600 / 4) || x >= (3 * 1024 / 4)) {
            *(location) = 0;     // Red                                                                          
            *(location + 1) = 102;                                                  
            *(location + 2) = 102;                           
        } else {                               
            *(location) = 53;
            *(location + 1) = 51; // Green
            *(location + 2) = 220;             
        }
                                 
    }        
    } 

    r = ak_tde_opt_scale(&tde_layer_bg, &tde_layer_screen);
    if (r != ERROR_TYPE_NO_ERROR) {
        perror("ak_tde_opt_scale failed");
        return 1;
    }

    if ( DUAL_FB_FIX == AK_TRUE )  {                                            //如果使用双buffer的话则调用ioctl
										//
        vinfo.activate = 128;
        print_fb_var_screeninfo(vinfo);

        if (ioctl(fbfd, FBIOPUT_VSCREENINFO, &vinfo) == -1) {
         perror("Failed to put framebuffer 2");
         close(fbfd);
         return 1;
        }	

    }
    sleep(1);

    ak_mem_dma_free(p_vaddr_bg);

    osal_fb_munmap_viraddr(fbp, finfo.smem_len);
    close(fbfd);
    ak_tde_close();
    ak_sdk_exit();

    return 0;
}

