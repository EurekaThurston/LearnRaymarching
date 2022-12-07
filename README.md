<div align="center">
# Unity Raymarching Notes

教程作者: The Art of Code (Youtube)
视频链接: https://www.youtube.com/watch?v=Ff0jJyyiVyw&list=PLGmrMu-IwbgtMxMiV3x4IrHPlPmg7FD-P

## 简单的场景

<img src="ReadmeImg/SimpleScene.png" width="400">

<br>
<br>

Raymarching是从光源处(摄像机)向当前片段的方向发射光线并进行步进,并在碰到物体后返回从光源处到触碰到的物体的表面的距离.
<br>
<img src="ReadmeImg/Raymarching.png" width="400">
<br>

每次步进开始前,光线从当前位置计算出到物体表面的最短距离,并向当前像素方向步进该距离,然后再次计算距离,并再次步进,直到光线的位置与物体表面的最小距离小于预定的阈值,raymarching函数会返回从光源位置到该物体表面的距离.

<img src="ReadmeImg/Raymarching解释图.png" width="400">
<br>

在不计算任何光照或其他额外的信息的情况下,光线步进函数所呈现出的画面即为光源(摄像机)到场景中所有可见物体的距离(越暗越近,越白越远),如下图:
<img src="ReadmeImg/raymarching返回值.png" width="400">
<br>

在获取到光源到场景中的距离之后,可以通过在物体表面位置的近点找三个点来计算出物体在该表面位置的法线方向,以此来计算光照.
    
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
<br>

光照中阴影的计算相对简单,只需要使光线以触碰到物体表面的位置为原点,向光源方向进行步进,获取到从光线位置到最近触碰到的物体表面的距离,如果距离大于光线位置到光源位置的距离,则该光线位置不在阴影中;如果小于光线位置到光源位置的距离,则说明光线位置和光源位置中间有物体,则该光线位置处于阴影中.
<img src="ReadmeImg/Raymarching.png" width="400">



## 各种多边形
<img src="ReadmeImg/Primitives.png" width="400">

### 胶囊体
<img src="ReadmeImg/胶囊体.png" width="400">



</div>