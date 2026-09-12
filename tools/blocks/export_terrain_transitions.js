(async () => {
const fs = require('fs');
const root = '/Users/jaili/projects/godot/outpost';
const base = root + '/assets/models/blocks/transitions';
const assets = JSON.parse(fs.readFileSync(root + '/output/terrain_transitions/native_geometry.json', 'utf8'));
const previous = Project;
const project = ModelProject.all.find(p => p.name === 'Outpost terrain transitions');
if (!project) throw new Error('Dedicated terrain transitions project is missing');
project.select();
const report = [];
for (const asset of assets) {
if (Project !== project) throw new Error('Active project changed; stopped to preserve user work');
for (const element of [...Outliner.root]) element.remove();
for (const texture of [...Texture.all]) texture.remove();
Project.name = asset.id;
Project.texture_width = 32;
Project.texture_height = 32;
const textures = {};
for (const part of asset.meshes) {
if (!textures[part.texture]) {
const path = part.texture === asset.id ? base + '/textures/' + part.texture + '.png' : root + '/assets/models/blocks/textures/' + part.texture + '.png';
const texture = new Texture({ name: part.texture + '.png', width: 32, height: 32, uv_width: 32, uv_height: 32 }).fromDataURL('data:image/png;base64,' + fs.readFileSync(path).toString('base64')).add(false);
await new Promise(resolve => setTimeout(resolve, 20));
if (Project !== project) throw new Error('Active project changed');
textures[part.texture] = texture;
}
const vertices = Object.fromEntries(part.vertices.map((point, i) => [String(i), point]));
const mesh = new Mesh({ name: part.texture === asset.id ? 'transition_top' : 'block_sides', vertices, faces: {} }).init();
for (let i = 0; i < part.vertices.length; i += 3) {
const keys = [String(i), String(i + 2), String(i + 1)];
mesh.addFaces(new MeshFace(mesh, { vertices: keys, uv: Object.fromEntries(keys.map(key => [key, part.uv[Number(key)]])), texture: textures[part.texture].uuid }));
}
}
Canvas.updateAll();
const native = Codecs.project.compile({ raw: true, bitmaps: true });
native.outpost = { tile_pixels: 32, units_per_tile: 32, origin: 'base Y=0', source: 'tools/blocks/build_terrain_transitions.gd', transition: true };
fs.writeFileSync(base + '/blockbench/' + asset.id + '.bbmodel', JSON.stringify(native));
const compiled = await Codecs.gltf.compile({ encoding: 'ascii', scale: 16, embed_textures: true, animations: false });
const gltf = typeof compiled === 'string' ? JSON.parse(compiled) : compiled;
for (const material of gltf.materials || []) {
material.pbrMetallicRoughness.metallicFactor = 0;
material.pbrMetallicRoughness.roughnessFactor = 1;
}
for (const sampler of gltf.samplers || []) { sampler.magFilter = 9728; sampler.minFilter = 9728; }
fs.writeFileSync(base + '/gltf/' + asset.id + '.gltf', JSON.stringify(gltf));
report.push({ id: asset.id, meshes: Mesh.all.length, textures: Texture.all.length });
}
fs.writeFileSync(root + '/output/terrain_transitions/blockbench_export.json', JSON.stringify(report, null, 2));
project.name = 'Outpost terrain transitions';
if (previous) previous.select();
return JSON.stringify({ exported: report.length });
})()
