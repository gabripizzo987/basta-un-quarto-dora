shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0; // 0=vuoto 1=pieno
uniform float cut_top : hint_range(0.0, 1.0) = 0.0;     // parte da tagliare sopra (UV)
uniform float cut_bottom : hint_range(0.0, 1.0) = 0.0;  // parte da tagliare sotto (UV)

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // finestra utile: [cut_top, 1 - cut_bottom]
    float y_min = cut_top;
    float y_max = 1.0 - cut_bottom;

    // fuori finestra -> invisibile (così sparisce tubo e roba fuori sacca)
    if (UV.y < y_min || UV.y > y_max) {
        tex.a = 0.0;
    } else {
        // normalizzo UV.y dentro la finestra in [0..1]
        float y_norm = (UV.y - y_min) / max(0.0001, (y_max - y_min));

        // riempio dal basso: mostro se y_norm >= (1 - fill_amount)
        float cutoff = 1.0 - fill_amount;
        if (y_norm < cutoff) {
            tex.a = 0.0;
        }
    }

    COLOR = tex;
}