#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Simple pseudo-normal from a tiled sine height field for refraction.
[[ stitchable ]] half4 glass_refraction(
    float2 position,
    SwiftUI::Layer layer,
    float2 viewSize,
    float refract,
    float frequency,
    float highlight)
{
    float2 uv = position / max(viewSize, float2(1.0));
    float aspect = viewSize.x / max(1.0, viewSize.y);

    float f = frequency; // recommended: 24–64
    float h0 = sin((uv.x * aspect + uv.y) * f);
    float h1 = cos((uv.y - uv.x * aspect) * (f * 0.85));
    float h = (h0 + h1) * 0.5;

    float2 eps = 1.0 / max(viewSize, float2(1.0));
    float hx = sin(((uv.x + eps.x) * aspect + uv.y) * f);
    float hy = cos((uv.y + eps.y - uv.x * aspect) * (f * 0.85));
    float h_dx = ((hx + h1) * 0.5) - h;
    float h_dy = ((h0 + hy) * 0.5) - h;

    float2 normal = normalize(float2(h_dx, h_dy) + float2(1e-5));

    float offsetScale = mix(0.0, 6.0, clamp(refract, 0.0, 1.0));
    float2 samplePos = position + normal * offsetScale;
    // Clamp to layer bounds to avoid sampling outside, which would yield transparent pixels
    samplePos = clamp(samplePos, float2(0.5, 0.5), viewSize - float2(0.5, 0.5));

    half4 color = layer.sample(samplePos);

    float diag = abs(uv.x - uv.y);
    half sheen = half(smoothstep(0.12, 0.0, diag)) * half(clamp(highlight, 0.0, 1.0));
    color.rgb = saturate(color.rgb + sheen);

    return color;
}

// Binary alpha from source layer after optional blur/merging; used for "glue" masks.
[[ stitchable ]] half4 alpha_threshold(
    float2 position,
    SwiftUI::Layer layer,
    float threshold)
{
    half4 c = layer.sample(position);
    half a = c.a > half(threshold) ? half(1.0) : half(0.0);
    // Output white with thresholded alpha
    return half4(1.0, 1.0, 1.0, a);
}