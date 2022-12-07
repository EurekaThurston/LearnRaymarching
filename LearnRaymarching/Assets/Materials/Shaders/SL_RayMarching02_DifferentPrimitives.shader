Shader "RayMarching/RayMarching02_DifferentPrimitives" {
    Properties {
        [Header(Capsule)]
        _CapsuleEndA    ("胶囊体顶点A位置", Vector) = (0.0, 1.0, 0.0, 0.0) 
        _CapsuleEndB    ("胶囊体顶点B位置", Vector) = (0.0, 7.0, 0.0, 0.0) 
        _CapsuleRadius  ("胶囊体半径", float)       = 0.5

        [Header(Torus)]
        _TorusOrigin    ("甜甜圈中心位置", Vector) = (0.0, 1.0, 6.0, 0.0)
        _TorusRadius    ("甜甜圈半径", float) = 0.5
        _TorusThickness ("甜甜圈厚度", float) = 0.5
        
        [Header(Box)]
        _BoxOrigin      ("盒体中心位置", Vector) = (-2.0, 1.0, 4.0, 0.0)
        _BoxSize        ("盒体大小, X: 长， Y: 宽， Z: 高", Vector) = (1.0, 1.0, 1.0, 1.0)
        
        [Header(Cylinder)]
        _CylinderEndA   ("圆柱体端点A位置", Vector) = (0.0, 1.0, 3.0, 0.0)
        _CylinderEndB   ("圆柱体端点B位置", Vector) = (0.0, 4.0, 3.0, 0.0)
        _CylinderRadius ("圆柱体半径", float) = 0.5
    
    }
    
    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_STEPS 100   // 光线步进的最大步进次数
            #define MAX_DIST 100.   // 光线步进的最大步进距离
            #define SURF_DIST 0.01  // 光线击中物体表面的判断距离，即光线与物体的距离小于SURF_DIST则判定击中物体表面

            // 胶囊体参数
            float4 _CapsuleEndA, _CapsuleEndB;
            float _CapsuleRadius;

            // 甜甜圈参数
            float4 _TorusOrigin;
            float _TorusRadius, _TorusThickness;

            // 盒体参数
            float4 _BoxOrigin, _BoxSize;

            // 圆柱体参数
            float4 _CylinderEndA, _CylinderEndB;
            float _CylinderRadius;
            
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
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // 胶囊体距离场
            float sdCapsule(float3 rayCurrentPos)
            {
                float3 AtoB = _CapsuleEndB - _CapsuleEndA;
                float3 AtoRay = rayCurrentPos - _CapsuleEndA;
                float t = dot(AtoB, AtoRay) / dot(AtoB, AtoB);
                t = clamp(t, 0, 1);
                float3 c = _CapsuleEndA + t *AtoB;
                return length(rayCurrentPos - c) - _CapsuleRadius;
                
            }

            // 甜甜圈距离场
            float sdTorus(float3 rayCurrentPos)
            {
                float3 rayPosRelativeToTorus = rayCurrentPos - _TorusOrigin;
                float distTorusOriginToRay_XZ = length(rayPosRelativeToTorus.xz) - _TorusRadius;
                float distGroundToRay = rayPosRelativeToTorus.y;
                float distTorusToRay = length(float2(distTorusOriginToRay_XZ, distGroundToRay)) - _TorusThickness;
                return distTorusToRay;
            }

            // 盒体距离场
            float sdBox(float3 rayCurrentPos)
            {
                float3 rayPosRelativeToBox = rayCurrentPos - _BoxOrigin;
                return length(max(abs(rayPosRelativeToBox) - _BoxSize, 0));
            }

            // 圆柱体距离场
            float sdCylinder(float3 rayCurrentPos)
            {
                float3 AToB = _CylinderEndB - _CylinderEndA;
                float3 AToRay = rayCurrentPos - _CylinderEndA;
                float AtoRayProjOnAtoB = dot(AToRay, AToB) / dot(AToB, AToB);
                float3 c = _CylinderEndA + AtoRayProjOnAtoB * AToB;

                float x = length(rayCurrentPos - c) - _CylinderRadius;
                float y = (abs(AtoRayProjOnAtoB - 0.5) - 0.5) * length(AToB);
                float e = length(max(float2(x, y), 0.0));
                float i = min(max(x, y), 0.0);

                return e + i;
            }

            // 计算光线当前位置到物体表面的距离
            float GetDist(float3 rayCurrentPos)
            {
                float distCapsuleToRay = sdCapsule(rayCurrentPos);   // 光线当前位置到胶囊体表面的距离
                float distTorusToRay = sdTorus(rayCurrentPos);
                float distBoxToRay = sdBox(rayCurrentPos);
                float distCylToRay = sdCylinder(rayCurrentPos);
                float distPlaneToRay = rayCurrentPos.y;                                         // 光线当前位置距离地面(高度为0)的距离

                float distance = min(distPlaneToRay, distCapsuleToRay);                         // 为了防止光线穿过物体，返回的值在距地面距离和距球体表面距离中取最小
                distance = min(distance, distTorusToRay);
                distance = min(distance, distBoxToRay);
                distance = min(distance, distCylToRay);
                return distance;
            }
            
            // 计算物体表面法线方向
            float3 GetNormal(float3 rayPos)
            {
                float distRayToObj = GetDist(rayPos);           // 获取光线当前位置到最近物体表面的距离
                float2 pointDelta = float2(0.01, 0);            // 取光线当前位置周围的点所需的偏移量
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
                float3 lightPos = float3(0, 5, 6);                          // 光源的位置(在球体的正上方)
                lightPos.xz += float2(sin(_Time.y) * 5, cos(_Time.y) * 5);  // 让光源动起来
                float3 lightDir = normalize(lightPos - rayPos);             // 物体表面到光源的方向
                float3 normalDir = GetNormal(rayPos);                       // 获取物体表面的法线方向
                float diffuse = saturate(dot(lightDir, normalDir));         // 兰伯特
                
                // 从光线当前位置向物体表面法线方向偏移一点距离，然后向光源方向做步进，得到当前光线位置与光源之间或最近物体表面的距离
                float distRayToLight = RayMarch(rayPos + normalDir * SURF_DIST * 2.0, lightDir);
                // 如果返回的值小于光线当前位置与光源之间的距离，即光线在步进的时候在碰到光源之前就因为碰到了其他物体而结束了步进，则该光线位置处于阴影中
                if(distRayToLight < length(lightPos - rayPos)) diffuse *= 0.1;
                
                return diffuse;   
            }

            
            

            float4 frag (VertexOutput i) : SV_Target {
                float2 uv = i.uv - 0.5;                                      // 将UV原点移至中心
                
                float3 rayOrigin = float3(0, 1, 0);                          // 摄像机位置/光线步进的起始点
                float3 rayDirection = normalize(float3(uv.x, uv.y, 1));      // 光线步进的方向
                float rayMarchedDist = RayMarch(rayOrigin, rayDirection);    // 光线在当前方向上返回结果所步进的距离
                float3 rayPos = rayOrigin + rayDirection * rayMarchedDist;   // 光线返回结果时所在的位置
                float diffuse = GetLight(rayPos);                            // 当前片段的diffuse颜色
                
                float3 FragColor = diffuse;
                return float4(FragColor, 1.0);
            }
            ENDHLSL
        }
    }
}
