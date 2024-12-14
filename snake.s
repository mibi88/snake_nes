; A small snake game on the NES.
; by Mibi88
;
; This software is licensed under the BSD-3-Clause license:
;
; Copyright 2024 Mibi88
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
; this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
; this list of conditions and the following disclaimer in the documentation
; and/or other materials provided with the distribution.
;
; 3. Neither the name of the copyright holder nor the names of its
; contributors may be used to endorse or promote products derived from this
; software without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.

; --- PPU REGISTERS ---
; 2000 PPUCTRL
; 2001 PPUMASK
; 2002 PPUSTATUS
; 2003 OAMADDR
; 2004 OAMDATA
; 2005 PPUSCROLL
; 2006 PPUADDR
; 2007 PPUDATA
; 4014 OAMDMA

; Sprites: Y, tile, flags, X

; Change maxticks and bytes 9 and 10 of the header to make a NTSC build.

.segment HEADER
.byte 4E
.byte 45
.byte 53
.byte 1A
.byte 01
.byte 01
.byte 00
.byte 00
.byte 00
.byte 01 ; 1 for PAL
.byte 32 ; 20 for bus conflicts, 10 for no PRG ram and 2 for PAL

.segment ZEROPAGE
.res nmi 1
.res ticks 1
.res maxticks 1
.res dir 1
.res snakelen 1
.res ctrl1 8
.res ptr 2
.res xvalue 1
.res yvalue 1
.res seed 1
.res namptr 2
.res namleft 1
.res score 8
.res lock 1
.res screen 1
.res tmp 1

.segment BSS
.res nambuffer 100

.segment STARTUP
RESET:
    SEI
    CLD
    LDA #40
    STA 4017
    LDX #FF
    TXS
    INX
    STX 2000
    STX 2001
    STX 4010
    ; Clear vblank flag
    BIT 2002
RESET_WAITVBLANK1:
    BIT 2002
    BPL RESET_WAITVBLANK1
    LDA #00
RESET_CLEARMEM:
    STA 000, X
    STA 100, X
    STA 200, X
    STA 300, X
    STA 400, X
    STA 500, X
    STA 600, X
    STA 700, X
    INX
    BNE RESET_CLEARMEM
RESET_WAITVBLANK2:
    BIT 2002
    BPL RESET_WAITVBLANK2
    TAX
    LDA #3F
    STA 2006
    STX 2006
RESET_LOADPALETTE:
    LDA PALETTE, X
    STA 2007
    INX
    CPX #20
    BNE RESET_LOADPALETTE
    ; Clear the first nametable
    LDA #20
    STA 2006
    LDA #00
    STA 2006
    TAX
RESET_LOADNAM_LOOP1:
    STA 2007
    INX
    BNE RESET_LOADNAM_LOOP1
    TAX
RESET_LOADNAM_LOOP2:
    STA 2007
    INX
    BNE RESET_LOADNAM_LOOP2
    TAX
RESET_LOADNAM_LOOP3:
    STA 2007
    INX
    BNE RESET_LOADNAM_LOOP3
    TAX
RESET_LOADNAM_LOOP4:
    STA 2007
    INX
    BNE RESET_LOADNAM_LOOP4
    ; Enable rendering
    LDA #80
    STA 2000
    LDA #18
    STA 2001
    ; Load the title text
    JSR LOAD_TITLE
    JSR LOAD_PRESS_START
    JSR LOAD_COPYRIGHT
    JSR LOAD_VERSION
    ; Set the max ticks to 0A on PAL and 0C on NTSC.
    LDA #0A
    STA maxticks
RESET_GAMELOOP:
    LDA nmi
    BEQ RESET_GAMELOOP
    LDA #00
    STA nmi
    ; Increase the seed to make the apple placement feel very random.
    INC seed
    JSR HANDLE_SCREENS
    JMP RESET_GAMELOOP

INGAME_START:
    ; Put the game in pause by stopping the snake.
    LDA #00
    STA dir
    RTS

REMOVE_SPRITES:
    LDX #00
    LDA #00
REMOVE_SPRITES_LOOP:
    STA 200, X
    INX
    BNE REMOVE_SPRITES_LOOP
    RTS

HANDLE_SCREENS:
    LDA screen
    ASL
    TAX
    LDA SCREEN_LUT, X
    STA ptr
    LDA SCREEN_LUT_HI, X
    STA ptr+1
    JSR HANDLE_SCREENS_JMP
    RTS
HANDLE_SCREENS_JMP:
    JMP (ptr)

