;  Copyright 2022, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


            ; Include kernal API entry points

include     include/bios.inc
include     include/kernel.inc


            ; VDP port assignments

#define     VDPREG 5
#define     VDPRAM 1

#define     RDRAM 00h
#define     WRRAM 40h
#define     WRREG 80h

#define     null 0

            ; table constants and locations

rows:       equ 24
cols:       equ 40

patterns:   equ 3800h
names:      equ 3c00h


            ; Executable program header

            org   2000h - 6
            dw    start
            dw    end-start
            dw    start

start:      org   2000h
            br    main


            ; Build information

            db    3+80h                 ; month
            db    6                     ; day
            dw    2022                  ; year
            dw    1                     ; build

            db    'See github.com/dmadole/Elfos-video for more info',0


            ; Check minimum kernel version we need before doing anything else,
            ; in particular we need support for the heap manager to allocate
            ; memory for the persistent module to use.

main:       ldi   high k_ver            ; get pointer to kernel version
            phi   r7
            ldi   low k_ver
            plo   r7

            lda   r7                    ; if major is non-zero we are good
            lbnz  allocmem

            lda   r7                    ; if major is zero and minor is 4
            smi   4                     ;  or higher we are good
            lbdf  allocmem

            sep   scall                 ; if not meeting minimum version
            dw    o_inmsg
            db    'ERROR: Needs kernel version 0.4.0 or higher',13,10,0

            sep   sret


            ; Allocate memory from the heap for the driver code block, leaving
            ; address of block in register R8 and RF for copying code and
            ; hooking vectors and the length of code to copy in RB.

allocmem:   ldi   high (end-module)     ; size of permanent code module
            phi   rb
            phi   rc
            ldi   low (end-module)
            plo   rb
            plo   rc

            ldi   255                   ; request page-aligned block
            phi   r7
            ldi   4 + 64                ; request permanent + named block
            plo   r7

            sep   scall                 ; allocate block on heap
            dw    o_alloc
            lbnf  copycode

            sep   scall                 ; if unable to get memory
            dw    o_inmsg
            db    'ERROR: Unable to allocate heap memory',13,10,0

            sep   sret


            ; Copy the code of the persistent module to the memory block that
            ; was just allocated using RF for destination and RB for length.
            ; This burns RF and RB but R8 will still point to the block.

copycode:   ldi   high module           ; get source address to copy from
            phi   rd
            ldi   low module
            plo   rd

            glo   rf                    ; make a copy of block pointer
            plo   r8
            ghi   rf
            phi   r8

copyloop:   lda   rd                    ; copy code to destination address
            str   rf
            inc   rf
            dec   rc
            dec   rb
            glo   rb
            lbnz  copyloop
            ghi   rb
            lbnz  copyloop

            ghi   r8                    ; put offset between source and
            smi   high module           ;  destination onto stack
            str   r2

            lbr   padname


            ; Pad name with zeroes to end of block.

padloop:    ldi   0                     ; pad name with zeros to end of block
            str   rf
            inc   rf
            dec   rc
padname:    glo   rc
            lbnz  padloop
            ghi   rc
            lbnz  padloop


            ; Update kernel hooks to point to our module code. Use the offset
            ; to the heap block at M(R2) to update module addresses to match
            ; the copy in the heap. If there is a chain address needed for a
            ; hook, copy that to the module first in the same way.

            ldi   high patchtbl         ; Get point to table of patch points
            phi   r7
            ldi   low patchtbl
            plo   r7

ptchloop:   lda   r7                    ; get address to patch, a zero
            lbz   inivideo              ;  msb marks end of the table
            phi   rd
            lda   r7
            plo   rd
            inc   rd

notchain:   lda   r7                    ; get module call point, adjust to
            add                         ;  heap, and update into vector jump
            str   rd
            inc   rd
            lda   r7
            str   rd

            lbr   ptchloop


            ; copy packed font bitmaps into pattern space

