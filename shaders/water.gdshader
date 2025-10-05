shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx, diffuse_burley;

// Wave parameters
uniform float wave_speed : hint_range(0.0, 2.0, 0.1) = 0.4;
uniform float wave_amplitude : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float wave_length : hint_range(1.0, 10.0, 0.1) = 4.0;
uniform float wave_steepness : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform vec2 wave_direction = vec2(1.0, 0.0);

// Secondary wave
uniform float wave2_amplitude : hint_range(0.0, 1.0, 0.01) = 0.15;
uniform float wave2_length : hint_range(1.0, 10.0, 0.1) = 2.5;
uniform vec2 wave2_direction = vec2(0.3, 1.0);
uniform float wave2_speed : hint_range(0.0, 2.0, 0.1) = 0.6;

// Large swell
uniform float swell_amplitude : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float swell_length : hint_range(5.0, 20.0, 0.1) = 8.0;
uniform float swell_speed : hint_range(0.0, 1.0, 0.1) = 0.2;

// Interactive ripple parameters
uniform float ripple_amplitude : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float ripple_speed : hint_range(0.0, 20.0, 0.1) = 8.0;
uniform float ripple_decay : hint_range(0.0, 5.0, 0.1) = 2.0;
uniform float ripple_wavelength : hint_range(0.5, 5.0, 0.1) = 1.5;

// Ripple data arrays (up to 10 ripples)
uniform float ripple_positions[20];  // x,y pairs
uniform float ripple_times[10];      // age of each ripple

// Color parameters
uniform vec4 water_color : source_color = vec4(0.1, 0.3, 0.5, 0.9);
uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.1, 0.2, 1.0);
uniform float foam_threshold : hint_range(0.0, 1.0, 0.01) = 0.7;

// Material parameters
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float specular_strength : hint_range(0.0, 2.0, 0.01) = 1.0;

// Gerstner wave calculation
vec3 gerstner_wave(vec2 pos, float amplitude, float wavelength, vec2 direction, float speed, float steepness, float time) {
    float k = 2.0 * PI / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(direction);
    float f = k * (dot(d, pos) - c * speed * time);
    float a = steepness / k;
    
    return vec3(
        d.x * a * sin(f),
        a * cos(f),
        d.y * a * sin(f)
    ) * amplitude;
}

// Calculate normal from Gerstner wave
vec3 gerstner_normal(vec2 pos, float amplitude, float wavelength, vec2 direction, float speed, float steepness, float time) {
    float k = 2.0 * PI / wavelength;
    float c = sqrt(9.8 / k);
    vec2 d = normalize(direction);
    float f = k * (dot(d, pos) - c * speed * time);
    float a = steepness / k;
    
    float wa = k * amplitude;
    float s = sin(f);
    float c_f = cos(f);
    
    return vec3(
        -d.x * wa * c_f,
        1.0 - wa * steepness * s,
        -d.y * wa * c_f
    );
}

// Calculate ripple effect at a position
float calculate_ripple(vec2 pos, vec2 ripple_center, float ripple_age) {
    if (ripple_age < 0.0 || ripple_age > 8.0) return 0.0;
    
    float distance = length(pos - ripple_center);
    float wave_distance = ripple_age * ripple_speed;
    
    // Create expanding ring with multiple wave peaks for thickness
    float primary_wave = sin((distance - wave_distance) * 2.0 * PI / ripple_wavelength);
    float secondary_wave = sin((distance - wave_distance - ripple_wavelength * 0.3) * 2.0 * PI / ripple_wavelength) * 0.5;
    float wave = primary_wave + secondary_wave;
    
    // Slower, more gradual decay
    float time_decay = exp(-ripple_age * ripple_decay * 0.5);
    float distance_decay = exp(-abs(distance - wave_distance) * 0.2);
    
    // Wider wavefront for thicker waves
    float wavefront_width = ripple_wavelength * 1.5;
    float in_wavefront = smoothstep(wavefront_width, 0.0, abs(distance - wave_distance));
    
    // Shape the wave to be more ocean-like (broader peaks)
    wave = pow(max(0.0, wave), 0.7) * sign(wave);
    
    return wave * time_decay * distance_decay * in_wavefront * ripple_amplitude;
}

