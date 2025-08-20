/******************************************************
Measurement accurate model of my Canyon Grail AL 6
Size M rear triangle geometry, used for designing
my bikepacking rear rack system

https://www.canyon.com/en-us/productpdf/geometry/?pid=3092
******************************************************/

//======================================================
// BOTTOM BRACKET SHELL PARAMETERS
//======================================================
bb_diameter = 41;     // Inner diameter; PF41 (PressFit86 standard)
bb_thickness = 3;     // Wall thickness of BB shell
bb_width = 86;        // Shell width for PressFit86 standard

// Derived BB values
outer_diameter = bb_diameter + 2*bb_thickness;
radius_outer = outer_diameter/2;
radius_inner = bb_diameter/2;

//======================================================
// SEAT TUBE PARAMETERS
//======================================================
seat_length = 522;                // Total seat tube length
seat_angle_horizontal = 73.5;     // Seat tube angle relative to horizontal (degrees)
seat_inner_d = 27.2;              // Inner diameter for seatpost
seat_thickness = 5;               // Wall thickness

// Derived seat tube values
seat_angle = 90 - seat_angle_horizontal;  // Convert for OpenSCAD rotate() (relative to z-axis)
seat_outer_d = seat_inner_d + 2*seat_thickness;
seat_radius_outer = seat_outer_d/2;
seat_radius_inner = seat_inner_d/2;

// Positioning offsets to place seat tube at BB rim
x_offset = cos(seat_angle_horizontal) * radius_inner;
z_offset = sin(seat_angle_horizontal) * radius_inner;

//======================================================
// CHAINSTAY PARAMETERS
//======================================================
chainstay_length = 430;           // Hypotenuse length (tube-axis length)
chainstay_thick = 15;             // Cross-section thickness (X width)
chainstay_height = 30;            // Cross-section height (Z dimension)
chainstay_corner_r = 3;           // Rounded corner radius for cross-section

// Angle relationship between seat tube and chainstays
seattube_chainstay_delta = 65;    // Angular difference (degrees)

//======================================================
// THRU-AXLE PARAMETERS
//======================================================
thru_axle_d = 14;                 // Axle diameter
thru_axle_w = 142;                // OLD (Over Locknut Dimension) spacing width

//======================================================
// SEATSTAY PARAMETERS
//======================================================
seatstay_len = 30;                // Vertical stub length above axle
seatstay_w = 14;                  // Cross-section X width
seatstay_depth = 16;              // Cross-section Y depth
seatstay_corner_r = 5;            // Corner radius for cross-section

// Two-segment seatstay geometry parameters
d1 = 90;                          // Upper segment length from seat-tube
separation = 60;                  // Y separation between upper segment endpoints
half_sep = separation/2;

// Cross-section parameters for long seatstay segments
seatstay_len_stub = 30;           // Reference stub length (matches seatstay_len)
seatstay_stub_angle = seattube_chainstay_delta-seat_angle_horizontal-5; // Rotation around axle in X–Z plane
           // 0 for perpendicular to horizontal; seattube_chainstay_delta-seat_angle_horizontal for perpendicular to chainstay
seatstay_w_long = 14;             // X width for long segments
seatstay_depth_long = 16;         // Y depth for long segments

// Hull blending parameters
t_off = 0.8;                      // Transition offset ratio for hull blending
e_off = 0.2;                      // End offset ratio for hull blending

//======================================================
// DERIVED GEOMETRY CALCULATIONS
//======================================================

// Bottom bracket and chainstay positioning
bb_half = bb_width/2;
bb_offset = bb_half - chainstay_thick;

// Chainstay angle calculations (referenced to seat tube)
chainstay_angle_horizontal = seat_angle_horizontal - seattube_chainstay_delta;
pitch_deg = 90 - chainstay_angle_horizontal - 90;  // Convert for OpenSCAD rotation

// Chainstay to axle geometry (triangle calculation)
height_y = (thru_axle_w/2) - chainstay_thick - bb_offset;
base_x = sqrt(max(0, chainstay_length*chainstay_length - height_y*height_y));
yaw_deg = atan2(height_y, base_x);

// Chainstay positioning at BB rim (similar to seat tube positioning)
chainstay_x_offset = cos(chainstay_angle_horizontal) * radius_inner;
chainstay_z_offset = sin(chainstay_angle_horizontal) * radius_inner;

