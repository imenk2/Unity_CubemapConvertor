using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

public class CubemapConvertor : EditorWindow
{
    enum Model
    {
        CircularCone = 0,
        Equirectangular = 1,
        ConcentricOctahedral = 2
    }
    
    enum MappingScale
    {
        Default = 0,
        Scale = 1,
        DoubleScale = 2,
    }
    
    enum DirectionModel
    {
        Front = 0,
        Back = 1,
        Top = 2,
    }

    enum EquirectangularModel
    
    {
        Defualt = 0,
        Top = 1
    }

    enum octModel
    {
        octSphere = 0,
        concentricSphere = 1
    }
    
    private Texture cubeObject;
    public Texture2D saveTexture;
    private Material mat;
    private static int size = 1024;
    RenderTexture renderTexture;
    private Model mod = Model.CircularCone;
    private MappingScale mappingScale = MappingScale.Default;
    private DirectionModel directionMod = DirectionModel.Front;
    private EquirectangularModel equirectangularModel = EquirectangularModel.Defualt;
    private octModel _octModel = octModel.octSphere;
    private string dataPath = "";
    private float sphereRadius;
    private bool isGamma;
    private static readonly int MainTex = Shader.PropertyToID("_MainTex");
    private static readonly int EquirectangularModel1 = Shader.PropertyToID("_EquirectangularModel");
    private static readonly int SpheredirectionMode = Shader.PropertyToID("_SpheredirectionMode");
    private static readonly int SpheremappingScale = Shader.PropertyToID("_SpheremappingScale");
    private static readonly int OctModel = Shader.PropertyToID("_octModel");

    [MenuItem("Window/CubeMap Convertor")]
    public static void ShowWindow()
    {
        GetWindow<CubemapConvertor>("CubeMap Convertor");
    }

    private void OnGUI()
    {
        GUILayout.Label("Cube图输入", EditorStyles.boldLabel);
        cubeObject = EditorGUILayout.ObjectField("CubeMap", cubeObject, typeof(Texture), true) as Texture;

        GUILayout.Space(20);

        GUILayout.Label("输出模式选择", EditorStyles.boldLabel);
        mod = (Model)EditorGUILayout.EnumPopup("Pass", mod);

        DrawGenerateModel(mod);

        GUILayout.Space(20);

        if (GUILayout.Button("输出"))
        {
            if (cubeObject != null)
            {
                CubeConvertSphere();
            }
            else
            {
                Debug.LogError("请指定Cube对象！");
            }
        }
    }

    void DrawGenerateModel(Model model)
    {
        switch (model)
        {
            case Model.CircularCone:
                directionMod = (DirectionModel)EditorGUILayout.EnumPopup("Direction Mod", directionMod);
                if (directionMod == DirectionModel.Top)
                {
                    mappingScale = (MappingScale)EditorGUILayout.EnumPopup("Mapping Scale", mappingScale);
                }
                else
                {
                    mappingScale = MappingScale.Default;
                }

                if (cubeObject != null)
                {
                    size = cubeObject.height;
                }
                break;
            case Model.Equirectangular:
                //sphereRadius = EditorGUILayout.Slider("Radius", sphereRadius, 0f, 10f);
                equirectangularModel = (EquirectangularModel)EditorGUILayout.EnumPopup("Equirectangular Mod", equirectangularModel);
                if (cubeObject != null)
                {
                    if (equirectangularModel == EquirectangularModel.Defualt)
                    {
                        size = cubeObject.height;
                    }
                    else
                    {
                        size = cubeObject.height / 2;
                    }
                }

                break;
            case Model.ConcentricOctahedral:
                _octModel = (octModel)EditorGUILayout.EnumPopup("octModel", _octModel);
                break;
        }
        
        MapGamma(cubeObject.graphicsFormat);
    }

    void MapGamma(GraphicsFormat format)
    {
        switch (format)
        {
            case GraphicsFormat.RGB_ETC2_SRGB:
            case GraphicsFormat.RGBA_PVRTC_2Bpp_SRGB:
            case GraphicsFormat.RGBA_BC7_SRGB:
            case GraphicsFormat.RGBA_DXT5_SRGB:
            case GraphicsFormat.RGBA_ASTC4X4_SRGB:
            case GraphicsFormat.RGBA_ASTC5X5_SRGB:
            case GraphicsFormat.RGBA_ASTC6X6_SRGB:
            case GraphicsFormat.RGBA_ASTC8X8_SRGB:
            case GraphicsFormat.R8G8B8A8_SRGB:
                isGamma = true;
                break;
            default:
                isGamma = false;
                break;
        }
    }


