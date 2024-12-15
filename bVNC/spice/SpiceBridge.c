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
#include "SpiceBridge.h"
#include "gst/gst.h"
#include "glue-service.h"
#include <glib.h>
#include "glue-spice-widget-priv.h"
#include <glue-service.h>
#define USE_CLIPBOARD
#include <glue-clipboard-client.h>
#include <glue-spice-widget.h>
#include <stdio.h>

SpiceConnectionParameters p;

pthread_t mainloop_worker;
pthread_t spice_worker;
int desiredFbW;
int desiredFbH;
uint32_t *guestClipboardP = NULL;
uint32_t *hostClipboardP = NULL;

static gint get_display_id(SpiceDisplay *display)
{
    SpiceDisplayPrivate *d = SPICE_DISPLAY_GET_PRIVATE(display);
    
    /* supported monitor_id only with display channel #0 */
    if (d->channel_id == 0 && d->monitor_id >= 0)
        return d->monitor_id;
    
    g_return_val_if_fail(d->monitor_id <= 0, -1);
    
    return d->channel_id;
}

void requestResolution(int w, int h) {
    SpiceDisplay* display = global_display();
    SpiceDisplayPrivate *d = SPICE_DISPLAY_GET_PRIVATE(display);
    if (d != NULL) {
        spice_main_channel_update_display_enabled(d->main, get_display_id(display), TRUE, FALSE);
        spice_main_channel_update_display(d->main, get_display_id(display), 0, 0, w, h, TRUE);
    }
}

void spiceConnectionFailure() {
    failure_callback(p.instance, (uint8_t*)"SPICE_SESSION_DISCONNECTED");
}

void spiceAuthenticationFailure() {
    failure_callback(p.instance, (uint8_t*)"SPICE_AUTHENTICATION_FAILED_TITLE");
}

void engine_spice_worker(void *data) {
    int result;
    SpiceGlibGlue_SetLogCallback(client_log_callback);
    if (strcmp(p.vv_file, "") != 0) {
        client_log("Starting SpiceGlibGlue_ConnectWithVv");
        result = SpiceGlibGlue_ConnectWithVv(p.vv_file, p.enable_sound);
    } else {
        client_log("Starting SpiceGlibGlue_Connect");
        result = SpiceGlibGlue_Connect(p.host, p.port, p.tls_port, p.ws_port, p.password,
                                       p.ca_file, p.cert_subj, p.enable_sound);
    }
    SpiceGlibGlue_SetBufferResizeCallback(resizeSpiceBuffer);
    SpiceGlibGlue_SetBufferUpdateCallback(updateSpiceBuffer);
    SpiceGlibGlue_SetDisconnectCallback(spiceConnectionFailure);
    SpiceGlibGlue_SetAuthFailedCallback(spiceAuthenticationFailure);
}

void engine_mainloop_worker(void *data) {
    SpiceGlibGlue_InitializeLogging(0);
    SpiceGlibGlue_MainLoop();
}

static void updateSpiceBuffer(int x, int y, int w, int h) {
    if (!updateFramebuffer(p.instance, globalFb.frameBuffer, x, y, w, h)) {
        disconnectSpice();
    }
}

/* Declaration of static plugins */
GST_PLUGIN_STATIC_DECLARE(coreelements);  GST_PLUGIN_STATIC_DECLARE(coretracers);  GST_PLUGIN_STATIC_DECLARE(adder);  GST_PLUGIN_STATIC_DECLARE(app);  GST_PLUGIN_STATIC_DECLARE(audioconvert);  GST_PLUGIN_STATIC_DECLARE(audiomixer);  GST_PLUGIN_STATIC_DECLARE(audiorate);  GST_PLUGIN_STATIC_DECLARE(audioresample);  GST_PLUGIN_STATIC_DECLARE(audiotestsrc);  GST_PLUGIN_STATIC_DECLARE(compositor);  GST_PLUGIN_STATIC_DECLARE(gio);  GST_PLUGIN_STATIC_DECLARE(overlaycomposition);  GST_PLUGIN_STATIC_DECLARE(rawparse);  GST_PLUGIN_STATIC_DECLARE(typefindfunctions);  GST_PLUGIN_STATIC_DECLARE(videoconvertscale);  GST_PLUGIN_STATIC_DECLARE(videorate);  GST_PLUGIN_STATIC_DECLARE(videotestsrc);  GST_PLUGIN_STATIC_DECLARE(volume);  GST_PLUGIN_STATIC_DECLARE(autodetect);  GST_PLUGIN_STATIC_DECLARE(videofilter);  GST_PLUGIN_STATIC_DECLARE(opus); GST_PLUGIN_STATIC_DECLARE(jpeg);
GST_PLUGIN_STATIC_DECLARE(osxaudio);

