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

#include "RemoteBridge.h"
#include "Utility.h"

bool (*framebuffer_update_callback)(int, uint8_t *, int fbW, int fbH, int x, int y, int w, int h);
void (*framebuffer_resize_callback)(int, int fbW, int fbH);
void (*failure_callback)(int, uint8_t *);

pCursorShapeUpdateCallback cursorShapeUpdateCallback;
pFrameBufferUpdateCallback frameBufferUpdateCallback;
pFrameBufferResizeCallback frameBufferResizeCallback;
pFailCallback failCallback;
pClientLogCallback clientLogCallback;
pYesNoCallback yesNoCallback;
FrameBuffer globalFb;

const int MAX_RESOLUTION_RETRIES = 3;

void signal_handler(int signal, siginfo_t *info, void *reserved) {
    client_log("Handling signal: %d", signal);
    failure_callback(-1, NULL);
}

void handle_signals(void) {
    struct sigaction handler;
    memset(&handler, 0, sizeof(handler));
    handler.sa_sigaction = signal_handler;
    handler.sa_flags = SA_SIGINFO;
    sigaction(SIGILL, &handler, NULL);
    sigaction(SIGABRT, &handler, NULL);
    sigaction(SIGBUS, &handler, NULL);
    sigaction(SIGFPE, &handler, NULL);
    sigaction(SIGSEGV, &handler, NULL);
    sigaction(SIGPIPE, &handler, NULL);
    sigaction(SIGINT, &handler, NULL);
}

bool updateFramebuffer(int instance, uint8_t *frameBuffer, int x, int y, int w, int h) {
    //client_log("Update received");
    if (!framebuffer_update_callback(instance, globalFb.frameBuffer, globalFb.fbW, globalFb.fbH, x, y, w, h)) {
        // This session is a left-over backgrounded session and must quit.
        client_log("Must quit background session with instance number %d", instance);
        return false;
    }
    return true;
}

void updateCursorShape(int instance, int w, int h, int x, int y, int *data) {
    cursorShapeUpdateCallback(instance, w, h, x, y, (uint8_t *)data);
}

int getCurrentFrameBufferWidth(void) {
    return globalFb.fbW;
}

int getCurrentFrameBufferHeight(void) {
    return globalFb.fbH;
}

uint8_t *getCurrentFrameBufferPixels(void) {
    return globalFb.frameBuffer;
}

void resetDesiredResolution(int width, int height) {
    globalFb.desiredFbW = width;
    globalFb.desiredFbH = height;
    globalFb.numResolutionRetries = 0;
}
