#version 130
uniform sampler2D ColorBuffer, IblAmbientBuffer, NormalBuffer, DepthBuffer;
uniform sampler2DArray ShadowMapArray;
uniform mat4 ShadowSpaceMatrices[4];
uniform mat4 GBufferMatrices[4];  // w2v, v2w, v2p, p2v
in vec4 texCoord0;
out vec4 fragData;

void main()
{
	vec2 uv0 = texCoord0.xy;
    vec4 colorData = texture(ColorBuffer, uv0), iblData = texture(IblAmbientBuffer, uv0);
    vec4 normalAlpha = texture(NormalBuffer, uv0);
    float depthValue = texture(DepthBuffer, uv0).r * 2.0 - 1.0;
    
    // Rebuild world vertex attributes
    vec4 vecInProj = vec4(uv0.x * 2.0 - 1.0, uv0.y * 2.0 - 1.0, depthValue, 1.0);
    vec4 eyeVertex = GBufferMatrices[3] * vecInProj;
    vec3 eyeNormal = normalAlpha.rgb;
    
    // Compute shadow and combine with color
    float shadow = 1.0, shadowLayerStep = 1.0;
    for (int i = 0; i < 4; ++i)
    {
        vec4 lightProjVec = ShadowSpaceMatrices[i] * eyeVertex;
        vec2 lightProjUV = (lightProjVec.xy / lightProjVec.w) * 0.5 + vec2(0.5);
        if (any(lessThan(lightProjUV, vec2(0.0))) || any(greaterThan(lightProjUV, vec2(1.0)))) continue;
        
        vec4 lightProjVec0 = texture(ShadowMapArray, vec3(lightProjUV.xy, shadowLayerStep * float(i)));
        float depth = lightProjVec.z / lightProjVec.w, depth0 = lightProjVec0.z + 0.005;
        shadow *= (lightProjVec0.x > 0.1 && depth > depth0) ? 0.1 : 1.0;  // FIXME: multi-shadows failed if window resized
    }
    
    colorData.rgb *= shadow;
    colorData.rgb += iblData.rgb;
	fragData = colorData;
}