inivideo:   sex   r3

            out   VDPREG                ; set the 16K bit in the vdp before
            db    080h                  ;  trying to write to memory
            out   VDPREG
            db    WRREG + 1

            ghi   r8
            adi   1
            phi   r7

            sep   scall
            dw    clsin

            sex   r3

            out   VDPREG                ; setup write to pattern table memory
            db    low (patterns+32*8)
            out   VDPREG
            db    WRRAM + high (patterns+32*8)

            sex   r2

            ldi   low fontdata          ; get pointer to packed font table
            plo   r7
            ldi   high fontdata
            phi   r7

            ldi   96                    ; number of character patterns to load
            plo   r9

            ldi   80h                   ; pre-set df flag to count input bits
            plo   r8

charloop:   ldi   7                     ; number of used rows per character
            plo   ra

byteloop:   ldi   08h                   ; pre-set df flag to count output bits

bitloop:    phi   r8                    ; process an input bit
            glo   r8
            shl
            lbnz  bitcopy

            lda   r7                    ; all bits shifted, get next byte
            shlc

bitcopy:    plo   r8                    ; process an output bit
            ghi   r8
            shlc
            lbnf  bitloop

            shl                         ; all bits shifted, now left-justify
            shl
            shl

            str   r2                    ; output pattern to vdp memory
            out   VDPRAM
            dec   r2

            dec   ra                    ; count character patten rows
            glo   ra
            lbnz  byteloop

            str   r2                    ; if 7 rows stored, add a zero row
            out   VDPRAM
            dec   r2

            dec   r9                    ; count 96 characters to load
            glo   r9
            lbnz  charloop


            ; All done installing driver and initializing VDP name and pattern
            ; memory. Set VDP registers appropriately, output a hello message
            ; and return to operating system.

            sep   scall                 ; setup vdp registers
            dw    init

            sep   scall                 ; display identity to indicate success
            dw    o_inmsg
            db    '9918 Video Driver Build 1 for Elf/OS',13,10,0

            sep   r5


            ; Table giving addresses of jump vectors we need to update to
            ; point to us instead, and what to point them to. The patching
            ; code adjusts the target address to the heap memory block.

patchtbl:   dw    o_type, type
            dw    o_tty, type
            dw    o_msg, msg
            dw    o_inmsg, inmsg
            dw    o_readkey, read
            dw    o_input, input
            dw    o_inputl, inputl
            db    null


            ; This is a packed representation of the font, read as a
            ; continuous bitstream MSB to LSB, and broken into 5-bit chunks
            ; representing the rows of the pattern definition. Every 7 rows
            ; a blank row gets inserted also. This way only the 35 live
            ; bits for each character are actually stored with no waste.

