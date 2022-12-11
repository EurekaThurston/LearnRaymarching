Shader "RayMarching/RayMarching01_SimpleScene" {
    Properties {

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

            // 计算光线当前位置到物体表面的距离
            float GetDist(float3 rayCurrentPos)
            {
                float4 spherePos = float4(0, 1, 6, 1);                                          // 物体(球)的位置(xyz)和半径(w);
                float distSphereToRay = length(rayCurrentPos - spherePos.xyz) - spherePos.w;    // 先计算光线当前位置到球体中心的距离，再减去球的半径得到光线当前位置到球体表面的距离
                float distPlaneToRay = rayCurrentPos.y;                                         // 光线当前位置距离地面(高度为0)的距离

                float distance = min(distPlaneToRay, distSphereToRay);                          // 为了防止光线进入地面内，返回的值在距地面距离和距球体表面距离中取最小
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