HANDLE_TITLE:
    JSR READCTRL1
    LDA lock
    BNE HANDLE_TITLE_NOSTART
    LDA ctrl1+3
    BEQ HANDLE_TITLE_NOSTART
    ; Go back to the ingame screen
    JSR DRAW_PLAYFIELD
    JSR RESET_GAME
    LDA #01
    STA screen
HANDLE_TITLE_NOSTART:
    LDA ctrl1+3
    STA lock
    RTS

HANDLE_INGAME:
    ; Handle the input
    JSR INGAME_CTRL
    ; Update the ticks. Continue the loop if not enough time has passed.
    LDX ticks
    INX
    STX ticks
    CPX maxticks
    BNE RESET_GAMELOOP
    LDA #00
    STA ticks
    ; Display the snake
    LDA #00
    STA lock
    JSR UPDATE_SNAKE
    RTS

HANDLE_GAME_OVER:
    JSR READCTRL1
    LDA lock
    BNE HANDLE_GAME_OVER_NOSTART
    LDA ctrl1+3
    BEQ HANDLE_GAME_OVER_NOSTART
    ; Go back to the title screen
    JSR REMOVE_SPRITES
    JSR REMOVE_PLAYFIELD
    JSR LOAD_TITLE
    JSR LOAD_PRESS_START
    JSR LOAD_COPYRIGHT
    JSR LOAD_VERSION
    LDA #00
    STA screen
HANDLE_GAME_OVER_NOSTART:
    LDA ctrl1+3
    STA lock
    RTS

DRAW_PLAYFIELD:
    LDA namleft
    BNE DRAW_PLAYFIELD
    LDA #20
    STA namptr
    LDY #00
    STY namptr+1
DRAW_PLAYFIELD_YLOOP:
    LDA namleft
    BNE DRAW_PLAYFIELD_YLOOP
    LDX #00
DRAW_PLAYFIELD_XLOOP:
    ; Choose the tile depending on the position
    CPX #03
    BCC DRAW_PLAYFIELD_CLEAR
    CPX #1E
    BCS DRAW_PLAYFIELD_CLEAR
    CPY #05
    BEQ DRAW_PLAYFIELD_BORDER
    BCC DRAW_PLAYFIELD_CLEAR
    CPY #1C
    BEQ DRAW_PLAYFIELD_BORDER
    BCS DRAW_PLAYFIELD_CLEAR
    CPX #03
    BEQ DRAW_PLAYFIELD_BORDER
    CPX #1D
    BEQ DRAW_PLAYFIELD_BORDER
DRAW_PLAYFIELD_CLEAR:
    LDA #00
    JMP DRAW_PLAYFIELD_SET_TILE
DRAW_PLAYFIELD_BORDER:
    LDA #81
DRAW_PLAYFIELD_SET_TILE:
    STY tmp
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    LDY tmp
    INX
    CPX #20
    BNE DRAW_PLAYFIELD_XLOOP
    INY
    CPY #1E
    BNE DRAW_PLAYFIELD_YLOOP
    RTS

REMOVE_PLAYFIELD:
    LDA namleft
    BNE REMOVE_PLAYFIELD
    LDA #20
    STA namptr
    LDY #00
    STY namptr+1
REMOVE_PLAYFIELD_YLOOP:
    LDA namleft
    BNE REMOVE_PLAYFIELD_YLOOP
    LDX #00
    LDA #00
REMOVE_PLAYFIELD_XLOOP:
    STY tmp
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    LDY tmp
    INX
    CPX #20
    BNE REMOVE_PLAYFIELD_XLOOP
    INY
    CPY #1E
    BNE REMOVE_PLAYFIELD_YLOOP
    RTS

COLLISION_CHECK:
    ; Check if the snake is going outside of the playfield
    ; On the Y axis
    LDA 200
    CMP #2F
    BCC COLLISION_CHECK_COLLISION
    CMP #DF
    BCS COLLISION_CHECK_COLLISION
    ; On the X axis
    LDA 203
    CMP #20
    BCC COLLISION_CHECK_COLLISION
    CMP #E8
    BCS COLLISION_CHECK_COLLISION
    ; Check if the snake is colliding with itself
    LDA snakelen
    CMP #08
    BCC COLLISION_CHECK_NOCOLLISION
    LDX #04
COLLISION_CHECK_LOOP:
    LDA 200, X
    CMP 200
    BNE COLLISION_CHECK_CONTINUE
    LDA 203, X
    CMP 203
    BEQ COLLISION_CHECK_COLLISION
