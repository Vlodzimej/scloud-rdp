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

#import <Foundation/Foundation.h>
#include "ios_freerdp.h"
#include "freerdp/gdi/gdi.h"
#include "RemoteBridge.h"


static void reallocate_buffer(mfInfo *mfi) {
    CGContextRef old_context = mfi->bitmap_context;
    mfi->bitmap_context = NULL;
    if (old_context != NULL) {
        CGContextRelease(old_context);
    }
        
    rdpGdi *gdi = mfi->instance->context->gdi;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bc;

    if (GetBytesPerPixel(gdi->dstFormat) == 2) {
        bc = CGBitmapContextCreate(gdi->primary_buffer, gdi->width, gdi->height, 5, gdi->stride,
                                   colorSpace, kCGBitmapByteOrder16Big | kCGImageAlphaNoneSkipLast);
    } else {
        bc = CGBitmapContextCreate(gdi->primary_buffer, gdi->width, gdi->height, 8, gdi->stride,
                                   colorSpace, kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipLast);
    }
    mfi->bitmap_context = bc;
    CGColorSpaceRelease(colorSpace);
}

static BOOL bitmap_update(rdpContext* context, const BITMAP_UPDATE* bitmap) {
    printf("bitmap_update, instance %d\n", context->instance->context->argc);
    return true;
}

static BOOL begin_paint(rdpContext* context) {
    printf("begin_paint, instance %d\n", context->instance->context->argc);
    return true;
}

static BOOL end_paint(rdpContext* context) {
    int i = context->instance->context->argc;
    printf("end_paint, instance %d\n", i);

    mfInfo *mfi = MFI_FROM_INSTANCE(context->instance);
    uint8_t* pixels = CGBitmapContextGetData(mfi->bitmap_context);
    fbW = context->instance->settings->DesktopWidth;
    fbH = context->instance->settings->DesktopHeight;

    if (!frameBufferUpdateCallback(i, pixels, fbW, fbH, 0, 0, fbW, fbH)) {
        // This session is a left-over backgrounded session and must quit.
        printf("Must quit background session with instance number %d\n", i);
    }
    
    return true;
}

static BOOL post_connect(freerdp *instance) {
    int i = instance->context->argc;
    printf("post_connect, instance %d\n", i);

    if (!instance) {
        return false;
    }

    mfInfo *mfi = MFI_FROM_INSTANCE(instance);

    if (!mfi) {
        return false;
    }

    if (!gdi_init(instance, PIXEL_FORMAT_RGBA32)) {
        return false;
    }

    reallocate_buffer(mfi);
    fbW = instance->settings->DesktopWidth;
    fbH = instance->settings->DesktopHeight;
    frameBufferResizeCallback(i, fbW, fbH);
    return true;
}

static BOOL resize_window(rdpContext *context) {
    printf("resize_window, instance %d\n", context->instance->context->argc);
    post_connect(context->instance);
    return true;
}

static DWORD verify_changed_cert(freerdp* instance, const char* host, UINT16 port,
                                  const char* common_name, const char* subject,
                                  const char* issuer, const char* new_fingerprint,
                                  const char* old_subject, const char* old_issuer,
                                  const char* old_fingerprint, DWORD flags) {
    printf("verify_changed_cert, instance %d\n", instance->context->argc);
    return 1;
}

static DWORD verify_cert(freerdp* instance, const char* host, UINT16 port,
                                const char* common_name, const char* subject,
                                const char* issuer, const char* fingerprint, DWORD flags) {
    printf("verify_cert, instance %d\n", instance->context->argc);
    return 1;
}

void *initializeRdp(int i, int width, int height,
                    pFrameBufferUpdateCallback fb_update_callback,
                    pFrameBufferResizeCallback fb_resize_callback,
                    pFailCallback fail_callback,
                    pClientLogCallback cl_log_callback,
                    pYesNoCallback y_n_callback,
                    char* addr, char* port, char* user, char* password, bool enable_sound) {

    frameBufferUpdateCallback = fb_update_callback;
    frameBufferResizeCallback = fb_resize_callback;
    failCallback = fail_callback;
    clientLogCallback = cl_log_callback;
    yesNoCallback = y_n_callback;

    freerdp* instance = ios_freerdp_new();
    instance->context->argc = i;
    instance->context->settings->ServerHostname = addr;
    instance->context->settings->ServerPort = atoi(port);
    instance->context->settings->Username = user;
    instance->context->settings->Password = password;
    instance->context->settings->AudioPlayback = enable_sound;
    instance->context->settings->DesktopWidth = width;
    instance->context->settings->DesktopHeight = height;

    instance->update->DesktopResize = resize_window;
    instance->update->BitmapUpdate = bitmap_update;
    instance->update->BeginPaint = begin_paint;
    instance->update->EndPaint = end_paint;

    //TODO: Implement
    //instance->context->settings->GatewayUsername
    //instance->context->settings->GatewayPassword
    //instance->GatewayAuthenticate

    instance->PostConnect = post_connect;
    instance->VerifyCertificateEx = verify_cert;
    instance->VerifyChangedCertificateEx = verify_changed_cert;
    
    ios_run_freerdp(instance);
    return (void *)instance;
}

void disconnectRdp(void *i) {
}
