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

SpiceConnectionParameters p;

pthread_t mainloop_worker;
pthread_t spice_worker;
extern int fbW;
extern int fbH;

static gint get_display_id(SpiceDisplay *display)
{
    SpiceDisplayPrivate *d = SPICE_DISPLAY_GET_PRIVATE(display);

    /* supported monitor_id only with display channel #0 */
    if (d->channel_id == 0 && d->monitor_id >= 0)
        return d->monitor_id;

    g_return_val_if_fail(d->monitor_id <= 0, -1);

    return d->channel_id;
}

static void requestResolution(int w, int h) {
    SpiceDisplay* display = global_display();
    SpiceDisplayPrivate *d = SPICE_DISPLAY_GET_PRIVATE(display);
    spice_main_channel_update_display_enabled(d->main, get_display_id(display), TRUE, FALSE);
    spice_main_channel_update_display(d->main, get_display_id(display), 0, 0, w, h, TRUE);
}

void spiceConnectionFailure() {
    failure_callback(p.instance, (uint8_t*)"SPICE_SESSION_DISCONNECTED");
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
    SpiceGlibGlue_SetBufferDisconnectCallback(spiceConnectionFailure);
}

void engine_mainloop_worker(void *data) {
    SpiceGlibGlue_InitializeLogging(0);
    SpiceGlibGlue_MainLoop();
}

static void updateSpiceBuffer(int x, int y, int w, int h) {
    if (!updateFramebuffer(p.instance, p.frameBuffer, x, y, w, h)) {
        disconnectSpice();
    }
}

/* Declaration of static plugins */
GST_PLUGIN_STATIC_DECLARE(coreelements);  GST_PLUGIN_STATIC_DECLARE(coretracers);  GST_PLUGIN_STATIC_DECLARE(adder);  GST_PLUGIN_STATIC_DECLARE(app);  GST_PLUGIN_STATIC_DECLARE(audioconvert);  GST_PLUGIN_STATIC_DECLARE(audiomixer);  GST_PLUGIN_STATIC_DECLARE(audiorate);  GST_PLUGIN_STATIC_DECLARE(audioresample);  GST_PLUGIN_STATIC_DECLARE(audiotestsrc);  GST_PLUGIN_STATIC_DECLARE(compositor);  GST_PLUGIN_STATIC_DECLARE(gio);  GST_PLUGIN_STATIC_DECLARE(overlaycomposition);  GST_PLUGIN_STATIC_DECLARE(pango);  GST_PLUGIN_STATIC_DECLARE(rawparse);  GST_PLUGIN_STATIC_DECLARE(typefindfunctions);  GST_PLUGIN_STATIC_DECLARE(videoconvert);  GST_PLUGIN_STATIC_DECLARE(videorate);  GST_PLUGIN_STATIC_DECLARE(videoscale);  GST_PLUGIN_STATIC_DECLARE(videotestsrc);  GST_PLUGIN_STATIC_DECLARE(volume);  GST_PLUGIN_STATIC_DECLARE(autodetect);  GST_PLUGIN_STATIC_DECLARE(videofilter);  GST_PLUGIN_STATIC_DECLARE(opus); GST_PLUGIN_STATIC_DECLARE(jpeg);
GST_PLUGIN_STATIC_DECLARE(osxaudio);