fontdata:   db    0h,0h,0h,0h,4h,21h,8h,40h,11h,4ah,50h,0h,0h,29h
            db    5fh,57h,0d4h,0a2h,3eh,8eh,2fh,89h,8ch,88h,88h,98h
            db    0d9h,2ah,22h,0b2h,6bh,8h,80h,0h,0h,11h,10h,84h,10h
            db    48h,20h,84h,22h,20h,4h,0abh,0aah,40h,0h,84h,0f9h
            db    8h,0h,0h,0h,61h,10h,0h,3h,0e0h,0h,0h,0h,0h,0ch,60h
            db    2h,22h,22h,0h,74h,67h,5ch,0c5h,0c4h,61h,8h,42h,39h
            db    0d1h,8h,88h,8fh,0fch,44h,10h,62h,0e1h,19h,52h,0f8h
            db    85h,0f8h,78h,21h,8bh,8ch,88h,7ah,31h,77h,0c2h,22h
            db    21h,8h,74h,62h,0e8h,0c5h,0ceh,8ch,5eh,11h,30h,0ch
            db    60h,18h,0c0h,1h,8ch,3h,8h,81h,11h,10h,41h,4h,0h
            db    7ch,1fh,0h,10h,41h,4h,44h,43h,0a2h,11h,10h,4h,74h
            db    42h,0dah,0d5h,0c4h,52h,0a3h,0f8h,0c7h,0d1h,8fh,0a3h
            db    1fh,3ah,30h,84h,22h,0eeh,4ah,31h,8ch,0b9h,0f8h,43h
            db    0d0h,87h,0ffh,8h,7ah,10h,83h,0a3h,0bh,0c6h,2eh,8ch
            db    63h,0f8h,0c6h,2eh,21h,8h,42h,38h,0e2h,10h,85h,26h
            db    46h,54h,0c5h,25h,18h,42h,10h,84h,3fh,1dh,0d6h,0b1h
            db    8ch,63h,1ch,0d6h,71h,8bh,0a3h,18h,0c6h,2eh,0f4h
            db    63h,0e8h,42h,0eh,8ch,63h,59h,37h,0d1h,8fh,0a9h,28h
            db    0beh,10h,70h,43h,0efh,90h,84h,21h,9h,18h,0c6h,31h
            db    8bh,0a3h,18h,0a9h,4ah,24h,63h,1ah,0d6h,0aah,8ch
            db    54h,45h,46h,31h,8ch,54h,42h,13h,0e1h,11h,11h,0fh
            db    0b9h,8h,42h,10h,0e0h,41h,4h,10h,40h,0e1h,8h,42h
            db    13h,88h,0a8h,80h,0h,0h,0h,0h,0h,1fh,41h,4h,0h,0h
            db    0h,3h,82h,0f8h,0beh,10h,0b6h,63h,1fh,0h,0eh,84h
            db    22h,0e0h,85h,0b3h,8ch,5eh,0h,3ah,3fh,83h,8ch,94h
            db    71h,8h,40h,0h,0f8h,0bch,2eh,84h,2dh,98h,0c6h,24h
            db    3h,8h,42h,38h,40h,30h,85h,26h,42h,12h,0a6h,29h,26h
            db    10h,84h,21h,1ch,0h,6ah,0b5h,8ch,40h,0bh,66h,31h
            db    88h,0h,0e8h,0c6h,2eh,0h,3dh,1fh,42h,0h,3h,0e2h,0f0h
            db    84h,0h,0b6h,61h,8h,0h,0eh,83h,82h,0e4h,23h,88h,42h
            db    4ch,0h,46h,31h,9bh,40h,8h,0c6h,2ah,20h,1h,18h,0d6h
            db    0aah,0h,22h,0a2h,2ah,20h,4h,62h,0f0h,0b8h,0h,0f8h
            db    88h,8fh,88h,84h,41h,8h,22h,10h,84h,21h,8h,82h,10h
            db    44h,22h,0h,6h,0c8h,0h,7h,0ffh,0ffh,0ffh,0ffh


            ; Code from this point gets put into the resident driver in a
            ; heap block. Since the address of this block cannot be known,
            ; the code is written to be relocatable, so start at a new page.

            org     (($ + 0ffh) & 0ff00h)

module:     ; Initialize text mode screen. This sets the VDP registers and
            ; loads the character set into the patten memory, and then falls
            ; through to the clear screen code which clears name  memory and
            ; initializes variables.

init:       sex   r3

            out   VDPREG
            db    0h                    ; m3=0, external=0
            out   VDPREG
            db    WRREG + 0

            out   VDPREG
            db    0d0h                  ; 16k=1, blank=1, m1=1, m2=0
            out   VDPREG
            db    WRREG + 1

            out   VDPREG
            db    names >> 10           ; name table address
            out   VDPREG
            db    WRREG + 2

            out   VDPREG
            db    patterns >> 11        ; pattern attribute address
            out   VDPREG
            db    WRREG + 4

            out   VDPREG 
            db    0f4h                  ; text and background color
            out   VDPREG
            db    WRREG + 7

            sep   r5


            ; clear name table

cls:        ghi   r3
            adi   1
            phi   r7

clsin:      sex   r7

            ldi   low column
            plo   r7

            ldi   0
            str   r7
            inc   r7

            ldi   low names
            str   r7
            out   VDPREG

            ldi   WRRAM + high names
            str   r7
            out   VDPREG

            ldi   32
            str   r7
            inc   r7

            out   VDPRAM
            dec   r7
            dec   r7

            ldi   25*40/4
            lskp

clsloop:    out   VDPRAM
            dec   r7
            out   VDPRAM
            dec   r7
            out   VDPRAM
            dec   r7
            out   VDPRAM
            dec   r7

            smi   1
            bnz   clsloop

            sep   r5

            ;

msg:        glo   r8
            stxd

            ldi   msgstr
            br    push

inmsg:      glo   r8
            stxd

            ldi   inmsgstr

