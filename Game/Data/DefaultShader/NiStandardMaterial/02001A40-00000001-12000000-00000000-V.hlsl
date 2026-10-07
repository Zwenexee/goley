#line 2 "C:\Users\zwenf\AppData\Local\Programs\Revival\Game\Data\DefaultShader\NiStandardMaterial\02001A40-00000001-12000000-00000000-V.hlsl"
/*
Shader description:
TRANSFORM = 0
OUTPUTWORLDPOS = 0
OUTPUTWORLDNBT = 0
OUTPUTWORLDVIEW = 0
OUTPUTTANGENTVIEW = 0
NORMAL = 1
SPECULAR = 0
FOGTYPE = 1
ENVMAPTYPE = 3
PROJLIGHTMAPCOUNT = 0
PROJLIGHTMAPTYPES = 0
PROJSHADOWMAPCOUNT = 0
PROJSHADOWMAPTYPES = 0
OUTPUTUVCOUNT = 2
UVSET00 = 0
UVSET00TEXOUTPUT = 0
UVSET01 = 1
UVSET01TEXOUTPUT = 0
UVSET02 = 0
UVSET02TEXOUTPUT = 0
UVSET03 = 0
UVSET03TEXOUTPUT = 0
UVSET04 = 0
UVSET04TEXOUTPUT = 0
UVSET05 = 0
UVSET05TEXOUTPUT = 0
UVSET06 = 0
UVSET06TEXOUTPUT = 0
UVSET07 = 0
UVSET07TEXOUTPUT = 0
UVSET08 = 0
UVSET08TEXOUTPUT = 0
UVSET09 = 0
UVSET09TEXOUTPUT = 0
UVSET10 = 0
UVSET10TEXOUTPUT = 0
UVSET11 = 0
UVSET11TEXOUTPUT = 0
POINTLIGHTCOUNT = 0
SPOTLIGHTCOUNT = 0
DIRLIGHTCOUNT = 0
VERTEXCOLORS = 0
VERTEXLIGHTSONLY = 1
AMBDIFFEMISSIVE = 0
LIGHTINGMODE = 1
APPLYMODE = 0
*/

//---------------------------------------------------------------------------
// Constant variables:
//---------------------------------------------------------------------------

float4x4 g_World;
float4x4 g_View;
float4x4 g_Proj;
float4 g_EyePos;
float4x4 g_EnvironmentMapWorldProjectionTransform0;
float4 g_FogDensity;
float4 g_FogNearFar;
//---------------------------------------------------------------------------
// Functions:
//---------------------------------------------------------------------------

/*

    This fragment is responsible for applying the view projection transform
    to the input position. Additionally, this fragment applies the world 
    transform to the input position. 
    
*/

