#ifndef LV_CONF_H
#define LV_CONF_H

#include <stdint.h>
typedef int16_t lv_coord_t;

/*====================
 *    LVGL CONFIGURATION
 *     ====================*/

/* Enable LVGL features */
#define LV_USE_LOG 1             /* Enable logging */
#define LV_LOG_LEVEL LV_LOG_LEVEL_INFO /* Set log level */

#define LV_COLOR_DEPTH 32        /* Set color depth (e.g., 16-bit RGB565) */
#define LV_COLOR_16_SWAP 0       /* Set to 1 if swapping bytes is needed */

#define LV_HOR_RES_MAX 1024       /* Adjust for your screen resolution */
#define LV_VER_RES_MAX 600      /* Adjust for your screen resolution */

#define LV_USE_GPU 0             /* Disable GPU acceleration (Anyka 3760D likely doesn't have one) */

#define LV_TICK_CUSTOM 0         /* Use a custom tick source */
#define LV_TICK_CUSTOM_INCLUDE "your_tick_function.h" /* Include custom tick file */
#define LV_TICK_CUSTOM_SYS_TIME_EXPR (your_custom_tick_function()) /* Define tick function */

#define LV_MEM_SIZE (32 * 1024/* * 1024 */)  /* Adjust memory allocation for LVGL objects */

#define LV_DISP_DEF_REFR_PERIOD 30  /* Refresh every 30 ms */

#define LV_USE_INDEV 1
#define LV_USE_EVDEV 1  // Enable evdev input driver

#define LV_USE_DEMO_WIDGETS 1

#endif /* LV_CONF_H */