// Through-axle final position
x_axle = chainstay_x_offset + chainstay_length * cos(yaw_deg) * cos(pitch_deg);
y_axle = 0;  // Centered by symmetry
z_axle = chainstay_z_offset - chainstay_length * cos(yaw_deg) * sin(pitch_deg);

// Seatstay positioning
y_end_mag = bb_offset + height_y;                     // Y position of chainstay ends
z_stub_center = z_axle + (thru_axle_d/2) + (seatstay_len/2);  // Z center for stub

//======================================================
// HELPER MODULES
//======================================================

/**
 * Creates a 2D rounded rectangle profile
 * @param h Height (Y dimension)
 * @param w Width (X dimension) 
 * @param r Corner radius
 */
module rounded_rect_2d(h, w, r) {
    r2 = min(r, w/2, h/2);  // Ensure radius doesn't exceed half-dimensions
    hull() {
        translate([+w/2 - r2, +h/2 - r2]) circle(r=r2, $fn=48);
        translate([+w/2 - r2, -h/2 + r2]) circle(r=r2, $fn=48);
        translate([-w/2 + r2, +h/2 - r2]) circle(r=r2, $fn=48);
        translate([-w/2 + r2, -h/2 + r2]) circle(r=r2, $fn=48);
    }
}

/**
 * Creates a 3D extruded segment aligned with a given vector
 * Extrudes rounded rectangle cross-section from origin along vector direction
 * @param vec 3D vector defining direction and length
 */
module extruded_stay_segment(vec) {
    len = sqrt(vec[0]*vec[0] + vec[1]*vec[1] + vec[2]*vec[2]);
    if (len > 0.001) {  // Guard against degenerate length
        ang = acos(vec[2] / len);        // Angle between +Z and vector
        axis = [-vec[1], vec[0], 0];     // Rotation axis (cross product)
        rotate(a=ang, v=axis)
            linear_extrude(height=len, center=false)
                rounded_rect_2d(seatstay_depth_long, seatstay_w_long, seatstay_corner_r);
    }
}

/**
 * Creates solid chainstay with rounded rectangular cross-section
 * Extruded along +Z then rotated to align along +X
 */
module chainstay_solid() {
    rotate([0,90,0])
        linear_extrude(height=chainstay_length, center=false)
            rounded_rect_2d(chainstay_thick, chainstay_height, chainstay_corner_r);
}

/**
 * Places and orients one chainstay at correct position and angle
 * @param side +1 for right side, -1 for left side
 */
module place_chainstay(side=+1) {
    translate([chainstay_x_offset, side*bb_offset, chainstay_z_offset])
        rotate([0, pitch_deg, 0])          // Vertical pitch around Y
            rotate([0, 0, side*yaw_deg])   // Horizontal yaw around Z (mirrored by side)
                chainstay_solid();
}

//======================================================
// MAIN SEATSTAY ASSEMBLY MODULE
//======================================================

/**
 * Complete fused seatstay assembly with organic transitions
 * Creates a three-part seatstay system:
 * 1. Upper two-segment stay from seat tube with bend
 * 2. Stub above axle (tilted by seatstay_stub_angle)
 * 3. Smooth hull transitions between all segments
 * 
 * @param side +1 for right side, -1 for left side
 */
module complete_fused_seatstay(side = +1) {
    // Geometry reference points
    y_end_mag = bb_offset + height_y;
    P_stub_base = [x_axle, side*y_end_mag, z_axle + (thru_axle_d/2)];
    
    // Direction vector for stub tilt in X–Z plane
    stub_dir = [ sin(seatstay_stub_angle), 0, cos(seatstay_stub_angle) ];
    
    // Top center of stub after tilt
    P_start = [
        P_stub_base[0] + stub_dir[0] * seatstay_len,
        P_stub_base[1] + stub_dir[1] * seatstay_len,
        P_stub_base[2] + stub_dir[2] * seatstay_len
    ];
    
    // Seat tube connection point (430mm from BB center)
    dist_from_base = max(0, 430 - radius_inner);
    u_seat = [cos(seat_angle_horizontal), 0, sin(seat_angle_horizontal)];
    P_seat_base = [x_offset, 0, z_offset];
    P_end = [
        P_seat_base[0] + dist_from_base * u_seat[0],
        P_seat_base[1] + dist_from_base * u_seat[1],
        P_seat_base[2] + dist_from_base * u_seat[2]
    ];
    
