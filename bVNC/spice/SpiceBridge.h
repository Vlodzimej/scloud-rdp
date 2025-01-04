/**
 * Copyright (C) 2021- Morpheusly Inc. All rights reserved.
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 * USA.
 */

#ifndef SpiceBridge_h
#define SpiceBridge_h

#include <stdio.h>
#include <stdbool.h>
#include "Utility.h"

typedef struct {
    int instance;
    char vv_file[4096];
    char host[256];
    char port[12];
    char tls_port[12];
    char ws_port[12];
    char password[256];
    char ca_file[4096];
    char cert_subj[4096];
    int32_t enable_sound;
    int resolutionRequested;
} SpiceConnectionParameters;

void *initializeSpice(int instance, int width, int height,
                      pCursorShapeUpdateCallback cursorUpdateCallback,
                      bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                      void (*fb_resize_callback)(int instance, int fbW, int fbH),
                      void (*fail_callback)(int instance, uint8_t *),
                      void (*cl_log_callback)(int8_t *),
                      void (*cl_cb_callback)(char *),
                      int (*y_n_callback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int),
                      char* addr, char* port, char* ws_port, char* tls_port, char* password, char* ca_file,
                      char* cert_subject, bool enable_sound);
void *initializeSpiceVv(int instance, int width, int height,
                        void (*cursor_update_callback)(int instance, int w, int h, int x, int y, uint8_t *),
                        bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                        void (*fb_resize_callback)(int instance, int fbW, int fbH),
                        void (*fail_callback)(int instance, uint8_t *),
                        void (*cl_log_callback)(int8_t *),
                        void (*cl_cb_callback)(char *),
                        int (*y_n_callback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int),
                        char* file, bool enable_sound);
void disconnectSpice(void);

static void resizeSpiceBuffer(int bytesPerPixel, int width, int height);
static void updateSpiceBuffer(int x, int y, int w, int h);

void sendPointerEvent(int x, int y, int buttonId, int buttonState, int stateChanged, int isDown);

int getButtonState(bool, bool, bool, bool, bool);

int32_t spiceKeyEvent(int16_t isDown, int32_t hardware_keycode);

void requestResolution(int w, int h);

void initClipboard(void (*clientClipboardCallbackP)(char *));

#endif /* SpiceBridge_h */
