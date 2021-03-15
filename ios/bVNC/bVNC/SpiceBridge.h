//
//  SpiceBridge.h
//  bVNC
//
//  Created by iordan iordanov on 2021-03-16.
//  Copyright © 2021 iordan iordanov. All rights reserved.
//

#ifndef SpiceBridge_h
#define SpiceBridge_h

#include <stdio.h>
#include <stdbool.h>
#include <glue-service.h>
#include <glue-spice-widget.h>
#include "Utility.h"

typedef struct {
    int instance;
    char host[256];
    char port[12];
    char tls_port[12];
    char ws_port[12];
    char password[256];
    char ca_file[4096];
    char cert_subj[4096];
    int32_t enable_sound;
    uint8_t *frameBuffer;
} SpiceConnectionParameters;

void *initializeSpice(int instance,
                   bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                   void (*fb_resize_callback)(int instance, int fbW, int fbH),
                   void (*fail_callback)(int instance, uint8_t *),
                   void (*cl_log_callback)(int8_t *),
                   int (*y_n_callback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int),
                   char* addr, char* port, char* ws_port, char* tls_port, char* password, char* ca_file,
                   char* cert_subject, bool enable_sound);
void disconnectSpice(void);

static void resizeSpiceBuffer(int bytesPerPixel, int width, int height);
static void updateSpiceBuffer(int x, int y, int w, int h);

void sendPointerEvent(int x, int y, int buttonId, int buttonState, int stateChanged, int isDown);

#endif /* SpiceBridge_h */
