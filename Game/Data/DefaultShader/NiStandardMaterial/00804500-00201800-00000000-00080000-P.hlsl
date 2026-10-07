#line 2 "C:\Users\zwenf\AppData\Local\Programs\Revival\Game\Data\DefaultShader\NiStandardMaterial\00804500-00201800-00000000-00080000-P.hlsl"
/*
Shader description:
APPLYMODE = 0
WORLDPOSITION = 0
WORLDNORMAL = 0
WORLDNBT = 0
WORLDVIEW = 0
NORMALMAPTYPE = 0
PARALLAXMAPCOUNT = 0
BASEMAPCOUNT = 1
NORMALMAPCOUNT = 0
DARKMAPCOUNT = 1
DETAILMAPCOUNT = 0
BUMPMAPCOUNT = 0
GLOSSMAPCOUNT = 0
GLOWMAPCOUNT = 1
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
UVSETFORMAP00 = 1
UVSETFORMAP01 = 0
UVSETFORMAP02 = 2
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
sampler2D Base;
sampler2D Glow;
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

    This fragment is responsible for sampling a texture and returning its value
    as a RGB value and an A value.
    
*/

void TextureRGBASample(float2 TexCoord,
    sampler2D Sampler,
    bool Saturate,
    out float4 ColorOut)
{

    ColorOut = tex2D(Sampler, TexCoord);
    if (Saturate)
    {
        ColorOut = saturate(ColorOut);
    }
    
}
//---------------------------------------------------------------------------
/*

    Separate a float4 into a float3 and a float.   
    
*/

void SplitColorAndOpacity(float4 ColorAndOpacity,
    out float3 Color,
    out float Opacity)
{

    Color.rgb = ColorAndOpacity.rgb;
    Opacity = ColorAndOpacity.a;
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for multiplying two float3's. 
    
*/

void MultiplyFloat3(float3 V1,
    float3 V2,
    out float3 Output)
{

    Output = V1 * V2;
    
}
//---------------------------------------------------------------------------
/*

    This fragment is responsible for adding two float3's. 
    
*/

void AddFloat3(float3 V1,
    float3 V2,
    out float3 Output)
{

    Output = V1 + V2;
    
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
    float2 UVSet1 : TEXCOORD1;
    float2 UVSet2 : TEXCOORD2;
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
    float3 ColorOut_CallOut1;
    TextureRGBSample(In.UVSet2, Glow, bool(false), ColorOut_CallOut1);

	// Function call #2
    float4 ColorOut_CallOut2;
    TextureRGBASample(In.UVSet1, Base, bool(false), ColorOut_CallOut2);

	// Function call #3
    float3 Color_CallOut3;
    float Opacity_CallOut3;
    SplitColorAndOpacity(ColorOut_CallOut2, Color_CallOut3, Opacity_CallOut3);

	// Function call #4
    float3 Output_CallOut4;
    MultiplyFloat3(ColorOut_CallOut0, Color_CallOut3, Output_CallOut4);

	// Function call #5
    float3 Output_CallOut5;
    AddFloat3(Output_CallOut4, ColorOut_CallOut1, Output_CallOut5);

	// Function call #6
    float3 OutputColor_CallOut6;
    CompositeFinalRGBColor(Output_CallOut5, float3(0.0, 0.0, 0.0), 
        OutputColor_CallOut6);

	// Function call #7
    float3 FoggedColor_CallOut7;
    ApplyFog(OutputColor_CallOut6, g_FogColor, In.FogDepth, 
        FoggedColor_CallOut7);

	// Function call #8
    CompositeFinalRGBAColor(FoggedColor_CallOut7, Opacity_CallOut3, Out.Color0);

    return Out;
}