// Calculate ripple normal contribution
vec3 calculate_ripple_normal(vec2 pos, vec2 ripple_center, float ripple_age) {
    if (ripple_age < 0.0 || ripple_age > 8.0) return vec3(0.0, 1.0, 0.0);
    
    float distance = length(pos - ripple_center);
    float wave_distance = ripple_age * ripple_speed;
    
    vec2 dir = normalize(pos - ripple_center);
    
    // Calculate derivative for both wave components
    float primary_deriv = cos((distance - wave_distance) * 2.0 * PI / ripple_wavelength) * 2.0 * PI / ripple_wavelength;
    float secondary_deriv = cos((distance - wave_distance - ripple_wavelength * 0.3) * 2.0 * PI / ripple_wavelength) * 2.0 * PI / ripple_wavelength * 0.5;
    float wave_deriv = primary_deriv + secondary_deriv;
    
    float time_decay = exp(-ripple_age * ripple_decay * 0.5);
    float distance_decay = exp(-abs(distance - wave_distance) * 0.2);
    float wavefront_width = ripple_wavelength * 1.5;
    float in_wavefront = smoothstep(wavefront_width, 0.0, abs(distance - wave_distance));
    
    float factor = wave_deriv * time_decay * distance_decay * in_wavefront * ripple_amplitude * 0.7;
    
    return vec3(-dir.x * factor, 1.0, -dir.y * factor);
}

void vertex() {
    float time = TIME;
    vec2 pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    
    // Calculate Gerstner waves
    vec3 wave1 = gerstner_wave(pos, wave_amplitude, wave_length, wave_direction, wave_speed, wave_steepness, time);
    vec3 wave2 = gerstner_wave(pos, wave2_amplitude, wave2_length, wave2_direction, wave2_speed, wave_steepness * 0.7, time);
    vec3 swell = gerstner_wave(pos, swell_amplitude, swell_length, vec2(0.7, 0.7), swell_speed, 0.2, time);
    
    // Apply base wave displacement
    VERTEX.x += wave1.x + wave2.x + swell.x;
    VERTEX.y += wave1.y + wave2.y + swell.y;
    VERTEX.z += wave1.z + wave2.z + swell.z;
    
    // Add interactive ripples
    float total_ripple_height = 0.0;
    vec3 ripple_normal_sum = vec3(0.0, 0.0, 0.0);
    
    for (int i = 0; i < 10; i++) {
        vec2 ripple_pos = vec2(ripple_positions[i * 2], ripple_positions[i * 2 + 1]);
        float ripple_age = ripple_times[i];
        
        total_ripple_height += calculate_ripple(pos, ripple_pos, ripple_age);
        ripple_normal_sum += calculate_ripple_normal(pos, ripple_pos, ripple_age) - vec3(0.0, 1.0, 0.0);
    }
    
    VERTEX.y += total_ripple_height;
    
    // Calculate combined normal
    vec3 normal1 = gerstner_normal(pos, wave_amplitude, wave_length, wave_direction, wave_speed, wave_steepness, time);
    vec3 normal2 = gerstner_normal(pos, wave2_amplitude, wave2_length, wave2_direction, wave2_speed, wave_steepness * 0.7, time);
    vec3 normal_swell = gerstner_normal(pos, swell_amplitude, swell_length, vec2(0.7, 0.7), swell_speed, 0.2, time);
    
    // Combine all normals
    vec3 normal = normalize(normal1 + normal2 + normal_swell + ripple_normal_sum);
    NORMAL = normalize((MODEL_MATRIX * vec4(normal, 0.0)).xyz);
}

