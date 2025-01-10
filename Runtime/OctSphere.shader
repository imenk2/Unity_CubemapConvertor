Shader "Unlit/OctSphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Toggle]_Model("mode", int) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD1;
                float3 pos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            int _Model;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                return o;
            }

            float RTXGISignNotZero(float v)
            {
                return (v >= 0.f) ? 1.f : -1.f;
            }

            /**
             * 2-component version of RTXGISignNotZero.
             */
            float2 RTXGISignNotZero(float2 v)
            {
                return float2(RTXGISignNotZero(v.x), RTXGISignNotZero(v.y));
            }

            /**
             * Computes the octant coordinates in the normalized [-1, 1] square, for the given a unit direction vector.
             * The opposite of DDGIGetOctahedralDirection().
             * Used by GetDDGIVolumeIrradiance() in Irradiance.hlsl.
             */
            float2 invOctSphereMap2(float3 direction)
            {
                float l1norm = abs(direction.x) + abs(direction.y) + abs(direction.z);
                float2 uv = direction.xy * (1.f / l1norm);
                if (direction.z < 0.f)
                {
                    uv = (1.f - abs(uv.yx)) * RTXGISignNotZero(uv.xy);
                }

                return uv * 0.5 + 0.5;
            }

            float signPreserveZero(float v)
            {
                int i = asint(v);

                return (i < 0) ? -1.0 : 1.0;
            }

            float2 invOctSphereMap(float3 dir)
            {
                float r = sqrt(1.f - abs(dir.z));
                float phi = atan2(abs(dir.y), abs(dir.x));

                float2 uv;
                uv.y = r * phi * (2 / UNITY_PI);
                uv.x = r - uv.y;

                if (dir.z < 0.f)
                {
                    uv = 1.f - uv.yx;
                }

                uv.x *= signPreserveZero(dir.x);
                uv.y *= signPreserveZero(dir.y);

                return uv * 0.5f + 0.5f;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // sample the texture
                float3 v = normalize(_WorldSpaceCameraPos - i.normalWS);
                float3 r = reflect(-v, i.normalWS);
                float2 uv = 0;
                if (_Model == 0)
                {
                    uv = invOctSphereMap2(i.normalWS);
                }
                else
                {
                    uv = invOctSphereMap(i.normalWS);
                }
                fixed4 col = tex2D(_MainTex, uv);
                // apply fog
                return col;
            }
            ENDCG
        }
    }
}