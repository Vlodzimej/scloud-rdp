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

#ifndef RdpBridge_h
#define RdpBridge_h

void *initializeRdp(int instance, int width, int height,
                    pFrameBufferUpdateCallback fb_update_callback,
                    pFrameBufferResizeCallback fb_resize_callback,
                    pFailCallback fail_callback,
                    pClientLogCallback cl_log_callback,
                    pYesNoCallback y_n_callback,
                    char* addr,
                    char* port,
                    char *domain,
                    char *user,
                    char *pass,
                    bool enable_sound);
void connectRdpInstance(void *instance);
void cursorEvent(void *instance, int x, int y, int flags);
void unicodeKeyEvent(void *instance, int flags, int code);
void vkKeyEvent(void *instance, int flags, int code);
void disconnectRdp(void *i);
void resizeRemoteRdpDesktop(void *instance, int x, int y);

#endif /* RdpBridge_h */