/* Call this function to register static plugins */
void gst_init_and_register_static_plugins () {
    GError * gst_init_error = NULL;
    gst_init_check(NULL, NULL, &gst_init_error);
    
    GST_PLUGIN_STATIC_REGISTER(coreelements);  GST_PLUGIN_STATIC_REGISTER(coretracers);  GST_PLUGIN_STATIC_REGISTER(adder);  GST_PLUGIN_STATIC_REGISTER(app);  GST_PLUGIN_STATIC_REGISTER(audioconvert);  GST_PLUGIN_STATIC_REGISTER(audiomixer);  GST_PLUGIN_STATIC_REGISTER(audiorate);  GST_PLUGIN_STATIC_REGISTER(audioresample);  GST_PLUGIN_STATIC_REGISTER(audiotestsrc);  GST_PLUGIN_STATIC_REGISTER(compositor);  GST_PLUGIN_STATIC_REGISTER(gio);  GST_PLUGIN_STATIC_REGISTER(overlaycomposition);  GST_PLUGIN_STATIC_REGISTER(pango);  GST_PLUGIN_STATIC_REGISTER(rawparse);  GST_PLUGIN_STATIC_REGISTER(typefindfunctions);  GST_PLUGIN_STATIC_REGISTER(videoconvert);  GST_PLUGIN_STATIC_REGISTER(videorate);  GST_PLUGIN_STATIC_REGISTER(videoscale);  GST_PLUGIN_STATIC_REGISTER(videotestsrc);  GST_PLUGIN_STATIC_REGISTER(volume);  GST_PLUGIN_STATIC_REGISTER(autodetect);  GST_PLUGIN_STATIC_REGISTER(videofilter);  GST_PLUGIN_STATIC_REGISTER(opus);  GST_PLUGIN_STATIC_REGISTER(jpeg);
    GST_PLUGIN_STATIC_REGISTER(osxaudio);

    if (gst_is_initialized()) {
        client_log("GStreamer successfully initialized");
    } else {
        client_log("GStreamer failed to initialize");
    }
}

void *initializeSpice(int instance,
                   bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                   void (*fb_resize_callback)(int instance, int fbW, int fbH),
                   void (*fail_callback)(int instance, uint8_t *),
                   void (*cl_log_callback)(int8_t *),
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

    fbW = 0;
    fbH = 0;
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
    
    pthread_create(&spice_worker, NULL, (void *) &engine_spice_worker, NULL);
    pthread_create(&mainloop_worker, NULL, (void *) &engine_mainloop_worker, NULL);
    client_log("Done initializing SPICE session\n");
    return (void *)&p;
}

void *initializeSpiceVv(int instance,
                   bool (*fb_update_callback)(int instance, uint8_t *, int fbW, int fbH, int x, int y, int w, int h),
                   void (*fb_resize_callback)(int instance, int fbW, int fbH),
                   void (*fail_callback)(int instance, uint8_t *),
                   void (*cl_log_callback)(int8_t *),
                   int (*y_n_callback)(int instance, int8_t *, int8_t *, int8_t *, int8_t *, int8_t *, int),
                   char* vv_file, bool enable_sound) {
    client_log("Initializing SPICE session from vv file\n");
        
    framebuffer_update_callback = fb_update_callback;
    framebuffer_resize_callback = fb_resize_callback;
    failure_callback = fail_callback;
    client_log_callback = cl_log_callback;
    yes_no_callback = y_n_callback;

    gst_init_and_register_static_plugins();

    fbW = 0;
    fbH = 0;
    p.instance = instance;
    if (vv_file != NULL)
        strncpy(p.vv_file, vv_file, sizeof(p.vv_file));
    p.enable_sound = enable_sound;
    
    pthread_create(&spice_worker, NULL, (void *) &engine_spice_worker, NULL);
    pthread_create(&mainloop_worker, NULL, (void *) &engine_mainloop_worker, NULL);
    client_log("Done initializing SPICE session from file\n");
    return (void *)&p;
}

static void resizeSpiceBuffer(int bytesPerPixel, int width, int height) {
    client_log("Resizing Draw Buffer, allocating buffer\n");
    fbW = width;
    fbH = height;
    client_log("Width, height: %d, %d\n", fbW, fbH);
    
    uint8_t *oldFrameBuffer = p.frameBuffer;
    int pixel_buffer_size = bytesPerPixel*fbW*fbH*sizeof(char);
    p.frameBuffer = (uint8_t*)malloc(pixel_buffer_size);
    if (fbW > 0 || fbH > 0) {
        framebuffer_resize_callback(p.instance, fbW, fbH);
        updateFramebuffer(p.instance, p.frameBuffer, 0, 0, fbW, fbH);
        requestResolution(1680, 1050);
    }
    if (oldFrameBuffer != NULL) {
        free(oldFrameBuffer);
    }
    SpiceGlibGlueLockDisplayBuffer(&width, &height);
    SpiceGlibGlueSetDisplayBuffer((uint32_t *)p.frameBuffer, width, height);
    SpiceGlibGlueUnlockDisplayBuffer();
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
