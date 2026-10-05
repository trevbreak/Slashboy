// Volumetric-looking fog for every built-in material: denser near the floor,
// with slowly drifting 3D noise. Patches three's shader chunks, so it must be
// imported before any material compiles.
import * as THREE from 'three';

// Plain object (not a Vector4) so UniformsUtils.clone shares it by reference
// across every material: x = time, y = height falloff, z = noise amount, w = floor height.
export const fogParams = { x: 0, y: 0.22, z: 0.9, w: 0 };

THREE.ShaderChunk.fog_pars_vertex = /* glsl */`
#ifdef USE_FOG
  varying float vFogDepth;
  varying vec3 vFogWorldPos;
#endif`;

THREE.ShaderChunk.fog_vertex = /* glsl */`
#ifdef USE_FOG
  vFogDepth = - mvPosition.z;
  // view matrix is orthonormal, so its inverse rotation is the transpose
  vFogWorldPos = cameraPosition + transpose(mat3(viewMatrix)) * mvPosition.xyz;
#endif`;

THREE.ShaderChunk.fog_pars_fragment = /* glsl */`
#ifdef USE_FOG
  uniform vec3 fogColor;
  uniform vec4 fogParams;
  varying float vFogDepth;
  varying vec3 vFogWorldPos;
  #ifdef FOG_EXP2
    uniform float fogDensity;
  #else
    uniform float fogNear;
    uniform float fogFar;
  #endif
  float fogHash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
  float fogNoise(vec3 x) {
    vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(fogHash(i), fogHash(i + vec3(1,0,0)), f.x), mix(fogHash(i + vec3(0,1,0)), fogHash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(fogHash(i + vec3(0,0,1)), fogHash(i + vec3(1,0,1)), f.x), mix(fogHash(i + vec3(0,1,1)), fogHash(i + vec3(1,1,1)), f.x), f.y), f.z);
  }
#endif`;

THREE.ShaderChunk.fog_fragment = /* glsl */`
#ifdef USE_FOG
  #ifdef FOG_EXP2
    vec3 fp = vFogWorldPos;
    float t = fogParams.x;
    float n = fogNoise(fp * 0.16 + vec3(t * 0.04, -t * 0.015, t * 0.025)) * 0.65
            + fogNoise(fp * 0.43 + vec3(-t * 0.06, t * 0.02, 0.0)) * 0.35;
    float h = exp(-max(fp.y - fogParams.w, 0.0) * fogParams.y);
    float dens = fogDensity * (0.45 + 1.0 * h) * (1.0 + (n - 0.5) * fogParams.z);
    float fogFactor = 1.0 - exp(- dens * dens * vFogDepth * vFogDepth);
  #else
    float fogFactor = smoothstep(fogNear, fogFar, vFogDepth);
  #endif
  gl_FragColor.rgb = mix(gl_FragColor.rgb, fogColor, fogFactor);
#endif`;

for (const lib of Object.values(THREE.ShaderLib)) {
  if (lib.uniforms && lib.uniforms.fogColor) lib.uniforms.fogParams = { value: fogParams };
}