push:       plo   r8

            ghi   r8
            stxd
            glo   r7
            stxd
            ghi   r7
            stxd

            ghi   r3
            adi   1
            phi   r7
            adi   1
            phi   r8

            sex   r7

            glo   r8
            plo   r3

msglp:      plo   re
            sep   r8

msgstr:     ldi   low typesep
            plo   r8

            lda   rf
            bnz   msglp

            br    return

inmsglp:    plo   re
            sep   r8

inmsgstr:   ldi   low typesep
            plo   r8

            lda   r6
            bnz   inmsglp

return:     inc   r2
            lda   r2
            phi   r7
            lda   r2
            plo   r7
            lda   r2
            phi   r8
            ldn   r2
            plo   r8

            sep   r5



            org     (($ + 0ffh) & 0ff00h)

            ; The first byte is the scan code, if the high bit is set then
            ; it is an extended code that was prefixed with an E0 code.
            ; Following is the corresponding ASCII character, but if the high
            ; bit is set, then another character follows which should be used
            ; instead if shift is pressed.

keytable:   db          0dh, 09h
            db          0eh, '`' + 80h, '~'
            db          15h, 'q' + 80h, 'Q'
            db          16h, '1' + 80h, '!'
            db          1ah, 'z' + 80h, 'Z'
            db          1bh, 's' + 80h, 'S'
            db          1ch, 'a' + 80h, 'A'
            db          1dh, 'w' + 80h, 'W'
            db          1eh, '2' + 80h, '@'
            db          21h, 'c' + 80h, 'C'
            db          22h, 'x' + 80h, 'X'
            db          23h, 'd' + 80h, 'D'
            db          24h, 'e' + 80h, 'E'
            db          25h, '4' + 80h, '$'
            db          26h, '3' + 80h, '^'
            db          29h, ' '
            db          2ah, 'v' + 80h, 'V'
            db          2bh, 'f' + 80h, 'F'
            db          2ch, 't' + 80h, 'T'
            db          2dh, 'r' + 80h, 'R'
            db          2eh, '5' + 80h, '%'
            db          31h, 'n' + 80h, 'N'
            db          32h, 'b' + 80h, 'B'
            db          33h, 'h' + 80h, 'H'
            db          34h, 'g' + 80h, 'G'
            db          35h, 'y' + 80h, 'Y'
            db          36h, '6' + 80h, '^'
            db          3ah, 'm' + 80h, 'M'
            db          3bh, 'j' + 80h, 'J'
            db          3ch, 'u' + 80h, 'U'
            db          3dh, '7' + 80h, '&'
            db          3eh, '8' + 80h, '*'
            db          41h, ',' + 80h, '<'
            db          42h, 'k' + 80h, 'K'
            db          43h, 'i' + 80h, 'I'
            db          44h, 'o' + 80h, 'O'
            db          45h, '0' + 80h, ')'
            db          46h, '9' + 80h, '('
            db          49h, '.' + 80h, '>'
            db          4ah, '/' + 80h, '?'
            db          4bh, 'l' + 80h, 'L'
            db          4ch, ';' + 80h, ':'
            db          4dh, 'p' + 80h, 'P'
            db          4eh, '-' + 80h, '_'
            db          52h, "'" + 80h, '"'
            db          54h, '[' + 80h, '{'
            db          55h, '=' + 80h, '+'
            db          5ah, 0dh
            db          5bh, ']' + 80h, '}'
            db          5dh, '\' + 80h, '|'
            db          66h, 08h
            db    80h + 6bh, 08h
            db    80h + 72h, 0ah
            db    80h + 74h, 0ch
            db    80h + 75h, 0bh
            db          76h, 1bh

            db    0


            ; Variables used by type

column:     db    0                     ; how many characters left in line
cursor:     db    0                     ; address of the cursor in vram
            db    0                     ;  set memory write command bit
            db    0                     ; scratch space to hold output byte
            db    127                   ; cursor character


            ; Variables used by read

flags:      db    0
state:      db    0

            ; Memory area to store and manipulate VRAM addresses to output
            ; to the VDP register port. Since the output has to happen from
            ; memory, it is cleaner and simpler to keep these in memory rather
            ; than a register.

