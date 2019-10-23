/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Header containing types and enum constants shared between Metal shaders and C/ObjC source
 */

#ifndef AAPLShaderTypes_h
#define AAPLShaderTypes_h
#define POS_BUFID 0
#define COL_BUFID 1
#define ALP_BUFID 2
#define SCA_BUFID 3
#define UNI_BUFID 4


#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
//typedef enum AAPLVertexInputIndex
//{
//    AAPLVertexInputIndexVertices     = 0,
//    AAPLVertexInputIndexViewportSize = 1,
//} AAPLVertexInputIndex;

//  This structure defines the layout of each vertex in the array of vertices set as an input to our
//    Metal vertex shader.  Since this header is shared between our .metal shader and C code,
//    we can be sure that the layout of the vertex array in our C code matches the layout that
//    our .metal vertex shader expects
typedef struct
{
    vector_float4 position;
    vector_float4 normal;
    vector_float2 texCoord;
    vector_float4 color;
} AAPLVertex;

typedef struct
{
    float intensity;
    vector_float3 lightPos;
    vector_float3 ka;
    vector_float3 kd;
    vector_float3 ks;
    float s;
} Material;

typedef struct
{
    matrix_float4x4 P;
    matrix_float4x4 MV;
    Material m;
} Uniforms;

typedef struct
{
    matrix_float4x4 P;
    matrix_float4x4 MV;
    vector_float2 screenSize;
} ParticleUniforms;

#endif /* AAPLShaderTypes_h */
