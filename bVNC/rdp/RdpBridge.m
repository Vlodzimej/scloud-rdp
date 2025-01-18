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
#include "freerdp/error.h"
#include "RemoteBridge.h"
#include "Utility.h"
#include <freerdp/client.h>

// libfreerdp gives us exit code 0 for authentication failures to Ubuntu 22.04
#define FREERDP_ERROR_CONNECT_AUTH_FAILURE_UBUNTU_REMOTE_DESKTOP 0

static CGContextRef reallocate_buffer(mfInfo *mfi) {
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
    CGColorSpaceRelease(colorSpace);
    return bc;
}

static BOOL bitmap_update(rdpContext* context, const BITMAP_UPDATE* bitmap) {
    //printf("bitmap_update, instance %d\n", context->instance->context->argc);
    return true;
}

static BOOL begin_paint(rdpContext* context) {
    //printf("begin_paint, instance %d\n", context->instance->context->argc);
    return true;
}

void disconnectRdp(void *instance) {
    freerdp_abort_connect((freerdp *)instance);
}

static BOOL end_paint(rdpContext* context) {
    int i = context->instance->context->argc;
    //printf("end_paint, instance %d\n", i);

    mfInfo *mfi = MFI_FROM_INSTANCE(context->instance);
    uint8_t* pixels = CGBitmapContextGetData(mfi->bitmap_context);
    globalFb.fbW = context->instance->settings->DesktopWidth;
    globalFb.fbH = context->instance->settings->DesktopHeight;
    globalFb.frameBuffer = pixels;

    if (!frameBufferUpdateCallback(i, pixels, globalFb.fbW, globalFb.fbH, 0, 0, globalFb.fbW, globalFb.fbH)) {
        // This session is a left-over backgrounded session and must quit.
        printf("Must quit background session with instance number %d\n", i);
        disconnectRdp(context->instance);
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

    CGContextRef old_context = mfi->bitmap_context;
    mfi->bitmap_context = reallocate_buffer(mfi);
    globalFb.fbW = instance->settings->DesktopWidth;
    globalFb.fbH = instance->settings->DesktopHeight;
    frameBufferResizeCallback(i, globalFb.fbW, globalFb.fbH);
    if (old_context != NULL) {
        CGContextRelease(old_context);
    }
    return true;
}

enum CLIENT_CONNECTION_STATE
{
    CLIENT_STATE_INITIAL,
    CLIENT_STATE_PRECONNECT_PASSED,
    CLIENT_STATE_POSTCONNECT_PASSED
};

static char* getStringForInt(int status) {
    NSString* status_str = [@(status) description];
    char* status_char_str = (char*)[status_str cStringUsingEncoding:[NSString defaultCStringEncoding]];
    return status_char_str;
}

static void ios_post_disconnect(freerdp *instance) {
    printf("ios_post_disconnect\n");

    int last_error = freerdp_get_last_error(instance->context);
    int connection_state = instance->ConnectionCallbackState;
    
    char* last_error_char_str = getStringForInt(last_error);
    
    int i = instance->context->argc;
    gdi_free(instance);
    
    switch(last_error) {
        case FREERDP_ERROR_CONNECT_AUTH_FAILURE_UBUNTU_REMOTE_DESKTOP:
        case FREERDP_ERROR_CONNECT_LOGON_FAILURE:
        case FREERDP_ERROR_AUTHENTICATION_FAILED:
        case FREERDP_ERROR_CONNECT_WRONG_PASSWORD:
        case FREERDP_ERROR_CONNECT_NO_OR_MISSING_CREDENTIALS:
        case FREERDP_ERROR_CONNECT_ACCESS_DENIED:
            clientLogCallback("Authentication failed\n");
            clientLogCallback(last_error_char_str);
            failCallback(i, (uint8_t*)"RDP_AUTHENTICATION_FAILED_TITLE");
            return;
        case FREERDP_ERROR_CONNECT_CANCELLED:
            clientLogCallback("Connection cancelled\n");
            failCallback(i, (uint8_t*)"RDP_CONNECTION_FAILURE_TITLE");
            break;
        case FREERDP_ERROR_NONE:
            break;
        default:
            clientLogCallback("Unhandled error value after disconnection\n");
            clientLogCallback(last_error_char_str);
            break;
    }

    switch (connection_state) {
        case CLIENT_STATE_INITIAL:
        case CLIENT_STATE_PRECONNECT_PASSED:
            clientLogCallback("Could not connect to remote server\n");
            failCallback(i, (uint8_t*)"RDP_CONNECTION_FAILURE_TITLE");
            return;
        case CLIENT_STATE_POSTCONNECT_PASSED:
            clientLogCallback("Connection to remote server was interrupted\n");
            failCallback(i, (uint8_t*)"CONNECTION_INTERRUPTED_TITLE");
            return;
        default:
            clientLogCallback("Unhandled connection state after disconnection\n");
            clientLogCallback(last_error_char_str);
            return;
    }
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


static BOOL serverCutText(rdpContext* context, uint8_t* data, UINT32 size) {
    utf8_client_clipboard_callback(data, size);
    return true;
}

static void setGlobalCallbacks(pClientClipboardCallback cl_clipboard_callback, pClientLogCallback cl_log_callback, pFailCallback fail_callback, pFrameBufferResizeCallback fb_resize_callback, pFrameBufferUpdateCallback fb_update_callback, pYesNoCallback y_n_callback) {
    frameBufferUpdateCallback = fb_update_callback;
    frameBufferResizeCallback = fb_resize_callback;
    failCallback = fail_callback;
    clientLogCallback = cl_log_callback;
    utf8_client_clipboard_callback = cl_clipboard_callback;
    yesNoCallback = y_n_callback;
}

static void copyCredentials(char *domain, char **domainCopy, char *pass, char **passCopy, char *user, char **userCopy) {
    int bufLength = 512;
    *domainCopy = malloc(bufLength);
    strncpy(*domainCopy, domain, bufLength - 1);
    *userCopy = malloc(bufLength);
    strncpy(*userCopy, user, bufLength - 1);
    *passCopy = malloc(bufLength);
    strncpy(*passCopy, pass, bufLength - 1);
}

static void setSessionParameters(freerdp *instance, int i, char *addr, char *gateway_addr, char *gateway_domain, bool gateway_enabled, char *gateway_pass, char *gateway_port, char *gateway_user, char *port, char *domain, char *user, char *pass) {
    instance->context->argc = i;

    char * domainCopy;
    char * userCopy;
    char * passCopy;
    copyCredentials(domain, &domainCopy, pass, &passCopy, user, &userCopy);
    instance->context->settings->Domain = domainCopy;
    instance->context->settings->Username = userCopy;
    instance->context->settings->Password = passCopy;
    
    instance->context->settings->ServerHostname = addr;
    instance->context->settings->ServerPort = atoi(port);
    
    instance->context->settings->GatewayEnabled = gateway_enabled;
    instance->context->settings->GatewayHostname = gateway_addr;
    instance->context->settings->GatewayPort = atoi(gateway_port);
    instance->context->settings->GatewayUsername = gateway_user;
    instance->context->settings->GatewayPassword = gateway_pass;
    instance->context->settings->GatewayDomain = gateway_domain;
    //FIXME: Implement dedicated RDP Gateway authentication support via:
    //instance->GatewayAuthenticate
}

static void setSessionConfigFile(freerdp *instance, int i, char *configFile, char *domain, char *user, char *pass) {
    char * domainCopy;
    char * userCopy;
    char * passCopy;
    copyCredentials(domain, &domainCopy, pass, &passCopy, user, &userCopy);

    instance->context->argc = i;
    instance->context->settings->ConnectionFile = configFile;
    instance->context->settings->Domain = domainCopy;
    instance->context->settings->Username = userCopy;
    instance->context->settings->Password = passCopy;
    int status = freerdp_client_settings_parse_connection_file(instance->context->settings, configFile);
    clientLogCallback("freerdp_client_settings_parse_connection_file:");
    clientLogCallback(getStringForInt(status));
}

static void setSessionPreferences(freerdp *instance, bool enable_sound, int height, int width, int desktopScaleFactor) {
    instance->context->settings->AudioPlayback = enable_sound;

    instance->context->settings->JpegCodec = TRUE;
    instance->context->settings->JpegQuality = 70;
    
    instance->context->settings->DisableWallpaper = TRUE;
    instance->context->settings->AllowFontSmoothing = TRUE;
    instance->context->settings->AllowDesktopComposition = TRUE;
    instance->context->settings->DisableFullWindowDrag = TRUE;
    instance->context->settings->DisableMenuAnims = TRUE;
    instance->context->settings->DisableThemes = TRUE;
    instance->context->settings->NetworkAutoDetect = TRUE;
    
    instance->context->settings->AsyncChannels = TRUE;
    
    instance->context->settings->GfxAVC444 = TRUE;
    instance->context->settings->GfxH264 = TRUE;
    
    instance->context->settings->RemoteFxCodec = TRUE;
    
    printf("Requesting initial remote resolution to be %dx%d\n", width, height);
    instance->context->settings->DesktopWidth = width;
    instance->context->settings->DesktopHeight = height;
    instance->context->settings->DynamicResolutionUpdate = TRUE;
    instance->context->settings->RedirectClipboard = TRUE;
    instance->context->settings->DesktopScaleFactor = desktopScaleFactor;
    instance->context->settings->DeviceScaleFactor = 100;
    instance->context->settings->SupportGraphicsPipeline = TRUE;
    instance->context->settings->ColorDepth = 32;

}

static void setSessionCallbacks(freerdp *instance) {
    instance->update->DesktopResize = resize_window;
    instance->update->BitmapUpdate = bitmap_update;
    instance->update->BeginPaint = begin_paint;
    instance->update->EndPaint = end_paint;
    mfInfo *mfi = MFI_FROM_INSTANCE(instance);
    mfi->context->ServerCutText = serverCutText;
    
    instance->PostDisconnect = ios_post_disconnect;
    instance->PostConnect = post_connect;
    
    // FIXME: Implement certificate verification
    //instance->VerifyX509Certificate;
    instance->VerifyCertificateEx = verify_cert;
    instance->VerifyChangedCertificateEx = verify_changed_cert;
}

void *initializeRdp(int i, int width, int height, int desktopScaleFactor,
                    pFrameBufferUpdateCallback fb_update_callback,
                    pFrameBufferResizeCallback fb_resize_callback,
                    pFailCallback fail_callback,
                    pClientLogCallback cl_log_callback,
                    pClientClipboardCallback cl_clipboard_callback,
                    pYesNoCallback y_n_callback,
                    char *configFile,
                    char *addr,
                    char *port,
                    char *domain,
                    char *user,
                    char *pass,
                    bool enable_sound,
                    char *gateway_addr,
                    char *gateway_port,
                    char *gateway_domain,
                    char *gateway_user,
                    char *gateway_pass,
                    bool gateway_enabled) {
    setGlobalCallbacks(cl_clipboard_callback, cl_log_callback, fail_callback, fb_resize_callback, fb_update_callback, y_n_callback);
    
    freerdp* instance = ios_freerdp_new();
    if (!instance) {
        clientLogCallback("Could not initialize new freerdp instance\n");
        return NULL;
    }
    
    if (strcmp(configFile, "") == 0) {
        setSessionParameters(instance, i, addr, gateway_addr, gateway_domain, gateway_enabled, gateway_pass, gateway_port, gateway_user, port, domain, user, pass);
    } else {
        setSessionConfigFile(instance, i, configFile, domain, user, pass);
    }
    
    setSessionPreferences(instance, enable_sound, height, width, desktopScaleFactor);

    setSessionCallbacks(instance);

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

void resizeRemoteRdpDesktop(void *i, int x, int y) {
    // FIXME: Implement
}

void clientCutText(void *i, char *hostClipboardContents, int size) {
    freerdp *instance = (freerdp *)i;
    if (instance != NULL && instance->context != NULL) {
        ios_send_clipboard_data(instance->context, (void*)hostClipboardContents, size);
    }
}