srcaddr:    ds    2
dstaddr:    ds    2


            ; This buffer is used for scrolling and needs to be at the end of
            ; the same page as the scroll routine since the rollover of the LSB
            ; to 00 is used to check for the end of the buffer so we don't
            ; need a separate counter.

            org     (($ + 0ffh + 40) & 0ff00h) - 40

buffer:     ds    40


            ; Start new page for more code.

            org     (($ + 0ffh) & 0ff00h)

typejmp:    phi   r3
            br    typesep


            ; This is the output routine that will get hooked into o_type
            ; to handle output of single characters. This is a "dual call"
            ; routine that can be called at _type_ via SCALL or at _typesep_
            ; via SEP; when calling via SEP it is assumed that R7 has been
            ; setup appropriately, to save the overhead in repeated calls.

type:       glo   r7                    ; r7 is used as pointer to data
            stxd                        ;  variables throughout, so save it
            ghi   r7
            stxd

            ghi   r3                    ; setup r7.1 to point to page before
            smi   1                     ;  this where data bytes are stored
            phi   r7

typesep:    sex   r7                    ; r7 will point to most data we use

            ldi   low cursor            ; point r7 to cursor location
            plo   r7

            glo   re                    ; get character

            smi   32                    ; if printable characters, display
            bdf   typepr

            adi   32-13                 ; if carriage return, move cursor
            bz    typecr

            adi   13-10                 ; if line feed, move cursor
            bz    typelf

            adi   10-8                  ; if backspace, move cursor
            bz    typebs

typeret:    sep   r3                    ; return if called via sep

            inc   r2                    ; restore saved r7 from stack
            lda   r2
            phi   r7
            ldn   r2
            plo   r7

            glo   re                    ; restore character and return
            sep   r5                    ;  if called via scall


            ; Output printable character to screen, advance cursor, and
            ; if at end of the screen, then scroll up.

typepr:     out   VDPREG                ; output cursor address to vdp
            out   VDPREG

            glo   re                    ; write character to vdp memory
            str   r7
            out   VDPRAM

            ldi   low column            ; point to column variable
            plo   r7

            ldn   r7                    ; if column number is 39, wrap to
            smi   39                    ;  zero, otherwise add one
            lsz
            adi   40
            str   r7

            inc   r7                    ; point to cursor address

            lda   r7                    ; if cursor is at last position of
            smi   low (names+959)       ;  screen, then go and scroll up
            ldn   r7
            smbi  WRRAM + high (names+959)
            bdf   scrollcr

            dec   r7                    ; otherwise, advance cursor by
            ldn   r7                    ;  one location
            adi   1
            str   r7
            inc   r7
            ldn   r7
            adci  0
            str   r7

            br    typeret


            ; Perform carriage return by moving cursor to beginning of the
            ; current display line.

typecr:     dec   r7                    ; point to column number

            lda   r7                    ; subtract column number from the
            sd                          ;  cursor position
            str   r7
            inc   r7
            ldn   r7
            smbi  0
            str   r7

            dec   r7                    ; move back to column number and
            dec   r7                    ;  reset to zero
            ldi   0
            str   r7

            br   typeret


            ; Perform line feed by moving cursor down one line, unless
            ; already on the last line, then scroll.

typelf:     lda   r7                    ; if cursor is on last line, just
            smi   low (names+920)       ;  scroll content up one line
            ldn   r7
            smbi  WRRAM + high (names+920)
            bdf   scroll

            dec   r7                    ; otherwise, add 40 to cursor position
            ldn   r7                    ;  to move down by one line
            adi   40
            str   r7
            inc   r7
            ldn   r7
            adci  0
            str   r7

            br   typeret


            ; Perform backspace by moving cursor one byte backwards, unless
            ; we are already at the start of the screen.

typebs:     lda   r7                    ; if in first position of screeen,
            smi   low (names+1)         ;  then just return
            ldn   r7
            smbi  WRRAM + high (names+1)
            bnf   typeret

            dec   r7                    ; move to column pointer
            dec   r7

            ldn   r7                    ; if column is zero then set to 39,
            lsnz                        ;  otherwise subtract one
            ldi   40
            smi   1
            str   r7
            inc   r7

            ldn   r7                    ; subtract one from cursor position
            smi   1
            str   r7
            inc   r7
            ldn   r7
            smbi  0
            str   r7

            br   typeret


            ; Scroll the screen up by copying one line at a time from VRAM
            ; to RAM and back as a compromise between the inefficiency of
            ; copying directly from VRAM to VRAM or the memory consumption
            ; of a full screen-sized buffer.