    void CubeConvertSphere()
    {
        Init();

        switch (mod)
        {
            case Model.CircularCone:
                mat.SetInt(SpheremappingScale, (int)mappingScale);
                mat.SetInt(SpheredirectionMode, (int)directionMod);
                break;
            case Model.Equirectangular:
                mat.SetInt(EquirectangularModel1, (int)equirectangularModel);
                break;
            case Model.ConcentricOctahedral:
                mat.SetInt(OctModel, (int)_octModel);
                break;
        }
        
        mat.SetTexture(MainTex, cubeObject);
        Graphics.Blit(null, renderTexture, mat, (int)mod);

        SaveTexture();
    }
    void Init()
    {
        
        if (cubeObject == null)
        {
            Debug.LogError("missing cubeMap");
            return;
        }
        else
        {
            dataPath = AssetDatabase.GetAssetPath(cubeObject);
        }
        
        if (dataPath.Equals(string.Empty))
        {
            Debug.LogError("生成球面映射图路径为空,请检查路径");
            return;
        }

        if (mat == null)
        {
            mat = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/CubeMapConvertor"));
            if (mat == null)
            {
                Debug.LogError("missing material");
                return;
            }
        }

        switch (mod)
        {
            case Model.CircularCone:
            case Model.ConcentricOctahedral:

                if (renderTexture == null || renderTexture.width != size)
                {
                    if(renderTexture != null) Object.DestroyImmediate(renderTexture);
                    renderTexture = null;
                    renderTexture = new RenderTexture(size, size, 0); 
                    renderTexture.format = RenderTextureFormat.ARGBFloat;
                    renderTexture.enableRandomWrite = true;
                    renderTexture.wrapMode = TextureWrapMode.Clamp;
                    renderTexture.filterMode = FilterMode.Trilinear;
                    renderTexture.Create();
                }
                if (saveTexture == null || saveTexture.width != size)
                {
                    if(saveTexture != null) Object.DestroyImmediate(saveTexture);
                    saveTexture = null;
                    saveTexture = new Texture2D(size, size, TextureFormat.ARGB32, false, !isGamma);
                }
                break;
            
            case Model.Equirectangular:
                if (renderTexture == null || renderTexture.width != cubeObject.width || renderTexture.height != size)
                {
                    if(renderTexture != null) Object.DestroyImmediate(renderTexture);
                    renderTexture = null;
					//high减半
                    renderTexture = new RenderTexture(cubeObject.width, size, 0);
                    renderTexture.format = RenderTextureFormat.ARGBFloat;
                    renderTexture.enableRandomWrite = true;
                    renderTexture.wrapMode = TextureWrapMode.Clamp;
                    renderTexture.filterMode = FilterMode.Trilinear;
                    renderTexture.Create();
                }

                if (saveTexture == null || saveTexture.width != cubeObject.width || saveTexture.height != size)
                {
                    if(saveTexture != null) Object.DestroyImmediate(saveTexture);
                    saveTexture = null;
                    saveTexture = new Texture2D(cubeObject.width, size, TextureFormat.ARGB32, false, !isGamma);
                }
                break;
        }
  
    }

    private void OnDestroy()
    {
        DestroyImmediate(saveTexture);
        saveTexture = null;
        DestroyImmediate(renderTexture);
        renderTexture = null;
    }
    
    void SaveTexture()
    {
        var path = dataPath == null ? "Assets" : dataPath.Replace(Application.dataPath, "Assets");
        var name = Path.GetFileNameWithoutExtension(dataPath);
        var folder = Path.GetDirectoryName(path);
        
        var originalRenderTexture = RenderTexture.active;
        RenderTexture.active = renderTexture;
       
        saveTexture.ReadPixels(new Rect(0,0,renderTexture.width, renderTexture.height), 0,0);
        saveTexture.Apply();
        TextureImporter importer = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(saveTexture)) as TextureImporter;
        if (importer != null)
        {
            importer.textureCompression = TextureImporterCompression.Compressed;
            importer.compressionQuality = 50;
            importer.SaveAndReimport();
        }
        var bytes = saveTexture.EncodeToTGA();
        string savePath = folder + "/" + name + "_" + mod + ".tga";
        if(File.Exists(savePath)) File.Delete(savePath);
        File.WriteAllBytes(savePath, bytes);
        RenderTexture.active = originalRenderTexture;
        AssetDatabase.Refresh();
        TextureImporter ti = AssetImporter.GetAtPath(savePath) as TextureImporter;
        ti.sRGBTexture = isGamma;
        ti.SaveAndReimport();
    }
}
