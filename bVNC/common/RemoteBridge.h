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

#ifndef RemoteBridge_h
#define RemoteBridge_h

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <signal.h>
#include <string.h>

typedef struct {
    uint8_t *frameBuffer;
    uint8_t *oldFrameBuffer;
    int resolutionRequested;
    int fbW;
    int fbH;
    int desiredFbW;
    int desiredFbH;
    int numResolutionRetries;
} FrameBuffer;

extern const int MAX_RESOLUTION_RETRIES;

extern FrameBuffer globalFb;

typedef bool (*pFrameBufferUpdateCallback)(int instance, uint8_t *buffer, int fbW, int fbH, int x, int y, int w, int h);
extern pFrameBufferUpdateCallback frameBufferUpdateCallback;
typedef void (*pFrameBufferResizeCallback)(int instance, int fbW, int fbH);
extern pFrameBufferResizeCallback frameBufferResizeCallback;
typedef void (*pFailCallback)(int instance, uint8_t *);
extern pFailCallback failCallback;
typedef void (*pClientLogCallback)(char *);
extern pClientLogCallback clientLogCallback;
typedef void (*pClientClipboardCallback)(uint8_t *, long);
extern pClientClipboardCallback clientClipboardCallback;
typedef int (*pYesNoCallback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int);
extern pYesNoCallback yesNoCallback;

extern bool (*framebuffer_update_callback)(int, uint8_t *, int fbW, int fbH, int x, int y, int w, int h);
extern void (*framebuffer_resize_callback)(int instance, int fbW, int fbH);
extern void (*failure_callback)(int, uint8_t *);

bool updateFramebuffer(int instance, uint8_t *frameBuffer, int x, int y, int w, int h);
void signal_handler(int signal, siginfo_t *info, void *reserved);
void handle_signals(void);
void clientCutText(void *c, char *hostClipboardContents, int size);
void handle_signals(void);
FrameBuffer *getCurrentFrameBuffer(void);
void resetDesiredResolution(int width, int height);

#endif /* RemoteBridge_h */
