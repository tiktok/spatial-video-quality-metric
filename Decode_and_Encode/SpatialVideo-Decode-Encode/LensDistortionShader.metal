//
//  LensDistortionShader.metal
//  SpatialVideo-Decode-Encode
//
//  Copyright (c) TikTok Pte. Ltd. All rights reserved. Licensed under the MIT license.
//  See LICENSE in the project root for license information.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

float2 barrel_distort(float2 coord, float strength) {
    float2 cc = coord - 0.5;
    float dist = dot(cc, cc);
    return coord + cc * (dist * strength);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> videoTexture [[texture(0)]],
                              constant float &strength [[buffer(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 distortedCoord = barrel_distort(in.texCoord, strength);
    return videoTexture.sample(s, distortedCoord);
}
