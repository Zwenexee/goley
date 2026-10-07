#line 2 "C:\Users\zwenf\AppData\Local\Programs\Revival\Game\Data\DefaultShader\NiStandardMaterial\00800400-00000800-00000000-00080000-P.hlsl"
/*
Shader description:
APPLYMODE = 0
WORLDPOSITION = 0
WORLDNORMAL = 0
WORLDNBT = 0
WORLDVIEW = 0
NORMALMAPTYPE = 0
PARALLAXMAPCOUNT = 0
BASEMAPCOUNT = 0
NORMALMAPCOUNT = 0
DARKMAPCOUNT = 1
DETAILMAPCOUNT = 0
BUMPMAPCOUNT = 0
GLOSSMAPCOUNT = 0
GLOWMAPCOUNT = 0
CUSTOMMAP00COUNT = 0
CUSTOMMAP01COUNT = 0
CUSTOMMAP02COUNT = 0
CUSTOMMAP03COUNT = 0
CUSTOMMAP04COUNT = 0
DECALMAPCOUNT = 0
FOGENABLED = 1
ENVMAPTYPE = 0
PROJLIGHTMAPCOUNT = 0
PROJLIGHTMAPTYPES = 0
PROJLIGHTMAPCLIPPED = 0
PROJSHADOWMAPCOUNT = 0
PROJSHADOWMAPTYPES = 0
PROJSHADOWMAPCLIPPED = 0
PERVERTEXLIGHTING = 1
UVSETFORMAP00 = 0
UVSETFORMAP01 = 0
UVSETFORMAP02 = 0
UVSETFORMAP03 = 0
UVSETFORMAP04 = 0
UVSETFORMAP05 = 0
UVSETFORMAP06 = 0
UVSETFORMAP07 = 0
UVSETFORMAP08 = 0
UVSETFORMAP09 = 0
UVSETFORMAP10 = 0
UVSETFORMAP11 = 0
POINTLIGHTCOUNT = 0
SPOTLIGHTCOUNT = 0
DIRLIGHTCOUNT = 0
SHADOWMAPFORLIGHT = 0
SPECULAR = 0
AMBDIFFEMISSIVE = 0
LIGHTINGMODE = 1
APPLYAMBIENT = 0
BASEMAPALPHAONLY = 0
APPLYEMISSIVE = 0
SHADOWTECHNIQUE = 0
ALPHATEST = 0
*/

//---------------------------------------------------------------------------
// Constant variables:
//---------------------------------------------------------------------------

sampler2D Dark;
float4 g_FogColor;
//---------------------------------------------------------------------------
// Functions:
//---------------------------------------------------------------------------

/*

    This fragment is responsible for sampling a texture and returning its value
    as a RGB value.
    
*/

void TextureRGBSample(float2 TexCoord,
    sampler2D Sampler,
    bool Saturate,
    out float3 ColorOut)
{

    ColorOut.rgb = tex2D(Sampler, TexCoord).rgb;
    if (Saturate)
    {
        ColorOut.rgb = saturate(ColorOut.rgb);
    }
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for computing the final RGB color.
    
*/

void CompositeFinalRGBColor(float3 DiffuseColor,
    float3 SpecularColor,
    out float3 OutputColor)
{

    OutputColor.rgb = DiffuseColor.rgb + SpecularColor.rgb;
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for applying the fog based on the 
    calculations in the vertex shader.
    
    
*/

void ApplyFog(float3 UnfoggedColor,
    float3 FogColor,
    float FogAmount,
    out float3 FoggedColor)
{

    FoggedColor = lerp(FogColor, UnfoggedColor, FogAmount);
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for computing the final RGBA color.
    
*/

void CompositeFinalRGBAColor(float3 FinalColor,
    float FinalOpacity,
    out float4 OutputColor)
{

    OutputColor.rgb = FinalColor.rgb;
    OutputColor.a = saturate(FinalOpacity);
    
}
//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
// Input:
//---------------------------------------------------------------------------

struct Input
{
    float4 PosProjected : POSITION0;
    float2 UVSet0 : TEXCOORD0;
    float FogDepth : FOG0;

};

//---------------------------------------------------------------------------
// Output:
//---------------------------------------------------------------------------

struct Output
{
    float4 Color0 : COLOR0;

};

//---------------------------------------------------------------------------
// Main():
//---------------------------------------------------------------------------

Output Main(Input In)
{
    Output Out;
	// Function call #0
    float3 ColorOut_CallOut0;
    TextureRGBSample(In.UVSet0, Dark, bool(false), ColorOut_CallOut0);

	// Function call #1
    float3 OutputColor_CallOut1;
    CompositeFinalRGBColor(ColorOut_CallOut0, float3(0.0, 0.0, 0.0), 
        OutputColor_CallOut1);

	// Function call #2
    float3 FoggedColor_CallOut2;
    ApplyFog(OutputColor_CallOut1, g_FogColor, In.FogDepth, 
        FoggedColor_CallOut2);

	// Function call #3
    CompositeFinalRGBAColor(FoggedColor_CallOut2, float(1.0), Out.Color0);

    return Out;
}

