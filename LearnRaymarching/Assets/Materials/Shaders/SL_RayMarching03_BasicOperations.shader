Shader "RayMarching/RayMarching03_BasicOperators" {
    Properties {
        [Header(Switches)]
        [Toggle(BasicOperators)]_BasicOperators ("基础运算", float) = 1.0
        [Toggle(SmoothUnion)]_SmoothUnion ("平滑融合", float) = 1.0
        [Toggle(LerpObjects)]_LerpObjects ("融合变形", float) = 1.0

        
        [Header(Lighting)]
        _LightPos       ("光源位置", Vector) = (0.0, 5.0, 0.0, 0.0)
        _ShadowInt      ("阴影强度", Range(0.0, 1.0)) = 0.1
        
        [Header(Basic Operator)]
        _SphereDOrigin   ("球体D中心位置", Vector) = (-1.0, 1.0, 3.0, 0.0)
        _SphereDRadius   ("球体D半径", float) = 1.0
        _SphereEOrigin   ("球体E中心位置", Vector) = (1.0, 1.0, 3.0, 0.0)
        _SphereERadius   ("球体E半径", float) = 1.0
        
        _SphereFOrigin   ("球体F中心位置", Vector) = (-1.0, 1.0, 3.0, 0.0)
        _SphereFRadius   ("球体F半径", float) = 1.0
        _SphereGOrigin   ("球体G中心位置", Vector) = (1.0, 1.0, 3.0, 0.0)
        _SphereGRadius   ("球体G半径", float) = 1.0
        
        
        [Header(Smooth Union)]
        _SphereColor     ("球颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        _SphereAOrigin   ("球体A中心位置", Vector) = (-1.0, 1.0, 3.0, 0.0)
        _SphereARadius   ("球体A半径", float) = 1.0
        _SphereBOrigin   ("球体B中心位置", Vector) = (1.0, 1.0, 3.0, 0.0)
        _SphereBRadius   ("球体B半径", float) = 1.0
        
        [Header(Blend)]
        _BoxOrigin      ("盒体中心位置", Vector) = (-2.0, 1.0, 4.0, 0.0)
        _BoxSize        ("盒体大小, X: 长， Y: 宽， Z: 高", Vector) = (1.0, 1.0, 1.0, 1.0)
        _SphereCOrigin   ("球体中心位置", Vector) = (1.0, 1.0, 3.0, 0.0)
        _SphereCRadius   ("球体半径", float) = 1.0
        
        
        [Header(Misc)]
        _Smoothness      ("融合平滑度", float) = 0.1
        _BackgroundColor ("背景颜色", Color) = (0.0, 0.0, 0.0, 1.0)
        
//        [Header(Capsule)]
//        _CapsuleEndA    ("胶囊体顶点A位置", Vector) = (0.0, 1.0, 0.0, 0.0) 
//        _CapsuleEndB    ("胶囊体顶点B位置", Vector) = (0.0, 7.0, 0.0, 0.0) 
//        _CapsuleRadius  ("胶囊体半径", float)       = 0.5
//
//        [Header(Torus)]
//        _TorusOrigin    ("甜甜圈中心位置", Vector) = (0.0, 1.0, 6.0, 0.0)
//        _TorusRadius    ("甜甜圈半径", float) = 0.5
//        _TorusThickness ("甜甜圈厚度", float) = 0.5
//        
//        
//        [Header(Cylinder)]
//        _CylinderEndA   ("圆柱体端点A位置", Vector) = (0.0, 1.0, 3.0, 0.0)
//        _CylinderEndB   ("圆柱体端点B位置", Vector) = (0.0, 4.0, 3.0, 0.0)
//        _CylinderRadius ("圆柱体半径", float) = 0.5
    
    }
    
    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature SmoothUnion
            #pragma shader_feature LerpObjects
            #pragma shader_feature BasicOperators

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_STEPS 200   // 光线步进的最大步进次数
            #define MAX_DIST 200.   // 光线步进的最大步进距离
            #define SURF_DIST 0.001  // 光线击中物体表面的判断距离，即光线与物体的距离小于SURF_DIST则判定击中物体表面


            // 光照参数
            float4 _LightPos;
            float _ShadowInt;

            // 基础运算
            float4 _SphereDOrigin, _SphereEOrigin, _SphereFOrigin, _SphereGOrigin;
            float _SphereDRadius, _SphereERadius, _SphereFRadius, _SphereGRadius;
            
            // 平滑融合
            float4 _SphereAOrigin, _SphereBOrigin, _SphereColor;
            float _SphereARadius, _SphereBRadius;
            
            // 融合变形
            float4 _BoxOrigin, _BoxSize;
            float4 _SphereCOrigin;
            float _SphereCRadius;

            // Misc
            float4 _BackgroundColor;
            float _Smoothness;
            
            
            struct VertexInput {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertexOutput {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            VertexOutput vert (VertexInput v) {
                VertexOutput o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            // 旋转矩阵
            float2x2 Rotate(float angle)
            {
                float c = cos(angle);
                float s = sin(angle);
                return transpose(float2x2(c, -s, s, c));
            }

            float smin(float a, float b, float k)
            {
                float h = saturate(0.5 + 0.5 * (b - a)/k);
                return lerp(b, a, h) - k * h * (1.0 - h);
            }

            // 球体距离场
            float sdSphere(float3 rayCurrentPos, float3 origin, float radius)
            {
                return length(rayCurrentPos - origin) - radius;
            }
            
            // 盒体距离场
            float sdBox(float3 rayCurrentPos)
            {
                float3 rayPosRelativeToBox = rayCurrentPos - _BoxOrigin.xyz;
                rayPosRelativeToBox.xz = mul(Rotate(_Time.y), rayPosRelativeToBox.xz);      // 旋转盒体
                return length(max(abs(rayPosRelativeToBox) - _BoxSize.xyz, 0));
            }
            

            // 计算光线当前位置到物体表面的距离
            float GetDist(float3 rayCurrentPos)
            {
                float distance = 0;

                // 基础运算
                #ifdef BasicOperators
                // Boolean
                float sphereA = sdSphere(rayCurrentPos, float3( sin(_Time.y) * 0.5 + _SphereDOrigin.x, _SphereDOrigin.yz ), 
                _SphereDRadius);
                float sphereB = sdSphere(rayCurrentPos, _SphereEOrigin, _SphereERadius);
                float boolean = max(-sphereA, sphereB);
                
                // Intersection
                float sphereC = sdSphere(rayCurrentPos, float3( sin(_Time.y) * 0.5 + _SphereFOrigin.x, _SphereFOrigin.yz ), 
                _SphereFRadius);
                float sphereD = sdSphere(rayCurrentPos, _SphereGOrigin, _SphereGRadius);
                float intersection = max(sphereC, sphereD);

                return min(intersection, boolean);
                #endif
                


                // 融合变形
                #ifdef LerpObjects
                float box = sdBox(rayCurrentPos);
                float sphere = sdSphere(rayCurrentPos, _SphereCOrigin.xyz, _SphereCRadius);
                distance = lerp(box, sphere, sin(_Time.y) * 0.5 + 0.5);
                return distance;
                #endif
                
                // 平滑融合
                #ifdef SmoothUnion
                float sphereA = sdSphere(rayCurrentPos, float3(sin(_Time.y) * 0.8 + _SphereAOrigin.x, _SphereAOrigin.y, 
                _SphereAOrigin.z), _SphereARadius);
                float sphereB = sdSphere(rayCurrentPos, float3(_SphereBOrigin.x, sin(_Time.z) * 0.5 + _SphereBOrigin.y, 
                _SphereBOrigin.z), _SphereBRadius);
                distance = smin(sphereA, sphereB, _Smoothness);
                return distance;
                #endif

                return distance;
                
                
                

                // float distance = max(-sphereA, sphereB);    // Boolean
                // float distance = max(sphereA, sphereB);     // Intersection
                // distance = min(distPlaneToRay, distance);
                
            }
            
            // 计算物体表面法线方向
            float3 GetNormal(float3 rayPos)
            {
                float distRayToObj = GetDist(rayPos);           // 获取光线当前位置到最近物体表面的距离
                float2 pointDelta = float2(0.001, 0);            // 取光线当前位置周围的点所需的偏移量
                float3 normalDir = distRayToObj - float3(       // 计算物体表面法线方向
                    GetDist(rayPos - pointDelta.xyy),
                    GetDist(rayPos - pointDelta.yxy),
                    GetDist(rayPos - pointDelta.yyx));
                return normalize(normalDir);
            }

            // RayMarching函数
            float RayMarch(float3 rayOrigin, float3 rayDirection)
            {
                float marchedDist = 0.0;                                            // 储存当前光线距离光线起始点的距离

                // 光线步进循环
                for(int i = 0; i < MAX_STEPS; i++)
                {
                    float3 rayCurrentPos = rayOrigin + marchedDist * rayDirection;  // 光线在当前步进循环前所处的位置
                    float distRayToObj = GetDist(rayCurrentPos);                    // 光线从当前位置到物体表面的距离
                    marchedDist += distRayToObj;                                    // 光线当前位置 + 距离物体表面的距离 = 本次步进之后光线行进的距离
                    if(marchedDist > MAX_DIST || distRayToObj <= SURF_DIST) break;  // 超过最大步进距离或与最近物体表面距离小于阈值，则结束步进循环
                }
                return marchedDist;
                
            }
            
            // 计算光照信息
            float GetLight(float3 rayPos)
            {
                float3 lightPos = _LightPos.xyz;                          // 光源的位置(在球体的正上方)
                // lightPos.xz += float2(sin(_Time.y) * 5, cos(_Time.y) * 5);  // 让光源动起来
                float3 lightDir = normalize(lightPos - rayPos);             // 物体表面到光源的方向
                float3 normalDir = GetNormal(rayPos);                       // 获取物体表面的法线方向
                float diffuse = dot(lightDir, normalDir) * 0.5 + 0.5;         // 兰伯特
                
                // 从光线当前位置向物体表面法线方向偏移一点距离，然后向光源方向做步进，得到当前光线位置与光源之间或最近物体表面的距离
                float distRayToLight = RayMarch(rayPos + normalDir * SURF_DIST * 2.0, lightDir);
                // 如果返回的值小于光线当前位置与光源之间的距离，即光线在步进的时候在碰到光源之前就因为碰到了其他物体而结束了步进，则该光线位置处于阴影中
                if(distRayToLight < length(lightPos - rayPos)) diffuse *= 1 -_ShadowInt;
                
                return diffuse;   
            }

            
            

            float4 frag (VertexOutput i) : SV_Target {
                float2 uv = i.uv - 0.5;                                      // 将UV原点移至中心
                
                float3 rayOrigin = float3(0, 1, 0);                          // 摄像机位置/光线步进的起始点
                float3 rayDirection = normalize(float3(uv.x, uv.y, 1));      // 光线步进的方向
                float rayMarchedDist = RayMarch(rayOrigin, rayDirection);    // 光线在当前方向上返回结果所步进的距离
                float3 rayPos = rayOrigin + rayDirection * rayMarchedDist;   // 光线返回结果时所在的位置
                float3 diffuse = GetLight(rayPos);                            // 当前片段的diffuse颜色

                float3 background = step(0.9,1 - diffuse);
                
                
                float3 FragColor = diffuse * _SphereColor.rgb + background * _BackgroundColor.rgb;
                return float4(FragColor, 1.0);
            }
            ENDHLSL
        }
    }
}
