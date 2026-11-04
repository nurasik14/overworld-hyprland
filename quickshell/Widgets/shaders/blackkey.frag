#version 440
// blackkey.frag — the game draws sun.png / moon phases with additive blending, so black means "nothing here".
// This turns luminance into alpha (premultiplied) so the sprite can sit on any sky.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 c = texture(source, qt_TexCoord0);
    float a = max(c.r, max(c.g, c.b)) * c.a;
    fragColor = vec4(c.rgb * c.a, a) * qt_Opacity;
}
