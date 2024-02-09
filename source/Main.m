#include <stdio.h>

#include <X11/Xlib.h>

#import <GNUstepGUI/GSDisplayServer.h>

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import <X11Window.h>
#import <X11Application.h>

void readConfiguration(X11AppDelegate * delegate, const char * filepath) {
    NSDictionary * dict = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithUTF8String:filepath]];

    [delegate setIcon:      [dict objectForKey:@"icon"]];
    [delegate setTitle:     [dict objectForKey:@"title"]];
    [delegate setFilepath:  [dict objectForKey:@"filepath"]];
    [delegate setArguments: [dict objectForKey:@"arguments"]];
}

int main(int argc, char * argv[]) {
    NSAutoreleasePool * pool = [NSAutoreleasePool new];
    [X11Application sharedApplication];

    X11AppDelegate * delegate = [X11AppDelegate alloc];

    for (int i = 1; i < argc; i++)
        if (strcmp(argv[i], "-config") == 0)
            if (++i < argc) readConfiguration(delegate, argv[i]);

    [NSApp setDelegate:delegate];
    [NSApp run];

    [pool drain];
    return 0;
}