scrollcr:   ldi   WRRAM + high (names+920)
            stxd
            ldi   low (names+920)       ; move cursor to start of last line
            str   r7

scroll:     ldi   low (dstaddr+1)       ; point to cursor location addresses
            plo   r7

            ldi   WRRAM + high (names-40)
            stxd
            ldi   low (names-40)        ; set destination to -1 line for write
            stxd

            ldi   high names            ; set source to first line for read
            stxd                        ;  and leave r7 pointing to address
            ldi   low names
            str   r7

scrollln:   ldn   r7                    ; advance source address by one line
            adi   40                    ;  and load new address into vdp for
            str   r7                    ;  read
            out   VDPREG
            ldn   r7
            adci  0
            str   r7
            out   VDPREG

            ldi   low buffer            ; repoint r7 to bounce buffer
            plo   r7

scrollrd:   inp   VDPRAM                ; fill buffer from display memeory
            inc   r7
            glo   r7
            bnz   scrollrd

            dec   r7                    ; move pointer back to right page
            ldi   low dstaddr           ;  then point to destinaton address
            plo   r7

            ldn   r7                    ; advance destination address by 
            adi   40                    ;  one line and load into vdp for
            str   r7                    ;  write
            out   VDPREG
            ldn   r7
            adci  0
            str   r7
            out   VDPREG

            ldi   low buffer            ; repoint r7 to bounce buffer
            plo   r7

scrollwr:   out   VDPRAM                ; write buffer to display memory
            glo   r7
            bnz   scrollwr

            dec   r7                    ; repoint r7 to source address
            ldi   low srcaddr
            plo   r7

            ldn   r7                    ; if whole screen not done then
            smi   low 24*40             ;  scroll another line
            bnz   scrollln

            br    typeret


            org   (($ + 0ffh) & 0ff00h)


            ; Input byte from keyboard

readjmp:    phi   r3
            br    readsep

read:       glo   r7
            stxd
            ghi   r7
            stxd
 
            ghi   r3
            smi   2
            phi   r7

            sex   r7

readsep:    ldi   low cursor
            plo   r7

            out   VDPREG
            lda   r7
            ani   WRRAM ^ 0ffh
            str   r7
            out   VDPREG
            dec   r7
            inp   VDPRAM

            ldi   low cursor
            plo   r7

            out   VDPREG
            out   VDPREG
            inc   r7
            out   VDPRAM

discard:    ldi   low flags
            plo   r7

            lda   r7                    ; get working copy of flags into re.0
            plo   re                    ;  and advance r7 to state

keyloop:    ldi   0                     ; clear states -
            str   r2                    ;  extended code (e0 xx) flag
            str   r7                    ;  key up or down status


            ; Get scan code from keyboard

getcode:    ldi   0ffh                  ; fill input byte to count data bits
            seq                         ;  enable sender by raising block line
            br    ps2loop               ;  and go receive data bits

ps2zero:    seq                         ; switch back to clock line,
            bn2   $                     ;  wait until clock goes high

            shr                         ; shift in a zero bit,
            bnf   ps2done               ;  done if 8 bits have been received

ps2loop:    b2    $                     ; wait for clock to go low

            req                         ; switch to sampling data line,
            bn2   ps2zero               ;  jump based on data line state

            seq                         ; switch back to clock line,
            bn2   $                     ;  wait until clock goes high

            shrc                        ; shift in a one bit,
            bdf   ps2loop               ;  loop until 8 bits have been received

ps2done:    b2    $                     ; wait a clock pulse
            bn2   $                     ;  to discard the parity bit

            b2    $                     ; wait until stop bit
            bn2   $
            req                         ;  drop clock line to disable sender


            ; Check if code is a prefix signifying a key up event or an
            ; extended scan code following. If so, set appropriate flags
            ; and get next scan code.

            xri   0f0h                  ; f0 code indicates key-up event
            bnz   notkeyup

            ldi   255                   ; set all bits in flag, get next code
            str   r7
            br    getcode

