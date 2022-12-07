using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UIElements;

public class GetNormalFuncDemo : MonoBehaviour
{
    [SerializeField]
    private GameObject Sphere;
    private void OnDrawGizmos()
    {
        Vector3 rayPos = transform.position;
        Gizmos.DrawLine(rayPos, DrawLineDest(rayPos));

        Vector2 pointDelta = new Vector2(0.1f, 0);
        Vector3 point1 = rayPos - new Vector3(pointDelta.x, pointDelta.y, pointDelta.y);
        Vector3 point2 = rayPos - new Vector3(pointDelta.y, pointDelta.x, pointDelta.y);
        Vector3 point3 = rayPos - new Vector3(pointDelta.y, pointDelta.y, pointDelta.x);
        
        Gizmos.color = Color.cyan;
        Gizmos.DrawLine(point1, DrawLineDest(point1));
        Gizmos.DrawLine(point2, DrawLineDest(point2));
        Gizmos.DrawLine(point3, DrawLineDest(point3));
        
        Gizmos.color = Color.blue;
        Vector3 normalDir = point1 + point2 + point3;
        
        Gizmos.DrawLine(normalDir, DrawLineDest(normalDir));


    }

    Vector3 DrawLineDest(Vector3 pointPos)
    {
        float sphereRadius = Sphere.GetComponent<SphereCollider>().radius;
        Vector3 rayPos = pointPos;
        Vector3 SpherePos = Sphere.transform.position;
        float toSphereDist = Vector3.Distance(rayPos,SpherePos) - sphereRadius;
        Vector3 direction = (SpherePos - rayPos).normalized;
        return rayPos + direction * toSphereDist;
    }
}
