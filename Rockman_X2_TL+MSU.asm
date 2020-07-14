;#################################
;VWF for Rockman X2 - By Her-Saki#
;#################################

;###############
; Variables    #
;###############
 !TextSpeed		   = $6F	 ;;Text speed
 !Letter           = $68     ;;Letter byte
 
 !Y_Backup 	       = $FF00   ;;Backup for Y
 !A_Backup         = $FF01   ;;Backup for A
 !X_Backup         = $FF02   ;;Backup for X
 
 !Shift    		   = $FF03   ;;Rows we shifted each time
 !Width            = $FF04   ;;Width of the old tile
 !ShiftRight       = $FF05   ;;Rows to shift right
 !ShiftLeft        = $FF06   ;;Rows to shift left
 
 !TileMapPosition  = $FF07   ;;Current position in the tilemap
 !LineFlag         = $FF08   ;;New line flag
 !TileMapSize      = $FF0B   ;;Size of the tilemap
 !BufferPosition   = $FF0F   ;;Position in the VROM space
 !TotalWidth	   = $FF11	 ;;Total width per string
 
 ;;Speed 0 heap variables
 !HeapPosition			= $FF13
 !HeapInitPosition		= $FF15
 !HeapLit		   		= #$EF00
 
 !OldTile          = $FF20   ;;Buffer for the old tile
 !NewTile          = $FF30   ;;Buffer for the new tile
 !RawTile    	   = $FF40   ;;Buffer for the raw tile
 !TileMap          = $FF50   ;;Buffer for the tilemap
 
 !OldTileLit       = #$FF20   ;;Old tile buffer literal address
 !NewTileLit       = #$FF30   ;;New tile buffer literal address
 !TileMapLit       = #$FF50   ;;Tile map buffer literal address
 
 !FontOffset       = $2BC1A0   ;;Font address
 !EndingFlag	   = $7E00D1   ;;Ending flag
 !ShiftData        = $31AF00   ;;Shift table address
 
;###############
;Address mode  #
;###############
LOROM