COLLISION_CHECK_CONTINUE:
    TXA
    CLC
    ADC #04
    TAX
    CPX snakelen
    BNE COLLISION_CHECK_LOOP
COLLISION_CHECK_NOCOLLISION:
    LDA #00
    RTS
COLLISION_CHECK_COLLISION:
    LDA #01
    RTS

RESET_GAME:
    ; Reset the score
    JSR RESET_SCORE
    ; Display the score
    JSR LOAD_SCORE
    ; Reset the direction
    LDA #00
    STA dir
    STA snakelen
    ; Initialize the snake head.
    ; Sprites are drawn 1px lower
    LDA #7F
    STA 200
    LDA #80
    STA 201
    LDA #80
    STA 203
    LDA #0C
    ; Initialize the apple
    JSR RESET_APPLE

RESET_SCORE:
    LDA #30
    LDX #00
RESET_SCORE_LOOP:
    STA score, X
    INX
    CPX #08
    BNE RESET_SCORE_LOOP
    RTS

INC_SCORE:
    LDX #07
INC_SCORE_LOOP:
    LDY score, X
    INY
    STY score, X
    CPY #3A
    BNE INC_SCORE_END
    LDA #30
    STA score, X
    DEX
    CPX #FF
    BNE INC_SCORE_LOOP
INC_SCORE_END:
    RTS

LOAD_TITLE:
    LDA namleft
    BNE LOAD_TITLE
    ; Draw it at (13;3)
    LDA #20
    STA namptr
    LDA #6D
    STA namptr+1
    LDX #00
    LDA TITLE, X
LOAD_TITLE_LOOP:
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    LDA TITLE, X
    BNE LOAD_TITLE_LOOP
    RTS

LOAD_COPYRIGHT:
    LDA namleft
    BNE LOAD_COPYRIGHT
    ; Draw it at (4;20)
    LDA #22
    STA namptr
    LDA #84
    STA namptr+1
    LDX #00
    LDA COPYRIGHT, X
LOAD_COPYRIGHT_LOOP:
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    LDA COPYRIGHT, X
    BNE LOAD_COPYRIGHT_LOOP
    RTS

LOAD_VERSION:
    LDA namleft
    BNE LOAD_VERSION
    ; Draw it at (23;20)
    LDA #22
    STA namptr
    LDA #97
    STA namptr+1
    LDX #00
    LDA VERSION, X
LOAD_VERSION_LOOP:
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    LDA VERSION, X
    BNE LOAD_VERSION_LOOP
    RTS

LOAD_PRESS_START:
    LDA namleft
    BNE LOAD_PRESS_START
    ; Draw it at (10;8)
    LDA #21
    STA namptr
    LDA #0A
    STA namptr+1
    LDX #00
    LDA PRESS_START, X
LOAD_PRESS_START_LOOP:
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    LDA PRESS_START, X
    BNE LOAD_PRESS_START_LOOP
    RTS

LOAD_GAME_OVER:
    LDA namleft
    BNE LOAD_GAME_OVER
    ; Draw it at (11;4)
    LDA #20
    STA namptr
    LDA #8B
    STA namptr+1
    LDX #00
    LDA GAME_OVER, X
LOAD_GAME_OVER_LOOP:
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    LDA GAME_OVER, X
    BNE LOAD_GAME_OVER_LOOP
    RTS

LOAD_SCORE:
    LDA namleft
    BNE LOAD_SCORE
    ; Draw it at (3;3)
    LDA #20
    STA namptr
    LDA #63
    STA namptr+1
    LDX #00
    LDA SCORE, X
LOAD_SCORE_LOOP:
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    LDA SCORE, X
    BNE LOAD_SCORE_LOOP
    ; Load the score number
    LDX #00
LOAD_SCORE_NUM_LOOP:
    LDA score, X
    LDY namleft
    STA nambuffer, Y
    INY
    STY namleft
    INX
    CPX #08
    BNE LOAD_SCORE_NUM_LOOP
    RTS

RESET_APPLE:
    JSR RAND
    AND #78
    CLC
    ADC #38
    ; Sprites are drawn 1px lower
    SEC
    SBC #01
    STA 2FC
    JSR RAND
    AND #78
    CLC
    ADC #28
    STA 2FF
    LDA #81
    STA 2FD
    RTS

RAND:
    LDX seed
    LDA RESET, X
    INX
    STX seed
    RTS

MOVE_SNAKE_POS:
    LDX snakelen
    BEQ MOVE_SNAKE_POS_SKIP
