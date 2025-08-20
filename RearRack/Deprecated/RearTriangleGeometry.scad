// parameters for the bottom bracket shell, measurements in mm
bb_diameter = 41;     // inner diameter; PF41 (PressFit86 standard)
bb_thickness = 3;     // wall thickness
bb_width = 86;        // shell width for PressFit86

// derived values
outer_diameter = bb_diameter + 2*bb_thickness;
radius_outer = outer_diameter/2;
radius_inner = bb_diameter/2;

// model hollow bottom bracket tube, centered at origin
difference() {
    // outer tube, rotated so axis lies along X
    rotate([90,90,0])
        cylinder(h = bb_width, r = radius_outer, center = true, $fn=128); //,$fn=128 smoothen circle
    
    // inner bore
    rotate([90,90,0])
        cylinder(h = bb_width+2, r = radius_inner, center = true, $fn=128);//,$fn=128 smoothen circle
}


//---- seat tube 
// parameters
seat_length = 522;
seat_angle_horizontal = 73.5;      // angle relative to horizontal
seat_angle = 90 - seat_angle_horizontal;  // convert for OpenSCAD rotate() relative to z axis
seat_inner_d = 27.2;       // inner diameter
seat_thickness = 5;        // wall thickness
seat_outer_d = seat_inner_d + 2*seat_thickness;
seat_radius_outer = seat_outer_d/2;
seat_radius_inner = seat_inner_d/2;
x_offset = cos(seat_angle_horizontal) * radius_inner;
z_offset = sin(seat_angle_horizontal) * radius_inner;


difference() {
    // outer seat tube
    translate([x_offset,0,z_offset])        // place tube at BB rim
        rotate([0, seat_angle, 0])          // tilt relative to X-axis
            cylinder(h = seat_length, r = seat_radius_outer, center = false, $fn=128);

    // inner bore
    translate([x_offset,0,z_offset])
        rotate([0, seat_angle, 0])
            cylinder(h = seat_length+2, r = seat_radius_inner, center = false, $fn=128);
}





/******************************************************
 PARAMETRIC CHAINSTAYS + THRU-AXLE
 -----------------------------------------------------
 - chainstay rounded-rectangle cross section
      thickness = 15 mm (X width)
      height    = 30 mm (Z height)
      extrusion length = chainstay_length (hypotenuse)
 - positioned
      vertical pitch = seat_tube_angle - seattube_chainstay_delta
      horizontal yaw = computed via triangle from BB + axle geometry
******************************************************/

// ---------- Parameters ----------
chainstay_length   = 430;   // hypotenuse (tube-axis length)
chainstay_thick    = 15;    // thickness (X width)
chainstay_height   = 30;    // vertical dimension
chainstay_corner_r = 3;     // rounded corner radius

seattube_chainstay_delta     = 65;    // angle between seat-tube and chainstay

thru_axle_d        = 14;    // axle dia
thru_axle_w        = 142;   // OLD (mm)

// ---------- Derived geometry ----------
bb_half        = bb_width/2;
bb_offset      = bb_half - chainstay_thick;                  // BB triangle offset
//pitch_deg      = seat_angle_horizontal - seattube_chainstay_delta;     // vertical pitch angle

chainstay_angle_horizontal = seat_angle_horizontal - seattube_chainstay_delta; // 60° below seat tube
pitch_deg      = 90-chainstay_angle_horizontal-90;           // convert for OpenSCAD like seat tube

height_y       = (thru_axle_w/2) - chainstay_thick - bb_offset;
base_x         = sqrt(max(0, chainstay_length*chainstay_length - height_y*height_y));
yaw_deg        = atan2(height_y, base_x);                    // horizontal yaw

// calculate BB rim offsets for chainstay positioning 
chainstay_x_offset = cos(chainstay_angle_horizontal) * radius_inner;
chainstay_z_offset = sin(chainstay_angle_horizontal) * radius_inner;

// cross-section helper 
module rounded_rect_2d(h, w, r){
    r2 = min(r, w/2, h/2);
    hull(){
        translate([+w/2 - r2, +h/2 - r2]) circle(r=r2, $fn=48);
        translate([+w/2 - r2, -h/2 + r2]) circle(r=r2, $fn=48);
        translate([-w/2 + r2, +h/2 - r2]) circle(r=r2, $fn=48);
        translate([-w/2 + r2, -h/2 + r2]) circle(r=r2, $fn=48);
    }
}