/* Call this function to register static plugins */
void gst_init_and_register_static_plugins () {
    GError * gst_init_error = NULL;
    gst_init_check(NULL, NULL, &gst_init_error);
    
    GST_PLUGIN_STATIC_REGISTER(coreelements);  GST_PLUGIN_STATIC_REGISTER(coretracers);  GST_PLUGIN_STATIC_REGISTER(adder);  GST_PLUGIN_STATIC_REGISTER(app);  GST_PLUGIN_STATIC_REGISTER(audioconvert);  GST_PLUGIN_STATIC_REGISTER(audiomixer);  GST_PLUGIN_STATIC_REGISTER(audiorate);  GST_PLUGIN_STATIC_REGISTER(audioresample);  GST_PLUGIN_STATIC_REGISTER(audiotestsrc);  GST_PLUGIN_STATIC_REGISTER(compositor);  GST_PLUGIN_STATIC_REGISTER(gio);  GST_PLUGIN_STATIC_REGISTER(overlaycomposition);  GST_PLUGIN_STATIC_REGISTER(rawparse);  GST_PLUGIN_STATIC_REGISTER(typefindfunctions);  GST_PLUGIN_STATIC_REGISTER(videoconvertscale);  GST_PLUGIN_STATIC_REGISTER(videorate);  GST_PLUGIN_STATIC_REGISTER(videotestsrc);  GST_PLUGIN_STATIC_REGISTER(volume);  GST_PLUGIN_STATIC_REGISTER(autodetect);  GST_PLUGIN_STATIC_REGISTER(videofilter);  GST_PLUGIN_STATIC_REGISTER(opus);  GST_PLUGIN_STATIC_REGISTER(jpeg);
    GST_PLUGIN_STATIC_REGISTER(osxaudio);
    
    if (gst_is_initialized()) {
        client_log("GStreamer successfully initialized");
    } else {
        client_log("GStreamer failed to initialize");
    }
}

static void initClipboardStorage() {
    if (guestClipboardP == NULL) {
        guestClipboardP = malloc(CB_SIZE);
    }
    if (hostClipboardP == NULL) {
        hostClipboardP = malloc(CB_SIZE);
    }
}

void initClipboard(void (*clientClipboardCallbackP)(char *)) {
    initClipboardStorage();
    SpiceGlibGlue_InitClipboard(true, true, guestClipboardP, hostClipboardP, clientClipboardCallbackP);
}

void clientCutText(void *c, char *hostClipboardContents, int size) {
    SpiceGlibGlue_GrabGuestClipboard();
    SpiceGlibGlue_ClientCutText(hostClipboardContents, size);
}

void *initializeSpice(int instance, int width, int height,
                      bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                      void (*fb_resize_callback)(int instance, int fbW, int fbH),
                      void (*fail_callback)(int instance, uint8_t *),
                      void (*cl_log_callback)(int8_t *),
                      void (*cl_cb_callback)(char *),
                      int (*y_n_callback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int),
                      char* addr, char* port, char* ws_port, char* tls_port, char* password, char* ca_file,
                      char* cert_subject, bool enable_sound) {
    client_log("Initializing SPICE session\n");
    
    framebuffer_update_callback = fb_update_callback;
    framebuffer_resize_callback = fb_resize_callback;
    failure_callback = fail_callback;
    client_log_callback = cl_log_callback;
    yes_no_callback = y_n_callback;
    
    gst_init_and_register_static_plugins();
    
    globalFb.fbW = 0;
    globalFb.fbH = 0;
    desiredFbW = width;
    desiredFbH = height;
    
    p.resolutionRequested = 0;
    p.instance = instance;
    strncpy(p.vv_file, "", sizeof(p.vv_file));
    if (addr != NULL)
        strncpy(p.host, addr, sizeof(p.host));
    if (port != NULL)
        strncpy(p.port, port, sizeof(p.port));
    if (ws_port != NULL)
        strncpy(p.ws_port, ws_port, sizeof(p.ws_port));
    if (tls_port != NULL)
        strncpy(p.tls_port, tls_port, sizeof(p.tls_port));
    if (password != NULL)
        strncpy(p.password, password, sizeof(p.password));
    if (ca_file != NULL)
        strncpy(p.ca_file, ca_file, sizeof(p.ca_file));
    if (cert_subject != NULL)
        strncpy(p.cert_subj, cert_subject, sizeof(p.cert_subj));
    p.enable_sound = enable_sound;
    initClipboard(cl_cb_callback);
    pthread_create(&spice_worker, NULL, (void *) &engine_spice_worker, NULL);
    pthread_create(&mainloop_worker, NULL, (void *) &engine_mainloop_worker, NULL);
    client_log("Done initializing SPICE session\n");
    return (void *)&p;
}

