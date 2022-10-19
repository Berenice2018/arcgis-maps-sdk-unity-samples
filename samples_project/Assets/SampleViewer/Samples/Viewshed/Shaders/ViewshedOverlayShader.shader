
Shader "URPViewshedOverlay"
{
    Properties
    { }

    SubShader
    {
        //Place in transparent queue to ensure opaques are rendered to depth buffer
        Tags { "Queue" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };

            float3 _ViewshedObserverPosition;
            float4x4 _ViewshedObserverViewProjMatrix;
            sampler2D _CameraOpaqueTexture;
            //sampler2D _LastCameraDepthTexture; //not working in URP
            sampler2D _ViewshedObserverDepthTexture;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;

                // Sample the depth from the Camera depth texture.
                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(UV);
                #else
                    // Adjust Z to match NDC for OpenGL ([-1, 1])
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif

                // Reconstruct the world space positions.
                float3 worldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
                float4 viewCoord = mul(_ViewshedObserverViewProjMatrix, float4(worldPos.xyz,1));
                float4 colorBase = tex2D(_CameraOpaqueTexture, UV);
                
                float2 viewUV = (viewCoord.xy / viewCoord.w) * 0.5 + 0.5;
                viewUV.y = 1-viewUV.y;

                //do not draw viewshed effect if fragment is outside of observer's viewable area
                if(viewUV.x < 0 || viewUV.x > 1 || viewUV.y < 0 || viewUV.y > 1 || viewCoord.z < 0 || depth < 0.000001)
                    return colorBase;

                float fragmentDepth = distance(_ViewshedObserverPosition, worldPos);
                float observerDepth = tex2D(_ViewshedObserverDepthTexture, viewUV).r;
                //float observerDepth = observerDepthSample.r;// - viewCoord.z;

                //colorize fragments withing viewshed area (ignore anything beyond reasonable depth threshold)
                //TODO: update for OpenGL platforms where depth is reversed
                const float eps = 0.0001;
                if(viewCoord.z > observerDepth && abs(viewCoord.z - observerDepth) > eps)
                {
                    colorBase *= float4(1, 0.6, 0.6, 1);
                }
                else
                {
                    colorBase *= float4(0.6, 1, 0.6, 1);
                }

                return colorBase;
            }
            ENDHLSL
        }
    }
}