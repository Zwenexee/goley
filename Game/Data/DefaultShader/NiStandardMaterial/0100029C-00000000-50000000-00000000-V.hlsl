#line 2 "C:\Users\zwenf\AppData\Local\Programs\Revival\Game\Data\DefaultShader\NiStandardMaterial\0100029C-00000000-50000000-00000000-V.hlsl"
/*
Shader description:
TRANSFORM = 0
OUTPUTWORLDPOS = 1
OUTPUTWORLDNBT = 1
OUTPUTWORLDVIEW = 1
OUTPUTTANGENTVIEW = 0
NORMAL = 2
SPECULAR = 0
FOGTYPE = 1
ENVMAPTYPE = 0
PROJLIGHTMAPCOUNT = 0
PROJLIGHTMAPTYPES = 0
PROJSHADOWMAPCOUNT = 0
PROJSHADOWMAPTYPES = 0
OUTPUTUVCOUNT = 1
UVSET00 = 0
UVSET00TEXOUTPUT = 0
UVSET01 = 0
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
VERTEXLIGHTSONLY = 0
AMBDIFFEMISSIVE = 0
LIGHTINGMODE = 1
APPLYMODE = 1
*/

//---------------------------------------------------------------------------
// Constant variables:
//---------------------------------------------------------------------------

float4x4 g_World;
float4x4 g_View;
float4x4 g_Proj;
float4 g_EyePos;
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
    normal, binormal, and tangent.
    
*/

void TransformNBT(float3 Normal,
    float3 Binormal,
    float3 Tangent,
    float4x4 World,
    out float3 WorldNrm,
    out float3 WorldBinormal,
    out float3 WorldTangent)
{

    // Transform the normal into world space for lighting
    WorldNrm      = mul( Normal, (float3x3)World );
    WorldBinormal = mul( Binormal, (float3x3)World );
    WorldTangent  = mul( Tangent, (float3x3)World );
    
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
//---------------------------------------------------------------------------
// Input:
//---------------------------------------------------------------------------

struct Input
{
    float3 Position : POSITION0;
    float3 Normal : NORMAL0;
    float2 UVSet0 : TEXCOORD0;
    float3 Tangent : TANGENT0;
    float3 Binormal : BINORMAL0;

};

//---------------------------------------------------------------------------
// Output:
//---------------------------------------------------------------------------

struct Output
{
    float4 PosProjected : POSITION0;
    float4 WorldPos : TEXCOORD0;
    float3 WorldNormal : TEXCOORD1;
    float3 WorldBinormal : TEXCOORD2;
    float3 WorldTangent : TEXCOORD3;
    float3 WorldView : TEXCOORD4;
    float2 UVSet0 : TEXCOORD5;
    float FogOut : FOG0;

};

//---------------------------------------------------------------------------
// Main():
//---------------------------------------------------------------------------

Output Main(Input In)
{
    Output Out;
	// Function call #0
    TransformPosition(In.Position, g_World, Out.WorldPos);

	// Function call #1
    float4 ViewPos_CallOut1;
    ProjectPositionWorldToViewToProj(Out.WorldPos, g_View, g_Proj, 
        ViewPos_CallOut1, Out.PosProjected);

	// Function call #2
    CalculateFog(int(3), g_FogDensity, ViewPos_CallOut1, bool(false), 
        g_FogNearFar, Out.FogOut);

	// Function call #3
    TransformNBT(In.Normal, In.Binormal, In.Tangent, g_World, Out.WorldNormal, 
        Out.WorldBinormal, Out.WorldTangent);

	// Function call #4
    CalculateViewVector(Out.WorldPos, g_EyePos, Out.WorldView);

    Out.UVSet0 = In.UVSet0;
    return Out;
}

