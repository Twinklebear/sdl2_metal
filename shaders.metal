#include <metal_stdlib>

using namespace metal;

#include "shader_types.h"

struct VertexOutput {
    float4 position [[position]];
    float4 color;
};

vertex VertexOutput vertex_shader(uint vid [[vertex_id]],
                                  constant Vertex *vertices [[buffer(0)]])
{
    VertexOutput out;
    out.position = vector_float4(vertices[vid].position, 1.f);
    out.color = vector_float4(vertices[vid].color, 1.f);
    return out;
}

fragment float4 fragment_shader(VertexOutput in [[stage_in]])
{
    return in.color;
}

constant int win_width = 1280;
constant int win_height = 720;

kernel void raygen(uint2 tid [[thread_position_in_grid]],
                   texture2d<float, access::write> render_target [[texture(0)]])
{
    render_target.write(float4(float(tid.x) / win_width, float(tid.y) / win_height, 1.f, 1.f),
                        tid);
}

