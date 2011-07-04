#ram.org 0x0, 0x30

pointer tmp_addr
byte    tmp_byte
byte    tmp_byte2
byte    tmp_byte3

// only used by NMI after init
shared byte _ppu_ctl0, _ppu_ctl1

// only set by NMI after init
shared byte _joypad0

struct hold_count_joypad0
{
    byte RIGHT, LEFT, DOWN, UP, START, SELECT, A, B
}
struct repeat_count_joypad0
{
    byte RIGHT, LEFT, DOWN, UP, START, SELECT, A, B
}

// main thread input tracking
byte last_joypad0
byte new_joypad0
byte cursor_x, cursor_y
byte current_command
pointer current_command_tile

byte cursor_x_limit_flag, cursor_y_limit_flag 
#ram.end

// fixed pattern setup
#ram.org 0x30, 0x10
byte tile_buf_1[8]
byte tile_buf_0[8]
#ram.end

// playfield tile update locals
#ram.org 0x30, 0x10
byte TU_buf_saved
byte TU_playfield_offset    // set for 1 and 2
byte TU_playfield_flags1    // set for 0 and 3 lines
byte TU_playfield_flags2    // set for 0 and 3 lines
byte TU_x
byte TU_y
#ram.end

// shared pattern staging area
#ram.org 0x40, 144
shared word TS_addr[TS_SIZE]
typedef struct TS_s {
    byte bit1[8]
    byte bit0[8]
}
shared TS_s TS_buf[TS_SIZE]

#ram.end

#ram.org 0x200, 0x100
OAM_ENTRY oam_buf[64]
#ram.end

#ram.org 0x300, 0x10

byte TS_next_index
byte TS_written // 0: nmi needs to write to ppu, nonzero: main thread is writing (must be absolute)

byte oam_ready  // nonzero: nmi needs to do OAM DMA

byte current_color

#ram.end


// blue playfield
#ram.org 0x310, 0xF0

// what display elements are displayed in each cell
// columns first to compute easier
byte playfield_blue_flags1[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]

byte playfield_blue_flags2[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]

// command in each cell
byte playfield_blue_cmd[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
#ram.end

// start state
#ram.org 0x400, 0x10
byte blue_start_x
byte blue_start_y
byte blue_start_dir

byte red_start_x
byte red_start_y
byte red_start_dir
#ram.end

// red playfield
#ram.org 0x410, 0xF0

byte playfield_red_flags1[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
byte playfield_red_flags2[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
byte playfield_red_cmd[PLAYFIELD_HEIGHT*PLAYFIELD_WIDTH]
#ram.end

// path stack
#ram.org 0x500, 0x100
// it is major overkill to reserve all this, but it is only used by one
// operation so we can reuse it for other large ops
byte render_path_stack[0xFF]
byte render_path_stack_pointer :0x5FF
#ram.end