// chainstay 
module chainstay_solid(){
    // extrude along +Z, then rotate to align along +X
    rotate([0,90,0])
        linear_extrude(height=chainstay_length, center=false)
            rounded_rect_2d(chainstay_thick, chainstay_height, chainstay_corner_r);
}

// place chainstay 
module place_chainstay(side=+1){
    // side = +1 right, -1 left
    translate([chainstay_x_offset, side*bb_offset, chainstay_z_offset]) // position at BB rim
        rotate([0, pitch_deg, 0])          // pitch around Y
            rotate([0, 0, side*yaw_deg])   // yaw around Z (mirrored by side)
                chainstay_solid();
}

// build stays + axle 
union(){
    place_chainstay(+1);   // right stay
    place_chainstay(-1);   // left stay
}

//  Thru-axle pin 
x_axle = chainstay_x_offset + chainstay_length * cos(yaw_deg) * cos(pitch_deg); // adjust for BB rim positioning
y_axle = 0;// symmetry
z_axle = chainstay_z_offset - chainstay_length * cos(yaw_deg) * sin(pitch_deg);// adjust for BB rim positioning

translate([x_axle, y_axle, z_axle])
    rotate([90,0,0])   // align cylinder along Y
        cylinder(h = thru_axle_w, r = thru_axle_d/2, center = true, $fn = 96);



/******************************************************
 SEATSTAY STUBS ROUNDED RECT TUBES AT CHAINSTAY ENDS
 -----------------------------------------------------
 Intent and explanation to myself in however many years 
  - two short “seatstay” stubs, one per side, placed at the
    end of each chainstay (i.e., above the thru-axle).
  - stub:
      - Cross-section: rounded rectangle 14 mm (X width) × 16 mm (Y depth)
      – Length along +Z: 30 mm (points upward)
      – Centered width/depth-wise over the chainstay end
      – Sits ON TOP of the axle: its bottom face is tangent to
        the axle’s top. Hence its Z center is:
            z_center = z_axle + (thru_axle_d/2) + (seatstay_len/2)

  - Chainstay end (for each side) is at:
        P_end(side) = (x_axle, side*(bb_offset + height_y), z_axle)
    because:
        x_axle = chainstay_x_offset + chainstay_length * cos(yaw_deg) * cos(pitch_deg)
        z_axle = chainstay_z_offset - chainstay_length * cos(yaw_deg) * sin(pitch_deg)
        (and the Y end magnitude is bb_offset + height_y)
  - reuse these to position each stub cleanly and symmetrically.

 Notes
  - Cross-section is built in the XY plane (width=X, depth=Y),
    then linear_extruded along Z (length = 30 mm).
  - The rounded_rect_2d() helper you already have is reused.

******************************************************/

seatstay_len      = 30;   // upward length
seatstay_w        = 14;   // X width of cross-section
seatstay_depth    = 16;   // Y depth of cross-section
seatstay_corner_r = 5;    // corner radius

// Y position of each chainstay end (one per side)
y_end_mag = bb_offset + height_y;

// Common Z center so stub sits on top of the axle
z_stub_center = z_axle + (thru_axle_d/2) + (seatstay_len/2);

// Helper: place one stub on a given side (+1 right, -1 left)
module seatstay_stub(side=+1){
    translate([ x_axle, side * y_end_mag, z_stub_center ])
        // Cross-section: width = seatstay_w (X), depth = seatstay_depth (Y)
        linear_extrude(height = seatstay_len, center = true)
            rounded_rect_2d(seatstay_depth, seatstay_w, seatstay_corner_r);
}

// Place both stubs
seatstay_stub(+1);
seatstay_stub(-1);


