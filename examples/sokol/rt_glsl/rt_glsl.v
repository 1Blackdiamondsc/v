/**********************************************************************
*
* Sokol 3d cube demo
*
* Copyright (c) 2021 Dario Deledda. All rights reserved.
* Use of this source code is governed by an MIT license
* that can be found in the LICENSE file.
*
* HOW TO COMPILE SHADERS:
* - donwload sokol shader tool from: https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md
* - compile shader with:
* linux  :  sokol-shdc --input rt_glsl.glsl --output rt_glsl.h --slang glsl330
* windows:  sokol-shdc.exe --input rt_glsl.glsl --output rt_glsl.h --slang glsl330 
*
* --slang parameter can be:
* - glsl330: desktop GL
* - glsl100: GLES2 / WebGL
* - glsl300es: GLES3 / WebGL2
* - hlsl4: D3D11
* - hlsl5: D3D11
* - metal_macos: Metal on macOS
* - metal_ios: Metal on iOS device
* - metal_sim: Metal on iOS simulator
* - wgpu: WebGPU
*
* you can have multiple platforms at the same time passing parameters like this: --slang glsl330:hlsl5:metal_macos
* for further infos have a look at the sokol shader tool docs.
*
* TODO:
* - frame counter
**********************************************************************/
import gg
import gx
//import math

import sokol.sapp
import sokol.gfx
import sokol.sgl

import time

const (
	win_width  = 800
	win_height = 800
	bg_color   = gx.white
)

struct App {
mut:
	gg            &gg.Context
	texture       C.sg_image
	init_flag     bool
	frame_count   int

	mouse_x       int = -1
	mouse_y       int = -1
	
	// glsl
	cube_pip_glsl C.sg_pipeline
	cube_bind     C.sg_bindings
	
	// time
	ticks         i64
}

/******************************************************************************
*
* GLSL Include and functions
*
******************************************************************************/
#flag -I @VROOT/.
#include "HandmadeMath.h"
#include "rt_glsl.h"
#include "default_include.h"
fn C.rt_shader_desc() &C.sg_shader_desc

fn C.calc_matrices(res voidptr,w f32, h f32, rx f32, ry f32, scale f32)

/******************************************************************************
*
* Texture functions
*
******************************************************************************/
fn create_texture(w int, h int, buf byteptr) C.sg_image{
	sz := w * h * 4
	mut img_desc := C.sg_image_desc{
		width:         w
		height:        h
		num_mipmaps:   0
		min_filter:    .linear
		mag_filter:    .linear
		//usage: .dynamic
		wrap_u:        .clamp_to_edge
		wrap_v:        .clamp_to_edge
		label:         &byte(0)
		d3d11_texture: 0
	}
	// comment if .dynamic is enabled
	img_desc.content.subimage[0][0] = C.sg_subimage_content{
		ptr:  buf
		size: sz
	}

	sg_img := C.sg_make_image(&img_desc)
	return sg_img
}

fn destroy_texture(sg_img C.sg_image){
	C.sg_destroy_image(sg_img)
}

// Use only if usage: .dynamic is enabled
fn update_text_texture(sg_img C.sg_image, w int, h int, buf byteptr){
	sz := w * h * 4
	mut tmp_sbc := C.sg_image_content{}
	tmp_sbc.subimage[0][0] = C.sg_subimage_content {
		ptr: buf
		size: sz
	}
	C.sg_update_image(sg_img, &tmp_sbc)
}

/******************************************************************************
*
* Draw functions
*
******************************************************************************/
/*
		Cube vertex buffer with packed vertex formats for color and texture coords.
		Note that a vertex format which must be portable across all
		backends must only use the normalized integer formats
		(BYTE4N, UBYTE4N, SHORT2N, SHORT4N), which can be converted
		to floating point formats in the vertex shader inputs.
		The reason is that D3D11 cannot convert from non-normalized
		formats to floating point inputs (only to integer inputs),
		and WebGL2 / GLES2 don't support integer vertex shader inputs.
*/

struct Vertex_t {
    x f32
		y f32
		z f32
    color u32
		
		//u u16   // for compatibility with D3D11
		//v u16   // for compatibility with D3D11
		u f32
		v f32
} 

