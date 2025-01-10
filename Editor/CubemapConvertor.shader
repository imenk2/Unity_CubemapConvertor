Shader "Hidden/CubeMapConvertor"
{
    Properties
    {
        _MainTex ("Texture", CUBE) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
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
            float3 poisitionWS : TEXCOORD2;
        };
        ENDCG

        Pass
        {
            //CircularCone
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            int _SpheremappingScale;
            int _SpheredirectionMode;

            half3x3 rotateX(half angle)
            {
                angle = radians(angle);
                half3x3 rotateMartix = half3x3(half3(1, 0, 0),
                                               half3(0, cos(angle), -sin(angle)),
                                               half3(0, sin(angle), cos(angle))
                );
                return rotateMartix;
            }

            half3x3 rotateY(half angle)
            {
                angle = radians(angle);
                half3x3 rotateMartix = half3x3(half3(cos(angle), 0, sin(angle)),
                                               half3(0, 1, 0),
                                               half3(-sin(angle), 0, cos(angle))
                );
                return rotateMartix;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 sphere = float2(i.uv) * 2 - 1;
                float3 cubeCoords = normalize(float3(sphere.x, sphere.y, sqrt(1 - dot(sphere, sphere))));
                if (_SpheredirectionMode == 1) //back
                {
                    cubeCoords = normalize(mul(rotateY(180), cubeCoords));
                }
                else if (_SpheredirectionMode == 2) //top
                {
                    cubeCoords = normalize(mul(rotateX(-90), cubeCoords));
                }

                //xy/z 等价 (x, y, smoothstep(0,value, dir.z)); value:1, 2
                if (_SpheremappingScale == 1) //scale
                {
                    cubeCoords.z = smoothstep(0, 1.5, cubeCoords.z);
                }
                else if (_SpheremappingScale == 2) //two scale
                {
                    cubeCoords.z = smoothstep(0, 2, cubeCoords.z);
                }

                float4 col = texCUBE(_MainTex, cubeCoords);
                return col;
            }
            ENDCG
        }

        Pass
        {
            //Equirectangular
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            int _EquirectangularModel;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.poisitionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                float theta = 0;
                if (_EquirectangularModel == 1)
                {
                    theta = (i.uv.y + 1) * UNITY_HALF_PI;
                }
                else
                {
                    theta = (i.uv.y) * UNITY_PI;
                }
                float phi = i.uv.x * UNITY_TWO_PI;
                float3 unit = float3(0, 0, 0);

                unit.x = sin(phi) * sin(theta) * -1;
                unit.y = cos(theta) * -1;
                unit.z = cos(phi) * sin(theta) * -1;
                //unit.y = smoothstep(0, 1, unit.y);//魔法赤道形变
                float4 col = texCUBE(_MainTex, unit);
                return col;
            }
            ENDCG
        }

        Pass
        {
            //ConcentricOctahedral
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            int _octModel;
            
            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.poisitionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float3 concentricMapping_hemisphere_2DTo3D(float2 direction)
            {
                direction = direction * 2.0f - 1.0f;
                float u = max(abs(direction.x), abs(direction.y));
                float v = min(abs(direction.x), abs(direction.y));

                float r = u;
                float phi = UNITY_PI / 4 * v / u;

                float x = cos(phi) * r * sqrt(2.0f - r * r);
                float y = sin(phi) * r * sqrt(2.0f - r * r);
                float z = 1.0f - r * r;

                if (abs(direction.x) < abs(direction.y))
                {
                    float temp = x;
                    x = y;
                    y = temp;
                }

                x *= sign(direction.x);
                y *= sign(direction.y);

                return normalize(float3(x, y, z));
            }

            float RTXGISignNotZero(float v)
            {
	            return (v >= 0.f) ? 1.f : -1.f;
            }
                        
            float2 RTXGISignNotZero(float2 v)
            {
	            return float2(RTXGISignNotZero(v.x), RTXGISignNotZero(v.y));
            }
            
           float3 octSphereMap(float2 coords)
            {
	            coords *= 2.f;
	            coords -= float2(1.f, 1.f);
	            
	            float3 direction = float3(coords.x, coords.y, 1.f - abs(coords.x) - abs(coords.y));
	            if (direction.z < 0.f)
	            {
		            direction.xy = (1.f - abs(direction.yx)) * RTXGISignNotZero(direction.xy);
	            }
	            return normalize(direction);
            }

            float signPreserveZero(float v)
            {
	            int i = asint(v);

	            return (i < 0) ? -1.0 : 1.0;
            }

            float3 concentric_octSphereMap(float2 u)
            {
	            u = u * 2.f - 1.f;

                // Compute radius r (branchless)
	            float d = 1.f - (abs(u.x) + abs(u.y));
	            float r = 1.f - abs(d);

                // Compute phi in the first quadrant (branchless, except for the
                // division-by-zero test), using sign(u) to map the result to the
                // correct quadrant below
	            float phi = (r == 0.f) ? 0.f :
                    (UNITY_PI / 4 * ((abs(u.y) - abs(u.x)) / r + 1.f));

	            float f = r * sqrt(2.f - r * r);

                // abs() around f * cos/sin(phi) is necessary because they can return
                // negative 0 due to floating precision
	            float x = signPreserveZero(u.x) * abs(f * cos(phi));
	            float y = signPreserveZero(u.y) * abs(f * sin(phi));
	            float z = signPreserveZero(d) * (1.f - r * r);

	            return float3(x, y, z);
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 cubeUV = 0;
                if(_octModel == 1)
                {
                    cubeUV = concentric_octSphereMap(i.uv);
                }else
                {
                    cubeUV = octSphereMap(i.uv);
                }
                float4 col = texCUBE(_MainTex, cubeUV);
                return col;
            }
            ENDCG
        }
    }
}