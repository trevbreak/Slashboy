#!/usr/bin/env python3
"""Write Godot .import files so generated textures get mipmaps + VRAM compression (normal maps flagged)."""
import os
ROOT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'textures')
TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{name}"

[params]

compress/mode={mode}
compress/high_quality=false
compress/lossy_quality=0.8
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate={mips}
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/size_limit=0
detect_3d/compress_to=0
"""
for f in sorted(os.listdir(ROOT)):
    if not f.endswith('.png'):
        continue
    ui = f in ('glow.png',) or f.startswith('screen_') or f.startswith('neon_')
    normal = 1 if f.endswith('_normal.png') else 2
    mode = 0 if (ui or f == 'stars.png') else 2  # lossless for small/glowy, VRAM for surfaces
    with open(os.path.join(ROOT, f + '.import'), 'w') as fh:
        fh.write(TEMPLATE.format(name=f, mode=mode, normal=normal, mips='true'))
print('ok')
