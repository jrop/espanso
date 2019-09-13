#include "bridge.h"

#import <Foundation/Foundation.h>
#include "AppDelegate.h"
#include <string.h>
extern "C" {

}

#include <vector>

KeypressCallback keypress_callback;
void * context_instance;

int32_t initialize(void * context) {
    context_instance = context;

    AppDelegate *delegate = [[AppDelegate alloc] init];
    NSApplication * application = [NSApplication sharedApplication];
    [application setDelegate:delegate];
}

void register_keypress_callback(KeypressCallback callback) {
    keypress_callback = callback;
}

int32_t eventloop() {
    [NSApp run];
}

void send_string(const char * string) {
    char * stringCopy = strdup(string);
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        // Convert the c string to a UniChar array as required by the CGEventKeyboardSetUnicodeString method
        NSString *nsString = [NSString stringWithUTF8String:stringCopy];
        CFStringRef cfString = (__bridge CFStringRef) nsString;
        std::vector <UniChar> buffer(nsString.length);
        CFStringGetCharacters(cfString, CFRangeMake(0, nsString.length), buffer.data());

        free(stringCopy);

        // Send the event

        // Because of a bug ( or undocumented limit ) of the CGEventKeyboardSetUnicodeString method
        // the string gets truncated after 20 characters, so we need to send multiple events.

        int i = 0;
        while (i < buffer.size()) {
            int chunk_size = 20;
            if ((i+chunk_size) >  buffer.size()) {
                chunk_size = buffer.size() - i;
            }

            UniChar * offset_buffer = buffer.data() + i;
            CGEventRef e = CGEventCreateKeyboardEvent(NULL, 0x31, true);
            CGEventKeyboardSetUnicodeString(e, chunk_size, offset_buffer);
            CGEventPost(kCGHIDEventTap, e);
            CFRelease(e);

            usleep(2000);

            i += chunk_size;
        }
    });
}

void delete_string(int32_t count) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        for (int i = 0; i < count; i++) {
            CGEventRef keydown;
            keydown = CGEventCreateKeyboardEvent(NULL, 0x33, true);
            CGEventPost(kCGHIDEventTap, keydown);
            CFRelease(keydown);

            usleep(2000);

            CGEventRef keyup;
            keyup = CGEventCreateKeyboardEvent(NULL, 0x33, false);
            CGEventPost(kCGHIDEventTap, keyup);
            CFRelease(keyup);

            usleep(2000);
        }
    });
}

void send_vkey(int32_t vk) {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGEventRef keydown;
        keydown = CGEventCreateKeyboardEvent(NULL, vk, true);
        CGEventPost(kCGHIDEventTap, keydown);
        CFRelease(keydown);

        usleep(2000);

        CGEventRef keyup;
        keyup = CGEventCreateKeyboardEvent(NULL, vk, false);
        CGEventPost(kCGHIDEventTap, keyup);
        CFRelease(keyup);

        usleep(2000);
    });
}

void trigger_paste() {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGEventRef keydown;
        keydown = CGEventCreateKeyboardEvent(NULL, 0x37, true);  // CMD
        CGEventPost(kCGHIDEventTap, keydown);
        CFRelease(keydown);

        usleep(2000);

        CGEventRef keydown2;
        keydown2 = CGEventCreateKeyboardEvent(NULL, 0x09, true);  // V key
        CGEventPost(kCGHIDEventTap, keydown2);
        CFRelease(keydown2);

        usleep(2000);

        CGEventRef keyup;
        keyup = CGEventCreateKeyboardEvent(NULL, 0x09, false);
        CGEventPost(kCGHIDEventTap, keyup);
        CFRelease(keyup);

        usleep(2000);

        CGEventRef keyup2;
        keyup2 = CGEventCreateKeyboardEvent(NULL, 0x37, false);  // CMD
        CGEventPost(kCGHIDEventTap, keyup2);
        CFRelease(keyup2);

        usleep(2000);
    });
}

int32_t get_active_app_bundle(char * buffer, int32_t size) {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    NSString *bundlePath = [frontApp bundleURL].path;
    const char * path = [bundlePath UTF8String];

    snprintf(buffer, size, "%s", path);

    [bundlePath release];

    return 1;
}

int32_t get_active_app_identifier(char * buffer, int32_t size) {
    NSRunningApplication *frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    NSString *bundleId = frontApp.bundleIdentifier;
    const char * bundle = [bundleId UTF8String];

    snprintf(buffer, size, "%s", bundle);

    [bundleId release];

    return 1;
}

int32_t get_clipboard(char * buffer, int32_t size) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    for (id element in pasteboard.pasteboardItems) {
        NSString *string = [element stringForType: NSPasteboardTypeString];
        if (string != NULL) {
            const char * text = [string UTF8String];
            snprintf(buffer, size, "%s", text);

            [string release];

            return 1;
        }
    }

    return -1;
}

int32_t set_clipboard(char * text) {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *array = @[NSPasteboardTypeString];
    [pasteboard declareTypes:array owner:nil];

    NSString *nsText = [NSString stringWithUTF8String:text];
    [pasteboard setString:nsText forType:NSPasteboardTypeString];
}