notkeyup:   xri   0e0h ^ 0f0h           ; e0 code if prefix for extended codes
            bnz   notextnd

            ldi   128                   ; set high bit for keycode result
            str   r2
            br    getcode


            ; End of prefix processing, now merge the extended code bit into
            ; final received code, setting the high bit for extended codes.

notextnd:   xri   0e0h                  ; recover original key code and or in
            sex   r2                    ;  the extended code flag if set
            or
            str   r2
            sex   r7


            ; Check for modifier keys and set flag bit based on key up or
            ; down event status. Left and right keys need to be tracked
            ; separately in case both are pressed. Note that caps is handled
            ; differently later since only key down events are needed for it.

chklshft:   xri   12h                   ; check for left shift key event
            bnz   chkrshft

            glo   re                    ; set bit 0 in re.0 to key up or down
            xor                         ;  status from m(r7)
            ori   1
            br    setflags

chkrshft:   xri   59h ^ 12h             ; check for right shift key event
            bnz   chklctrl

            glo   re                    ; set bit 1 in re.0 to key up or down
            xor                         ;  status from m(r7)
            ori   2
            br    setflags

chklctrl:   xri   14h ^ 59h             ; check for left control key event
            bnz   chkrctrl

            glo   re                    ; set bit 2 in re.0 to key up or down
            xor                         ;  status from m(r7)
            ori   4
            br    setflags

chkrctrl:   xri   94h ^ 14h             ; check for right control key event
            bnz   endmodif

            glo   re                    ; set bit 3 in re.0 to key up or down
            xor                         ;  status from m(r7)
            ori   8

setflags:   xor
            plo   re
            br    keyloop


            ; All modifier keys that we are interested in have already been
            ; checked, so ignore any other key-up events. Check the caps lock
            ; key as a key-down event only.

endmodif:   ldn   r7                    ; if key-up flag is set, discard code
            bnz   keyloop

            ldn   r2                    ; recover key code and check if caps
            xri   58h
            bnz   dolookup

            glo   re                    ; toggle the caps bit in flags in re.0
            xri   16
            plo   re
            br    keyloop


            ; Lookup the keycode in the table of translations to ASCII. Any
            ; extended codes will have their own entry, and codes with a
            ; different value when shifted will have two data values.

dolookup:   glo   re                    ; update modifier flags into memory
            dec   r7                    ;  byte so they survive across calls
            str   r7

            ldi   low keytable          ; get pointer to keyboard mapping
            plo   r7                    ;  table

            inc   r7                    ; advance to next table entry
twobyte:    inc   r7

onebyte:    ldn   r7                    ; get key code, if zero then not
            bz    discard               ;  found, ignore this code

lookup:     ldn   r2                    ; check if key code matches entry
            xor
            inc   r7
            bz    foundkey

looknext:   lda   r7                    ; if no match, check how many bytes
            ani   80h                   ;  in table we need to skip
            bz    onebyte
            br    twobyte


            ; At this point we have the correct table entry, we just need to 
            ; process any modifier key translations.

foundkey:   ldn   r7                    ; check if entry has shifted code
            ani   80h                    
            bz    notshift

            glo   re                    ; check if either shift key is down,
            ani   1 + 2                 ;  advance to shifted entry if so
            bz    notshift
            inc   r7

notshift:   glo   re                    ; check if either control key down
            ani   4 + 8
            bz    notcontrl

            ldn   r7                    ; check if character is in alpha
            ani   40h                   ;  range of 96-127
            bz    discard

            ldn   r7                    ; clear high bits to make control code
            ani   1fh
            br    output

notcontrl:  glo   re                    ; check if caps lock state is on
            ani   16
            bz    notcaps

            ldn   r7                    ; check if a lower-case letter
            smi   'a' + 80h
            bnf   notcaps
            smi   'z' - 'a' + 81h
            bdf   notcaps

            ldn   r7                    ; translate to upper-case and remove
            smi   20h + 80h             ;  high bit indicator flag
            br    output


            ; If no modifiers are set, then just return the code from the
            ; lookup table as-is, except clear the high bit flag.