;----------------------;
; Main routine         ;
;----------------------;
main() assume mx:%00 {

;=====================
;Jump to jump to main routine
;=====================
org $670A
JMP $FF90

;==========================
MainJump:
;==========================
org $7F90
JMP $31B000

;==========================
BackupValues:
;==========================
org $31B000
SEP #$30          ;;8-bit accumulator and registers
PHB               ;;Save bank
PHA               ;;Save tilemap byte
LDA #$7F          ;;Load bank
PHA               ;;Save bank
PLB               ;;Restore bank
PLA               ;;Restore tilemap byte
STY !Y_Backup     ;;Save original Y
STA !A_Backup     ;;Save original A
STX !X_Backup     ;;Save original X

;==========================
FreeSpace:
;==========================
LDA $FFF7            		;;Load random byte from the space we want to free
CMP #$00             	
BEQ CheckCleanBufferFlag	;;If zero, skip cleaning
LDX #$00             	
.loop
STZ $FF05,X          	
INX                   	
CPX #$FB              	
BNE .loop             	
LDX #$00

;==========================
;Upon detect #$7D, flush buffer and start anew
CheckCleanBufferFlag:
;==========================
SEP #$20           
LDA !A_Backup      
CMP #$7D           
BNE CheckLineFlag

;==========================
CleanFlags:
;==========================
STZ !LineFlag      
STZ !TileMapPosition
STZ !ShiftRight
STZ !ShiftLeft
STZ !Shift
STZ !Width
STZ !TileMapSize
;;Total Width
STZ $FF11
STZ $FF12
;;Buffer position          
STZ $FF0F          
STZ $FF10
;;Heap Position
STZ $FF13
STZ $FF14
;;HeapInitPosition
STZ $FF15
STZ $FF16

;==========================
CleanBuffer:
;Doing queued DMA here causes
;overflow
;==========================
SEP #$30           
LDA #$18           ;;VRAM gate register
STA $804311        
LDA #$09           ;;Word increment
STA $804310        
LDA #$80           ;;Video port
STA $802115        
REP #$20           
LDA #$0400         ;;Buffer position
LSR                
STA $802116        
LDA #$0C00         ;;Size
STA $804315        
LDA #$FFFF         ;;RAM address
STA $804312        
SEP #$20           
LDA #$7F           ;;Bank   
STA $804314        
.loop
LDA $804212        ;;Wait for V-Blank
BPL .loop          
LDA #$02           
STA $80420B        
PLB                ;;Restore original bank
JMP $00E739        ;;Return

;==========================
CheckLineFlag:
;==========================
SEP #$10
LDA !LineFlag
CMP #$00
BEQ DeactivateLineFlag
JMP Start

DeactivateLineFlag:
INC !LineFlag

;==========================
GetTotalWidth:
;==========================
DEY 				   ;;Start from the first letter
REP #$20			   ;;Clean accumulator
LDA #$0000
SEP #$20
.loop
PEA $7F27
PLB
LDA ($68),y
PLB
CMP #$87
BEQ .SkipNextByte
CMP #$83
BNE .CheckNewLine
.SkipNextByte
INY
.CheckNewLine
CMP #$80
BEQ GetStringLenght
TAX
LDA !ShiftData,x
REP #$20
CLC
ADC !TotalWidth
STA !TotalWidth
SEP #$20
INY
BRA .loop
;==========================
GetStringLenght:
;==========================
REP #$20
LDA !TotalWidth
STA $004204
SEP #$20
LDA #$08
STA $004206
NOP
NOP
NOP
NOP
NOP
NOP
NOP

LDA $004216
TAX
LDA $004214
INC
CPX #$00
BNE DoubleSize
DEC
DoubleSize:
ASL
STA !TileMapSize

STZ $FF11
STZ $FF12
;==========================
InitializeTilemapPosition:
;==========================
LDA !TileMapPosition
CMP #$00               
BNE WriteTilemap       ;;Skip if it was already initialized
LDA #$40               ;;Load #$40 as initial position
STA !TileMapPosition   

;==========================
WriteTilemap:
;==========================
SEP #$30          			
LDX #$00
.loop
INC !TileMapPosition     	
LDA !TileMapPosition     	
STA !TileMap,X    			;;Tilemap byte
INX               			
LDA $6E           			;;Palette byte
STA !TileMap,X    			 
INX               			
CPX !TileMapSize  			
BNE .loop         			
;;Palette bugfix
INX               
LDA $6E          
STA !TileMap,X    

;==========================
;Using $0500 buffer
TilemapToVRAM:
;==========================
LDX $A4
LDY #$00
;;Video port
LDA #$80	
STA $000500,x
INX
;;Load the tilemap address originally assigned to THIS line
REP #$20
LDA $6A         
STA $000500,x
INX
INX
;;Size
SEP #$20
LDA !TileMapSize
STA $000500,x
INX
LDA #$00
STA $000500,x
INX
;;RAM address
REP #$20
LDA !TileMapLit
STA $000500,x
INX
INX
;;Bank
SEP #$20
LDA #$7F
STA $000500,x
INX
;;Add to queue
STX $A4

;==========================
Start:
;==========================
REP #$30             
LDA !BufferPosition  ;;Advance a space
CLC                  
ADC #$10             
STA !BufferPosition  

;==========================
GetIndex:
;==========================
LDA #$0000
SEP #$20
LDA !A_Backup
REP #$20
ASL                  
ASL                  
ASL                  
ASL         
TAX

;==========================
GetLetter:
;==========================
SEP #$20                 
LDY #$00                
.loop
LDA !FontOffset,X        
STA !NewTile,Y           
STA !RawTile,Y     
INY                      
INX                      
CPY #$10                 
BNE .loop                

;==========================
CheckLetterPosition:
;==========================
SEP #$10
LDA !Width
CMP #$00
BNE ShiftingRight
JMP WriteNewTile

;==========================
ShiftingRight:
;==========================
LDX #$00                  
LDY #$00                   
.loop
LSR !NewTile,X   
INY              
CPY !ShiftRight  
BNE .loop       
LDY #$00        
INX            
CPX #$10        
BNE .loop      

;==========================
Oring:
;==========================
LDY #$00         
.loop
LDA !OldTile,Y   
ORA !NewTile,Y   
STA !OldTile,Y   
INY              
CPY #$10         
BCC .loop        

;==========================
ShiftingLeft:
;==========================
LDY #$00               
LDX #$00               
.loop
ASL !RawTile,X   
LDA !RawTile,X   
STA !NewTile,X
INY                   
CPY !ShiftLeft        
BNE .loop             
LDY #$00               
INX                    
CPX #$10               
BNE .loop              

;;This must happen ALWAYS inside shift operations
LDA !ShiftLeft
STA !Shift

;==========================
WriteOldTile:
;==========================
LDA !TextSpeed
CMP #$00
BNE OldTileRegular

LDA !EndingFlag
CMP #$06
BNE OldTileRegular

;;Check if this is the first transfer
REP #$30
LDA !HeapInitPosition
CMP #$0000
BNE CopyOldTile
;;Set initial position
REP #$20
LDA #$0400
CLC
ADC !BufferPosition
STA !HeapInitPosition
LDA !BufferPosition
STA !HeapPosition
;;Old tile to heap buffer
CopyOldTile:
LDY #$0000
LDA !BufferPosition
SEC
SBC #$0010
TAX
LDA #$0000
SEP #$20
.LoopHeap
LDA !OldTile,y
STA $7FEF00,X
INY
INX
CPY #$0010
BNE .LoopHeap
SEP #$30
JMP NewTileToHeap

OldTileRegular:
LDX $A5
CPX #$80
BCC RegularDMA1
;;If the queue overflows, force blank to write tiles
LDA #$00
STA $0609CE
.loop
LDA $804212        ;;Wait for
BPL .loop          ;;V-Blank
LDX $A5

RegularDMA1:
LDX $A5
LDY #$00
;;Video port
LDA #$80
STA $000600,x
INX
;;VRAM address
REP #$20
LDA #$0400
CLC
ADC !BufferPosition
SEC
SBC #$10
LSR
STA $000600,x
INX
INX
;;Size
SEP #$20
LDA #$10
STA $000600,x
INX
;;Bytes
LoopThru2:
LDA !OldTile,y
STA $000600,x
INY
INX
CPY #$10
BNE LoopThru2
;;Add to queue
STX $A5

;==========================
WriteNewTile:
;==========================
LDA !TextSpeed
CMP #$00
BNE NewTileRegular

LDA !EndingFlag
CMP #$06
BNE NewTileRegular

;;Check if this is the first transfer
NewTileToHeap:
REP #$30
LDA !HeapInitPosition
CMP #$0000
BNE CopyNewTile
;;Set initial position
REP #$20
LDA #$0400
CLC
ADC !BufferPosition
STA !HeapInitPosition
LDA !BufferPosition
STA !HeapPosition
;;Old tile to heap buffer
CopyNewTile:
SEP #$20
LDY #$0000
LDX !BufferPosition
.LoopHeap
LDA !NewTile,y
STA $7FEF00,X
INY
INX
CPY #$0010
BNE .LoopHeap
SEP #$30
JMP HeapQueue

NewTileRegular:
LDX $A5
CPX #$80
BCC RegularDMA
;;If the queue overflows, force blank to write tiles
LDA #$00
STA $0609CE
.loop
LDA $804212        ;;Wait for
BPL .loop          ;;V-Blank
LDX $A5

RegularDMA:
LDX $A5
LDY #$00
;;Video port
LDA #$80
STA $000600,x
INX
;;VRAM address
REP #$20
LDA #$0400
CLC
ADC !BufferPosition
LSR
STA $000600,x
INX
INX
SEP #$20
;;Size
LDA #$10
STA $000600,x
INX
;;Bytes
LoopThru:
LDA !NewTile,y
STA $000600,X
INY
INX
CPY #$10
BNE LoopThru
;;Add to queue
STX $A5
JMP CheckWidth

;==========================
HeapQueue:
;==========================
;;Check if the line is complete
LDY !Y_Backup
PEA $7F27
PLB
LDA ($68),y
PLB
CMP #$80
BNE CheckWidth

LDX $A4
LDY #$00
;;Video port
LDA #$80	
STA $000500,x
INX
;;Load the initial position
REP #$20
LDA !HeapInitPosition
LSR      
STA $000500,x
INX
INX
;Size
LDA #$0000
SEP #$20
LDA !TileMapSize
REP #$20
ASL
ASL
ASL
STA $000500,x
INX
INX
;;RAM address
LDA !HeapLit
CLC
ADC !HeapPosition
STA $000500,x
INX
INX
;;Bank
SEP #$20
LDA #$7F
STA $000500,x
INX
;;Add to queue
STX $A4
;;Heap Position
STZ $FF13
STZ $FF14
;;HeapInitPosition
STZ $FF15
STZ $FF16

;==========================
CheckWidth:
;==========================
LDX !A_Backup      ;;Load A backup as index
LDA !ShiftData,X   ;;Load tile width
SEC                ;;Substract shift
SBC !Shift    		
STA !Width         ;;Store as old width
CMP #$00              
BEQ .Reset00       ;;If zero, reset shift and buffer position
BMI .Reset08       ;;If less, reset everything 
BPL GetWidth       ;;If greater, continue normally
.Reset00
JSR ResetShift     ;;Redundancy save
JMP GetWidth     
.Reset08              
JSR ResetShift     ;;Redundancy save
LDA #$00              
SEC                   
SBC !Width         
STA !Width        
;LDA !Width            
STA !ShiftLeft     ;;Old width and shift left = 0 - Negative width     
LDA #$08                   
SEC                        
SBC !Width          
STA !ShiftRight    ;;Shift right = 8 - Width
JMP LoadBackups

;==========================
GetWidth:
;==========================
LDA !Width       	
STA !ShiftRight    ;;Shift right = Width
LDA #$08            
SEC                 
SBC !Width       	
STA !ShiftLeft     ;;Shift left = 8 - Width

;==========================
SaveOldTile:
;==========================
LDX #$00         
.loop
LDA !NewTile,X   
STA !OldTile,X   
INX              
CPX #$10         
BNE .loop        

;==========================
LoadBackups:
;==========================
LDX !X_Backup
LDY !Y_Backup
PEA $7F27		   ;;Check if the next byte is (LINE)
PLB
LDA ($68),y
PLB
CMP #$80
BNE .skip
;;Reset stuff
STZ !TileMapSize
STZ !Shift
STZ !Width
DEC !LineFlag      ;;Activate newline flag
.skip
SEP #$20
PLB                ;;Restore bank
JMP $00E739		   ;;Exit

;==========================
ResetShift:
;==========================
REP #$20
LDA !BufferPosition
SEC
SBC #$10
STA !BufferPosition
SEP #$20
STZ !Shift
RTS

;==========================
;Text font to VRAM
;==========================
TextFontToVRAM:
LDX $A4
LDY #$00
;;Video port
LDA #$80	
STA $000500,x
INX
;;Write after the original tilemap
REP #$20
LDA #$0600
STA $000500,x
INX
INX
;;Size
LDA #$0400
STA $000500,x
INX
INX
;;Check ending flag
SEP #$20
LDA !EndingFlag
CMP #$06
BNE RamAddress
REP #$20
LDA #$8000
STA $000500,x
INX
INX
;;Bank
SEP #$20
LDA #$32
STA $000500,x
INX
JMP AddToQueue
;;;;;;;;;;;;;;
;;RAM address
RamAddress:
REP #$20
LDA #$C6A0
STA $000500,x
INX
INX
;;Bank
SEP #$20
LDA #$2B
STA $000500,x
INX
;;Add to queue
AddToQueue:
STX $A4
LDX $A5
LDY #$00
RTL

;==========================
;Check CHR address
;==========================
CheckCopyCHR:
REP #$20 				;;Bugfix 
LDA $FA03,X
CMP #$3282
BNE ExitCheckCopyCHR
;==========================
;Copy CHR
;==========================
PHX
PHY
SEP #$30
LDX $A4
;;Video port
LDA #$80	
STA $000500,x
INX
;;Write after the original CHR
REP #$20
LDA #$1C00
STA $000500,x
INX
INX
;;Size
LDA #$1600
STA $000500,x
INX
INX
;;RAM address
REP #$20
LDA #$9200
STA $000500,x
INX
INX
;;Bank
SEP #$20
LDA #$32
STA $000500,x
INX
;;Add to queue
STX $A4
REP #$30
PLY
PLX
ExitCheckCopyCHR:
LDA $FA03,X
STA $F7
RTL

;###############
;Subroutines   #
;###############
;=====================
;Copy weapon text CHR
;=====================
org $B27C
JSL CheckCopyCHR
NOP
;==========================
;Jump to regular letters DMA
;==========================
org $867B
JSL TextFontToVRAM

;###############
;Strings	   #
;###############
;==========================
;"Rockman X2" string
;==========================
org $68DF0
db $20, $C0, $C1, $C2, $C3, $C4, $C5, $C6, $20, $20
org $68E00
fillbyte $20 : fill 19
org $68E17
db $20
;==========================
;"New Game" strings
;==========================
org $68E83
db $C7, $C8, $C9, $CA, $CB, $CC, $20, $20, $20, $20, $20
org $68EAF
db $C7, $C8, $C9, $CA, $CB, $CC, $20, $20, $20, $20, $20
org $68EDB
db $C7, $C8, $C9, $CA, $CB, $CC, $20, $20, $20, $20, $20

;==========================
;"Password" strings
;==========================
org $68E92
db $CD, $CE, $CF, $D0, $D1, $20, $20, $20, $20
org $68EBE
db $CD, $CE, $CF, $D0, $D1, $20, $20, $20, $20
org $68EEA
db $CD, $CE, $CF, $D0, $D1, $20, $20, $20, $20

;==========================
;"Options" strings
;==========================
org $68E9F
db $D2, $D3, $D4, $D5, $20, $20, $20, $20, $20, $20, $20
org $68ECB
db $D2, $D3, $D4, $D5, $20, $20, $20, $20, $20, $20, $20
org $68EF7
db $D2, $D3, $D4, $D5, $20, $20, $20, $20, $20, $20, $20

;==========================
;"Controls" strings
;==========================
;;Length fix
org $69038
db $09
;;Window fix
;;4 bytes of palettes and position:
;;Lenght
;;Palette
;;Position low byte
;;Position high byte
org $69041
db $AC, $AC, $AC, $AA, $05, $30, $EE, $08
;;Text
org $69049
db $D6, $D7, $D8, $D9, $DA
;;Window fix
org $6904E
db $09, $64, $F3, $08, $AA, $AC, $AC, $AC

;;Length fix
org $690CB
db $09
;;Window fix
org $690D4
db $AC, $AC, $AC, $AA, $05, $34, $EE, $08
;;Text
org $690DC
db $D6, $D7, $D8, $D9, $DA
;;Window fix
org $690E1
db $09, $6C, $F3, $08, $AA, $AC, $AC, $AC

;==========================
;"Shot" strings
;==========================
org $69224
db $DB, $DC, $DD, $20
org $6922D
db $DB, $DC, $DD, $20

;==========================
;"Jump" strings
;==========================
org $69236
db $DE, $DF, $E0, $20
org $6923F
db $DE, $DF, $E0, $20

;==========================
;"Dash" strings
;==========================
org $69248
db $E1, $E2, $E3, $20
org $69251
db $E1, $E2, $E3, $20

;==========================
;"Select L" strings
;==========================
org $6925A
db $20, $E4, $E5, $E6, $E7, $E8, $20, $20
org $69267
db $20, $E4, $E5, $E6, $E7, $E8, $20, $20

;==========================
;"Select R" strings
;==========================
org $69274
db $20, $E4, $E5, $E6, $E7, $E9, $20, $20
org $69281
db $20, $E4, $E5, $E6, $E7, $E9, $20, $20

;==========================
;"Menu" strings
;==========================
org $6928E
db $EA, $EB, $EC, $20
org $69297
db $EA, $EB, $EC, $20

;==========================
;"Exit" strings
;==========================
org $692A0
db $FB, $FC, $FD, $20
org $692A9
db $FB, $FC, $FD, $20

;==========================
;"Stereo" strings
;==========================
org $692B3
db $20, $ED, $F5, $F6, $F7, $20
org $692C0
db $20, $ED, $F5, $F6, $F7, $20

;==========================
;"Mono" strings
;==========================
org $692CC
db $20, $20, $EA, $F9, $FA, $20, $20, $20
org $692D9
db $20, $20, $EA, $F9, $FA, $20, $20, $20

;==========================
;Input strings
;==========================
;;B
org $6B441
db $FF
;;Y
org $6B447
db $F8
;;A
org $6B44D
db $FE
;;X
org $6B453
db $F4
;;L
org $6B459
db $E8
;;R
org $6B45F
db $E9
;;Select
org $6B463
db $20, $E4, $E5, $E6, $E7, $20
;;Start
org $6B469
db $20, $ED, $EE, $EF, $20

;==========================
;"Sound" strings
;==========================
;Lenght fix
org $6915E
db $09
;Window fix
org $69167
db $AC, $AC, $AC, $AA
;Data
org $6916B
db $04, $30, $6E, $0A
;Text
org $6916F
db $F0, $F1, $F2, $F3
;Data
org $69173
db $09, $64, $72, $0A
;Window fix
org $69177
db $AA, $AC, $AC, $AC

;Lenght fix
org $691BF
db $09
;Window fix
org $691C8
db $AC, $AC, $AC, $AA
;Data
org $691CC
db $04, $34, $6E, $0A
;Text
org $691D0
db $F0, $F1, $F2, $F3
;Data
org $691D4
db $09, $6C, $72, $0A
;Window fix
org $691D8
db $AA, $AC, $AC, $AC

;=====================
;"Thanks for playing!"
;string
;=====================
org $69567
db $20, $20, $20, $20, $20, $C0, $C1, $C2, $C3, $C4, $C5, $C6, $C7, $C8, $C9, $CA, $20, $20, $20, $20, $20

;=====================
;"Presented by" string
;=====================
org $69580
db $20, $20, $D0, $D1, $D2, $D3, $D4, $D5, $D6, $D7, $20, $20

;=====================
;Weapon text
;=====================
;Compressed chunk pointer
org $6FB7E
db $00, $82, $32

;X-Buster
org $69D51
db $72, $73, $74, $75, $76, $00, $00
;Crystal Hunter
org $69CFA
db $EB, $EC, $ED, $EE, $EF, $F0, $F1, $F2, $00
;Bubble Splash
org $69D04
db $C0, $C1, $C2, $C3, $C4, $C5, $C6, $C7
;Scrap Shoot
org $69D0D
db $D6, $D7, $D8, $D9, $DA, $DB, $DC
;Spin Wheel
org $69D15
db $88, $89, $8A, $8B, $8C, $8D, $00
;Sonic Slicer
org $69D1D
db $8E, $8F, $90, $91, $92, $93, $94, $00
;Strike chain
org $69D26
db $77, $78, $79, $7A, $7B, $7C, $7D
;Magnet Mine
org $69D2E
db $E4, $E5, $E6, $E7, $E8, $E9, $EA, $00
;Rushing Burner
org $69D37
db $C8, $C9, $CA, $CB, $CC, $CD, $CE, $CF
;Giga Crush
org $69D40
db $D0, $D1, $D2, $D3, $D4, $D5, $00
;Item Tracer
org $69D48
db $DD, $DE, $DF, $E0, $E1, $E2, $E3, $00
;Sub-Tanks
org $69D65
db $7E, $7F, $82, $83, $84
;Exit
org $69D5A
db $85, $86, $87, $00

;###############
;Binaries	   #
;###############
;Width table
org $31AF00
incbin Width.bin

;Compressed weapon text chunk binary
;org $328200
;incbin "WeaponData.bin"

;Uncompressed weapon text chunk binary
;org $329200
;incbin "WeaponData2.bin"

}