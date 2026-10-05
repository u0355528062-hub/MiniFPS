// Image d'échographie calculée en direct : secteur de sonde cardiaque (phased array), coupe dans le
// volume anatomique du patient (tissu mou, foie, myocarde, cavités, poumon, os). Le cœur bat et
// « nage » dans l'épanchement ; speckle qui suit les tissus, interfaces brillantes, ombres derrière
// les côtes, air du poumon opaque, aiguille hyperéchogène avec artefact en queue de comète.
shader_type canvas_item;
render_mode unshaded;

uniform sampler3D vol : filter_nearest, repeat_disable;
// Même volume lu en filtrage linéaire : distance au cœur lissée (bords du cœur, du liquide et du
// péricarde sans marches d'escalier)
uniform sampler3D vol_sdf : filter_linear, repeat_disable;
uniform vec3 vol_min = vec3(0.0);
uniform float vol_size = 0.32;
uniform vec3 probe_pos = vec3(0.0);
uniform vec3 beam_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 lat_dir = vec3(0.0, 0.0, 1.0);
uniform float depth = 0.16; // profondeur affichée (m)
uniform float half_angle = 0.74; // demi-ouverture du secteur (rad)
uniform float contact = 0.0; // sonde posée sur la peau (gel)
uniform float effusion = 1.0; // épanchement : 1 = tamponnade, 0 = vidé
uniform vec3 heart_c = vec3(0.0);
uniform float beat = 0.0; // phase du cycle cardiaque (0..1)
uniform vec3 needle_a = vec3(0.0);
uniform vec3 needle_b = vec3(0.0);
uniform float needle_on = 0.0;
uniform float aspect = 1.333; // largeur / hauteur de l'image
uniform float frame = 0.0; // change à chaque image (speckle du bruit électronique)

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Tissu au point p : x = échogénicité, y = nature (0 air, 1 tissu mou, 2 foie, 3 myocarde,
// 4 poumon, 5 os, 6 liquide ou sang, 7 péricarde) ; `live` : point déformé par le battement du
// cœur (le speckle le suit).
vec4 tissue(vec3 p, out vec3 live) {
	float ph = beat * 6.2832;
	float sys = pow(max(0.0, sin(ph)), 1.5);
	vec3 rel = p - heart_c;
	float near = 1.0 - smoothstep(0.06, 0.1, length(rel));
	// Le cœur se contracte et se balance dans le liquide (signe de la tamponnade)
	vec3 swing = vec3(0.004, 0.001, 0.007) * sin(ph + 1.2) * effusion;
	vec3 q = heart_c + rel * (1.0 + 0.07 * sys * near) - swing * near;
	live = q;
	vec3 uvw = (q - vol_min) / vol_size;
	if (any(lessThan(uvw, vec3(0.0))) || any(greaterThan(uvw, vec3(1.0)))) {
		return vec4(0.0);
	}
	// Nature du tissu : lecture tramée d'un voxel (pas de bords en escalier)
	vec3 jit = vec3(hash13(q * 3100.0), hash13(q * 2900.0 + 5.1), hash13(q * 3300.0 + 9.7)) - 0.5;
	float lab = floor(texture(vol, uvw + jit / 128.0 * 1.1).r * 255.0 + 0.5);
	float sd = (texture(vol_sdf, uvw).g * 255.0 - 128.0) * 0.25;
	float thick = 2.5 + 15.0 * effusion;
	// L'épanchement repousse ce qui entoure le cœur (poumon, foie, graisse) ; pas l'os
	if (lab != 5.0 && lab != 0.0) {
		if (sd > 0.0 && sd < thick) {
			return vec4(0.012, 6.0, 0.0, 0.0);
		}
		if (sd >= thick && sd < thick + 2.4) {
			return vec4(0.95, 7.0, 0.0, 0.0);
		}
		// Endocarde : la paroi du cœur brille un peu plus du côté des cavités
		if (lab == 3.0 && sd < -7.5) {
			return vec4(0.42, 3.0, 0.0, 0.0);
		}
	}
	if (lab == 1.0) return vec4(0.30, 1.0, 0.0, 0.0);
	if (lab == 2.0) return vec4(0.44, 2.0, 0.0, 0.0);
	if (lab == 3.0) return vec4(0.30, 3.0, 0.0, 0.0);
	if (lab == 4.0) return vec4(0.06, 4.0, 0.0, 0.0);
	if (lab == 5.0) return vec4(1.0, 5.0, 0.0, 0.0);
	if (lab == 6.0) return vec4(0.03, 6.0, 0.0, 0.0);
	return vec4(0.0);
}

float seg_dist(vec3 p, vec3 a, vec3 b) {
	vec3 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-9), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	vec2 q = vec2((UV.x - 0.5) * aspect, UV.y - 0.035) / 0.95;
	float r = length(q);
	float th = atan(q.x, q.y);
	vec3 bg = vec3(0.012, 0.014, 0.016);
	if (q.y <= 0.0 || abs(th) > half_angle || r > 1.0) {
		COLOR = vec4(bg, 1.0);
	} else {
		float rm = r * depth;
		vec3 dir = beam_dir * cos(th) + lat_dir * sin(th);
		vec3 p = probe_pos + dir * rm;
		// La résolution latérale se dégrade avec la profondeur
		vec3 perp = lat_dir * cos(th) - beam_dir * sin(th);
		p += perp * (hash13(vec3(UV * 911.0, 3.1)) - 0.5) * (0.0006 + rm * 0.01);
		vec3 live;
		vec4 t = tissue(p, live);
		// Atténuation et ombres le long du faisceau
		float trans = 1.0;
		vec3 dummy;
		for (int i = 1; i < 20; i++) {
			float s = rm * float(i) / 20.0;
			vec4 ti = tissue(probe_pos + dir * s, dummy);
			if (ti.y == 5.0) {
				trans *= 0.62;
			} else if (ti.y == 4.0) {
				trans *= 0.86;
			}
		}
		trans *= exp(-rm * 4.0) * (1.0 + rm * 9.0); // atténuation compensée (TGC)
		// Speckle : grain qui suit les tissus (le myocarde bouge avec son grain), plus allongé en
		// travers du faisceau qu'en profondeur
		vec3 cell = live * 1500.0 - perp * dot(live, perp) * 700.0;
		float sp1 = hash13(floor(cell));
		float sp2 = hash13(floor(live * 700.0) + 7.0);
		float speckle = sqrt(-2.0 * log(max(sp1, 1e-4))) * 0.45 + sp2 * 0.3;
		float v = t.x * (0.2 + 0.85 * speckle);
		// Interfaces : là où le tissu change, l'écho est fort
		vec4 tb = tissue(p - dir * 0.0013, dummy);
		if (tb.y != t.y) {
			v += 0.35 * abs(tb.x - t.x) + 0.12;
		}
		// Os : seule la surface renvoie, l'intérieur est dans l'ombre
		if (t.y == 5.0 && tb.y == 5.0) {
			v *= 0.35;
		}
		// Poumon : ligne pleurale brillante puis réverbérations
		if (t.y == 4.0) {
			v += 0.18 * step(0.7, fract(rm * 120.0)) * hash13(live * 300.0);
		}
		v *= trans;
		// Aiguille : trait très brillant, queue de comète derrière
		if (needle_on > 0.5) {
			float dn = seg_dist(p, needle_a, needle_b);
			v = max(v, (1.0 - smoothstep(0.0006, 0.0013, dn)) * 1.2);
			float dc = seg_dist(p - dir * 0.004, needle_a, needle_b);
			v += (1.0 - smoothstep(0.0006, 0.0016, dc)) * 0.25 * step(0.5, fract(rm * 900.0));
		}
		// Bruit électronique, champ proche saturé
		v += hash13(vec3(UV * 640.0, frame)) * 0.035;
		v += (1.0 - smoothstep(0.0, 0.008, rm)) * 0.12;
		v *= contact;
		v = pow(clamp(v, 0.0, 1.2), 0.85);
		vec3 col = vec3(v) * vec3(0.97, 0.98, 1.0);
		// Bord du secteur, graduations tous les 2 cm
		float edge = 1.0 - smoothstep(0.0, 0.006, half_angle - abs(th));
		col = mix(col, vec3(0.35), edge * 0.6);
		if (th > half_angle - 0.022 && fract(rm / 0.02 + 0.5) > 0.94) {
			col = vec3(0.85);
		}
		COLOR = vec4(max(col, bg), 1.0);
	}
}
