// 8 byte tiles, monochrome, reverse rows

MonoTiles:

Tile_ArrowDown:
#incbin "arrowdown.imgbin"

Tile_ArrowLeft:
#incbin "arrowleft.imgbin"

Tile_ArrowRight:
#incbin "arrowright.imgbin"

Tile_ArrowUp:
#incbin "arrowup.imgbin"

Tile_FringeBot:
#incbin "fringebot.imgbin"

Tile_FringeLeft:
#incbin "fringeleft.imgbin"

Tile_FringeRight:
#incbin "fringeright.imgbin"

Tile_FringeTop:
#incbin "fringetop.imgbin"

Tile_LineCorners:
#incbin "linebotleft.imgbin"
#incbin "linebotright.imgbin"
#incbin "linetopleft.imgbin"
#incbin "linetopright.imgbin"

Tile_HLine:
#incbin "lineh.imgbin"

Tile_VLine:
#incbin "linev.imgbin"

Tile_LoopLeft:
#incbin "loopleft.imgbin"

Tile_LoopRight:
#incbin "loopright.imgbin"

Tile_LoopUp:
#incbin "loopup.imgbin"

Tile_LoopDown:
#incbin "loopdown.imgbin"

Tile_Cmds:
byte Tile_Clear[8] = {0,0,0,0,0,0,0,0}  // 0, no command, clear
Tile_CmdAlpha:
#incbin "cmd_alpha.imgbin"  // 1
#incbin "cmd_beta.imgbin"   // 2
#incbin "cmd_bondadd.imgbin"// 3
#incbin "cmd_bondsub.imgbin"// 4
#incbin "cmd_d.imgbin"      // 5
#incbin "cmd_ff.imgbin"     // 6
#incbin "cmd_gd.imgbin"     // 7
#incbin "cmd_g.imgbin"      // 8
#incbin "cmd_omega.imgbin"  // 9
#incbin "cmd_psi.imgbin"    // 10
#incbin "cmd_start.imgbin"  // 11

Tile_Elements:
struct Tile_Elements_s
{
#incbin "element_H.imgbin"  // 1
#incbin "element_He.imgbin" // 2
#incbin "element_Li.imgbin" // 3
#incbin "element_Be.imgbin" // 4
#incbin "element_B.imgbin"  // 5
#incbin "element_C.imgbin"  // 6
#incbin "element_N.imgbin"  // 7
#incbin "element_O.imgbin"  // 8
#incbin "element_F.imgbin"  // 9
#incbin "element_Ne.imgbin" // 10
}

Tile_Cursor_TopLeft:
#incbin "cursor_topleft.imgbin"
Tile_Cursor_TopRight_BotLeft:
#incbin "cursor_topright_botleft.imgbin"
Tile_Cursor_BotRight:
#incbin "cursor_botright.imgbin"

Tile_BG:
Tile_Grid:
Tile_Grid0:
#incbin "grid0.imgbin"
Tile_Grid1:
#incbin "grid1.imgbin"
Tile_Grid2:
#incbin "grid2.imgbin"
Tile_Grid3:
#incbin "grid3.imgbin"

Tile_Grid_Edge_Bot:
#incbin "grid_edge_bot.imgbin"
Tile_Grid_Edge_Right:
#incbin "grid_edge_right.imgbin"