    // Two-segment seatstay geometry calculations
    v_full = [P_start[0] - P_end[0], P_start[1] - P_end[1], P_start[2] - P_end[2]];
    pitch1 = atan2(v_full[2], sqrt(v_full[0]*v_full[0] + v_full[1]*v_full[1]));
    dy_target = side * half_sep;
    cos_pitch1_safe = max(1e-6, abs(cos(pitch1)));  // Prevent division by zero
    sin_yaw1_clamped = max(-1, min(1, dy_target / (d1 * cos_pitch1_safe)));  // Clamp to valid domain
    yaw1 = asin(sin_yaw1_clamped);
    sx = (v_full[0] < 0) ? -1 : 1;  // Choose X direction toward stub
    
    // Upper segment vector components (first segment from seat tube)
    dx1 = d1 * cos_pitch1_safe * cos(yaw1) * sx;
    dz1 = d1 * sin(pitch1);
    dy1 = dy_target;
    v1 = [dx1, dy1, dz1];
    
    // Mid-point where upper segment ends
    P_mid = [P_end[0] + v1[0], P_end[1] + v1[1], P_end[2] + v1[2]];
    
    // Lower segment vector (from mid-point to stub top)
    v2 = [P_start[0] - P_mid[0], P_start[1] - P_mid[1], P_start[2] - P_mid[2]];
    
    // Build complete fused assembly
    union() {
        // Upper segment 1: from seat tube connection point
        translate(P_end) 
            extruded_stay_segment(v1);
        
        // Organic blend between upper segments
        hull() {
            translate(P_end) 
                translate([v1[0]*t_off, v1[1]*t_off, v1[2]*t_off])
                extruded_stay_segment([v1[0]*e_off, v1[1]*e_off, v1[2]*e_off]);
            
            translate(P_mid)
                extruded_stay_segment([v2[0]*e_off, v2[1]*e_off, v2[2]*e_off]);
        }
        
        // Upper segment 2: most of the way toward stub
        translate(P_mid) 
            extruded_stay_segment([v2[0]*t_off, v2[1]*t_off, v2[2]*t_off]);
        
        // Organic blend between upper stay and stub
        hull() {
            // End of upper segment 2
            translate(P_mid)
                translate([v2[0]*t_off, v2[1]*t_off, v2[2]*t_off])
                extruded_stay_segment([v2[0]*e_off, v2[1]*e_off, v2[2]*e_off]);
            
            // Proxy geometry at stub top for hull connection
            translate(P_stub_base)
                rotate([0, seatstay_stub_angle, 0])
                    translate([0,0,seatstay_len])
                        linear_extrude(height = 0.01, center = false)
                            rounded_rect_2d(seatstay_depth, seatstay_w, seatstay_corner_r);
        }
        
        // Stub itself (tilted around axle)
        translate(P_stub_base)
            rotate([0, seatstay_stub_angle, 0])
                translate([0,0,seatstay_len/2])
                    linear_extrude(height = seatstay_len, center = true)
                        rounded_rect_2d(seatstay_depth, seatstay_w, seatstay_corner_r);
    }
}


//======================================================
// FRAME CONSTRUCTION
//======================================================

// Bottom bracket shell (hollow cylinder along X-axis)
difference() {
    rotate([90,90,0])
        cylinder(h = bb_width, r = radius_outer, center = true, $fn=128);
    
    rotate([90,90,0])
        cylinder(h = bb_width+2, r = radius_inner, center = true, $fn=128);
}

// Seat tube (hollow cylinder at seat angle)
difference() {
    translate([x_offset,0,z_offset])
        rotate([0, seat_angle, 0])
            cylinder(h = seat_length, r = seat_radius_outer, center = false, $fn=128);
    
    translate([x_offset,0,z_offset])
        rotate([0, seat_angle, 0])
            cylinder(h = seat_length+2, r = seat_radius_inner, center = false, $fn=128);
}

// Chainstays (both left and right)
union() {
    place_chainstay(+1);   // Right
    place_chainstay(-1);   // Left
}

// thru-axle (centered cylinder along Y-axis)
translate([x_axle, y_axle, z_axle])
    rotate([90,0,0])
        cylinder(h = thru_axle_w, r = thru_axle_d/2, center = true, $fn = 96);

complete_fused_seatstay(+1);
complete_fused_seatstay(-1);