/******************************************************
 SEATSTAYS — CONNECT STUB TOPS TO SEAT TUBE @ 430 mm
 -----------------------------------------------------
 Intent and explanation to myself in however many years 
  - create one tube per side (“seatstay”) as a straight prism with
    rounded-rectangle cross-section, connecting:
       P_start(side): top of the seatstay stub above the axle
       P_end: point on the seat-tube axis located 430 mm from the BB center
  - Cross-section: reuse the stub’s style by default (14 * 16 mm).
  - Length and orientation are computed from endpoints; object is
    extruded along +Z and then rotated via an axis–angle rotation that
    aligns +Z with the vector (P_end - P_start).

 Geometry & math
  - Seat-tube axis direction (unit) in XZ-plane:
        u_seat = [ cos(seat_angle_horizontal), 0, sin(seat_angle_horizontal) ]
    Seat-tube base point at BB inner rim (already used for the seat tube):
        P_seat_base = [ x_offset, 0, z_offset ]
    Target seat-tube point at 430 mm from BB center:
        dist_from_base = max(0, 430 - radius_inner)
        P_end = P_seat_base + dist_from_base * u_seat

  - Stub top (per side), centered over axle and sitting on it:
        y_end_mag = bb_offset + height_y
        P_start(+1) = [ x_axle, +y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len ]
        P_start(-1) = [ x_axle, -y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len ]

  - To align a +Z-extruded prism to vector v = (P_end - P_start):
        len  = |v| = sqrt(vx^2 + vy^2 + vz^2)
        ang  = acos( vz / len )          // angle between +Z and v (degrees in OpenSCAD)
        axis = cross([0,0,1], v) = [ -vy, vx, 0 ]   // rotation axis
    Then:
        translate(P_start)
          rotate(a=ang, v=axis)
            linear_extrude(height=len) <rounded-rect profile>

 Notes
  - OpenSCAD trig uses DEGREES; acos returns degrees as well.
  - Cross-section is centered in XY, extruded from z=0 → z=len (center=false),
    so the tube starts exactly at P_start and ends at P_end.

******************************************************/
/*
// --- seatstay cross-section (reuse stub style by default) ---
seatstay_len_stub   = 30;     // you already used this for the stubs
seatstay_w_long     = 14;     // X width (same as stub)
seatstay_depth_long = 16;     // Y depth (same as stub)

// --- compute seat-tube target point at 430 mm from BB center ---
dist_from_base = max(0, 430 - radius_inner);
u_seat = [ cos(seat_angle_horizontal), 0, sin(seat_angle_horizontal) ];
P_seat_base = [ x_offset, 0, z_offset ];
P_end = [
    P_seat_base[0] + dist_from_base * u_seat[0],
    P_seat_base[1] + dist_from_base * u_seat[1],
    P_seat_base[2] + dist_from_base * u_seat[2]
];

// --- helper: build one seatstay from stub top to seat tube target ---
module seatstay_long(side=+1){
    y_end_mag = bb_offset + height_y;
    P_start = [ x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len_stub ];

    v = [ P_end[0] - P_start[0],
          P_end[1] - P_start[1],
          P_end[2] - P_start[2] ];

    len = sqrt( v[0]*v[0] + v[1]*v[1] + v[2]*v[2] );
    // Guard against degenerate length
    if (len > 0.001) {
        ang  = acos( v[2] / len );     // degrees in OpenSCAD
        axis = [ -v[1], v[0], 0 ];     // cross([0,0,1], v)

        translate(P_start)
            rotate(a=ang, v=axis)
                linear_extrude(height=len, center=false)
                    // rounded_rect_2d(h=depth(Y), w=width(X), r)
                    rounded_rect_2d(seatstay_depth_long, seatstay_w_long, seatstay_corner_r);
    }
}

// --- place both seatstays ---
seatstay_long(+1);
seatstay_long(-1);*/


// ---------------------------------------------------------------------------
// two-segment seatstay (replacement for the inaccurate single-segment seatstay)
// ---------------------------------------------------------------------------

// upper segment length (from seat-tube intersection away from seat tube)
d1 = 90;            // 90 mm as you requested (distance along the stay from seat-tube)
separation = 60;    // total Y separation between the two upper-segment end points (mm)
half_sep = separation/2;

// reuse these cross-section params
seatstay_len_stub   = 30;     // stub length already used
seatstay_w_long     = 14;     // X width
seatstay_depth_long = 16;     // Y depth

// helper: build a rounded-rect prism that goes from origin along +Z and has
// rounded_rect_2d() profile; this matches your previous extrusion convention.
// ---------- safe extrude helper ----------
module extruded_stay_segment(vec) {
    len = sqrt(vec[0]*vec[0] + vec[1]*vec[1] + vec[2]*vec[2]);
    if (len > 0.001) {
        ang  = acos(vec[2] / len);            // angle between +Z and vec
        axis = [ -vec[1], vec[0], 0 ];
        rotate(a=ang, v=axis)
            linear_extrude(height=len, center=false)
                rounded_rect_2d(seatstay_depth_long, seatstay_w_long, seatstay_corner_r);
    }
}

// ---------- corrected two-segment seatstay ----------
module seatstay_two_segment(side = +1) {
    y_end_mag = bb_offset + height_y;
    P_start = [ x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len_stub ];