void fragment() {
    // Calculate wave height for foam
    float wave_height = 0.0;
    vec2 pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
    float time = TIME;
    
    // Sample wave heights
    vec3 wave1 = gerstner_wave(pos, wave_amplitude, wave_length, wave_direction, wave_speed, wave_steepness, time);
    vec3 wave2 = gerstner_wave(pos, wave2_amplitude, wave2_length, wave2_direction, wave2_speed, wave_steepness * 0.7, time);
    wave_height = (wave1.y + wave2.y) / (wave_amplitude + wave2_amplitude);
    
    // Add ripple contribution to foam
    float ripple_foam = 0.0;
    float ripple_height_influence = 0.0;
    for (int i = 0; i < 10; i++) {
        vec2 ripple_pos = vec2(ripple_positions[i * 2], ripple_positions[i * 2 + 1]);
        float ripple_age = ripple_times[i];
        
        if (ripple_age > 0.0 && ripple_age < 8.0) {
            float distance = length(pos - ripple_pos);
            float wave_distance = ripple_age * ripple_speed;
            float wavefront_width = ripple_wavelength * 1.5;
            float at_wavefront = smoothstep(wavefront_width, 0.0, abs(distance - wave_distance));
            
            // Calculate ripple height at this position for lighting
            float ripple_h = calculate_ripple(pos, ripple_pos, ripple_age);
            ripple_height_influence = max(ripple_height_influence, abs(ripple_h) / ripple_amplitude);
            
            // Foam only on ripple crests, more subtle and wave-like
            float ripple_slope = abs(ripple_h) / ripple_amplitude;
            float age_factor = 1.0 - smoothstep(0.0, 8.0, ripple_age);
            ripple_foam = max(ripple_foam, at_wavefront * ripple_slope * age_factor * 0.25);
        }
    }
    
    // Calculate view-dependent effects
    float fresnel = 1.0 - dot(NORMAL, VIEW);
    fresnel = pow(fresnel, 1.5);
    
    // Water color based on view angle and depth
    vec4 base_color = mix(deep_color, water_color, fresnel);
    
    // Foam on wave crests and ripples
    float foam_amount = smoothstep(foam_threshold - 0.1, foam_threshold + 0.1, wave_height);
    foam_amount += smoothstep(0.8, 1.0, fresnel) * 0.3;
    foam_amount = clamp(foam_amount, 0.0, 1.0);
    
    // Blend ripple foam more subtly
    vec4 final_color = mix(base_color, foam_color, foam_amount);
    
    // Apply ripple effect as subtle color variation rather than bright foam
    if (ripple_foam > 0.0) {
        vec4 ripple_color = mix(water_color, foam_color, ripple_foam * 0.5);
        ripple_color = mix(ripple_color, base_color, 0.3); // Blend with base for lighting consistency
        final_color = mix(final_color, ripple_color, ripple_foam);
    }
    
    ALBEDO = final_color.rgb;
    ALPHA = water_color.a;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 0.1, foam_amount);
    
    // Enhanced specular on wave slopes
    float slope = 1.0 - abs(dot(NORMAL, vec3(0.0, 1.0, 0.0)));
    float specular_mask = smoothstep(0.1, 0.3, slope) * (1.0 - foam_amount);
    
    // Specular highlights
    vec3 light_dir = normalize(vec3(1.0, -1.0, 0.5));
    vec3 half_vector = normalize(VIEW + light_dir);
    float spec = pow(max(dot(NORMAL, half_vector), 0.0), 32.0) * specular_strength;
    
    SPECULAR = spec * specular_mask;
    
    // Reduce emission intensity and make ripples respect lighting
    float emission_strength = foam_amount * 0.05 + spec * specular_mask * 0.1;
    EMISSION = foam_color.rgb * emission_strength * (1.0 - ripple_height_influence * 0.5);
}