//
//  RemoteBridge.h
//  bVNC
//
//  Created by iordan iordanov on 2021-03-16.
//  Copyright © 2021 iordan iordanov. All rights reserved.
//

#ifndef RemoteBridge_h
#define RemoteBridge_h

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <signal.h>
#include <string.h>

extern int fbW;
extern int fbH;
extern bool (*framebuffer_update_callback)(int, uint8_t *, int fbW, int fbH, int x, int y, int w, int h);
extern void (*framebuffer_resize_callback)(int, int fbW, int fbH);
extern void (*failure_callback)(int, uint8_t *);

bool updateFramebuffer(int instance, uint8_t *frameBuffer, int x, int y, int w, int h);
void signal_handler(int signal, siginfo_t *info, void *reserved);
void handle_signals(void);

#endif /* RemoteBridge_h */