    // seat-tube target point (same as earlier)
    dist_from_base = max(0, 430 - radius_inner);
    u_seat = [ cos(seat_angle_horizontal), 0, sin(seat_angle_horizontal) ];
    P_seat_base = [ x_offset, 0, z_offset ];
    P_end = [
        P_seat_base[0] + dist_from_base * u_seat[0],
        P_seat_base[1] + dist_from_base * u_seat[1],
        P_seat_base[2] + dist_from_base * u_seat[2]
    ];

    // full original vector (from seat-tube point to stub top)
    v_full = [ P_start[0] - P_end[0],
               P_start[1] - P_end[1],
               P_start[2] - P_end[2] ];

    // pitch of the original stay (angle above XY plane)
    pitch1 = atan2(v_full[2], sqrt(v_full[0]*v_full[0] + v_full[1]*v_full[1]));

    // lateral target for upper-segment end
    dy_target = side * half_sep;

    // protect against tiny cos(pitch) by using a safe variable (no reassignment)
    cos_pitch1 = cos(pitch1);
    cos_pitch1_safe = (abs(cos_pitch1) < 1e-6) ? 1e-6 : cos_pitch1;

    // compute yaw needed to produce dy_target after length d1 (clamp domain)
    sin_yaw1 = dy_target / (d1 * cos_pitch1_safe);
    sin_yaw1_clamped = max(-1, min(1, sin_yaw1));
    yaw1 = asin(sin_yaw1_clamped);

    // choose X direction sign so the upper segment points toward the stub X
    sx = (v_full[0] < 0) ? -1 : 1;

    // upper-segment vector components (pointing away from P_end)
    dx1 = d1 * cos_pitch1_safe * cos(yaw1) * sx;
    dz1 = d1 * sin(pitch1);
    dy1 = dy_target;

    v1 = [ dx1, dy1, dz1 ];

    // mid-point (end of upper segment)
    P_mid = [ P_end[0] + v1[0], P_end[1] + v1[1], P_end[2] + v1[2] ];

    // lower segment connects P_mid -> P_start
    v2 = [ P_start[0] - P_mid[0], P_start[1] - P_mid[1], P_start[2] - P_mid[2] ];

    // place both extruded prisms
    translate(P_end) extruded_stay_segment(v1);
    translate(P_mid) extruded_stay_segment(v2);
}


module seatstay_multi_hull(side = +1) {
    y_end_mag = bb_offset + height_y;
    P_start = [ x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len_stub ];
    
    dist_from_base = max(0, 430 - radius_inner);
    u_seat = [ cos(seat_angle_horizontal), 0, sin(seat_angle_horizontal) ];
    P_seat_base = [ x_offset, 0, z_offset ];
    P_end = [
        P_seat_base[0] + dist_from_base * u_seat[0],
        P_seat_base[1] + dist_from_base * u_seat[1],
        P_seat_base[2] + dist_from_base * u_seat[2]
    ];
    
    // calculate existing mid-point
    v_full = [ P_start[0] - P_end[0], P_start[1] - P_end[1], P_start[2] - P_end[2] ];
    pitch1 = atan2(v_full[2], sqrt(v_full[0]*v_full[0] + v_full[1]*v_full[1]));
    dy_target = side * half_sep;
    cos_pitch1_safe = max(1e-6, abs(cos(pitch1)));
    sin_yaw1_clamped = max(-1, min(1, dy_target / (d1 * cos_pitch1_safe)));
    yaw1 = asin(sin_yaw1_clamped);
    sx = (v_full[0] < 0) ? -1 : 1;
    
    dx1 = d1 * cos_pitch1_safe * cos(yaw1) * sx;
    dz1 = d1 * sin(pitch1);
    dy1 = dy_target;
    v1 = [ dx1, dy1, dz1 ];
    P_mid = [ P_end[0] + v1[0], P_end[1] + v1[1], P_end[2] + v1[2] ];
    v2 = [ P_start[0] - P_mid[0], P_start[1] - P_mid[1], P_start[2] - P_mid[2] ];
    
    // create three overlapping segments with hull blending
    blend_length = 25; // mm of overlap for blending
    
    union() {
        // segment 1: from P_end toward P_mid
        translate(P_end) extruded_stay_segment(v1);
        
        // blending region around P_mid
        hull() {
            // end of segment 1
            translate(P_end) 
                translate([v1[0]*0.8, v1[1]*0.8, v1[2]*0.8])
                extruded_stay_segment([v1[0]*0.2, v1[1]*0.2, v1[2]*0.2]);
            
            // start of segment 2  
            translate(P_mid)
                extruded_stay_segment([v2[0]*0.2, v2[1]*0.2, v2[2]*0.2]);
        }
        