void *initializeSpiceVv(int instance, int width, int height,
                        bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                        void (*fb_resize_callback)(int instance, int fbW, int fbH),
                        void (*fail_callback)(int instance, uint8_t *),
                        void (*cl_log_callback)(int8_t *),
                        void (*cl_cb_callback)(char *),
                        int (*y_n_callback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int),
                        char* vv_file, bool enable_sound) {
    client_log("Initializing SPICE session from vv file\n");
    
    framebuffer_update_callback = fb_update_callback;
    framebuffer_resize_callback = fb_resize_callback;
    failure_callback = fail_callback;
    client_log_callback = cl_log_callback;
    yes_no_callback = y_n_callback;
    
    gst_init_and_register_static_plugins();
    
    globalFb.fbW = 0;
    globalFb.fbH = 0;
    desiredFbW = width;
    desiredFbH = height;
    
    p.resolutionRequested = 0;
    p.instance = instance;
    if (vv_file != NULL) {
        strncpy(p.vv_file, vv_file, sizeof(p.vv_file));
    }
    p.enable_sound = enable_sound;
    initClipboard(cl_cb_callback);
    pthread_create(&spice_worker, NULL, (void *) &engine_spice_worker, NULL);
    pthread_create(&mainloop_worker, NULL, (void *) &engine_mainloop_worker, NULL);
    client_log("Done initializing SPICE session from file\n");
    return (void *)&p;
}

static void resizeSpiceBuffer(int bytesPerPixel, int width, int height) {
    client_log("Resizing Draw Buffer, allocating buffer\n");
    client_log("Width, height: %d, %d\n", globalFb.fbW, globalFb.fbH);
    SpiceGlibGlueLockDisplayBuffer(&width, &height);
    if (globalFb.oldFrameBuffer != NULL) {
        client_log("Freeing old framebuffer");
        free(globalFb.oldFrameBuffer);
        globalFb.oldFrameBuffer = NULL;
    }
    globalFb.oldFrameBuffer = globalFb.frameBuffer;
    int pixel_buffer_size = bytesPerPixel*width*height*sizeof(char);
    uint8_t* new_buffer = (uint8_t*)malloc(pixel_buffer_size);
    globalFb.frameBuffer = new_buffer;
    globalFb.fbW = width;
    globalFb.fbH = height;
    if (width > 0 && height > 0) {
        framebuffer_resize_callback(p.instance, globalFb.fbW, globalFb.fbH);
        updateFramebuffer(p.instance, globalFb.frameBuffer, 0, 0, globalFb.fbW, globalFb.fbH);
    }
    SpiceGlibGlueSetDisplayBuffer((uint32_t *)globalFb.frameBuffer, width, height);
    SpiceGlibGlueUnlockDisplayBuffer();
    
    if (globalFb.fbW > 0 && globalFb.fbH > 0 &&
        (globalFb.fbW != desiredFbW || globalFb.fbH != desiredFbH) &&
        p.resolutionRequested == 0) {
        client_log("Requesting new width, height: %d, %d\n", desiredFbW, desiredFbH);
        requestResolution(desiredFbW, desiredFbH);
        p.resolutionRequested = 1;
    }
}

void disconnectSpice() {
    SpiceGlibGlue_Disconnect();
}

void sendPointerEvent(int x, int y, int buttonId, int buttonState, int stateChanged, int isDown) {
    if (stateChanged) {
        SpiceGlibGlueMotionEvent(x, y, (int16_t)buttonState);
        SpiceGlibGlueButtonEvent(x, y, (int16_t)buttonId, (int16_t)buttonState, (int16_t)isDown);
    } else {
        SpiceGlibGlueMotionEvent(x, y, (int16_t)buttonState);
    }
}

int getButtonState(bool firstDown, bool secondDown, bool thirdDown, bool scrollUp, bool scrollDown) {
    int newButtonState = 0;
    if (firstDown) {
        newButtonState |= SPICE_MOUSE_BUTTON_MASK_LEFT;
    } else {
        newButtonState &= ~SPICE_MOUSE_BUTTON_MASK_LEFT;
    }
    if (secondDown) {
        newButtonState |= SPICE_MOUSE_BUTTON_MASK_MIDDLE;
    } else {
        newButtonState &= ~SPICE_MOUSE_BUTTON_MASK_MIDDLE;
    }
    if (thirdDown) {
        newButtonState |= SPICE_MOUSE_BUTTON_MASK_RIGHT;
    } else {
        newButtonState &= ~SPICE_MOUSE_BUTTON_MASK_RIGHT;
    }
    /*
     if (scrollUp) {
     newButtonState |= SPICE_MOUSE_BUTTON_UP;
     } else {
     newButtonState &= ~SPICE_MOUSE_BUTTON_UP;
     }
     if (scrollDown) {
     newButtonState |= SPICE_MOUSE_BUTTON_DOWN;
     } else {
     newButtonState &= ~SPICE_MOUSE_BUTTON_DOWN;
     }*/
    return newButtonState;
}

int32_t spiceKeyEvent(int16_t isDown, int32_t hardware_keycode) {
    return SpiceGlibGlue_SpiceKeyEvent(isDown, hardware_keycode);
}