fn init_cube_glsl(mut app App) {
	/* cube vertex buffer */
	//d := u16(32767)     // for compatibility with D3D11, 32767 stand for 1
	d := f32(1.0)
	c := u32(0xFFFFFF_FF) // color RGBA8
  vertices := [
	
		Vertex_t{-1.0, -1.0, -1.0, c,  0, 0},
		Vertex_t{ 1.0, -1.0, -1.0, c,  d, 0},
		Vertex_t{ 1.0,  1.0, -1.0, c,  d, d},
		Vertex_t{-1.0,  1.0, -1.0, c,  0, d},

		Vertex_t{-1.0, -1.0,  1.0, c,  0, 0},
		Vertex_t{ 1.0, -1.0,  1.0, c,  d, 0},
		Vertex_t{ 1.0,  1.0,  1.0, c,  d, d},
		Vertex_t{-1.0,  1.0,  1.0, c,  0, d},

		Vertex_t{-1.0, -1.0, -1.0, c,  0, 0},
		Vertex_t{-1.0,  1.0, -1.0, c,  d, 0},
		Vertex_t{-1.0,  1.0,  1.0, c,  d, d},
		Vertex_t{-1.0, -1.0,  1.0, c,  0, d},

		Vertex_t{ 1.0, -1.0, -1.0, c,  0, 0},
		Vertex_t{ 1.0,  1.0, -1.0, c,  d, 0},
		Vertex_t{ 1.0,  1.0,  1.0, c,  d, d},
		Vertex_t{ 1.0, -1.0,  1.0, c,  0, d},

		Vertex_t{-1.0, -1.0, -1.0, c,  0, 0},
		Vertex_t{-1.0, -1.0,  1.0, c,  d, 0},
		Vertex_t{ 1.0, -1.0,  1.0, c,  d, d},
		Vertex_t{ 1.0, -1.0, -1.0, c,  0, d},

		Vertex_t{-1.0,  1.0, -1.0, c,  0, 0},
		Vertex_t{-1.0,  1.0,  1.0, c,  d, 0},
		Vertex_t{ 1.0,  1.0,  1.0, c,  d, d},
		Vertex_t{ 1.0,  1.0, -1.0, c,  0, d},

	]

	mut vert_buffer_desc := C.sg_buffer_desc{}
	unsafe {C.memset(&vert_buffer_desc, 0, sizeof(vert_buffer_desc))}
	vert_buffer_desc.size    = vertices.len * int(sizeof(Vertex_t))
	vert_buffer_desc.content = byteptr(vertices.data)
	vert_buffer_desc.@type   = .vertexbuffer
	vert_buffer_desc.label   = "cube-vertices".str
	vbuf := gfx.make_buffer(&vert_buffer_desc)
	
	/* create an index buffer for the cube */
	indices := [
				u16(0), 1, 2,  0, 2, 3,
        6, 5, 4,       7, 6, 4,
        8, 9, 10,      8, 10, 11,
        14, 13, 12,    15, 14, 12,
        16, 17, 18,    16, 18, 19,
        22, 21, 20,    23, 22, 20
	]
	
	mut index_buffer_desc := C.sg_buffer_desc{}
	unsafe {C.memset(&index_buffer_desc, 0, sizeof(index_buffer_desc))}
	index_buffer_desc.size    = indices.len * int(sizeof(u16))
	index_buffer_desc.content = byteptr(indices.data)
	index_buffer_desc.@type   = .indexbuffer
	index_buffer_desc.label   = "cube-indices".str
	ibuf := gfx.make_buffer(&index_buffer_desc)
	
	/* create shader */
	shader := gfx.make_shader(C.rt_shader_desc())

	mut pipdesc := C.sg_pipeline_desc{}
	unsafe {C.memset(&pipdesc, 0, sizeof(pipdesc))}
	pipdesc.layout.buffers[0].stride = int(sizeof(Vertex_t))
	
	// the constants [C.ATTR_vs_pos, C.ATTR_vs_color0, C.ATTR_vs_texcoord0] are generated by sokol-shdc
	pipdesc.layout.attrs[C.ATTR_vs_pos      ].format  = .float3   // x,y,z as f32
	pipdesc.layout.attrs[C.ATTR_vs_color0   ].format  = .ubyte4n  // color as u32
	pipdesc.layout.attrs[C.ATTR_vs_texcoord0].format  = .float2   // u,v as f32
	//pipdesc.layout.attrs[C.ATTR_vs_texcoord0].format  = .short2n  // u,v as u16
 
	pipdesc.shader = shader
	pipdesc.index_type = .uint16
	
	pipdesc.depth_stencil  = C.sg_depth_stencil_state{
		depth_write_enabled: true
		depth_compare_func : gfx.CompareFunc(C.SG_COMPAREFUNC_LESS_EQUAL)
	}
	pipdesc.rasterizer  = C.sg_rasterizer_state {
		cull_mode: .back
	}
	pipdesc.label = "glsl_shader pipeline".str
	
	app.cube_bind.vertex_buffers[0] = vbuf
	app.cube_bind.index_buffer      = ibuf
	app.cube_bind.fs_images[C.SLOT_tex] = app.texture
	app.cube_pip_glsl = gfx.make_pipeline(&pipdesc)
	println("GLSL init DONE!")
}

