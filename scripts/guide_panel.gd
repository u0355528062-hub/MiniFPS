class_name GuidePanel
extends Node3D
## Écran de guidage flottant au-dessus du patient, face au chirurgien.

var ui: GuideUI
var _vp: SubViewport


func build() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(GuideUI.W), int(GuideUI.H))
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	ui = GuideUI.new()
	_vp.add_child(ui)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0 * GuideUI.H / GuideUI.W)
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
