// Include header shared between this Metal shader code and C code executing Metal API commands
#import "AAPLShaderTypes.h"
#import <metal_stdlib>
using namespace metal;

float floatMax(float a, float b) {
    if(a >= b)
        return a;
    return b;
}

// Vertex shader outputs and fragment shader inputs
typedef struct
{
    // The [[position]] attribute of this member indicates that this value is the clip space
    // position of the vertex when this structure is returned from the vertex function
    float4 pos [[position]];
    // Since this member does not have a special attribute, the rasterizer interpolates
    // its value with the values of the other triangle vertices and then passes
    // the interpolated value to the fragment shader for each fragment in the triangle
    float3 color;
} NormalShaderData;

// Vertex shader outputs and fragment shader inputs
typedef struct
{
    float4 pos [[position]];
    float3 vertPos;
    float3 normal;
    float3 lightPos;
    float3 ka;
    float3 kd;
    float3 ks;
    float intensity;
    float s;
} PhongShaderData;

// Vertex shader outputs and fragment shader inputs
typedef struct
{
    float4 pos [[position]];
    float3 color;
    float2 texCoord;
    float pointsize [[point_size]];
    float alp;
} ParticleShaderData;

vertex NormalShaderData
vertexShaderNormal(uint vertexID [[vertex_id]],
                   constant AAPLVertex *vertices [[buffer(0)]],
                   constant Uniforms *uniforms [[buffer(1)]])
{
    NormalShaderData out;
    out.pos = uniforms->P * uniforms->MV * vertices[vertexID].position;
    out.color = normalize(uniforms->MV * vertices[vertexID].normal).xyz;
    return out;
}

fragment float4 fragmentShaderNormal(NormalShaderData in [[stage_in]],
                                    constant Uniforms *uniforms [[buffer(1)]])
{
    return float4(0.5*in.color + 0.5, 1.0);
}

// PHONG
vertex PhongShaderData
vertexShaderPhong(uint vertexID [[vertex_id]],
                  constant AAPLVertex *vertices [[buffer(0)]],
                  constant Uniforms *uniforms [[buffer(1)]])
{
    PhongShaderData out;
    
    out.normal = (uniforms->MV * vertices[vertexID].normal).xyz; // no shear/nonuniform scale transformations, so may do just a mult
    out.pos = uniforms->MV * vertices[vertexID].position;
    out.vertPos = out.pos.xyz;
    out.pos = uniforms->P * out.pos;
    out.lightPos = (uniforms->MV * float4(uniforms->m.lightPos, 1)).xyz;
    out.ka = uniforms->m.ka;
    out.kd = uniforms->m.kd;
    out.ks = uniforms->m.ks;
    out.intensity = uniforms->m.intensity;
    out.s = uniforms->m.s;
    return out;
}

fragment float4 fragmentShaderPhong(PhongShaderData in [[stage_in]])
{
    float3 n = normalize(in.normal);
    float3 c = float3(0, 0, 0);
    float3 l = normalize(in.lightPos - in.vertPos);
    float3 h = normalize(normalize(-1 * in.vertPos) + l); // eye vector is 0 - vertPos since camPos = origin
    float3 cd = in.kd * floatMax(0, dot(l, n));
    float3 cs = in.ks * pow(floatMax(0, dot(h, n)), in.s);
    c += in.intensity * (in.ka + cd + cs);
    return float4(c, 1.0);
}


vertex ParticleShaderData
vertexShaderParticle(uint vertexID [[vertex_id]],
                     constant float3 *pos [[buffer(POS_BUFID)]],
                     constant float3 *col [[buffer(COL_BUFID)]],
                     constant float *alp [[buffer(ALP_BUFID)]],
                     constant float *sca [[buffer(SCA_BUFID)]],
                   constant ParticleUniforms *uniforms [[buffer(UNI_BUFID)]])
{
    ParticleShaderData out;
    out.pos = uniforms->P * uniforms->MV * float4(pos[vertexID], 1.0);
    out.color = col[vertexID];
    out.alp = alp[vertexID];
    // http://stackoverflow.com/questions/25780145/gl-pointsize-corresponding-to-world-space-size
    out.pointsize = uniforms->screenSize.y * uniforms->P[1][1] * sca[vertexID] / out.pos.w;
    return out;
}

fragment float4 fragmentShaderParticle(ParticleShaderData in [[stage_in]],
                                       texture2d<float>  tex [[texture(0)]],
                                       sampler s [[sampler(0)]],
                                       float2 pointCoord [[point_coord]])
{
    float alpha = tex.sample(s, pointCoord).r;
    return float4(in.color, in.alp*alpha);
}