notcaps:    ldn   r7                    ; if no modifier, just strip high bit
            ani   7fh

output:     plo   re

            ldi   low cursor
            plo   r7

            out   VDPREG
            out   VDPREG
            out   VDPRAM

            sep   r3

            ghi   re
            shr
            bnf   dontecho

            ghi   r7
            adi   1
            br    readjmp

dontecho:   inc   r2
            lda   r2
            phi   r7
            ldn   r2
            plo   r7
 
            glo   re
            sep   sret



            org   (($ + 0ffh) & 0ff00h)

input:      ldi   high 256              ; preset for fixed-size version
            phi   rc
            ldi   low 256
            plo   rc

inputl:     dec   rc                    ; space for terminating zero

            glo   r8                    ; use r8 for subroutine pc
            stxd
            ghi   r8
            stxd

            glo   r7                    ; use r7 for data page pointer
            stxd
            ghi   r7
            stxd

            glo   rb                    ; use rb for counting input
            stxd
            ghi   rb
            stxd

            ldi   0                     ; zero input count
            phi   rb
            plo   rb

            ghi   r3
            smi   3
            phi   r7

            sex   r7

getchar:    ghi   r3
            smi   1
            phi   r8

            ldi   low readsep
            plo   r8
            sep   r8

            ghi   r3
            smi   2
            phi   r8

            glo   re                    ; get character

            smi   127                   ; got backspace
            bz    gotbksp

            bdf   getchar               ; has high bit set, ignore

            adi   127-32                ; printing character received
            bdf   gotprnt
 
            adi   32-8                  ; backspace received
            bz    gotbksp

            adi   8-3                   ; control-c received
            bz    gotctlc

            adi   3-13                  ; carriage return received
            bnz   getchar


            ; Return from input due to either return or control-c. When
            ; either entry point is called, D will be zero and DF will be
            ; set as a result of the subtraction used for comparison.

gotctlc:    str   rf                    ; zero-terminate input string

            inc   r2                    ; restore saved rb
            lda   r2
            phi   rb
            ldn   r2
            plo   rb

            ghi   re                    ; if not return or echo not enabled,
            shr                         ;  don't echo anything, but save
            glo   re                    ;  input char to stack along the way
            str   r2
            dec   r2
            smbi  13
            bnz   notecho

            ldi   low typesep
            plo   r8
            sep   r8

notecho:    inc   r2                    ; get back character typed, if 3
            ldn   r2                    ;  then set df, if 13 then clear df
            sdi   3

            inc   r2                    ; restore saved r7 register
            lda   r2
            phi   r7
            lda   r2
            plo   r7

            lda   r2
            phi   r8
            ldn   r2
            plo   r8

            glo   re                    ; get result and return via scrt
            sep   sret


            ; If a printing character, see if there is any room left in
            ; the buffer, and append it if there is, ignore otherwise.

gotprnt:    glo   rc                    ; if any room for character
            bnz   addprnt
            ghi   rc                    ; if not any room for character
            bz    getchar

addprnt:    glo   re
            str   rf                    ; append character to buffer
            inc   rf

            dec   rc                    ; increment count, decrement space
            inc   rb

            ghi   re                    ; if echo disabled, get next char
            shr
            bnf   getchar

            ldi   low typesep
            plo   r8
            sep   r8

            br    getchar               ; echo char and get next


            ; Process a backspace received: if not at beginning of buffer,
            ; decrement buffer and count, increment free space, and output
            ; a backspace-space-backspace sequence to erase character.

gotbksp:    glo   rb
            bnz   dobkspc
            ghi   rb
            bz    getchar

dobkspc:    dec   rf                    ; back up pointer

            dec   rb                    ; decrement count, increment space
            inc   rc

            ghi   re                    ; if echo disabled, get next char
            shr
            bnf   getchar

            ldi   low typesep
            plo   r8
            sep   r8

            dec   r7
            out   VDPREG
            out   VDPREG
            ldi   32
            str   r7
            out   VDPRAM

            br    getchar


            ; Include name of loadable module for display by 'minfo'.

            db    0,'PSTwo',0


end:        ; That's all, folks!

