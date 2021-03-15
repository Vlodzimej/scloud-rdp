//
//  RemoteBridge.c
//  bVNC
//
//  Created by iordan iordanov on 2021-03-16.
//  Copyright © 2021 iordan iordanov. All rights reserved.
//

#include "RemoteBridge.h"
#include "Utility.h"

int fbW = 0;
int fbH = 0;
bool (*framebuffer_update_callback)(int, uint8_t *, int fbW, int fbH, int x, int y, int w, int h);
void (*framebuffer_resize_callback)(int, int fbW, int fbH);
void (*failure_callback)(int, uint8_t *);

void signal_handler(int signal, siginfo_t *info, void *reserved) {
    client_log("Handling signal: %d", signal);
    failure_callback(-1, NULL);
}

void handle_signals() {
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
    if (!framebuffer_update_callback(instance, frameBuffer, fbW, fbH, x, y, w, h)) {
        // This session is a left-over backgrounded session and must quit.
        client_log("Must quit background session with instance number %d", instance);
        return false;
    }
    return true;
}
