Shader "Hidden/CubeMapConvertor"
{
    Properties
    {
        _MainTex ("Texture", CUBE) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        CGINCLUDE
            #include "UnityCG.cginc"
             samplerCUBE _MainTex;
            float4 _MainTex_ST;
            
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
                float3  poisitionWS : TEXCOORD2;
            };
        
        ENDCG
        
        Pass
        {//sphere
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            int _SpheremappingScale;
            int _SpheredirectionMode;
            
            half3x3 rotateX(half angle)
            {
                angle = radians(angle);
                half3x3 rotateMartix = half3x3( half3(1,0,0),   
                                                half3(0,cos(angle),-sin(angle)),
                                                half3(0,sin(angle),cos(angle))
                                                );
                return rotateMartix;
            }

            half3x3 rotateY(half angle)
            {
                angle = radians(angle);
                half3x3 rotateMartix = half3x3( half3(cos(angle),0,sin(angle)),   
                                                half3(0,1,0),
                                                half3(-sin(angle), 0, cos(angle))
                                                );
                return rotateMartix;
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 sphere = float2(i.uv) * 2 - 1;
                float3 cubeCoords = normalize(float3(sphere.x, sphere.y, sqrt(1 - dot(sphere, sphere))));
                if(_SpheredirectionMode == 1)//back
                {
                    cubeCoords = normalize(mul(rotateY(180), cubeCoords));
                }else if(_SpheredirectionMode == 2)//top
                {
                    cubeCoords = normalize(mul(rotateX(-90), cubeCoords));
                    
                }

                //xy/z 等价 (x, y, smoothstep(0,value, dir.z)); value:1, 2
                if(_SpheremappingScale == 1)//scale
                {
                   cubeCoords.z = smoothstep(0,1.5, cubeCoords.z);
                }
                else if(_SpheremappingScale == 2)//two scale
                {
                    cubeCoords.z = smoothstep(0,2, cubeCoords.z);
                }
                
                float4 col = texCUBE(_MainTex, cubeCoords);
                return col;
            }
            ENDCG
        }
        
         Pass
        {//Equirectangular
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            int _EquirectangularModel;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.poisitionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float theta = 0;
                if(_EquirectangularModel == 1)
                {
                     theta = (i.uv.y + 1) * UNITY_HALF_PI;
                }else
                {
                    theta = (i.uv.y) * UNITY_PI;
                }
                float phi = i.uv.x * UNITY_TWO_PI;
                float3 unit = float3(0,0,0);
                
                unit.x = sin(phi) * sin(theta) * -1;
                unit.y = cos(theta) * -1;
                unit.z = cos(phi) * sin(theta) * -1;
              	//unit.y = smoothstep(0, 1, unit.y);//魔法赤道形变
                float4 col = texCUBE(_MainTex, unit);
                return col;
            }
            ENDCG
        }
    }
}
