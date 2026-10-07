#line 2 "C:\Users\zwenf\AppData\Local\Programs\Revival\Game\Data\DefaultShader\NiStandardMaterial\81000000-00000000-12000000-00000000-V.hlsl"
/*
Shader description:
TRANSFORM = 0
OUTPUTWORLDPOS = 0
OUTPUTWORLDNBT = 0
OUTPUTWORLDVIEW = 0
OUTPUTTANGENTVIEW = 0
NORMAL = 0
SPECULAR = 0
FOGTYPE = 0
ENVMAPTYPE = 0
PROJLIGHTMAPCOUNT = 0
PROJLIGHTMAPTYPES = 0
PROJSHADOWMAPCOUNT = 0
PROJSHADOWMAPTYPES = 0
OUTPUTUVCOUNT = 1
UVSET00 = 0
UVSET00TEXOUTPUT = 1
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
VERTEXLIGHTSONLY = 1
AMBDIFFEMISSIVE = 0
LIGHTINGMODE = 1
APPLYMODE = 0
*/

//---------------------------------------------------------------------------
// Constant variables:
//---------------------------------------------------------------------------

float4x4 g_World;
float4x4 g_ViewProj;
float4x4 UVSet0_TexTransform;
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

    This fragment is responsible for applying a transform to the input set
    of texture coordinates.
    
*/

void TexTransformApply(float2 TexCoord,
    float4x4 TexTransform,
    out float2 TexCoordOut)
{

    
    TexCoordOut = mul(float4(TexCoord.x, TexCoord.y, 0.0, 1.0), TexTransform);
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for applying the view projection transform
    to the input world position.
    
*/

void ProjectPositionWorldToProj(float4 WorldPosition,
    float4x4 ViewProjection,
    out float4 ProjPos)
{

    ProjPos = mul(WorldPosition, ViewProjection);
    
}
//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
// Input:
//---------------------------------------------------------------------------

struct Input
{
    float3 Position : POSITION0;
    float2 UVSet0 : TEXCOORD0;

};

//---------------------------------------------------------------------------
// Output:
//---------------------------------------------------------------------------

struct Output
{
    float4 PosProjected : POSITION0;
    float2 UVSet0 : TEXCOORD0;

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
    TexTransformApply(In.UVSet0, UVSet0_TexTransform, Out.UVSet0);

	// Function call #2
    ProjectPositionWorldToProj(WorldPos_CallOut0, g_ViewProj, Out.PosProjected);

    return Out;
}