fn draw_cube_glsl(app App){
	if app.init_flag == false {
		return
	}

	ws := gg.window_size()
	ratio := f32(ws.width) / ws.height
	dw := f32(ws.width  / 2)
	dh := f32(ws.height / 2)
	
	mut res := [f32(0),0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]!

	// use the following commented lines to rotate the 3d glsl cube
	// rot := [f32(app.mouse_y), f32(app.mouse_x)]
	// C.calc_matrices( voidptr(&res), dw, dh, rot[0], rot[1] ,2.3)
	C.calc_matrices( voidptr(&res), dw, dh, 0, 0 ,2.3)
	gfx.apply_viewport(0, 0, ws.width, ws.height, true)

	// apply the pipline and bindings
	gfx.apply_pipeline(app.cube_pip_glsl)
	gfx.apply_bindings(app.cube_bind)
	
	//***************
	// Uniforms
	//***************
	// passing the view matrix as uniform
	// res is a 4x4 matrix of f32 thus: 4*16 byte of size
	gfx.apply_uniforms(C.SG_SHADERSTAGE_VS, C.SLOT_vs_params, &res, int(sizeof(res)) )
	
	// fragment shader uniforms
	time_ticks := f32(time.ticks() - app.ticks) / 1000
	mut tmp_fs_params := [
		f32(ws.width), ws.height * ratio,  // x,y resolution to pass to FS
		app.mouse_x,               // mouse x
		ws.height - app.mouse_y*2, // mouse y scaled
		time_ticks,                // time as f32
		app.frame_count,           // frame count
		0,0                        // padding bytes , see "fs_params" struct paddings in rt_glsl.h 
	]!
	gfx.apply_uniforms(C.SG_SHADERSTAGE_FS, C.SLOT_fs_params, &tmp_fs_params, int(sizeof(tmp_fs_params)))
	
	// 3 vertices for triangle * 2 triangles per face * 6 faces = 36 vertices to draw
	gfx.draw(0, (3 * 2) * 6, 1)
	gfx.end_pass()
	gfx.commit()
}

fn frame(mut app App) {
	ws := gg.window_size()

	// clear
	mut color_action := C.sg_color_attachment_action{
		action: gfx.Action(C.SG_ACTION_CLEAR)
	}
	color_action.val[0] = 0
	color_action.val[1] = 0
	color_action.val[2] = 0
	color_action.val[3] = 1.0
	mut pass_action := C.sg_pass_action{}
	pass_action.colors[0] = color_action
	gfx.begin_default_pass(&pass_action, ws.width, ws.height)
	
	// glsl cube
	draw_cube_glsl(app)
	app.frame_count++
}	

/******************************************************************************
*
* Init / Cleanup
*
******************************************************************************/
fn my_init(mut app App) {
	// set max vertices,
	// for a large number of the same type of object it is better use the instances!!
	desc := sapp.create_desc()
	gfx.setup(&desc)
	sgl_desc := C.sgl_desc_t{
		max_vertices: 50 * 65536
	}
	sgl.setup(&sgl_desc)

	// create chessboard texture 256*256 RGBA
	w := 256
	h := 256
	sz := w * h * 4
	tmp_txt := unsafe {malloc(sz)}
	mut i := 0
	for i < sz {
		unsafe {
			y := (i >> 0x8) >> 5  // 8 cell
			x := (i & 0xFF) >> 5  // 8 cell
			// upper left corner
			if x==0 && y==0 {
				tmp_txt[i  ] =  byte(0xFF)
				tmp_txt[i+1] =  byte(0)
				tmp_txt[i+2] =  byte(0)
				tmp_txt[i+3] =  byte(0xFF)
			}
			// low right corner
			else if x==7 && y==7 {
				tmp_txt[i  ] =  byte(0)
				tmp_txt[i+1] =  byte(0xFF)
				tmp_txt[i+2] =  byte(0)
				tmp_txt[i+3] =  byte(0xFF)
			} else {
				col := if ((x+y) & 1) == 1 {0xFF} else {128}
				tmp_txt[i  ] =  byte(col)   // red
				tmp_txt[i+1] =  byte(col)   // green
				tmp_txt[i+2] =  byte(col)   // blue
				tmp_txt[i+3] =  byte(0xFF)  // alpha
			}
			i += 4
		}
	}
	unsafe {
		app.texture = create_texture(w, h, tmp_txt)
		free(tmp_txt)
	}
	// glsl
	init_cube_glsl(mut app)
	app.init_flag = true
}

fn cleanup(mut app App) {
	gfx.shutdown()
}

/******************************************************************************
*
* event
*
******************************************************************************/
fn my_event_manager(mut ev sapp.Event, mut app App) {
	if ev.typ == .mouse_move {
		app.mouse_x = int(ev.mouse_x)
		app.mouse_y = int(ev.mouse_y)
	}
	if ev.typ == .touches_began || ev.typ == .touches_moved {
		if ev.num_touches > 0 {
			touch_point := ev.touches[0]
			app.mouse_x = int(touch_point.pos_x)
			app.mouse_y = int(touch_point.pos_y)
		}
	}
}

/******************************************************************************
*
* Main
*
******************************************************************************/
[console]
fn main(){
	// App init
	mut app := &App{
		gg: 0
	}

	app.gg = gg.new_context({
		width:         win_width
		height:        win_height
		use_ortho:     true // This is needed for 2D drawing
		create_window: true
		window_title:  '3D Ray Marching Cube'
		user_data:     app
		bg_color:      bg_color
		frame_fn:      frame
		init_fn:       my_init
		cleanup_fn:    cleanup
		event_fn:      my_event_manager
	})

	app.ticks = time.ticks() 
	app.gg.run()
}