#include <algorithm>
#include <array>
#include <iostream>
#include <string>
#include <vector>
#include <SDL.h>
#include <SDL_syswm.h>
#include "metalview.h"
#include "shader_types.h"

int win_width = 1280;
int win_height = 720;

@implementation AppMetalView

// Return a Metal compatible layer
+ (Class)layerClass
{
    // SDL does
    // return NSClassFromString(@"CAMetalLayer");
    return [CAMetalLayer class];
}

// Indicate we want to draw using a backing layer
- (BOOL)wantsUpdateLayer
{
    return YES;
}

// Return an instance of the layer we want
- (CALayer *)makeBackingLayer
{
    return [self.class.layerClass layer];
}

- (instancetype)initWithFrame:(NSRect)frame_rect
{
    self = [super initWithFrame:frame_rect];
    if (self) {
        self.wantsLayer = YES;
        // TODO Later resizing support
        // self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self updateDrawableSize];
    }
    return self;
}

- (NSInteger)tag
{
    return APP_METAL_VIEW_TAG;
}

- (void)updateDrawableSize
{
    CAMetalLayer *metal_layer = (CAMetalLayer *)self.layer;
    CGSize size = self.bounds.size;
    metal_layer.contentsScale = 1.0;
    metal_layer.drawableSize = size;
}

- (void)resizeWithOldSuperviewSize:(NSSize)old_size
{
    [super resizeWithOldSuperviewSize:old_size];
    [self updateDrawableSize];
}

@end

int main(int argc, const char **argv)
{
    if (SDL_Init(SDL_INIT_EVERYTHING) != 0) {
        std::cerr << "Failed to init SDL: " << SDL_GetError() << "\n";
        return -1;
    }

    SDL_Window *window = SDL_CreateWindow("SDL2 + Metal",
                                          SDL_WINDOWPOS_CENTERED,
                                          SDL_WINDOWPOS_CENTERED,
                                          win_width,
                                          win_height,
                                          0);

    SDL_SysWMinfo wm_info;
    SDL_VERSION(&wm_info.version);
    SDL_GetWindowWMInfo(window, &wm_info);

    NSWindow *nswindow = wm_info.info.cocoa.window;
    NSView *view = nswindow.contentView;

    // TODO: Do I need an autorelease block wrapping everything below?

    // Find a Metal device that supports ray tracing
    NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
    id<MTLDevice> device;
    for (id<MTLDevice> d in devices) {
        if (d.supportsRaytracing && (!device || !device.isLowPower)) {
            device = d;
        }
    }
    std::cout << "Selected Metal device " << [device.name UTF8String] << "\n";

    AppMetalView *metal_view = [[AppMetalView alloc] initWithFrame:view.frame];
    [view addSubview:metal_view];

    // Setup the Metal layer
    CAMetalLayer *metal_layer = (CAMetalLayer *)[metal_view layer];
    metal_layer.device = device;
    metal_layer.pixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;

    id<MTLCommandQueue> command_queue = [device newCommandQueue];

    MTLRenderPassDescriptor *render_pass_desc = [MTLRenderPassDescriptor new];
    render_pass_desc.colorAttachments[0].loadAction = MTLLoadActionClear;
    render_pass_desc.colorAttachments[0].storeAction = MTLStoreActionStore;
    render_pass_desc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);

    // Load the shader library
    NSError *err = nullptr;
    id<MTLLibrary> shader_library = [device newLibraryWithFile:@"shaders.metallib" error:&err];
    if (!shader_library) {
        std::cout << "Failed to load shader library: " << [err.localizedDescription UTF8String]
                  << "\n";
        return 1;
    }

    id<MTLFunction> vertex_shader = [shader_library newFunctionWithName:@"vertex_shader"];
    id<MTLFunction> fragment_shader = [shader_library newFunctionWithName:@"fragment_shader"];

    // Setup the render pipeline state
    MTLRenderPipelineDescriptor *pipeline_desc = [[MTLRenderPipelineDescriptor alloc] init];
    pipeline_desc.vertexFunction = vertex_shader;
    pipeline_desc.fragmentFunction = fragment_shader;
    pipeline_desc.colorAttachments[0].pixelFormat = metal_layer.pixelFormat;

    id<MTLRenderPipelineState> pipeline =
        [device newRenderPipelineStateWithDescriptor:pipeline_desc error:&err];
    if (!pipeline) {
        std::cout << "Failed to create render pipeline: " <<
            [err.localizedDescription UTF8String] << "\n";
        return 1;
    }

    // Upload vertex data
    const Vertex vertex_data[] = {
        {{-0.5, -0.5, 0}, {1, 0, 0}}, {{0, 0.5, 0}, {0, 1, 0}}, {{0.5, -0.5, 0}, {0, 0, 1}}};

    id<MTLBuffer> vertex_buffer = [device newBufferWithLength:3 * sizeof(Vertex)
                                                      options:MTLResourceStorageModeManaged];
    std::memcpy(vertex_buffer.contents, vertex_data, vertex_buffer.length);
    [vertex_buffer didModifyRange:NSMakeRange(0, vertex_buffer.length)];

    bool done = false;
    while (!done) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                done = true;
            }
            if (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE) {
                done = true;
            }
            if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE &&
                event.window.windowID == SDL_GetWindowID(window)) {
                done = true;
            }
        }

        // Does it need some autorelease here in the loop?
        id<CAMetalDrawable> render_target = [metal_layer nextDrawable];
        if (!render_target) {
            std::cout << "No render target?\n";
            continue;
        }

        render_pass_desc.colorAttachments[0].texture = render_target.texture;

        id<MTLCommandBuffer> command_buffer = [command_queue commandBuffer];
        id<MTLRenderCommandEncoder> command_encoder =
            [command_buffer renderCommandEncoderWithDescriptor:render_pass_desc];

        [command_encoder setViewport:(MTLViewport){0,
                                                   0,
                                                   static_cast<double>(win_width),
                                                   static_cast<double>(win_height),
                                                   0,
                                                   1}];
        // Render our triangle!
        [command_encoder setRenderPipelineState:pipeline];
        [command_encoder setVertexBuffer:vertex_buffer offset:0 atIndex:0];
        [command_encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];

        [command_encoder endEncoding];
        [command_buffer presentDrawable:render_target];
        [command_buffer commit];
    }

    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

