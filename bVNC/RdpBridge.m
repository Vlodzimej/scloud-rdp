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
#include "freerdp/freerdp.h"
#include "freerdp/gdi/gdi.h"
#include "RemoteBridge.h"
#include "Utility.h"

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
    if (!instance) {
        return false;
    }
    
    int i = instance->context->argc;
    printf("post_connect, instance %d\n", i);

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

enum CLIENT_CONNECTION_STATE
{
    CLIENT_STATE_INITIAL,
    CLIENT_STATE_PRECONNECT_PASSED,
    CLIENT_STATE_POSTCONNECT_PASSED
};

static void ios_post_disconnect(freerdp *instance) {
    printf("ios_post_disconnect\n");
    if (instance->ConnectionCallbackState == CLIENT_STATE_INITIAL ||
        instance->ConnectionCallbackState == CLIENT_STATE_PRECONNECT_PASSED) {
        if (authAttempted()) {
            clientLogCallback((int8_t*)"Authentication failed\n");
            failCallback(instance->context->argc, (uint8_t*)"RDP_AUTHENTICATION_FAILED_TITLE");
        } else {
            clientLogCallback((int8_t*)"Could not connect to remote server\n");
            failCallback(instance->context->argc, (uint8_t*)"RDP_CONNECTION_FAILURE_TITLE");
        }
    } else if (instance->ConnectionCallbackState == CLIENT_STATE_POSTCONNECT_PASSED) {
        clientLogCallback((int8_t*)"Connection to remote server was interrupted\n");
        failCallback(instance->context->argc, (uint8_t*)"RDP_CONNECTION_FAILURE_TITLE");
    }
    gdi_free(instance);
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
    // FIXME: Implement
    return 1;
}

static DWORD verify_cert(freerdp* instance, const char* host, UINT16 port,
                                const char* common_name, const char* subject,
                                const char* issuer, const char* fingerprint, DWORD flags) {
    printf("verify_cert, instance %d\n", instance->context->argc);
    // FIXME: Implement
    return 1;
}

static BOOL authenticate(freerdp* instance, char** username, char** password,
                         char** domain) {
    *username = (char *)getUsernameCallback();
    *password = (char *)getPasswordCallback();
    *domain = (char *)getDomainCallback();
    return TRUE;
}

void *initializeRdp(int i, int width, int height,
                    pFrameBufferUpdateCallback fb_update_callback,
                    pFrameBufferResizeCallback fb_resize_callback,
                    pFailCallback fail_callback,
                    pClientLogCallback cl_log_callback,
                    pYesNoCallback y_n_callback,
                    pGetDomainCallback get_domain_callback,
                    pGetUsernameCallback get_username_callback,
                    pGetPasswordCallback get_password_callback,
                    pAuthAttempted auth_attempted_callback,
                    char* addr, char* port, bool enable_sound) {

    frameBufferUpdateCallback = fb_update_callback;
    frameBufferResizeCallback = fb_resize_callback;
    failCallback = fail_callback;
    clientLogCallback = cl_log_callback;
    yesNoCallback = y_n_callback;
    getDomainCallback = get_domain_callback;
    getUsernameCallback = get_username_callback;
    getPasswordCallback = get_password_callback;
    authAttempted = auth_attempted_callback;
    
    freerdp* instance = ios_freerdp_new();
    instance->context->argc = i;
    instance->context->settings->ServerHostname = addr;
    instance->context->settings->ServerPort = atoi(port);
    instance->context->settings->AudioPlayback = enable_sound;
    printf("Requesting initial remote resolution to be %dx%d\n", width, height);
    instance->context->settings->DesktopWidth = width;
    instance->context->settings->DesktopHeight = height;
    instance->context->settings->DynamicResolutionUpdate = TRUE;

    instance->update->DesktopResize = resize_window;
    instance->update->BitmapUpdate = bitmap_update;
    instance->update->BeginPaint = begin_paint;
    instance->update->EndPaint = end_paint;

    //FIXME: Implement RDP gateway support
    //instance->context->settings->GatewayUsername
    //instance->context->settings->GatewayPassword
    //instance->GatewayAuthenticate

    instance->Authenticate = authenticate;
    instance->PostDisconnect = ios_post_disconnect;
    instance->PostConnect = post_connect;
    
    // FIXME: Implement certificate verification
    //instance->VerifyX509Certificate;
    instance->VerifyCertificateEx = verify_cert;
    instance->VerifyChangedCertificateEx = verify_changed_cert;

    return (void *)instance;
}

void connectRdpInstance(void *instance) {
    ios_run_freerdp((freerdp *)instance);
}

void cursorEvent(void *instance, int x, int y, int flags) {
    mfInfo *mfi = MFI_FROM_INSTANCE((freerdp *)instance);
    mfi->instance->input->MouseEvent(mfi->instance->input, flags, x, y);
}

void unicodeKeyEvent(void *instance, int flags, int code) {
    mfInfo *mfi = MFI_FROM_INSTANCE((freerdp *)instance);
    mfi->instance->input->UnicodeKeyboardEvent(mfi->instance->input, flags, code);
}

void vkKeyEvent(void *instance, int flags, int code) {
    mfInfo *mfi = MFI_FROM_INSTANCE((freerdp *)instance);
    mfi->instance->input->KeyboardEvent(mfi->instance->input, flags, code);
}

void disconnectRdp(void *instance) {
    freerdp_abort_connect((freerdp *)instance);
}

void resizeRemoteRdpDesktop(void *i, int x, int y) {
    // FIXME: Implement
}