void TransformPosition(float3 Position,
    float4x4 World,
    out float4 WorldPos)
{

    // Transform the position into world space for lighting, and projected 
    // space for display
    WorldPos = mul( float4(Position, 1.0f), World );
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for applying the view projection transform
    to the input world position.
    
*/

void ProjectPositionWorldToViewToProj(float4 WorldPosition,
    float4x4 ViewTransform,
    float4x4 ProjTransform,
    out float4 ViewPos,
    out float4 ProjPos)
{

    ViewPos = mul(WorldPosition, ViewTransform);
    ProjPos = mul(ViewPos, ProjTransform);
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for handling fogging calculations.
    FogType can be one of 4 values:
    
        NONE   - 0
        EXP    - 1
        EXP2   - 2
        LINEAR - 3
    
*/

void CalculateFog(int FogType,
    float FogDensity,
    float4 ViewPosition,
    bool FogRange,
    float2 FogStartEnd,
    out float FogOut)
{

    float d;
    if (FogRange)
    {
        d = length(ViewPosition);
    }
    else
    {
        d = ViewPosition.z;
    }
    
    if (FogType == 0) // NONE
    {
        FogOut = 1.0;
    }
    else if (FogType == 1) // EXP
    {
        FogOut = 1.0 / exp( d * FogDensity);
    }
    else if (FogType == 2) // EXP2
    {
        FogOut = 1.0 / exp( pow( d * FogDensity, 2));
    }
    else if (FogType == 3) // LINEAR
    {
        FogOut = saturate( (FogStartEnd.y - d) / 
            (FogStartEnd.y - FogStartEnd.x));
    }
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for applying the world transform to the
    normal.
    
*/

void TransformNormal(float3 Normal,
    float4x4 World,
    out float3 WorldNrm)
{

    // Transform the normal into world space for lighting
    WorldNrm = mul( Normal, (float3x3)World );

    // Should not need to normalize here since we will normalize in the pixel 
    // shader due to linear interpolation across triangle not preserving
    // normality.
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for calculating the camera view vector.
    
*/

void CalculateViewVector(float4 WorldPos,
    float3 CameraPos,
    out float3 WorldViewVector)
{

    WorldViewVector = CameraPos - WorldPos;
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for computing the reflection vector.
    The WorldViewVector is negated because the HLSL "reflect" function
    expects a world-to-camera vector, rather than a camera-to-world vector.
    
*/

void WorldReflect(float3 WorldNrm,
    float3 WorldViewVector,
    bool NormalizeNormal,
    out float3 WorldReflect)
{

    if (NormalizeNormal)
        WorldNrm = normalize(WorldNrm);
    WorldReflect = reflect(-WorldViewVector, WorldNrm);
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for normalizing a float3.
    
*/

void NormalizeFloat3(float3 VectorIn,
    out float3 VectorOut)
{

    VectorOut = normalize(VectorIn);
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for applying a projection to the input set
    of texture coordinates.
    
*/

void ProjectTextureCoordinates(float3 TexCoord,
    float4x4 TexTransform,
    out float4 TexCoordOut)
{

  
    TexCoordOut = mul(float4(TexCoord, 1.0), TexTransform);
    
    
}
//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
// Input:
//---------------------------------------------------------------------------

struct Input
{
    float3 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 UVSet0 : TEXCOORD0;
    float2 UVSet1 : TEXCOORD1;

};

//---------------------------------------------------------------------------
// Output:
//---------------------------------------------------------------------------

struct Output
{
    float4 PosProjected : POSITION0;
    float2 UVSet0 : TEXCOORD0;
    float2 UVSet1 : TEXCOORD1;
    float4 UVSet2 : TEXCOORD2;
    float FogOut : FOG0;

};

//---------------------------------------------------------------------------
// Main():
//---------------------------------------------------------------------------

Output Main(Input In)
{
    Output Out;
	// Function call #0
    float4 WorldPos_CallOut0;
    TransformPosition(In.Position, g_World, WorldPos_CallOut0);

	// Function call #1
    float4 ViewPos_CallOut1;
    ProjectPositionWorldToViewToProj(WorldPos_CallOut0, g_View, g_Proj, 
        ViewPos_CallOut1, Out.PosProjected);

	// Function call #2
    CalculateFog(int(3), g_FogDensity, ViewPos_CallOut1, bool(false), 
        g_FogNearFar, Out.FogOut);

	// Function call #3
    float3 WorldNrm_CallOut3;
    TransformNormal(In.Normal, g_World, WorldNrm_CallOut3);

	// Function call #4
    float3 WorldViewVector_CallOut4;
    CalculateViewVector(WorldPos_CallOut0, g_EyePos, WorldViewVector_CallOut4);

	// Function call #5
    float3 WorldReflect_CallOut5;
    WorldReflect(WorldNrm_CallOut3, WorldViewVector_CallOut4, bool(true), 
        WorldReflect_CallOut5);

	// Function call #6
    float3 VectorOut_CallOut6;
    NormalizeFloat3(WorldReflect_CallOut5, VectorOut_CallOut6);

	// Function call #7
    ProjectTextureCoordinates(VectorOut_CallOut6, 
        g_EnvironmentMapWorldProjectionTransform0, Out.UVSet2);

    Out.UVSet0 = In.UVSet0;
    Out.UVSet1 = In.UVSet1;
    return Out;
}

