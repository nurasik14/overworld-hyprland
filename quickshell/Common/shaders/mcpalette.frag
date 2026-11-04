#version 440
// mcpalette — recolours grey GUI sprites without touching alpha, nearest sampling comes from the layer.
//   mode 0: multiply by `tint` (block/water_still + water colour, grass…)
//   mode 1: Night palette swap, piecewise-linear on the grey level:
//           00→c0, 37→c1, 55→c2, 8B→c3, C6→c4, FF→c5 (the exact greys of the Java GUI)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;
    vec4 tint;
    vec4 c0; vec4 c1; vec4 c2; vec4 c3; vec4 c4; vec4 c5;
};
layout(binding = 1) uniform sampler2D source;

vec3 remap(float g) {
    const float s1 = 55.0 / 255.0, s2 = 85.0 / 255.0, s3 = 139.0 / 255.0, s4 = 198.0 / 255.0;
    if (g < s1) return mix(c0.rgb, c1.rgb, g / s1);
    if (g < s2) return mix(c1.rgb, c2.rgb, (g - s1) / (s2 - s1));
    if (g < s3) return mix(c2.rgb, c3.rgb, (g - s2) / (s3 - s2));
    if (g < s4) return mix(c3.rgb, c4.rgb, (g - s3) / (s4 - s3));
    return mix(c4.rgb, c5.rgb, (g - s4) / (1.0 - s4));
}

void main() {
    vec4 p = texture(source, qt_TexCoord0);
    if (p.a <= 0.0) { fragColor = vec4(0.0); return; }
    vec3 rgb = p.rgb / p.a;                 // layers are premultiplied
    vec3 outc = mode < 0.5 ? rgb * tint.rgb : remap(dot(rgb, vec3(0.2126, 0.7152, 0.0722)));
    fragColor = vec4(outc * p.a, p.a) * qt_Opacity;
}
