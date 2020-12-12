#pragma once

#include <Cocoa/Cocoa.h>
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>

#define APP_METAL_VIEW_TAG 1234

@interface AppMetalView : NSView

- (instancetype) initWithFrame:(NSRect)frame_rect;

@property (assign, readonly) NSInteger tag;

@end