        // segment 2: from P_mid to P_start
        translate(P_mid) extruded_stay_segment(v2);
    }
}


// Replace both your seatstay_stub() calls and seatstay_multi_hull() calls with this:

module complete_fused_seatstay(side = +1) {
    y_end_mag = bb_offset + height_y;
    P_start = [ x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len_stub ];
    
    //stub base point (bottom of the stub, sitting on axle)
    P_stub_base = [ x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) ];
    
    dist_from_base = max(0, 430 - radius_inner);
    u_seat = [ cos(seat_angle_horizontal), 0, sin(seat_angle_horizontal) ];
    P_seat_base = [ x_offset, 0, z_offset ];
    P_end = [
        P_seat_base[0] + dist_from_base * u_seat[0],
        P_seat_base[1] + dist_from_base * u_seat[1],
        P_seat_base[2] + dist_from_base * u_seat[2]
    ];
    
    // Calculate your existing mid-point
    v_full = [ P_start[0] - P_end[0], P_start[1] - P_end[1], P_start[2] - P_end[2] ];
    pitch1 = atan2(v_full[2], sqrt(v_full[0]*v_full[0] + v_full[1]*v_full[1]));
    dy_target = side * half_sep;
    cos_pitch1_safe = max(1e-6, abs(cos(pitch1)));
    sin_yaw1_clamped = max(-1, min(1, dy_target / (d1 * cos_pitch1_safe)));
    yaw1 = asin(sin_yaw1_clamped);
    sx = (v_full[0] < 0) ? -1 : 1;
    
    dx1 = d1 * cos_pitch1_safe * cos(yaw1) * sx;
    dz1 = d1 * sin(pitch1);
    dy1 = dy_target;
    v1 = [ dx1, dy1, dz1 ];
    P_mid = [ P_end[0] + v1[0], P_end[1] + v1[1], P_end[2] + v1[2] ];
    v2 = [ P_start[0] - P_mid[0], P_start[1] - P_mid[1], P_start[2] - P_mid[2] ];
    
    // create the complete fused assembly
    union() {
        // upper segment 1: from P_end toward P_mid
        translate(P_end) extruded_stay_segment(v1);
        
        // blending region around P_mid (upper junction)
        hull() {
            translate(P_end) 
                translate([v1[0]*0.8, v1[1]*0.8, v1[2]*0.8])
                extruded_stay_segment([v1[0]*0.2, v1[1]*0.2, v1[2]*0.2]);
            
            translate(P_mid)
                extruded_stay_segment([v2[0]*0.2, v2[1]*0.2, v2[2]*0.2]);
        }
        
        // upper segment 2: most of the way from P_mid toward P_start
        translate(P_mid) 
            extruded_stay_segment([v2[0]*0.8, v2[1]*0.8, v2[2]*0.8]);
        
        t_off=0.8;
        e_off=0.2;
        // blending region between upper stay and stub
        hull() {
            // end of upper segment 2
            translate(P_mid)
                //translate([v2[0]*0.8, v2[1]*0.8, v2[2]*0.8])
                //extruded_stay_segment([v2[0]*0.2, v2[1]*0.2, v2[2]*0.2]);
                //translate([v2[0], v2[1], v2[2]])
                //extruded_stay_segment([v2[0], v2[1], v2[2]]);
                translate([v2[0]*t_off, v2[1]*t_off, v2[2]*t_off])
                extruded_stay_segment([v2[0]*e_off, v2[1]*e_off, v2[2]*e_off]);

            /*// top portion of stub
            translate([x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len-(seatstay_len*0.4)])
                linear_extrude(height = seatstay_len+0.0, center = true)
                    rounded_rect_2d(seatstay_depth, seatstay_w, seatstay_corner_r);*/
            // Proxy geometry: just the stub’s top face
            translate([x_axle, side*y_end_mag, z_axle + (thru_axle_d/2) + seatstay_len])
                linear_extrude(height = 0.01, center = false)
                    rounded_rect_2d(seatstay_depth, seatstay_w, seatstay_corner_r);
        }
        
        //stub itself
        translate([x_axle, side*y_end_mag, z_stub_center])
            linear_extrude(height = seatstay_len, center = true)
                rounded_rect_2d(seatstay_depth, seatstay_w, seatstay_corner_r);
    }
}


//seatstay_two_segment(+1);
//seatstay_two_segment(-1);

   //seatstay_multi_hull(+1);
   //seatstay_multi_hull(-1);

complete_fused_seatstay(+1);
complete_fused_seatstay(-1);