MOVE_SNAKE_POS_LOOP:
    LDA 1FC, X
    STA 200, X
    LDA #82
    STA 201, X
    LDA 1FF, X
    STA 203, X
    ; Loop if needed
    TXA
    SEC
    SBC #04
    TAX
    BNE MOVE_SNAKE_POS_LOOP
MOVE_SNAKE_POS_SKIP:
    RTS

INGAME_CTRL:
    JSR READCTRL1
    LDX #00
INGAME_CTRL_LOOP:
    LDA ctrl1, X
    BEQ INGAME_CTRL_SKIP
    TXA
    ASL
    TAY
    LDA INGAME_LUT, Y
    STA ptr
    LDA INGAME_LUT_HI, Y
    STA ptr+1
    STX xvalue
    JSR INGAME_CTRL_JMP
    LDX xvalue
    JMP INGAME_CTRL_SKIP
INGAME_CTRL_JMP:
    JMP (ptr)
INGAME_CTRL_SKIP:
    INX
    CPX #08
    BNE INGAME_CTRL_LOOP
    RTS

READCTRL1:
    LDA #01
    STA 4016
    LDA #00
    STA 4016
    LDX #00
READCTRL1_LOOP:
    LDA 4016
    AND #01
    STA ctrl1, X
    INX
    CPX #08
    BNE READCTRL1_LOOP
    RTS

UPDATE_SNAKE:
    JSR MOVE_SNAKE_POS
    LDA dir
    ASL
    TAY
    LDA 200
    CLC
    ADC MOV_Y, Y
    STA 200
    LDA 203
    CLC
    ADC MOV_X, Y
    STA 203
    ; Check for collisions
    JSR COLLISION_CHECK
    BEQ UPDATE_SNAKE_NOCOLLISION
    ; Go to the game over screen
    JSR LOAD_GAME_OVER
    LDA #02
    STA screen
UPDATE_SNAKE_NOCOLLISION:
    ; Increase the length of the snake if needed
    LDA 200
    CMP 2FC
    BNE UPDATE_SNAKE_SKIP
    LDA 203
    CMP 2FF
    BNE UPDATE_SNAKE_SKIP
    ; Increase the score
    JSR INC_SCORE
    ; Display the score
    JSR LOAD_SCORE
    ; Move the apple
    JSR RESET_APPLE
    ; Do not exceed a snake len of 5 (6*4 = 24)!
    LDA snakelen
    CMP #18
    BCS UPDATE_SNAKE_SKIP
    ; Increase the snake len
    LDA snakelen
    CLC
    ADC #04
    STA snakelen
UPDATE_SNAKE_SKIP:
    RTS

NMI:
    ; Save the registers
    PHA
    TXA
    PHA
    TYA
    PHA
    ; Read PPUSTATUS
    BIT 2002
    LDA #02
    STA 4014
    ; Skip nametable loading if needed
    LDA namleft
    BEQ NMI_SKIP_NAM_LOADING
    ; Load the nambuffer
    LDA #00
    STA 2000
    STA 2001
    ; Set the PPU address.
    LDA namptr
    STA 2006
    LDA namptr+1
    STA 2006
    ; Copy the nametable data.
    LDX #00
NMI_LOAD_LOOP:
    LDA nambuffer, X
    STA 2007
    INX
    CPX namleft
    BNE NMI_LOAD_LOOP
    ; Update the pointer and namleft
    LDA namptr+1
    CLC
    ADC namleft
    STA namptr+1
    LDA namptr
    ADC #00
    STA namptr
    LDA #00
    STA namleft
    ; Turn rendering back on
    LDA #80
    STA 2000
    LDA #18
    STA 2001
    ; Set the scrolling to zero.
    LDA #00
    STA 2005
    STA 2005
NMI_SKIP_NAM_LOADING:
    ; Set nmi to 1
    LDA #01
    STA nmi
    ; Restore registers
    PLA
    TAY
    PLA
    TAX
    PLA
    ; Return from the interrupt
    RTI

IRQ:
    RTI

INGAME_LEFT:
    ; If the player already changed direction, ignore this button press
    LDA lock
    BNE INGAME_LEFT_SKIP
    ; Keep the player from going in the opposite direction
    LDA dir
    CMP #02
    BEQ INGAME_LEFT_SKIP
    ; Set the new direction
    LDA #01
    STA dir
    STA lock
INGAME_LEFT_SKIP:
    RTS

