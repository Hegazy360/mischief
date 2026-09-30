import bpy, sys, math
from mathutils import Vector
A="/tmp/claude-0/-home-user-ideaboard/6a6517aa-4127-5e59-9718-da742a6ce0ad/scratchpad/mnd/work/3d/assets/quaternius/universal-base-characters/Universal Base Characters[Standard]/Base Characters/Godot - UE/"
out=sys.argv[sys.argv.index("--")+1]
bpy.ops.wm.read_factory_settings(use_empty=True)
for i,f in enumerate(["Superhero_Male_FullBody.gltf","Superhero_Female_FullBody.gltf"]):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=A+f)
    new=set(bpy.data.objects)-before
    for o in new:
        if o.parent is None: o.location.x += i*1.2
        if o.name.startswith("Icosphere"): bpy.data.objects.remove(o)
for o in bpy.data.objects:
    if o.type=="MESH": print("M",o.name,len(o.data.polygons), [vg.name for vg in o.vertex_groups][:3])
sc=bpy.context.scene
sc.render.engine="BLENDER_WORKBENCH"
sc.display.shading.light="STUDIO"; sc.display.shading.color_type="SINGLE"
sc.display.shading.show_cavity=True
sc.render.resolution_x, sc.render.resolution_y = 1200, 900
cd=bpy.data.cameras.new("c"); cd.type="ORTHO"; cd.ortho_scale=2.1
cam=bpy.data.objects.new("cam",cd); sc.collection.objects.link(cam); sc.camera=cam
for view,loc,rot in (("front",(0.6,-4,0.95),(math.radians(90),0,0)),("side",(4.6,0,0.95),(math.radians(90),0,math.radians(90)))):
    cam.location=loc; cam.rotation_euler=rot
    sc.render.filepath=out+"_"+view+".png"; bpy.ops.render.render(write_still=True)
