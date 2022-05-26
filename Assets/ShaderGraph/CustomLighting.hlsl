#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

/* This is a neat trick to work around a bug in the shader when
   enabling shadow keywords */

#ifndef SHADERGRAPH_PREVIEW
    #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
        #if(SHADERPASS != SHADERPASS_FORWARD)
            #undef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
        #endif
 #endif

struct CustomLightingData
{
    //poistion and orientation
    float3 positionWS;
    float3 normalWS;
    float3 viewDirectionWS;
    float4 shadowCoord;
    
    // Surface attributes
    float3 albedo;
    float3 smoothness;
};

// Translate a [0,1] smoothness value to an exponent
float GetSmoothnessPower(float rawSmoothness)
{
    return exp2(10*rawSmoothness+1);
}

#ifndef SHADERGRAPH_PREVIEW

/* It calculates light with normals, light direction, viewDirection and returns color*/
float3 CustomLightHandling(CustomLightingData d, Light light)
{
    float3 radiance= light.color*light.shadowAttenuation;

    float3 diffuse= saturate(dot(d.normalWS,light.direction));

    float3 specularDot=saturate(dot(d.normalWS, normalize(light.direction+d.viewDirectionWS)));

    float3 specular= pow(specularDot, GetSmoothnessPower(d.smoothness)) * diffuse;
    
    float3 color= d.albedo*radiance*(diffuse+specular);

    return color;
}
#endif

/* It calculates lighting  which from light and converts into color */
float3 CalculateCustomLighting(CustomLightingData d)
{
    #ifdef SHADERGRAPH_PREVIEW
        /* In preview, estimate diffuse + specular */
        float3 lightDir=float3(0.5,0.5,0);
        float3 intensity= saturate(dot(d.normalWS,lightDir));
        return d.albedo*intensity;

    #else
        /* get the main lighting. Located in URP/ShaderLibrary/Lightng.hlsl */
         Light mainLight= GetMainLight(d.shadowCoord,d.positionWS,1);

        float3 color=0;
        /* shade the main lighting */
        color+=CustomLightHandling(d, mainLight);

        return color;

    #endif
}

/* Custom function which used in shader graph */
void CalculateCustomLighting_float(float3 Position,float3 Normal, float3 ViewDirection,float3 Albedo, float Smoothness,
                                                    out float3 Color)
{
    CustomLightingData d;
    d.positionWS=Position;
    d.normalWS= Normal;
    d.viewDirectionWS=ViewDirection;
    d.albedo = Albedo;
    d.smoothness=Smoothness;

    #ifdef SHADERGRAPH_PREVIEW
   /*  In preview, there are no shadows or bakedGI */
    d.shadowCoord=0;

   #else
       /* Calculate the main light shadow coord 
        * There are two types depending if cascading are enabled */
        float4 positionCS= TransformWorldToHClip(Position);

        #if SHADOWS_SCREEN
            d.shadowCoord=ComputeScreenPos(positionCS);
        #else
            d.shadowCoord=TransformWorldToShadowCoord(Position);
        #endif
    #endif 

    Color = CalculateCustomLighting(d);
}

#endif