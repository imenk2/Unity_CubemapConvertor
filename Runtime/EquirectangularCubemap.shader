Shader "Unlit/testCubemap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue" = "Background" "RenderType" = "Background" "PreviewType" = "Skybox" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

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
                float3 Pos : TEXCOORD1;
                float3 Normal : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.Normal = UnityObjectToWorldNormal(v.normal);//UnityObjectToWorldNormal(v.normal);
                o.Pos = mul(UNITY_MATRIX_M, float4(v.vertex.xyz,1)).xyz;//mul(UNITY_MATRIX_M, v.vertex).xyz;
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 N = normalize(i.Normal);
                float2 longlat = float2(atan2(N.x, N.z), asin(N.y));
                float2 uv = longlat / float2(UNITY_TWO_PI, UNITY_PI);
                uv.x += 0.5;
                uv.y += uv.y;
                uv.x += frac(_Time.y * 0.01);
                // 将经纬度映射到贴图上
                fixed4 col = tex2D(_MainTex, uv);
                return col;
            }
            ENDCG
        }
    }
}