INGAME_RIGHT:
    ; If the player already changed direction, ignore this button press
    LDA lock
    BNE INGAME_RIGHT_SKIP
    ; Keep the player from going in the opposite direction
    LDA dir
    CMP #01
    BEQ INGAME_RIGHT_SKIP
    ; Set the new direction
    LDA #02
    STA dir
    STA lock
INGAME_RIGHT_SKIP:
    RTS

INGAME_UP:
    ; If the player already changed direction, ignore this button press
    LDA lock
    BNE INGAME_UP_SKIP
    ; Keep the player from going in the opposite direction
    LDA dir
    CMP #04
    BEQ INGAME_UP_SKIP
    ; Set the new direction
    LDA #03
    STA dir
    STA lock
INGAME_UP_SKIP:
    RTS

INGAME_DOWN:
    ; If the player already changed direction, ignore this button press
    LDA lock
    BNE INGAME_DOWN_SKIP
    ; Keep the player from going in the opposite direction
    LDA dir
    CMP #03
    BEQ INGAME_DOWN_SKIP
    ; Set the new direction
    LDA #04
    STA dir
    STA lock
INGAME_DOWN_SKIP:
    RTS

SUB_NONE:
    RTS

INGAME_LUT:
    .byte <SUB_NONE
INGAME_LUT_HI:
    .byte >SUB_NONE
    .byte <SUB_NONE
    .byte >SUB_NONE
    .byte <SUB_NONE
    .byte >SUB_NONE
    .byte <INGAME_START
    .byte >INGAME_START
    .byte <INGAME_UP
    .byte >INGAME_UP
    .byte <INGAME_DOWN
    .byte >INGAME_DOWN
    .byte <INGAME_LEFT
    .byte >INGAME_LEFT
    .byte <INGAME_RIGHT
    .byte >INGAME_RIGHT

SCREEN_LUT:
    .byte <HANDLE_TITLE
SCREEN_LUT_HI:
    .byte >HANDLE_TITLE
    .byte <HANDLE_INGAME
    .byte >HANDLE_INGAME
    .byte <HANDLE_GAME_OVER
    .byte >HANDLE_GAME_OVER

MOV_X:
    .byte 00 ; Do not move
MOV_Y:
    .byte 00
    .byte F8 ; Move to the left
    .byte 00
    .byte 08 ; Move to the right
    .byte 00
    .byte 00 ; Move up
    .byte F8
    .byte 00 ; Move down
    .byte 08


PALETTE:
    ; Palette 1
    .byte 1D
    .byte 00
    .byte 10
    .byte 20
    ; Palette 2
    .byte 1D
    .byte 00
    .byte 10
    .byte 20
    ; Palette 3
    .byte 1D
    .byte 00
    .byte 10
    .byte 20
    ; Palette 4
    .byte 1D
    .byte 00
    .byte 10
    .byte 20
    ; Palette 1
    .byte 1D
    .byte 0A
    .byte 16
    .byte 1A
    ; Palette 2
    .byte 1D
    .byte 00
    .byte 10
    .byte 20
    ; Palette 3
    .byte 1D
    .byte 00
    .byte 10
    .byte 20
    ; Palette 4
    .byte 1D
    .byte 00
    .byte 10
    .byte 20

; Some strings
; "SNAKE"
TITLE:
    .byte 53
    .byte 4E
    .byte 41
    .byte 4B
    .byte 45
    .byte 00

; "Press START"
PRESS_START:
    .byte 50
    .byte 72
    .byte 65
    .byte 73
    .byte 73
    .byte 20
    .byte 53
    .byte 54
    .byte 41
    .byte 52
    .byte 54
    .byte 00

; "GAME OVER"
GAME_OVER:
    .byte 47
    .byte 41
    .byte 4D
    .byte 45
    .byte 20
    .byte 4F
    .byte 56
    .byte 45
    .byte 52
    .byte 00

; "Score: "
SCORE:
    .byte 53
    .byte 63
    .byte 6F
    .byte 72
    .byte 65
    .byte 3A
    .byte 20
    .byte 00

; "(c) Mibi88"
COPYRIGHT:
    .byte 28
    .byte 63
    .byte 29
    .byte 20
    .byte 4D
    .byte 69
    .byte 62
    .byte 69
    .byte 38
    .byte 38
    .byte 00

; "v.1.1"
VERSION:
    .byte 76
    .byte 2E
    .byte 31
    .byte 2E
    .byte 31
    .byte 00

.segment VECTORS
.byte <NMI ; Get the low byte
.byte >NMI ; Get the high byte
.byte <RESET
.byte >RESET
.byte <IRQ
.byte >IRQ
