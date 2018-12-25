	.org $8000

	.segment "bank7"

	.include "lost.inc"
	.include "shared.inc"
	.include "macros.inc"
	.include "wram.inc"

	FDS_Delay132:
	FDS_LoadFiles:
		jmp FDS_LoadFiles

WRAM_DefaultState:
		.incbin "wram/init.bin"

Initialize_WRAM:
		ldx #Initialize_WRAM-WRAM_DefaultState
InitMoreWRAM:
		lda WRAM_DefaultState - 1, x
		sta WRAM_StartAddress - 1, x
		dex
		bne InitMoreWRAM
		rts

Start:
		; lda FdsLastWrite4025
		; and #$F7
		; sta FDS_CONTROL
		lda WorldNumber
		pha

		ldx #CHR_LOST
		jsr Enter_LoadChrFromX
		jsr Initialize_WRAM

		ldy #$FE
		jsr InitializeMemory

		sta SND_DELTA_REG+1
		sta OperMode
		sta FdsOperTask
		pla
		sta WorldNumber
		lda #$A5
		sta PseudoRandomBitReg
		lda #$F
		sta SND_MASTERCTRL_REG
		lda #6
		sta PPU_CTRL_REG2
		jsr MoveAllSpritesOffscreen
		jsr InitializeNameTables
		inc DisableScreenFlag
		lda #$C0
		sta FdsBiosIrqAction
		; CLI
		lda Mirror_PPU_CTRL_REG1
		ora #$80
		jsr WritePPUReg1
EndlessLoop:
		lda TMP_0
		jmp EndlessLoop

VRAM_AddrTable_DW_NEW:
		.word $301
		.word unk_6B8D
		.word unk_6BB1
		.word unk_6BD5
		.word unk_6BF9
		.word SWAPDATA_C62B
		.word VRAM_Buffer2
		.word VRAM_Buffer2
		.word unk_6C35
		.word word_6C1D
		.word unk_6C25
		.word unk_6C2D
		.word WRAM_ThankYouMario
		.word unk_6C51
		.word SWAPDATA_C876
		.word SWAPDATA_C87F
		.word SWAPDATA_C893
		.word SWAPDATA_C8AB
		.word SWAPDATA_C8C1
		.word SWAPDATA_C8D7
		.word SWAPDATA_C8EB
		.word SWAPDATA_C8FC
		.word SWAPDATA_C913
		.word SWAPDATA_C92B
		.word SWAPDATA_C943
		.word $FFFF
		.word byte_C10B
		.word SWAPDATA_C95C
		.word WRAM_MushroomSelection
		.word SWAPDATA_C97D
		.word SWAPDATA_C9C0
VRAM_Buffer_Offset:
		.byte 0
		.byte $40

NonMaskableInterrupt:
		lda Mirror_PPU_CTRL_REG1
		and #$7E
		sta Mirror_PPU_CTRL_REG1
		sta PPU_CTRL_REG1
		; sei
		lda Mirror_PPU_CTRL_REG2
		and #$E6
		ldy DisableScreenFlag
		bne ScreenOff
		lda Mirror_PPU_CTRL_REG2
		ora #$1E
ScreenOff:
		sta Mirror_PPU_CTRL_REG2
		and #$E7
		sta PPU_CTRL_REG2
		ldx PPU_STATUS
		lda #0
		jsr InitScroll
		sta PPU_SPR_ADDR
		lda #2
		sta SPR_DMA
		lda VRAM_Buffer_AddrCtrl
		asl
		tax
		lda VRAM_AddrTable_DW_NEW,x
		sta TMP_0
		inx
		lda VRAM_AddrTable_DW_NEW,x
		sta TMP_1
		jsr UpdateScreen
		ldy #0
		ldx VRAM_Buffer_AddrCtrl
		cpx #6
		bne InitBuffer
		iny
InitBuffer:
		ldx VRAM_Buffer_Offset,y
		lda #0
		sta VRAM_Buffer1_Offset,x
		sta VRAM_Buffer1,x
		sta VRAM_Buffer_AddrCtrl
		lda Mirror_PPU_CTRL_REG2
		sta PPU_CTRL_REG2
		; CLI
		jsr Enter_SoundEngine
		jsr ReadJoypads
		jsr PauseRoutine
		jsr UpdateTopScore
		lda GamePauseStatus
		lsr
		bcs PauseSkip
		lda TimerControl
		beq DecTimers
		dec TimerControl
		bne NoDecTimers
DecTimers:
		ldx #$14
		dec IntervalTimerControl
		bpl DecTimersLoop
		lda #$14
		sta IntervalTimerControl
		ldx #$23
DecTimersLoop:

		lda SelectTimer,x
		beq SkipExpTimer
		dec SelectTimer,x
SkipExpTimer:

		dex
		bpl DecTimersLoop
NoDecTimers:
		inc FrameCounter
PauseSkip:

		ldx #0
		ldy #7
		lda PseudoRandomBitReg
		and #2
		sta TMP_0
		lda PseudoRandomBitReg+1
		and #2
		eor TMP_0
		clc
		beq RotPRandomBit
		sec
RotPRandomBit:

		ror PseudoRandomBitReg,x
		inx
		dey
		bne RotPRandomBit
		;
		; hack begins
		;
		lda Sprite0HitDetectFlag
		beq SkipSprite0

Sprite0Clr:
		lda PPU_STATUS
		and #$40
		bne Sprite0Clr

		lda GamePauseStatus
		lsr
		bcs Sprite0Hit

		jsr MoveSpritesOffscreen
		jsr SpriteShuffler

Sprite0Hit:
		lda PPU_STATUS
		and #$40
		beq Sprite0Hit
		ldy #$8
HBlankDelay:
		dey
		bne HBlankDelay

SkipSprite0:
		;
		; XXX - In smb2j-fds, this is effectively done AFTER the OperModeExecTree has ran.
		;       If vert-/horizontalscroll is changed (and they are) in OperMode, we are showing wrong px i think
		;
		lda PPU_STATUS
		lda Mirror_PPU_CTRL_REG1
		and #$F7
		ora UseNtBase2400
		sta Mirror_PPU_CTRL_REG1
		sta PPU_CTRL_REG1
		lda HorizontalScroll
		sta PPU_SCROLL_REG
		lda VerticalScroll
		sta PPU_SCROLL_REG

		lda WorldNumber
		cmp #9
		bcc NotWorld9Something
		jsr sub_708D
NotWorld9Something:

		lda GamePauseStatus
		lsr
		bcs SkipMainOper

		jsr OperModeExecutionTree
SkipMainOper:
		lda PPU_STATUS
		lda Mirror_PPU_CTRL_REG1
		ora #$80
		sta Mirror_PPU_CTRL_REG1
		sta PPU_CTRL_REG1
OnIRQ:
		rti


PauseRoutine:
		lda OperMode
		cmp #VictoryModeValue
		beq ChkPauseTimer
		cmp #GameModeValue
		bne ExitPause
		lda OperMode_Task
		cmp #4
		bne ExitPause
ChkPauseTimer:
		lda GamePauseTimer
		beq ChkStart
		dec GamePauseTimer
		rts
ChkStart:
		lda SavedJoypad1Bits
		and #Start_Button
		beq ClrPauseTimer
		lda GamePauseStatus
		and #$80
		bne ExitPause
		lda #$2B
		sta GamePauseTimer
		lda GamePauseStatus
		tay
		iny
		sty PauseSoundQueue
		eor #1
		ora #$80
		bne SetPause
ClrPauseTimer:
		lda GamePauseStatus
		and #$7F
SetPause:
		sta GamePauseStatus
ExitPause:
		rts

SpriteShuffler:
		ldy AreaType
		lda #$28
		sta TMP_0
		ldx #$E
loc_6236:

		lda Player_SprDataOffset,x
		cmp TMP_0
		bcc loc_624C
		ldy SprShuffleAmtOffset
		clc
		adc SprShuffleAmt,y
		bcc loc_6249
		clc
		adc TMP_0
loc_6249:

		sta Player_SprDataOffset,x
loc_624C:

		dex
		bpl loc_6236
		ldx SprShuffleAmtOffset
		inx
		cpx #3
		bne loc_6259
		ldx #0
loc_6259:

		stx SprShuffleAmtOffset
		ldx #8
		ldy #2
loc_6260:

		lda unk_6E9,y
		sta FBall_SprDataOffset,x
		clc
		adc #8
		sta unk_6F2,x
		clc
		adc #8
		sta Misc_SprDataOffset,x
		dex
		dex
		dex
		dey
		bpl loc_6260
		rts
OperModeExecutionTree:

		lda OperMode
		jsr JumpEngine
		.word TitleScreenMode
		.word GameMode
		.word VictoryMode
		.word GameOverMode
MoveAllSpritesOffscreen:

		ldy #0
		.byte $2c
MoveSpritesOffscreen:
		ldy #4
		lda #$F8
SprInitLoop:

		sta Sprite_Y_Position,y
		iny
		iny
		iny
		iny
		bne SprInitLoop
locret_6297:

		rts
VictoryMode:

		jsr VictoryModeSubroutines
		lda OperMode_Task
		beq AutoPlayer
		ldx WorldNumber
		cpx #7
		bne loc_62AF
		cmp #5
		beq locret_6297
		cmp #$D
		beq locret_6297
loc_62AF:

		ldx #0
		stx ObjectOffset
		jsr EnemiesAndLoopsCore
AutoPlayer:

		jsr RelativePlayerPosition
		jmp PlayerGfxHandler
VictoryModeSubroutines:

		lda WorldNumber
		cmp #7
		beq VictoryOnWorld8_NEW
		lda OperMode_Task
		jsr JumpEngine
		.word BridgeCollapse
		.word SetupVictoryMode
		.word PlayerVictoryWalk
		.word PrintVictoryMessages
		.word PlayerEndWorld_MAYBE_NEW
		.word PlayerEndWorld_2_MAYBE_NEW
VictoryOnWorld8_NEW:

		lda OperMode_Task
		jsr JumpEngine
		.word BridgeCollapse
		.word SetupVictoryMode
		.word PlayerVictoryWalk
		.word InitializeWorldEndTimer
		.word CheckWorldEndTimer
		.word FdsLoadFile_SM2DATA3
		.word AlternateInitScreen
		.word AlternatePrintVictoryMessages
		.word PlayerEndWorld_MAYBE_NEW
		.word AlternatePlayerEndWorld
		.word UNK_C6CA
		.word XXX_CopySomethingAndReset
		.word XXX_SomethingOrOther
		.word FdsWriteFile_SM2SAVE
ConvertIndexToBit:
		.byte 1
		.byte 2
		.byte 4
		.byte 8
		.byte $10
		.byte $20
		.byte $40
		.byte $80

SetupVictoryMode:
		ldx ScreenRight_PageLoc
		inx
		stx FirebarSpinDirection
		ldy WorldNumber
		lda ConvertIndexToBit,y
		ora byte_7FA
		sta byte_7FA
		lda IsPlayingExtendedWorlds
		beq loc_6322
		lda WorldNumber
		cmp #3
		bcc loc_6322
		lda #7
		sta WorldNumber
loc_6322:
		lda #8
		sta EventMusicQueue
Next_OperMode_Task:
		inc OperMode_Task
		rts

DrawTitleScreen:
		lda OperMode
		bne Next_OperMode_Task
		lda #5
		jmp loc_65A1

PlayerVictoryWalk:
		ldy #0
		sty VictoryWalkControl
		lda Player_PageLoc
		cmp FirebarSpinDirection
		bne loc_6344
		lda Player_X_Position
		cmp #$60
		bcs loc_6347
loc_6344:
		inc VictoryWalkControl
		iny
loc_6347:
		tya
		jsr AutoControlPlayer
		lda ScreenLeft_PageLoc
		cmp FirebarSpinDirection
		beq loc_6368
		lda ScrollFractional
		clc
		adc #$80
		sta ScrollFractional
		lda #1
		adc #0
		tay
		jsr loc_7B20
		jsr sub_7ACB
		inc VictoryWalkControl
loc_6368:
		lda VictoryWalkControl
		beq loc_63AB
		rts

PrintVictoryMessages:
		lda SecondaryMsgCounter
		bne loc_6391
		lda PrimaryMsgCounter
		beq loc_637F
		cmp #8
		bcs loc_6391
		cmp #1
		bcc loc_6391
loc_637F:
		tay
		beq loc_638A
		cpy #3
		bcs loc_63A4
		cpy #2
		bcs loc_6391
loc_638A:
		tya
		clc
		adc #$C
		sta VRAM_Buffer_AddrCtrl
loc_6391:
		lda SecondaryMsgCounter
		clc
		adc #4
		sta SecondaryMsgCounter
		lda PrimaryMsgCounter
		adc #0
		sta PrimaryMsgCounter
		cmp #6
loc_63A4:
		bcc locret_63AE
		lda #8
		sta WorldEndTimer
loc_63AB:
		inc OperMode_Task
locret_63AE:
		rts

PlayerEndWorld_MAYBE_NEW:
		lda WorldEndTimer
		cmp #6
		bcs locret_63D1
		jsr sub_9F57
		lda byte_7EC
		ora byte_7ED
		ora byte_7EE
		bne locret_63D1
		lda #$30
		sta SelectTimer
		lda #6
		sta WorldEndTimer
		inc OperMode_Task
locret_63D1:
		rts

PlayerEndWorld_2_MAYBE_NEW:
		lda WorldEndTimer
		bne locret_63FC
		lda #0
		sta AreaNumber
		sta LevelNumber
		sta OperMode_Task
		lda WorldNumber
		clc
		adc #1
		cmp #8
		bcc loc_63EE
		lda #8
loc_63EE:

		sta WorldNumber
		jsr LoadAreaPointer
		inc FetchNewGameTimerFlag
		lda #1
		sta OperMode
locret_63FC:

		rts
FloateyNumTileData:
		.byte $FF
unk_63FE:
		.byte $FF
		.byte $F6
		.byte $FB
		.byte $F7
		.byte $FB
		.byte $F8
		.byte $FB
		.byte $F9
		.byte $FB
		.byte $FA
		.byte $FB
		.byte $F6
		.byte $50
		.byte $F7
		.byte $50
		.byte $F8
		.byte $50
		.byte $F9
		.byte $50
		.byte $FA
		.byte $50
		.byte $FD
		.byte $FE
ScoreUpdateData:
		.byte $FF
		.byte $41
		.byte $42
		.byte $44
		.byte $45
		.byte $48
		.byte $31
		.byte $32
		.byte $34
		.byte $35
		.byte $38
		.byte 0
FloateyNumbersRoutine:

		lda FloateyNum_Control,x
		beq locret_63FC
		cmp #$B
		bcc loc_642F
		lda #$B
		sta FloateyNum_Control,x
loc_642F:

		tay
		lda FloateyNum_Timer,x
		bne loc_6439
		sta FloateyNum_Control,x
		rts
loc_6439:

		dec FloateyNum_Timer,x
		cmp #$2B
		bne loc_645E
		cpy #$B
		bne loc_644B
		inc NumberofLives
		lda #$40
		sta Square2SoundQueue
loc_644B:

		lda ScoreUpdateData,y
		lsr
		lsr
		lsr
		lsr
		tax
		lda ScoreUpdateData,y
		and #$F
		sta DigitModifier,x
		jsr AddToScore
loc_645E:

		ldy Enemy_SprDataOffset,x
		lda Enemy_ID,x
		cmp #$12
		beq loc_6489
		cmp #$D
		beq loc_6489
		cmp #5
		beq loc_6481
		cmp #$A
		beq loc_6489
		cmp #$B
		beq loc_6489
		cmp #9
		bcs loc_6481
		lda $1E,x
		cmp #2
		bcs loc_6489
loc_6481:

		ldx SprDataOffset_Ctrl
		ldy Alt_SprDataOffset,x
		ldx ObjectOffset
loc_6489:

		lda FloateyNum_Y_Pos,x
		cmp #$18
		bcc loc_6495
		sbc #1
		sta FloateyNum_Y_Pos,x
loc_6495:

		lda FloateyNum_Y_Pos,x
		sbc #8
		jsr DumpTwoSpr
		lda FloateyNum_X_Pos,x
		sta Sprite_X_Position,y
		clc
		adc #8
		sta $207,y
		lda #2
		sta Sprite_Attributes,y
		sta $206,y
		lda FloateyNum_Control,x
		asl
		tax
		lda FloateyNumTileData,x
		sta $201,y
		lda unk_63FE,x
		sta $205,y
		ldx ObjectOffset
		rts

ScreenRoutines:
		lda ScreenRoutineTask
		jsr JumpEngine
		.word InitScreen
		.word SetupIntermediate
		.word WriteTopStatusLine
		.word WriteBottomStatusLine
		.word DisplayTimeUp
		.word ResetSpritesAndScreenTimer
		.word DisplayIntermediate
		.word PrepareInitializeArea
		.word ResetSpritesAndScreenTimer
		.word AreaParserTaskControl
		.word GetAreaPalette
		.word GetBackgroundColor
		.word GetAlternatePalette1
		.word DrawTitleScreen
		.word ClearBuffersDrawIcon
		.word WriteTopScore

InitScreen:
		jsr MoveAllSpritesOffscreen
		jsr InitializeNameTables
		lda OperMode
		beq loc_6528
InitializeScreeNoSpritesNoNt:

		ldx #3
		jmp loc_6525
SetupIntermediate:

		lda BackgroundColorCtrl
		pha
		lda PlayerStatus
		pha
		lda #0
		sta UseNtBase2400
		sta PlayerStatus
		lda #2
		sta BackgroundColorCtrl
		jsr GetPlayerColors_RW
		pla
		sta PlayerStatus
		pla
		sta BackgroundColorCtrl
		jmp IncSubtask
AreaPalette:
		.byte 1
		.byte 2
		.byte 3
		.byte 4

GetAreaPalette:
		ldy AreaType
		ldx AreaPalette,y
loc_6525:

		stx VRAM_Buffer_AddrCtrl
loc_6528:

		jmp IncSubtask
BGColorCtrl_Addr:
		.byte $00, $09, $0A, $04
BackgroundColors:
		.byte $22, $22, $0F, $0F
		.byte $0F, $22, $0F, $0F

GetBackgroundColor:
		ldy BackgroundColorCtrl
		beq loc_654A
		lda BGColorCtrl_Addr-4,y
		sta VRAM_Buffer_AddrCtrl
loc_654A:
		inc ScreenRoutineTask

GetPlayerColors_RW:
		ldx VRAM_Buffer1_Offset
		ldy #0
		lda PlayerStatus
		cmp #2
		bne StartClrGet
		ldy #4
StartClrGet:
		lda #3
		sta TMP_0
ClrGetLoop:
		lda WRAM_PlayerColors,y
		sta VRAM_Buffer1+3,x
		iny
		inx
		dec TMP_0
		bpl ClrGetLoop
		ldx VRAM_Buffer1_Offset
		ldy BackgroundColorCtrl
		bne SetBGColor
		ldy AreaType
SetBGColor:
		lda BackgroundColors,y
		sta VRAM_Buffer1+3,x
		lda #$3F
		sta VRAM_Buffer1,x
		lda #$10
		sta VRAM_Buffer1+1,x
		lda #4
		sta VRAM_Buffer1+2,x
		lda #0
		sta VRAM_Buffer1+7,x
		txa
		clc
		adc #7
SetVRAMOffset:
		sta VRAM_Buffer1_Offset
		rts

GetAlternatePalette1:
		lda AreaStyle
		cmp #1
		bne NoAltPal
		lda #$B
loc_65A1:
		sta VRAM_Buffer_AddrCtrl
NoAltPal:
		jmp IncSubtask

WriteTopStatusLine:
		lda #0
		jsr WriteGameText_NEW
		jmp IncSubtask
WriteBottomStatusLine:
		jsr GetSBNybbles_RW
		ldx VRAM_Buffer1_Offset
		lda #$20
		sta $301,x
		lda #$73
		sta $302,x
		lda #3
		sta $303,x
		jsr GetWorldNumber
		sta $304,x
		lda #$28
		sta $305,x
		ldy LevelNumber
		iny
		tya
		sta $306,x
		lda #0
		sta $307,x
		txa
		clc
		adc #6
		sta VRAM_Buffer1_Offset
		jmp IncSubtask

GetWorldNumber:
		ldy WorldNumber
		lda IsPlayingExtendedWorlds
		beq loc_65F5
		tya
		and #3
		clc
		adc #9
		tay
loc_65F5:
		iny
		tya
		rts

DisplayTimeUp:
		lda GameTimerExpiredFlag
		beq NoTimeUp
		lda #0
		sta GameTimerExpiredFlag
		lda #2
WriteTextAndResetTimers:
		jsr WriteGameText_NEW
		jsr ResetScreenTimer
		lda #0
		sta DisableScreenFlag
		rts
NoTimeUp:
		inc ScreenRoutineTask
IncSubtask:
		inc ScreenRoutineTask
		rts

DisplayIntermediate:
		lda OperMode
		beq loc_6653
		cmp #3
		beq loc_6644
		lda AltEntranceControl
		bne loc_6653
		ldy AreaType
		cpy #3
		beq loc_6631
		lda DisableIntermediate
		bne loc_6653
loc_6631:
		jsr DrawPlayer_Intermediate
		lda #1
		jsr WriteTextAndResetTimers
		lda WorldNumber
		cmp #8
		bne IncSubtask
		inc DisableScreenFlag
		rts
loc_6644:
		lda #3
		jsr WriteGameText_NEW
		lda WorldNumber
		cmp #8
		beq IncSubtask
		jmp Next_OperMode_Task
loc_6653:
		lda #9
		sta ScreenRoutineTask
		rts

AreaParserTaskControl:
		inc DisableScreenFlag
loc_665C:
		jsr AreaParserTaskHandler
		lda AreaParserTaskNum
		bne loc_665C
		dec ColumnSets
		bpl loc_666C
		inc ScreenRoutineTask
loc_666C:
		lda #6
		sta VRAM_Buffer_AddrCtrl
		rts

unk_66E7:
		.byte $25
		.byte $84
		.byte $15
		.byte $20
		.byte $E
		.byte $15
		.byte $C
		.byte $18
		.byte $16
		.byte $E
		.byte $24
		.byte $1D
		.byte $18
		.byte $24
		.byte $20
		.byte $A
		.byte $1B
		.byte $19
		.byte $24
		.byte $23
		.byte $18
		.byte $17
		.byte $E
		.byte $2B
		.byte $26
		.byte $2D
		.byte 1
		.byte $24
		.byte $27
		.byte $D9
		.byte $46
		.byte $AA
		.byte $27
		.byte $E1
		.byte $45
		.byte $AA
		.byte 0
NEW_WarpZoneNumbers_MAYBE:
		.byte 2
		.byte 3
		.byte 4
		.byte 1
		.byte 6
		.byte 7
		.byte 8
		.byte 5
		.byte $B
		.byte $C
		.byte $D
GameTextOffsets:
		.byte 0
		.byte $27
		.byte $46
		.byte $51

WriteGameText_NEW:
		pha
		tay
		ldx GameTextOffsets,y
		ldy #0
loc_6722:
		lda WRAM_GameText,x
		cmp #$FF
		beq loc_6730
		sta $301,y
		inx
		iny
		bne loc_6722
loc_6730:
		lda #0
		sta $301,y
		pla
		beq EndOfWriteGameText
		tax
		dex
		bne EndOfWriteGameText
		lda NumberofLives
		clc
		adc #1
		cmp #$A
		bcc LessThan10Lives
		sbc #$A
		ldy #$9F
		sty byte_308
LessThan10Lives:
		sta byte_309
		jsr GetWorldNumber
		sta byte_314
		ldy LevelNumber
		iny
		sty byte_316
EndOfWriteGameText:
		rts

sub_675E:
		pha
		ldy #$FF
loc_6761:

		iny
		lda unk_66E7,y
		sta $301,y
		bne loc_6761
		pla
		sec
		sbc #$80
		tax
		lda NEW_WarpZoneNumbers_MAYBE,x
		sta byte_31C
		lda #$24
		jmp SetVRAMOffset
ResetSpritesAndScreenTimer:

		lda ScreenTimer
		bne NoReset
		jsr MoveAllSpritesOffscreen
ResetScreenTimer:

		lda #7
		sta ScreenTimer
		inc ScreenRoutineTask
NoReset:

		rts
RenderAreaGraphics:

		lda CurrentColumnPos
		and #1
		sta byte_5
		ldy VRAM_Buffer2_Offset
		sty TMP_0
		lda CurrentNTAddr_Low
		sta $342,y
		lda CurrentNTAddr_High
		sta $341,y
		lda #$9A
		sta $343,y
		lda #0
		sta byte_4
		tax
loc_67AD:

		stx TMP_1
		lda $6A1,x
		and #$C0
		sta byte_3
		asl
		rol
		rol
		tay
		lda MetatileGraphics_Low_RELOC,y
		sta byte_6
		lda MetatileGraphics_High_RELOC,y
		sta unk_7
		lda $6A1,x
		asl
		asl
		sta byte_2
		lda AreaParserTaskNum
		and #1
		eor #1
		asl
		adc byte_2
		tay
		ldx TMP_0
		lda (6),y
		sta $344,x
		iny
		lda (6),y
		sta $345,x
		ldy byte_4
		lda byte_5
		bne loc_67F7
		lda TMP_1
		lsr
		bcs loc_6807
		rol byte_3
		rol byte_3
		rol byte_3
		jmp loc_680D
loc_67F7:

		lda TMP_1
		lsr
		bcs loc_680B
		lsr byte_3
		lsr byte_3
		lsr byte_3
		lsr byte_3
		jmp loc_680D
loc_6807:

		lsr byte_3
		lsr byte_3
loc_680B:

		inc byte_4
loc_680D:

		lda $3F9,y
		ora byte_3
		sta $3F9,y
		inc TMP_0
		inc TMP_0
		ldx TMP_1
		inx
		cpx #$D
		bcc loc_67AD
		ldy TMP_0
		iny
		iny
		iny
		lda #0
		sta $341,y
		sty VRAM_Buffer2_Offset
		inc CurrentNTAddr_Low
		lda CurrentNTAddr_Low
		and #$1F
		bne loc_6844
		lda #$80
		sta CurrentNTAddr_Low
		lda CurrentNTAddr_High
		eor #4
		sta CurrentNTAddr_High
loc_6844:

		jmp loc_689A
RenderAttributeTables:

		lda CurrentNTAddr_Low
		and #$1F
		sec
		sbc #4
		and #$1F
		sta TMP_1
		lda CurrentNTAddr_High
		bcs loc_685A
		eor #4
loc_685A:

		and #4
		ora #$23
		sta TMP_0
		lda TMP_1
		lsr
		lsr
		adc #$C0
		sta TMP_1
		ldx #0
		ldy VRAM_Buffer2_Offset
loc_686D:

		lda TMP_0
		sta $341,y
		lda TMP_1
		clc
		adc #8
		sta $342,y
		sta TMP_1
		lda $3F9,x
		sta $344,y
		lda #1
		sta $343,y
		lsr
		sta $3F9,x
		iny
		iny
		iny
		iny
		inx
		cpx #7
		bcc loc_686D
		sta $341,y
		sty VRAM_Buffer2_Offset
loc_689A:

		lda #6
		sta VRAM_Buffer_AddrCtrl
		rts
ColorRotatePalette:
		.byte $27
		.byte $27
		.byte $27
		.byte $17
		.byte 7
		.byte $17
BlankPalette:
		.byte $3F
		.byte $C
		.byte 4
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte 0
Palette3Data:
		.byte $F
		.byte 7
		.byte $12
		.byte $F
		.byte $F
		.byte 7
		.byte $17
		.byte $F
		.byte $F
		.byte 7
		.byte $17
		.byte $1C
		.byte $F
		.byte 7
		.byte $17
		.byte 0
ColorRotation:

		lda FrameCounter
		and #7
		bne locret_6915
		ldx VRAM_Buffer1_Offset
		cpx #$31
		bcs locret_6915
		tay
loc_68CC:

		lda BlankPalette,y
		sta $301,x
		inx
		iny
		cpy #8
		bcc loc_68CC
		ldx VRAM_Buffer1_Offset
		lda #3
		sta TMP_0
		lda AreaType
		asl
		asl
		tay
loc_68E5:

		lda Palette3Data,y
		sta $304,x
		iny
		inx
		dec TMP_0
		bpl loc_68E5
		ldx VRAM_Buffer1_Offset
		ldy ColorRotateOffset
		lda ColorRotatePalette,y
		sta $305,x
		lda VRAM_Buffer1_Offset
		clc
		adc #7
		sta VRAM_Buffer1_Offset
		inc ColorRotateOffset
		lda ColorRotateOffset
		cmp #6
		bcc locret_6915
		lda #0
		sta ColorRotateOffset
locret_6915:

		rts
BlockGfxData:
		.byte $45
		.byte $45
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $57
		.byte $58
		.byte $59
		.byte $5A
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $26
		.byte $26
		.byte $26
		.byte $26

RemoveCoin_Axe:
		ldy #$41
		lda #3
		ldx AreaType
		bne WriteBlankMT
		lda #4
WriteBlankMT:
		jsr PutBlockMetatile
		lda #6
		sta VRAM_Buffer_AddrCtrl
		rts

ReplaceBlockMetatile:
		jsr WriteBlockMetatile
		inc Block_ResidualCounter
		dec Block_RepFlag,x
		rts

DestroyBlockMetatile:
		lda #0
WriteBlockMetatile:
		ldy #3
		cmp #0
		beq loc_6964
		ldy #0
		cmp #$56
		beq loc_6964
		cmp #$4F
		beq loc_6964
		iny
		cmp #$5C
		beq loc_6964
		cmp #$50
		beq loc_6964
		iny
loc_6964:
		tya
		ldy VRAM_Buffer1_Offset
		iny
		jsr PutBlockMetatile
loc_696C:
		dey
		tya
		clc
		adc #$A
		jmp SetVRAMOffset

PutBlockMetatile:
		stx TMP_0
		sty TMP_1
		asl
		asl
		tax
		ldy #$20
		lda byte_6
		cmp #$D0
		bcc loc_6985
		ldy #$24
loc_6985:
		sty byte_3
		and #$F
		asl
		sta byte_4
		lda #0
		sta byte_5
		lda byte_2
		clc
		adc #$20
		asl
		rol byte_5
		asl
		rol byte_5
		adc byte_4
		sta byte_4
		lda byte_5
		adc #0
		clc
		adc byte_3
		sta byte_5
		ldy TMP_1
loc_69AA:
		lda BlockGfxData,x
		sta $303,y
		lda BlockGfxData+1,x
		sta $304,y
		lda BlockGfxData+2,x
		sta $308,y
		lda BlockGfxData+3,x
		sta $309,y
		lda byte_4
		sta $301,y
		clc
		adc #$20
		sta $306,y
		lda byte_5
		sta $300,y
		sta $305,y
		lda #2
		sta $302,y
		sta $307,y
		lda #0
		sta $30A,y
		ldx TMP_0
		rts

MetatileGraphics_Low_RELOC:
		.byte <Palette0_MTiles
		.byte <Palette1_MTiles
		.byte <Palette2_MTiles
		.byte <Palette3_MTiles
MetatileGraphics_High_RELOC:
		.byte >Palette0_MTiles
		.byte >Palette1_MTiles
		.byte >Palette2_MTiles
		.byte >Palette3_MTiles
Palette0_MTiles:
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $27
		.byte $27
		.byte $27
		.byte $27
		.byte $24
		.byte $24
		.byte $24
		.byte $35
		.byte $36
		.byte $25
		.byte $37
		.byte $25
		.byte $24
		.byte $38
		.byte $24
		.byte $24
		.byte $24
		.byte $30
		.byte $30
		.byte $26
		.byte $26
		.byte $26
		.byte $34
		.byte $26
		.byte $24
		.byte $31
		.byte $24
		.byte $32
		.byte $33
		.byte $26
		.byte $24
		.byte $33
		.byte $34
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $24
		.byte $C0
		.byte $24
		.byte $C0
		.byte $24
		.byte $7F
		.byte $7F
		.byte $24
		.byte $B8
		.byte $BA
		.byte $B9
		.byte $BB
		.byte $B8
		.byte $BC
		.byte $B9
		.byte $BD
		.byte $BA
		.byte $BC
		.byte $BB
		.byte $BD
		.byte $60
		.byte $64
		.byte $61
		.byte $65
		.byte $62
		.byte $66
		.byte $63
		.byte $67
		.byte $60
		.byte $64
		.byte $61
		.byte $65
		.byte $62
		.byte $66
		.byte $63
		.byte $67
		.byte $68
		.byte $68
		.byte $69
		.byte $69
		.byte $26
		.byte $26
		.byte $6A
		.byte $6A
		.byte $4B
		.byte $4C
		.byte $4D
		.byte $4E
		.byte $4D
		.byte $4F
		.byte $4D
		.byte $4F
		.byte $4D
		.byte $4E
		.byte $50
		.byte $51
		.byte $86
		.byte $8A
		.byte $87
		.byte $8B
		.byte $88
		.byte $8C
		.byte $88
		.byte $8C
		.byte $89
		.byte $8D
		.byte $69
		.byte $69
		.byte $8E
		.byte $91
		.byte $8F
		.byte $92
		.byte $26
		.byte $93
		.byte $26
		.byte $93
		.byte $90
		.byte $94
		.byte $69
		.byte $69
		.byte $A4
		.byte $E9
		.byte $EA
		.byte $EB
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $2F
		.byte $24
		.byte $3D
		.byte $A2
		.byte $A2
		.byte $A3
		.byte $A3
		.byte $24
		.byte $24
		.byte $24
		.byte $24
Palette1_MTiles:
		.byte $A2
		.byte $A2
		.byte $A3
		.byte $A3
		.byte $99
		.byte $24
		.byte $99
		.byte $24
		.byte $24
		.byte $A2
		.byte $3E
		.byte $3F
		.byte $5B
		.byte $5C
		.byte $24
		.byte $A3
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $9D
		.byte $47
		.byte $9E
		.byte $47
		.byte $47
		.byte $47
		.byte $27
		.byte $27
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $27
		.byte $27
		.byte $47
		.byte $47
		.byte $A9
		.byte $47
		.byte $AA
		.byte $47
		.byte $9B
		.byte $27
		.byte $9C
		.byte $27
		.byte $27
		.byte $27
		.byte $27
		.byte $27
		.byte $52
		.byte $52
		.byte $52
		.byte $52
		.byte $80
		.byte $A0
		.byte $81
		.byte $A1
		.byte $BE
		.byte $BE
		.byte $BF
		.byte $BF
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $45
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $AB
		.byte $AC
		.byte $AD
		.byte $AE
		.byte $5D
		.byte $5E
		.byte $5D
		.byte $5E
		.byte $C1
		.byte $24
		.byte $C1
		.byte $24
		.byte $C6
		.byte $C8
		.byte $C7
		.byte $C9
		.byte $CA
		.byte $CC
		.byte $CB
		.byte $CD
		.byte $2A
		.byte $2A
		.byte $40
		.byte $40
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $47
		.byte $24
		.byte $47
		.byte $82
		.byte $83
		.byte $84
		.byte $85
		.byte $B4
		.byte $B6
		.byte $B5
		.byte $B7
		.byte $24
		.byte $47
		.byte $24
		.byte $47
		.byte $86
		.byte $8A
		.byte $87
		.byte $8B
		.byte $8E
		.byte $91
		.byte $8F
		.byte $92
		.byte $24
		.byte $2F
		.byte $24
		.byte $3D
Palette2_MTiles:
		.byte $24
		.byte $24
		.byte $24
		.byte $35
		.byte $36
		.byte $25
		.byte $37
		.byte $25
		.byte $24
		.byte $38
		.byte $24
		.byte $24
		.byte $24
		.byte $24
		.byte $39
		.byte $24
		.byte $3A
		.byte $24
		.byte $3B
		.byte $24
		.byte $3C
		.byte $24
		.byte $24
		.byte $24
		.byte $41
		.byte $26
		.byte $41
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $B0
		.byte $B1
		.byte $B2
		.byte $B3
		.byte $77
		.byte $79
		.byte $77
		.byte $79
		.byte $6B
		.byte $70
		.byte $2C
		.byte $2D
		.byte $6C
		.byte $71
		.byte $6D
		.byte $72
		.byte $6E
		.byte $73
		.byte $6F
		.byte $74
Palette3_MTiles:
		.byte $53
		.byte $55
		.byte $54
		.byte $56
		.byte $53
		.byte $55
		.byte $54
		.byte $56
		.byte $53
		.byte $55
		.byte $54
		.byte $56
		.byte $A5
		.byte $A7
		.byte $A6
		.byte $A8
		.byte $C2
		.byte $C4
		.byte $C3
		.byte $C5
		.byte $57
		.byte $59
		.byte $58
		.byte $5A
		.byte $7B
		.byte $7D
		.byte $7C
		.byte $7E
unk_6B8D:
		.byte $3F
		.byte 0
		.byte $20
		.byte $F
		.byte $15
		.byte $12
		.byte $25
		.byte $F
		.byte $3A
		.byte $1A
		.byte $F
		.byte $F
		.byte $30
		.byte $12
		.byte $F
		.byte $F
		.byte $27
		.byte $12
		.byte $F
		.byte $22
		.byte $16
		.byte $27
		.byte $18
		.byte $F
		.byte $10
		.byte $30
		.byte $27
		.byte $F
		.byte $16
		.byte $30
		.byte $27
		.byte $F
		.byte $F
		.byte $30
		.byte $10
		.byte 0
unk_6BB1:
		.byte $3F
		.byte 0
		.byte $20
		.byte $F
		.byte $29
		.byte $1A
		.byte $F
		.byte $F
		.byte $36
		.byte $17
		.byte $F
		.byte $F
		.byte $30
		.byte $21
		.byte $F
		.byte $F
		.byte $27
		.byte $17
		.byte $F
		.byte $F
		.byte $16
		.byte $27
		.byte $18
		.byte $F
		.byte $1A
		.byte $30
		.byte $27
		.byte $F
		.byte $16
		.byte $30
		.byte $27
		.byte $F
		.byte $F
		.byte $36
		.byte $17
		.byte 0
unk_6BD5:
		.byte $3F
		.byte 0
		.byte $20
		.byte $F
		.byte $29
		.byte $1A
		.byte 9
		.byte $F
		.byte $3C
		.byte $1C
		.byte $F
		.byte $F
		.byte $30
		.byte $21
		.byte $1C
		.byte $F
		.byte $27
		.byte $17
		.byte $1C
		.byte $F
		.byte $16
		.byte $27
		.byte $18
		.byte $F
		.byte $1C
		.byte $36
		.byte $17
		.byte $F
		.byte $16
		.byte $30
		.byte $27
		.byte $F
		.byte $C
		.byte $3C
		.byte $1C
		.byte 0
unk_6BF9:
		.byte $3F
		.byte 0
		.byte $20
		.byte $F
		.byte $30
		.byte $10
		.byte 0
		.byte $F
		.byte $30
		.byte $10
		.byte 0
		.byte $F
		.byte $30
		.byte $16
		.byte 0
		.byte $F
		.byte $27
		.byte $17
		.byte 0
		.byte $F
		.byte $16
		.byte $27
		.byte $18
		.byte $F
		.byte $1C
		.byte $36
		.byte $17
		.byte $F
		.byte $16
		.byte $30
		.byte $27
		.byte $F
		.byte 0
		.byte $30
		.byte $10
		.byte 0
word_6C1D:
		.word $3F
		.byte 4
byte_6C20:
		.byte $22
		.byte $30
		.byte 0
		.byte $10
		.byte 0
unk_6C25:
		.byte $3F
		.byte 0
		.byte 4
		.byte $F
		.byte $30
		.byte 0
		.byte $10
		.byte 0
unk_6C2D:
		.byte $3F
		.byte 0
		.byte 4
		.byte $22
		.byte $27
		.byte $16
		.byte $F
		.byte 0
unk_6C35:
		.byte $3F
		.byte $14
		.byte 4
		.byte $F
		.byte $1A
		.byte $30
		.byte $27
		.byte 0
unk_6C51:
		.byte $25
		.byte $C5
		.byte $16
		.byte $B
		.byte $1E
		.byte $1D
		.byte $24
		.byte $18
		.byte $1E
		.byte $1B
		.byte $24
		.byte $19
		.byte $1B
		.byte $12
		.byte $17
		.byte $C
		.byte $E
		.byte $1C
		.byte $1C
		.byte $24
		.byte $12
		.byte $1C
		.byte $24
		.byte $12
		.byte $17
		.byte $26
		.byte 5
		.byte $F
		.byte $A
		.byte $17
		.byte $18
		.byte $1D
		.byte $11
		.byte $E
		.byte $1B
		.byte $24
		.byte $C
		.byte $A
		.byte $1C
		.byte $1D
		.byte $15
		.byte $E
		.byte $2B
		.byte 0
JumpEngine:

		asl
		tay
		pla
		sta byte_4
		pla
		sta byte_5
		iny
		lda (4),y
		sta byte_6
		iny
		lda (4),y
		sta unk_7
		jmp (byte_6)
InitializeNameTables:

		lda PPU_STATUS
		lda Mirror_PPU_CTRL_REG1
		ora #$10
		and #$F0
		jsr WritePPUReg1
		lda #$24
		jsr sub_6CA6
		lda #$20
sub_6CA6:

		sta PPU_ADDRESS
		lda #0
		sta PPU_ADDRESS
		ldx #4
		ldy #$C0
		lda #$24
loc_6CB4:

		sta PPU_DATA
		dey
		bne loc_6CB4
		dex
		bne loc_6CB4
		ldy #$40
		txa
		sta VRAM_Buffer1_Offset
		sta VRAM_Buffer1
loc_6CC6:

		sta PPU_DATA
		dey
		bne loc_6CC6
		sta HorizontalScroll
		sta VerticalScroll
		jmp InitScroll
ReadJoypads:

		lda #1
		sta JOYPAD_PORT1
		lsr
		tax
		sta JOYPAD_PORT1
		jsr ReadPortBits
		inx
ReadPortBits:

		ldy #8
loc_6CE5:

		pha
		lda JOYPAD_PORT1,x
		sta TMP_0
		lsr
		ora TMP_0
		lsr
		pla
		rol
		dey
		bne loc_6CE5
		sta SavedJoypad1Bits,x
		pha
		and #$30
		and JoypadBitMask,x
		beq loc_6D06
		pla
		and #$CF
		sta SavedJoypad1Bits,x
		rts
loc_6D06:

		pla
		sta JoypadBitMask,x
		rts

WriteBufferToScreen:
		sta PPU_ADDRESS
		iny
		lda (0),y
		sta PPU_ADDRESS
		iny
		lda (0),y
		asl
		pha
		lda Mirror_PPU_CTRL_REG1
		ora #4
		bcs loc_6D22
		and #$FB
loc_6D22:
		jsr WritePPUReg1
		pla
		asl
		bcc loc_6D2C
		ora #2
		iny
loc_6D2C:
		lsr
		lsr
		tax
loc_6D2F:
		bcs loc_6D32
		iny
loc_6D32:
		lda (0),y
		sta PPU_DATA
		dex
		bne loc_6D2F
		sec
		tya
		adc TMP_0
		sta TMP_0
		lda #0
		adc TMP_1
		sta TMP_1
		lda #$3F
		sta PPU_ADDRESS
		lda #0
		sta PPU_ADDRESS
		sta PPU_ADDRESS
		sta PPU_ADDRESS
UpdateScreen:
		ldx PPU_STATUS
		ldy #0
		lda (0),y
		bne WriteBufferToScreen
InitScroll:
		sta PPU_SCROLL_REG
		sta PPU_SCROLL_REG
		rts
WritePPUReg1:
		sta PPU_CTRL_REG1
		sta Mirror_PPU_CTRL_REG1
		rts

StatusBarData:
		.byte $EF
unk_6D6E:
		.byte 6
		.byte $62
		.byte 6
		.byte $6D
		.byte 2
		.byte $7A
		.byte 3
unk_6D75:
		.byte 6
		.byte $C
		.byte $12
		.byte $18
PrintStatusBarNumbers:

		sta TMP_0
		jsr OutputNumbers
		lda TMP_0
		lsr
		lsr
		lsr
		lsr
OutputNumbers:

		clc
		adc #1
		and #$F
		cmp #6
		bcs locret_6DD1
		pha
		asl
		tay
		ldx VRAM_Buffer1_Offset
		lda #$20
		cpy #0
		bne loc_6D9B
		lda #$22
loc_6D9B:

		sta VRAM_Buffer1,x
		lda StatusBarData,y
		sta VRAM_Buffer1+1,x
		lda unk_6D6E,y
		sta $303,x
		sta byte_3
		stx byte_2
		pla
		tax
		lda unk_6D75,x
		sec
		sbc unk_6D6E,y
		tay
		ldx byte_2
loc_6DBA:

		lda $7D7,y
		sta $304,x
		inx
		iny
		dec byte_3
		bne loc_6DBA
		lda #0
		sta $304,x
		inx
		inx
		inx
		stx VRAM_Buffer1_Offset
locret_6DD1:

		rts
DigitsMathRoutine:

		lda OperMode
		beq loc_6DED
		ldx #5
loc_6DD9:

		lda DigitModifier,x
		clc
		adc TopScoreDisplay,y
		bmi loc_6DF8
		cmp #$A
		bcs loc_6DFF
loc_6DE6:

		sta TopScoreDisplay,y
		dey
		dex
		bpl loc_6DD9
loc_6DED:

		lda #0
		ldx #6
loc_6DF1:

		sta $133,x
		dex
		bpl loc_6DF1
		rts
loc_6DF8:

		dec $133,x
		lda #9
		bne loc_6DE6
loc_6DFF:

		sec
		sbc #$A
		inc $133,x
		jmp loc_6DE6
UpdateTopScore:

		ldx #5
		ldy #5
		sec
loc_6E0D:

		lda $7DD,x
		sbc $7D7,y
		dex
		dey
		bpl loc_6E0D
		bcc locret_6E27
		inx
		iny
loc_6E1B:

		lda $7DD,x
		sta $7D7,y
		inx
		iny
		cpy #6
		bcc loc_6E1B
locret_6E27:

		rts
		.byte $FF
		.byte $FF
unk_6E2A:
		.byte 4
		.byte $30
		.byte $48
		.byte $60
		.byte $78
		.byte $90
		.byte $A8
		.byte $C0
		.byte $D8
		.byte $E8
		.byte $24
		.byte $F8
		.byte $FC
		.byte $28
		.byte $2C
InitializeArea:

		ldy #$4B
		jsr InitializeMemory
		ldx #$21
		lda #0
loc_6E42:

		sta SelectTimer,x
		dex
		bpl loc_6E42
		lda HalfwayPage
		ldy AltEntranceControl
		beq loc_6E53
		lda EntrancePage
loc_6E53:

		sta ScreenLeft_PageLoc
		sta CurrentPageLoc
		sta BackloadingFlag
		jsr sub_7B90
		ldy #$20
		and #1
		beq loc_6E67
		ldy #$24
loc_6E67:
		sty CurrentNTAddr_High
		ldy #$80
		sty CurrentNTAddr_Low
		asl
		asl
		asl
		asl
		sta BlockBufferColumnPos
		dec AreaObjectLength
		dec byte_731
		dec byte_732
		lda #$B
		sta ColumnSets
		jsr GetAreaDataAddrs_NEW
		lda IsPlayingExtendedWorlds
		bne loc_6E9C
		lda WorldNumber
		cmp #3
		bcc loc_6E9F
		bne loc_6E9C
		lda LevelNumber
		cmp #3
		bcc loc_6E9F
loc_6E9C:
		inc SecondaryHardMode
loc_6E9F:
		lda HalfwayPage
		beq loc_6EA9
		lda #2
		sta PlayerEntranceCtrl
loc_6EA9:
		lda #$80
		sta AreaMusicQueue
		lda #1
		sta DisableScreenFlag
		jsr PatchLuigiOrMarioPhysics_NEW
		inc OperMode_Task
		rts

SecondaryGameSetup:
		lda #0
		sta DisableScreenFlag
		sta byte_7F9
		sta byte_7F6
		tay
loc_6EC5:
		sta $300,y
		iny
		bne loc_6EC5
		sta GameTimerExpiredFlag
		sta DisableIntermediate
		sta BackloadingFlag
		lda #$FF
		sta BalPlatformAlignment
		lda ScreenLeft_PageLoc
		and #1
		sta UseNtBase2400
		jsr sub_6F2D
		lda #$38
		sta byte_6E3
		lda #$48
		sta byte_6E2
		lda #$58
		sta SprShuffleAmt
		ldx #$E
loc_6EF5:
		lda unk_6E2A,x
		sta $6E4,x
		dex
		bpl loc_6EF5

		ldx #3
CopyMoreSprite0Data:
		lda Sprite0Data, x
		sta $200, x
		dex
		bpl CopyMoreSprite0Data

		jsr sub_70BB
		inc Sprite0HitDetectFlag
		inc OperMode_Task
		rts

Sprite0Data:
		.byte $17, $6b, $23, $58

InitializeMemory:
		ldx #7
		lda #0
		sta byte_6
loc_6F0E:

		stx unk_7
loc_6F10:

		cpx #1
		bne loc_6F1C
		cpy #$60
		bcs loc_6F1E
		cpy #9
		bcc loc_6F1E
loc_6F1C:

		sta (6),y
loc_6F1E:

		dey
		cpy #$FF
		bne loc_6F10
		dex
		bpl loc_6F0E
		rts
byte_6F27:
		.byte 2
		.byte 1
		.byte 4
		.byte 8
		.byte $10
		.byte $20
sub_6F2D:

		lda OperMode
		beq locret_6F55
		lda AltEntranceControl
		cmp #2
		beq loc_6F46
		ldy #5
		lda PlayerEntranceCtrl
		cmp #6
		beq loc_6F50
		cmp #7
		beq loc_6F50
loc_6F46:

		ldy AreaType
		lda CloudTypeOverride
		beq loc_6F50
		ldy #4
loc_6F50:

		lda byte_6F27,y
		sta AreaMusicQueue
locret_6F55:

		rts
byte_6F56:
		.byte $28
		.byte $18
byte_6F58:
		.byte $38
		.byte $28
		.byte 8
		.byte 0
byte_6F5C:
		.byte 0
		.byte $20
		.byte $B0
		.byte $50
		.byte 0
		.byte 0
		.byte $B0
		.byte $B0
		.byte $F0
unk_6F65:
		.byte 0
		.byte $20
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
unk_6F6D:
		.byte $20
		.byte 4
		.byte 3
		.byte 2
Entrance_GameTimerSetup:

		lda ScreenLeft_PageLoc
		sta Player_PageLoc
		lda #$28
		sta VerticalForceDown
		lda #1
		sta PlayerFacingDir
		sta Player_Y_HighPos
		lda #0
		sta Player_State
		dec Player_CollisionBits
		ldy #0
		sty HalfwayPage
		lda AreaType
		bne loc_6F93
		iny
loc_6F93:

		sty SwimmingFlag
		ldx PlayerEntranceCtrl
		ldy AltEntranceControl
		beq loc_6FA5
		cpy #1
		beq loc_6FA5
		ldx byte_6F58,y
loc_6FA5:

		lda byte_6F56,y
		sta Player_X_Position
		lda byte_6F5C,x
		sta SprObject_Y_Position
		lda unk_6F65,x
		sta Player_SprAttrib
		jsr GetPlayerColors_RW
		ldy GameTimerSetting
		beq loc_6FD7
		lda FetchNewGameTimerFlag
		beq loc_6FD7
		lda unk_6F6D,y
		sta byte_7EC
		lda #1
		sta byte_7EE
		lsr
		sta byte_7ED
		sta FetchNewGameTimerFlag
		sta StarInvincibleTimer
loc_6FD7:

		ldy JoypadOverride
		beq loc_6FF0
		lda #3
		sta Player_State
		ldx #0
		jsr sub_8945
		lda #$F0
		sta Block_Y_Position
		ldx #5
		ldy #0
		jsr Setup_Vine
loc_6FF0:

		ldy AreaType
		bne loc_6FF8
		jsr SetupBubble
loc_6FF8:

		lda #7
		sta GameEngineSubroutine
		rts


PlayerLoseLife:
		inc DisableScreenFlag
		lda #0
		sta Sprite0HitDetectFlag
		lda #$80
		sta EventMusicQueue
		dec NumberofLives
		bpl StillInGame
		lda #0
		sta OperMode_Task
		lda #3
		sta OperMode
		rts
StillInGame:

		lda WorldNumber
		asl
		tax
		lda LevelNumber
		and #2
		beq loc_7038
		inx
loc_7038:

		ldy WRAM_HalfwayPageNybbles,x
		lda LevelNumber
		lsr
		tya
		bcs loc_7046
		lsr
		lsr
		lsr
		lsr
loc_7046:

		and #$F
		cmp ScreenLeft_PageLoc
		beq loc_7051
		bcc loc_7051
		lda #0
loc_7051:

		sta HalfwayPage
		jmp loc_709D
GameOverMode:

		lda OperMode_Task
		jsr JumpEngine
		.word SetupGameOver
		.word ScreenRoutines
		.word RunGameOver
SetupGameOver:

		lda #0
		sta ScreenRoutineTask
		sta Sprite0HitDetectFlag
		sta GameTimerDisplay_OBSOLETE
		lda #2
		sta EventMusicQueue
		inc DisableScreenFlag
		inc OperMode_Task
		rts
RunGameOver:

		lda #0
		sta DisableScreenFlag
		lda WorldNumber
		cmp #8
		beq loc_7088
		jmp loc_C1C2
loc_7088:

		lda ScreenTimer
		bne locret_709C
sub_708D:

		lda #$80
		sta EventMusicQueue
		lda #0
		sta OperMode_Task
		sta ScreenTimer
		sta OperMode
locret_709C:

		rts
loc_709D:

		jsr LoadAreaPointer
		lda #1
		sta PlayerSize
		inc FetchNewGameTimerFlag
		lda #0
		sta TimerControl
sub_70AD:

		sta PlayerStatus
		sta GameEngineSubroutine
		sta OperMode_Task
		lda #1
		sta OperMode
		rts
sub_70BB:

		lda #$FF
		sta byte_6C9
		rts
AreaParserTaskHandler:

		ldy AreaParserTaskNum
		bne loc_70CB
		ldy #8
		sty AreaParserTaskNum
loc_70CB:

		dey
		tya
		jsr AreaParserTasks
		dec AreaParserTaskNum
		bne locret_70D8
		jsr RenderAttributeTables
locret_70D8:

		rts
AreaParserTasks:

		jsr JumpEngine
		.word IncrementColumnPos
		.word RenderAreaGraphics
		.word RenderAreaGraphics
		.word AreaParserCore
		.word IncrementColumnPos
		.word RenderAreaGraphics
		.word RenderAreaGraphics
		.word AreaParserCore
IncrementColumnPos:

		inc CurrentColumnPos
		lda CurrentColumnPos
		and #$F
		bne NoColWrap
		sta CurrentColumnPos
		inc CurrentPageLoc
NoColWrap:

		inc BlockBufferColumnPos
		lda BlockBufferColumnPos
		and #$1F
		sta BlockBufferColumnPos
locret_7107:

		rts
		.byte 0
		.byte $30
		.byte $60
unk_710B:
		.byte $93
		.byte 0
		.byte 0
		.byte $11
		.byte $12
		.byte $12
		.byte $13
		.byte 0
		.byte 0
		.byte $51
		.byte $52
		.byte $53
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 1
		.byte 2
		.byte 2
		.byte 3
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $91
		.byte $92
		.byte $93
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $51
		.byte $52
		.byte $53
		.byte $41
		.byte $42
		.byte $43
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $91
		.byte $92
		.byte $97
		.byte $87
		.byte $88
		.byte $89
		.byte $99
		.byte 0
		.byte 0
		.byte 0
		.byte $11
		.byte $12
		.byte $13
		.byte $A4
		.byte $A5
		.byte $A5
		.byte $A5
		.byte $A6
		.byte $97
		.byte $98
		.byte $99
		.byte 1
		.byte 2
		.byte 3
		.byte 0
		.byte $A4
		.byte $A5
		.byte $A6
		.byte 0
		.byte $11
		.byte $12
		.byte $12
		.byte $12
		.byte $13
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 1
		.byte 2
		.byte 2
		.byte 3
		.byte 0
		.byte $A4
		.byte $A5
		.byte $A5
		.byte $A6
		.byte 0
		.byte 0
		.byte 0
		.byte $11
		.byte $12
		.byte $12
		.byte $13
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $9C
		.byte 0
		.byte $8B
		.byte $AA
		.byte $AA
		.byte $AA
		.byte $AA
		.byte $11
		.byte $12
		.byte $13
		.byte $8B
		.byte 0
		.byte $9C
		.byte $9C
		.byte 0
		.byte 0
		.byte 1
		.byte 2
		.byte 3
		.byte $11
		.byte $12
		.byte $12
		.byte $13
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $AA
		.byte $AA
		.byte $9C
		.byte $AA
		.byte 0
		.byte $8B
		.byte 0
		.byte 1
		.byte 2
		.byte 3
unk_719B:
		.byte $80
		.byte $83
		.byte 0
		.byte $81
		.byte $84
		.byte 0
		.byte $82
		.byte $85
		.byte 0
		.byte 2
		.byte 0
		.byte 0
		.byte 3
		.byte 0
		.byte 0
		.byte 4
		.byte 0
		.byte 0
		.byte 0
		.byte 5
		.byte 6
		.byte 7
		.byte 6
		.byte $A
		.byte 0
		.byte 8
		.byte 9
		.byte $4D
		.byte 0
		.byte 0
		.byte $D
		.byte $F
		.byte $4E
		.byte $E
		.byte $4E
unk_71BE:
		.byte $4E
		.byte 0
		.byte $D
		.byte $1A
unk_71C2:
		.byte $86
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $87
		.byte $6A
		.byte $6A
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $45
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $86
		.byte $87
unk_71E9:
		.byte $6A
		.byte $6B
		.byte $50
		.byte $63
unk_71ED:
		.byte 0
		.byte 0
		.byte 0
		.byte $18
		.byte 1
		.byte $18
		.byte 7
		.byte $18
		.byte $F
		.byte $18
		.byte $FF
		.byte $18
		.byte 1
		.byte $1F
		.byte 7
		.byte $1F
		.byte $F
		.byte $1F
		.byte $81
		.byte $1F
		.byte 1
		.byte 0
		.byte $8F
		.byte $1F
		.byte $F1
		.byte $1F
		.byte $F9
		.byte $18
		.byte $F1
		.byte $18
		.byte $FF
		.byte $1F
AreaParserCore:

		lda BackloadingFlag
		beq RenderSceneryTerrain
		jsr ProcessAreaData
RenderSceneryTerrain:

		ldx #$C
		lda #0
loc_7219:

		sta $6A1,x
		dex
		bpl loc_7219
		ldy BackgroundScenery
		beq loc_7266
		lda CurrentPageLoc
loc_7227:

		cmp #3
		bmi loc_7230
		sec
		sbc #3
		bpl loc_7227
loc_7230:

		asl
		asl
		asl
		asl
		adc locret_7107,y
		adc CurrentColumnPos
		tax
		lda unk_710B,x
		beq loc_7266
		pha
		and #$F
		sec
		sbc #1
		sta TMP_0
		asl
		adc TMP_0
		tax
		pla
		lsr
		lsr
		lsr
		lsr
		tay
		lda #3
		sta TMP_0
loc_7256:

		lda unk_719B,x
		sta $6A1,y
		inx
		iny
		cpy #$B
		beq loc_7266
		dec TMP_0
		bne loc_7256
loc_7266:

		ldx ForegroundScenery
		beq loc_727E
		ldy unk_71BE,x
		ldx #0
loc_7270:

		lda unk_71C2,y
		beq loc_7278
		sta $6A1,x
loc_7278:

		iny
		inx
		cpx #$D
		bne loc_7270
loc_727E:

		ldy AreaType
		bne loc_728F
		lda WorldNumber
		cmp #7
		bne loc_728F
		lda #$63
		jmp loc_7299
loc_728F:

		lda unk_71E9,y
		ldy CloudTypeOverride
		beq loc_7299
		lda #$88
loc_7299:

		sta unk_7
		ldx #0
		lda TerrainControl
		asl
		tay
loc_72A2:

		lda unk_71ED,y
		sta TMP_0
		iny
		sty TMP_1
		lda CloudTypeOverride
		beq loc_72B9
		cpx #0
		beq loc_72B9
		lda TMP_0
		and #8
		sta TMP_0
loc_72B9:

		ldy #0
loc_72BB:

		lda Bitmasks,y
		bit TMP_0
		beq loc_72C7
		lda unk_7
		sta $6A1,x
loc_72C7:

		inx
		cpx #$D
		beq loc_72E4
		lda AreaType
		cmp #2
		bne loc_72DB
		cpx #$B
		bne loc_72DB
		lda #$6B
		sta unk_7
loc_72DB:

		iny
		cpy #8
		bne loc_72BB
		ldy TMP_1
		bne loc_72A2
loc_72E4:

		jsr ProcessAreaData
		lda BlockBufferColumnPos
		jsr GetBlockBufferAddr
		ldx #0
		ldy #0
loc_72F1:

		sty TMP_0
		lda $6A1,x
		and #$C0
		asl
		rol
		rol
		tay
		lda $6A1,x
		cmp unk_7315,y
		bcs loc_7306
		lda #0
loc_7306:

		ldy TMP_0
		sta (6),y
		tya
		clc
		adc #$10
		tay
		inx
		cpx #$D
		bcc loc_72F1
		rts
unk_7315:
		.byte $10
		.byte $4F
		.byte $88
		.byte $C0
ProcessAreaData:

		ldx #2
loc_731B:

		stx ObjectOffset
		lda #0
		sta BehindAreaParserFlag
		ldy AreaDataOffset
		lda ($E7),y
		cmp #$FD
		beq loc_7376
		lda $730,x
		bpl loc_7376
		iny
		lda ($E7),y
		asl
		bcc loc_7341
		lda AreaObjectPageSel
		bne loc_7341
		inc AreaObjectPageSel
		inc AreaObjectPageLoc
loc_7341:

		dey
		lda ($E7),y
		and #$F
		cmp #$D
		bne loc_7365
		iny
		lda ($E7),y
		dey
		and #$40
		bne loc_736E
		lda AreaObjectPageSel
		bne loc_736E
		iny
		lda ($E7),y
		and #$1F
		sta AreaObjectPageLoc
		inc AreaObjectPageSel
		jmp loc_737F
loc_7365:

		cmp #$E
		bne loc_736E
		lda BackloadingFlag
		bne loc_7376
loc_736E:

		lda AreaObjectPageLoc
		cmp CurrentPageLoc
		bcc loc_737C
loc_7376:

		jsr DecodeAreaData
		jmp loc_7382
loc_737C:

		inc BehindAreaParserFlag
loc_737F:

		jsr IncAreaObjOffset
loc_7382:

		ldx ObjectOffset
		lda AreaObjectLength,x
		bmi loc_738C
		dec AreaObjectLength,x
loc_738C:

		dex
		bpl loc_731B
		lda BehindAreaParserFlag
		bne ProcessAreaData
		lda BackloadingFlag
		bne ProcessAreaData
locret_7399:

		rts
IncAreaObjOffset:

		inc AreaDataOffset
		inc AreaDataOffset
		lda #0
		sta AreaObjectPageSel
		rts
DecodeAreaData:

		lda AreaObjectLength,x
		bmi loc_73AE
		ldy AreaObjOffsetBuffer,x
loc_73AE:

		ldx #$10
		lda (AreaDataLow),y
		cmp #$FD
		beq locret_7399
		and #$F
		cmp #$F
		beq loc_73C4
		ldx #8
		cmp #$C
		beq loc_73C4
		ldx #0
loc_73C4:

		stx unk_7
		ldx ObjectOffset
		cmp #$E
		bne loc_73D4
		lda #0
		sta unk_7
		lda #$36
		bne loc_7427
loc_73D4:

		cmp #$D
		bne loc_73F3
		lda #$28
		sta unk_7
		iny
		lda (AreaDataLow),y
		and #$40
		beq locret_7446
		lda (AreaDataLow),y
		and #$7F
		cmp #$4B
		bne loc_73EE
		inc LoopCommand
loc_73EE:

		and #$3F
		jmp loc_7427
loc_73F3:

		cmp #$C
		bcs loc_741E
		iny
		lda ($E7),y
		and #$70
		bne loc_7409
		lda #$18
		sta unk_7
		lda ($E7),y
		and #$F
		jmp loc_7427
loc_7409:

		sta TMP_0
		cmp #$70
		bne loc_7419
		lda ($E7),y
		and #8
		beq loc_7419
		lda #0
		sta TMP_0
loc_7419:

		lda TMP_0
		jmp loc_7423
loc_741E:

		iny
		lda ($E7),y
		and #$70
loc_7423:

		lsr
		lsr
		lsr
		lsr
loc_7427:

		sta TMP_0
		lda $730,x
		bpl loc_7470
		lda AreaObjectPageLoc
		cmp CurrentPageLoc
		beq loc_7447
		ldy AreaDataOffset
		lda ($E7),y
		and #$F
		cmp #$E
		bne locret_7446
		lda BackloadingFlag
		bne loc_7467
locret_7446:

		rts
loc_7447:

		lda BackloadingFlag
		beq loc_7457
		lda #0
		sta BackloadingFlag
		sta BehindAreaParserFlag
		sta ObjectOffset
LoopCmdE:

		rts
loc_7457:

		ldy AreaDataOffset
		lda ($E7),y
		and #$F0
		lsr
		lsr
		lsr
		lsr
		cmp CurrentColumnPos
		bne locret_7446
loc_7467:

		lda AreaDataOffset
		sta AreaObjOffsetBuffer,x
		jsr IncAreaObjOffset
loc_7470:

		lda TMP_0
		clc
		adc unk_7
		jsr JumpEngine
		.word VerticalPipe
		.word AreaStyleObject
		.word RowOfBricks
		.word RowOfSolidBlocks
		.word RowOfCoins
		.word ColumnOfBricks
		.word ColumnOfSolidBlocks
		.word VerticalPipe
		.word Hole_Empty
		.word PulleyRopeObject
		.word Bridge_High
		.word Bridge_Middle_NODIRECT+1
		.word Bridge_Low_NODIRECT+1
		.word Hole_Water
		.word QuestionBlockRow_High
		.word QuestionBlockRow_Low_NODIRECT+1
		.word EndlessRope
		.word BalancePlatRope
		.word CastleObject
		.word StaircaseObject
		.word ExitPipe
		.word FlagBalls_Residual
		.word GameMenuRoutine_NEW+2 ; SM2DATA2 VerticalPipeUpsideDown
		.word GameMenuRoutineInner_NEW
		.word QuestionBlock
		.word QuestionBlock
		.word QuestionBlock
		.word QuestionBlock
		.word Hidden1UpBlock
		.word QuestionBlock
		.word QuestionBlock
		.word BrickWithItem
		.word BrickWithItem
		.word BrickWithItem
		.word BrickWithItem
		.word BrickWithCoins
		.word BrickWithItem
		.word WaterPipe
		.word EmptyBlock
		.word Jumpspring
		.word IntroPipe
		.word FlagpoleObject
		.word AxeObj
		.word ChainObj
		.word CastleBridgeObj
		.word XXX_ScrollLockObject_Warp_RW_POSS
		.word ScrollLockObject
		.word ScrollLockObject
		.word AreaFrenzy
		.word AreaFrenzy
		.word AreaFrenzy
		.word LoopCmdE
		.word UNBANKED_FIX_ME_0
		.word UNBANKED_FIX_ME_1
		.word AlterAreaAttributes

UNBANKED_FIX_ME_0:
UNBANKED_FIX_ME_1:
		jmp UNBANKED_FIX_ME_0

AlterAreaAttributes:

		ldy AreaObjOffsetBuffer,x
		iny
		lda ($E7),y
		pha
		and #$40
		bne loc_7503
		pla
		pha
		and #$F
		sta TerrainControl
		pla
		and #$30
		lsr
		lsr
		lsr
		lsr
		sta BackgroundScenery
		rts
loc_7503:

		pla
		and #7
		cmp #4
		bcc loc_750F
		sta BackgroundColorCtrl
		lda #0
loc_750F:

		sta ForegroundScenery
		rts
XXX_ScrollLockObject_Warp_RW_POSS:

		ldx #$80
		lda IsPlayingExtendedWorlds
		bne loc_752F
		lda WorldNumber
		bne loc_7537
		ldy AreaType
		dey
		beq loc_752B
		lda AreaAddrsLOffset
		beq loc_752C
		inx
loc_752B:

		inx
loc_752C:

		jmp loc_7558
loc_752F:

		lda #$87
		clc
		adc LevelNumber
		bne loc_7559
loc_7537:

		ldx #$83
		lda WorldNumber
		cmp #2
		beq loc_7558
		inx
		cmp #4
		bne loc_7555
		lda AreaAddrsLOffset
		cmp #$B
		beq loc_7558
		ldy AreaType
		dey
		beq loc_7556
		jmp loc_7557
loc_7555:

		inx
loc_7556:

		inx
loc_7557:

		inx
loc_7558:

		txa
loc_7559:

		sta WarpZoneControl
		jsr sub_675E
		lda #$D
		jsr sub_756D
ScrollLockObject:

		lda ScrollLock
		eor #1
		sta ScrollLock
		rts
sub_756D:

		sta TMP_0
		lda #0
		ldx #4
loc_7573:

		ldy $16,x
		cpy TMP_0
		bne loc_757B
		sta $F,x
loc_757B:

		dex
		bpl loc_7573
		rts
FrenzyIDData:
		.byte $14
		.byte $17
		.byte $18
AreaFrenzy:

		ldx TMP_0
		lda FrenzyIDData-8,x
		ldy #5
loc_7589:

		dey
		bmi loc_7593
		cmp Enemy_ID,y
		bne loc_7589
		lda #0
loc_7593:

		sta EnemyFrenzyQueue
		rts
AreaStyleObject:

		lda AreaStyle
		jsr JumpEngine
		.word TreeLedge
		.word MushroomLedge
		.word BulletBillCannon
TreeLedge:

		jsr GetLrgObjAttrib
		lda $730,x
		beq loc_75CA
		bpl loc_75BE
		tya
		sta $730,x
		lda CurrentPageLoc
		ora CurrentColumnPos
		beq loc_75BE
		lda #$16
		jmp loc_75FC
loc_75BE:

		ldx unk_7
		lda #$17
		sta $6A1,x
		lda #$4C
		jmp loc_75F6
loc_75CA:

		lda #$18
		jmp loc_75FC
MushroomLedge:

		jsr ChkLrgObjLength
		sty byte_6
		bcc loc_75E2
		lda AreaObjectLength,x
		lsr
		sta MushroomLedgeHalfLen,x
		lda #$8A
		jmp loc_75FC
loc_75E2:

		lda #$8C
		ldy AreaObjectLength,x
		beq loc_75FC
		lda MushroomLedgeHalfLen,x
		sta byte_6
		ldx unk_7
		lda #$8B
		sta MetatileBuffer,x
		rts
loc_75F6:

		inx
		ldy #$F
		jmp RenderUnderPart
loc_75FC:

		ldx unk_7
		ldy #0
		jmp RenderUnderPart
unk_7603:
		.byte $42
		.byte $41
		.byte $43
PulleyRopeObject:

		jsr ChkLrgObjLength
		ldy #0
		bcs loc_7614
		iny
		lda AreaObjectLength,x
		bne loc_7614
		iny
loc_7614:

		lda unk_7603,y
		sta MetatileBuffer
		rts
unk_761B:
		.byte 0
		.byte $45
		.byte $45
		.byte $45
		.byte 0
		.byte 0
		.byte $48
		.byte $47
		.byte $46
		.byte 0
		.byte $45
		.byte $49
		.byte $49
		.byte $49
		.byte $45
		.byte $47
		.byte $47
		.byte $4A
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $4B
		.byte $47
		.byte $47
		.byte $49
		.byte $49
		.byte $49
		.byte $49
		.byte $49
		.byte $47
		.byte $4A
		.byte $47
		.byte $4A
		.byte $47
		.byte $47
		.byte $4B
		.byte $47
		.byte $4B
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $47
		.byte $4A
		.byte $47
		.byte $4A
		.byte $47
		.byte $4A
		.byte $4B
		.byte $47
		.byte $4B
		.byte $47
		.byte $4B
CastleObject:

		jsr GetLrgObjAttrib
		sty unk_7
		ldy #4
		jsr ChkLrgObjFixedLength
		txa
		pha
		ldy AreaObjectLength,x
		ldx unk_7
		lda #$B
		sta byte_6
loc_7667:

		lda unk_761B,y
		sta MetatileBuffer,x
		inx
		lda byte_6
		beq loc_7679
		iny
		iny
		iny
		iny
		iny
		dec byte_6
loc_7679:

		cpx #$B
		bne loc_7667
		pla
		tax
		lda CurrentPageLoc
		beq locret_76BA
		lda AreaObjectLength,x
		cmp #1
		beq loc_76B5
		ldy unk_7
		bne loc_7693
		cmp #3
		beq loc_76B5
loc_7693:

		cmp #2
		bne locret_76BA
		jsr GetAreaObjXPosition
		pha
		jsr FindEmptyEnemySlot
		pla
		sta $87,x
		lda CurrentPageLoc
		sta $6E,x
		lda #1
		sta $B6,x
		sta $F,x
		lda #$90
		sta $CF,x
		lda #$31
		sta $16,x
		rts
loc_76B5:

		ldy #$50
		sty byte_6AB
locret_76BA:

		rts
WaterPipe:

		jsr GetLrgObjAttrib
		ldy AreaObjectLength,x
		ldx unk_7
		lda #$6D
		sta MetatileBuffer,x
		lda #$6E
		sta unk_6A2,x
		rts
IntroPipe:

		ldy #3
		jsr ChkLrgObjFixedLength
		ldy #$A
		jsr RenderSidewaysPipe
		bcs locret_76EA
		ldx #6
loc_76DC:

		lda #0
		sta MetatileBuffer,x
		dex
		bpl loc_76DC
		lda VerticalPipeData,y
		sta byte_6A8
locret_76EA:

		rts
SidePipeShaftData:
		.byte $15
		.byte $14
		.byte 0
		.byte 0
SidePipeTopPart:
		.byte $15
		.byte $1B
		.byte $1A
		.byte $19
SidePipeBottomPart:
		.byte $15
		.byte $1E
		.byte $1D
		.byte $1C
ExitPipe:

		ldy #3
		jsr ChkLrgObjFixedLength
		jsr GetLrgObjAttrib
RenderSidewaysPipe:

		dey
		dey
		sty byte_5
		ldy $730,x
		sty byte_6
		ldx byte_5
		inx
		lda SidePipeShaftData,y
		cmp #0
		beq loc_771A
		ldx #0
		ldy byte_5
		jsr RenderUnderPart
		clc
loc_771A:

		ldy byte_6
		lda SidePipeTopPart,y
		sta $6A1,x
		lda SidePipeBottomPart,y
		sta $6A2,x
		rts
VerticalPipeData:
		.byte $11
		.byte $10
VerticalPipeDataOff2:
		.byte $15
		.byte $14
		.byte $13
		.byte $12
		.byte $15
		.byte $14
VerticalPipe:

		jsr GetPipeHeight
		lda TMP_0
		beq loc_773C
		iny
		iny
		iny
		iny
loc_773C:

		tya
		pha
		ldy AreaObjectLength,x
		beq loc_774D
		jsr FindEmptyEnemySlot
		bcs loc_774D
		lda #$D
		jsr InitPiranhaPlant
loc_774D:

		pla
		tay
		ldx unk_7
		lda VerticalPipeData,y
		sta $6A1,x
		inx
		lda VerticalPipeDataOff2,y
		ldy byte_6
		dey
		jmp RenderUnderPart
GetPipeHeight:

		ldy #1
		jsr ChkLrgObjFixedLength
		jsr GetLrgObjAttrib
		tya
		and #7
		sta byte_6
		ldy $730,x
		rts
InitPiranhaPlant:

		sta Enemy_ID,x
		jsr GetAreaObjXPosition
		clc
		adc #8
		sta Enemy_X_Position,x
		lda CurrentPageLoc
		adc #0
		sta Enemy_PageLoc,x
		lda #1
		sta Enemy_Y_HighPos,x
		sta $F,x
		jsr GetAreaObjYPosition
		sta Enemy_Y_Position,x
		jmp loc_9398
FindEmptyEnemySlot:

		ldx #0
loc_7793:

		clc
		lda Enemy_Flag,x
		beq locret_779D
		inx
		cpx #5
		bne loc_7793
locret_779D:

		rts
Hole_Water:

		jsr ChkLrgObjLength
		lda #$86
		sta byte_6AB
		ldx #$B
		ldy #1
		lda #$87
		jmp RenderUnderPart
QuestionBlockRow_High:

		lda #3
QuestionBlockRow_Low_NODIRECT:

		bit byte_7A9
		pha
		jsr ChkLrgObjLength
		pla
		tax
		lda #$C0
		sta $6A1,x
		rts
Bridge_High:

		lda #6
Bridge_Middle_NODIRECT:

		bit byte_7A9
Bridge_Low_NODIRECT:

		bit $9A9
		pha
		jsr ChkLrgObjLength
		pla
		tax
		lda #$B
		sta MetatileBuffer,x
		inx
		ldy #0
		lda #$64
		jmp RenderUnderPart
FlagBalls_Residual:

		jsr GetLrgObjAttrib
		ldx #2
		lda #$6F
		jmp RenderUnderPart
FlagpoleObject:

		lda #$21
		sta MetatileBuffer
		ldx #1
		ldy #8
		lda #$22
		jsr RenderUnderPart
		lda #$62
		sta byte_6AB
		jsr GetAreaObjXPosition
		sec
		sbc #8
		sta byte_8C
		lda CurrentPageLoc
		sbc #0
		sta byte_73
		lda #$30
		sta byte_D4
		lda #$B0
		sta FlagpoleFNum_Y_Pos
		lda #$30
		sta byte_1B
		inc byte_14
		rts
EndlessRope:

		ldx #0
		ldy #$F
		jmp DrawRope
BalancePlatRope:

		txa
		pha
		ldx #1
		ldy #$F
		lda #$44
		jsr RenderUnderPart
		pla
		tax
		jsr GetLrgObjAttrib
		ldx #1
DrawRope:

		lda #$40
		jmp RenderUnderPart
unk_7835:
		.byte $C4
		.byte $C3
		.byte $C3
		.byte $C3
RowOfCoins:

		ldy AreaType
		lda unk_7835,y
loc_783F:

		jmp GetRow
C_ObjectRow:
		.byte 6
		.byte 7
		.byte 8
C_ObjectMetatile:
		.byte $C6
		.byte $C
		.byte $89
CastleBridgeObj:

		ldy #$C
		jsr ChkLrgObjFixedLength
		jmp ChainObj
AxeObj:

		lda #8
		sta VRAM_Buffer_AddrCtrl
ChainObj:

		ldy TMP_0
		ldx C_ObjectRow-2,y
		lda C_ObjectMetatile-2,y
		jmp ColObj
EmptyBlock:

		jsr GetLrgObjAttrib
		ldx unk_7
		lda #$C5
ColObj:

		ldy #0
		jmp RenderUnderPart
SolidBlockMetatiles:
		.byte $6A
		.byte $62
		.byte $62
		.byte $63
BrickMetatiles:
		.byte $1F
		.byte $4F
		.byte $50
		.byte $50
		.byte $88
RowOfBricks:

		ldy AreaType
		lda CloudTypeOverride
		beq loc_787F
		ldy #4
loc_787F:

		lda BrickMetatiles,y
		jmp GetRow
RowOfSolidBlocks:

		ldy AreaType
		lda SolidBlockMetatiles,y
GetRow:

		pha
		jsr ChkLrgObjLength
DrawRow:

		ldx unk_7
		ldy #0
		pla
		jmp RenderUnderPart
ColumnOfBricks:

		ldy AreaType
		lda BrickMetatiles,y
		jmp GetRow2
ColumnOfSolidBlocks:

		ldy AreaType
		lda SolidBlockMetatiles,y
GetRow2:

		pha
		jsr GetLrgObjAttrib
		pla
		ldx unk_7
		jmp RenderUnderPart
BulletBillCannon:

		jsr GetLrgObjAttrib
		ldx unk_7
		lda #$65
		sta $6A1,x
		inx
		dey
		bmi loc_78CC
		lda #$66
		sta $6A1,x
		inx
		dey
		bmi loc_78CC
		lda #$67
		jsr RenderUnderPart
loc_78CC:

		ldx Whirlpool_Offset
		jsr GetAreaObjYPosition
		sta $477,x
		lda CurrentPageLoc
		sta $46B,x
		jsr GetAreaObjXPosition
		sta $471,x
		inx
		cpx #6
		bcc loc_78E8
		ldx #0
loc_78E8:

		stx Whirlpool_Offset
		rts
unk_78EC:
		.byte 7
		.byte 7
		.byte 6
		.byte 5
		.byte 4
		.byte 3
		.byte 2
		.byte 1
		.byte 0
unk_78F5:
		.byte 3
		.byte 3
		.byte 4
		.byte 5
		.byte 6
		.byte 7
		.byte 8
		.byte 9
		.byte $A
StaircaseObject:

		jsr ChkLrgObjLength
		bcc loc_7908
		lda #9
		sta StaircaseControl
loc_7908:

		dec StaircaseControl
		ldy StaircaseControl
		ldx unk_78F5,y
		lda unk_78EC,y
		tay
		lda #$62
		jmp RenderUnderPart
Jumpspring:

		jsr GetLrgObjAttrib
		jsr FindEmptyEnemySlot
		bcs locret_7949
		jsr GetAreaObjXPosition
		sta Enemy_X_Position,x
		lda CurrentPageLoc
		sta $6E,x
		jsr GetAreaObjYPosition
		sta $CF,x
		sta $58,x
		lda #$32
		sta $16,x
		ldy #1
		sty $B6,x
		inc $F,x
		ldx unk_7
		lda #$68
		sta $6A1,x
		lda #$69
		sta $6A2,x
locret_7949:

		rts
Hidden1UpBlock:

		lda Hidden1UpFlag
		beq locret_7985
		lda #0
		sta Hidden1UpFlag
		jmp BrickWithItem
QuestionBlock:

		jsr GetAreaObjectID
		jmp DrawQBlk
BrickWithCoins:

		lda #0
		sta BrickCoinTimerFlag
BrickWithItem:

		jsr GetAreaObjectID
		sty unk_7
		lda #0
		ldy AreaType
		dey
		beq loc_7971
		lda #6
loc_7971:

		clc
		adc unk_7
		tay
DrawQBlk:

		lda BrickQBlockMetatiles,y
		pha
		jsr GetLrgObjAttrib
		jmp DrawRow
GetAreaObjectID:

		lda TMP_0
		sec
		sbc #0
		tay
locret_7985:

		rts
unk_7986:
		.byte $87
		.byte 0
		.byte 0
		.byte 0
Hole_Empty:

		jsr ChkLrgObjLength
		bcc loc_79BC
		lda AreaType
		bne loc_79BC
		ldx Whirlpool_Offset
		jsr GetAreaObjXPosition
		sec
		sbc #$10
		sta Whirlpool_LeftExtent,x
		lda CurrentPageLoc
		sbc #0
		sta Whirlpool_PageLoc,x
		iny
		iny
		tya
		asl
		asl
		asl
		asl
		sta Whirlpool_Length,x
		inx
		cpx #5
		bcc loc_79B9
		ldx #0
loc_79B9:

		stx Whirlpool_Offset
loc_79BC:

		ldx AreaType
		lda unk_7986,x
		ldx #8
		ldy #$F
RenderUnderPart:

		sty AreaObjectHeight
		ldy MetatileBuffer,x
		beq loc_79DE
		cpy #$17
		beq loc_79E1
		cpy #$8B
		beq loc_79E1
		cpy #$C0
		beq loc_79DE
		cpy #$C0
		bcs loc_79E1
loc_79DE:

		sta MetatileBuffer,x
loc_79E1:

		inx
		cpx #$D
		bcs locret_79EC
		ldy AreaObjectHeight
		dey
		bpl RenderUnderPart
locret_79EC:

		rts
ChkLrgObjLength:

		jsr GetLrgObjAttrib
ChkLrgObjFixedLength:

		lda AreaObjectLength,x
		clc
		bpl locret_79FB
		tya
		sta AreaObjectLength,x
		sec
locret_79FB:

		rts
GetLrgObjAttrib:

		ldy AreaObjOffsetBuffer,x
		lda ($E7),y
		and #$F
		sta unk_7
		iny
		lda ($E7),y
		and #$F
		tay
		rts
GetAreaObjXPosition:

		lda CurrentColumnPos
		asl
		asl
		asl
		asl
		rts
GetAreaObjYPosition:

		lda unk_7
		asl
		asl
		asl
		asl
		clc
		adc #$20
		rts
BlockBufferAddr:
		.byte <Block_Buffer_1
		.byte <Block_Buffer_2
		.byte >Block_Buffer_1
		.byte >Block_Buffer_2
GetBlockBufferAddr:

		pha
		lsr
		lsr
		lsr
		lsr
		tay
		lda BlockBufferAddr+2,y
		sta unk_7
		pla
		and #$F
		clc
		adc BlockBufferAddr,y
		sta byte_6
		rts
GameMode:

		lda OperMode_Task
		jsr JumpEngine
		.word LoadCorrectData
		.word InitializeArea
		.word ScreenRoutines
		.word SecondaryGameSetup
		.word GameCoreRoutine_RW
GameCoreRoutine_RW:
		jsr GameRoutines
		lda OperMode_Task
		cmp #4
		bcs GameEngine
		rts

GameEngine:
		jsr ProcFireball_Bubble
		ldx #0
ProcELoop:

		stx ObjectOffset
		jsr EnemiesAndLoopsCore
		jsr FloateyNumbersRoutine
		inx
		cpx #6
		bne ProcELoop
		jsr GetPlayerOffscreenBits
		jsr RelativePlayerPosition
		jsr PlayerGfxHandler
		jsr BlockObjMT_Updater
		ldx #1
		stx ObjectOffset
		jsr BlockObjectsCore
		dex
		stx ObjectOffset
		jsr BlockObjectsCore
		jsr MiscObjectsCore
		jsr ProcessCannons
		jsr ProcessWhirlpools
		jsr FlagpoleRoutine
		jsr RunGameTimer
		jsr ColorRotation
		lda LoadListIndex
		beq loc_7A97
		jsr func_C550_DATA2
loc_7A97:

		lda Player_Y_HighPos
		cmp #2
		bpl loc_7AAE
		lda StarInvincibleTimer
		beq loc_7AC0
		cmp #4
		bne loc_7AAE
		lda IntervalTimerControl
		bne loc_7AAE
		jsr sub_6F2D
loc_7AAE:

		ldy StarInvincibleTimer
		lda FrameCounter
		cpy #8
		bcs loc_7AB9
		lsr
		lsr
loc_7AB9:

		lsr
		jsr CyclePlayerPalette
		jmp loc_7AC3
loc_7AC0:

		jsr sub_7DF2
loc_7AC3:

		lda A_B_Buttons
		sta PreviousA_B_Buttons
		lda #0
		sta Left_Right_Buttons
sub_7ACB:

		lda VRAM_Buffer_AddrCtrl
		cmp #6
		beq locret_7AEE
		lda AreaParserTaskNum
		bne loc_7AEB
		lda ScrollThirtyTwo
		cmp #$20
		bmi locret_7AEE
		lda ScrollThirtyTwo
		sbc #$20
		sta ScrollThirtyTwo
		lda #0
		sta VRAM_Buffer2_Offset
loc_7AEB:

		jsr AreaParserTaskHandler
locret_7AEE:

		rts
ScrollHandler:

		lda Player_X_Scroll
		clc
		adc Platform_X_Scroll
		sta Player_X_Scroll
		lda ScrollLock
		bne InitScrlAmt
		lda Player_Pos_ForScroll
		cmp #$50
		bcc InitScrlAmt
		lda SideCollisionTimer
		bne InitScrlAmt
		ldy Player_X_Scroll
		dey
		bmi InitScrlAmt
		iny
		cpy #2
		bcc loc_7B16
		dey
loc_7B16:

		lda Player_Pos_ForScroll
		cmp #$70
		bcc loc_7B20
		ldy Player_X_Scroll
loc_7B20:

		lda WaitForIRQ
		bne loc_7B20
		tya
		sta ScrollAmount
		clc
		adc ScrollThirtyTwo
		sta ScrollThirtyTwo
		tya
		clc
		adc ScreenLeft_X_Pos
		sta ScreenLeft_X_Pos
		sta HorizontalScroll
		lda ScreenLeft_PageLoc
		adc #0
		sta ScreenLeft_PageLoc
		and #1
		sta UseNtBase2400
		jsr sub_7B90
		lda #8
		sta ScrollIntervalTimer
		jmp ChkPOffscr
InitScrlAmt:

		lda #0
		sta ScrollAmount
ChkPOffscr:

		ldx #0
		jsr GetXOffscreenBits
		sta TMP_0
		ldy #0
		asl
		bcs KeepOnscr
		iny
		lda TMP_0
		and #$20
		beq InitPlatScrl
KeepOnscr:

		lda $71C,y
		sec
		sbc X_SubtracterData,y
		sta Player_X_Position
		lda $71A,y
		sbc #0
		sta Player_PageLoc
		lda Left_Right_Buttons
		cmp OffscrJoypadBitsData,y
		beq InitPlatScrl
		lda #0
		sta Player_X_Speed
InitPlatScrl:

		lda #0
		sta Platform_X_Scroll
		rts
X_SubtracterData:
		.byte 0
		.byte $10
OffscrJoypadBitsData:
		.byte 1
		.byte 2
sub_7B90:

		lda ScreenLeft_X_Pos
		clc
		adc #$FF
		sta ScreenRight_X_Pos
		lda ScreenLeft_PageLoc
		adc #0
		sta ScreenRight_PageLoc
		rts
GameRoutines:

		lda GameEngineSubroutine
		jsr JumpEngine
		.word Entrance_GameTimerSetup
		.word Vine_AutoClimb
		.word SideExitPipeEntry
		.word VerticalPipeEntry
		.word FlagpoleSlide
		.word PlayerEndLevel
		.word PlayerLoseLife
		.word PlayerEntrance
		.word PlayerCtrlRoutine
		.word PlayerChangeSize
		.word PlayerInjuryBlink
		.word PlayerDeath
		.word PlayerFireFlower
PlayerEntrance:

		lda AltEntranceControl
		cmp #2
		beq loc_7BF3
		lda #0
		ldy SprObject_Y_Position
loc_7BCC:

		cpy #$30
		bcc AutoControlPlayer
		lda PlayerEntranceCtrl
		cmp #6
		beq loc_7BDB
		cmp #7
		bne loc_7C2B
loc_7BDB:

		lda Player_SprAttrib
		bne loc_7BE5
		lda #1
		jmp AutoControlPlayer
loc_7BE5:

		jsr EnterSidePipe
		dec ChangeAreaTimer
		bne locret_7C3D
		inc DisableIntermediate
		jmp loc_7E66
loc_7BF3:

		lda JoypadOverride
		bne loc_7C04
		lda #$FF
		jsr MovePlayerYAxis
		lda SprObject_Y_Position
		cmp #$91
		bcc loc_7C2B
		rts
loc_7C04:

		lda VineHeight
		cmp #$60
		bne locret_7C3D
		lda SprObject_Y_Position
		cmp #$99
		ldy #0
		lda #1
		bcc loc_7C1F
		lda #3
		sta Player_State
		iny
		lda #8
		sta byte_5B4
loc_7C1F:

		sty DisableCollisionDet
		jsr AutoControlPlayer
		lda Player_X_Position
		cmp #$48
		bcc locret_7C3D
loc_7C2B:

		lda #8
		sta GameEngineSubroutine
		lda #1
		sta PlayerFacingDir
		lsr
		sta AltEntranceControl
		sta DisableCollisionDet
		sta JoypadOverride
locret_7C3D:

		rts
AutoControlPlayer:

		sta SavedJoypad1Bits
PlayerCtrlRoutine:

		lda GameEngineSubroutine
		cmp #$B
		beq loc_7C83
		lda AreaType
		bne loc_7C5C
		ldy Player_Y_HighPos
		dey
		bne loc_7C57
		lda SprObject_Y_Position
		cmp #$D0
		bcc loc_7C5C
loc_7C57:

		lda #0
		sta SavedJoypad1Bits
loc_7C5C:

		lda SavedJoypad1Bits
		and #$C0
		sta A_B_Buttons
		lda SavedJoypad1Bits
		and #3
		sta Left_Right_Buttons
		lda SavedJoypad1Bits
		and #$C
		sta Up_Down_Buttons
		and #4
		beq loc_7C83
		lda Player_State
		bne loc_7C83
		ldy Left_Right_Buttons
		beq loc_7C83
		lda #0
		sta Left_Right_Buttons
		sta Up_Down_Buttons
loc_7C83:

		jsr PlayerMovementSubs
		ldy #1
		lda PlayerSize
		bne loc_7C96
		ldy #0
		lda CrouchingFlag
		beq loc_7C96
		ldy #2
loc_7C96:

		sty Player_BoundBoxCtrl
		lda #1
		ldy Player_X_Speed
		beq loc_7CA4
		bpl loc_7CA2
		asl
loc_7CA2:

		sta Player_MovingDir
loc_7CA4:

		jsr ScrollHandler
		jsr GetPlayerOffscreenBits
		jsr RelativePlayerPosition
		ldx #0
		jsr BoundingBoxCore
		jsr sub_A8D2
		lda SprObject_Y_Position
		cmp #$40
		bcc loc_7CD1
		lda GameEngineSubroutine
		cmp #5
		beq loc_7CD1
		cmp #7
		beq loc_7CD1
		cmp #4
		bcc loc_7CD1
		lda Player_SprAttrib
		and #$DF
		sta Player_SprAttrib
loc_7CD1:

		lda Player_Y_HighPos
		cmp #2
		bmi locret_7D12
		ldx #1
		stx ScrollLock
		ldy #4
		sty unk_7
		ldx #0
		ldy GameTimerExpiredFlag
		bne loc_7CEC
		ldy CloudTypeOverride
		bne loc_7D02
loc_7CEC:

		inx
		ldy GameEngineSubroutine
		cpy #$B
		beq loc_7D02
		ldy DeathMusicLoaded
		bne loc_7CFE
		iny
		sty EventMusicQueue
		sty DeathMusicLoaded
loc_7CFE:

		ldy #6
		sty unk_7
loc_7D02:

		cmp unk_7
		bmi locret_7D12
		dex
		bmi loc_7D13
		ldy EventMusicBuffer
		bne locret_7D12
		lda #6
		sta GameEngineSubroutine
locret_7D12:

		rts
loc_7D13:

		lda #0
		sta JoypadOverride
		jsr SetEntr
		inc AltEntranceControl
		rts
Vine_AutoClimb:

		lda Player_Y_HighPos
		bne AutoClimb
		lda SprObject_Y_Position
		cmp #$E4
		bcc SetEntr
AutoClimb:

		lda #8
		sta JoypadOverride
		ldy #3
		sty Player_State
		jmp AutoControlPlayer
SetEntr:

		lda #2
		sta AltEntranceControl
		jmp sub_7D6B
VerticalPipeEntry:

		lda #1
		jsr MovePlayerYAxis
		jsr ScrollHandler
		ldy #0
		lda WarpZoneControl
		bne ChgAreaPipe
		iny
		lda AreaType
		cmp #3
		bne ChgAreaPipe
		iny
		jmp ChgAreaPipe
MovePlayerYAxis:

		clc
		adc SprObject_Y_Position
		sta SprObject_Y_Position
		rts
SideExitPipeEntry:

		jsr EnterSidePipe
		ldy #2
ChgAreaPipe:

		dec ChangeAreaTimer
		bne locret_7D76
		sty AltEntranceControl
sub_7D6B:

		inc DisableScreenFlag
		lda #0
		sta OperMode_Task
		sta Sprite0HitDetectFlag
locret_7D76:

		rts
EnterSidePipe:

		lda #8
		sta Player_X_Speed
		ldy #1
		lda Player_X_Position
		and #$F
		bne loc_7D86
		sta Player_X_Speed
		tay
loc_7D86:

		tya
		jsr AutoControlPlayer
		rts
PlayerChangeSize:

		lda TimerControl
		cmp #$F8
		bne EndChgSize
		jmp InitChangeSize
EndChgSize:

		cmp #$C4
		bne locret_7D9C
		jsr DonePlayerTask
locret_7D9C:

		rts
PlayerInjuryBlink:

		lda TimerControl
		cmp #$F0
		bcs loc_7DAB
		cmp #$C8
		beq DonePlayerTask
		jmp PlayerCtrlRoutine
loc_7DAB:

		bne locret_7DC0
InitChangeSize:

		ldy PlayerChangeSizeFlag
		bne locret_7DC0
		sty PlayerAnimCtrl
		inc PlayerChangeSizeFlag
		lda PlayerSize
		eor #1
		sta PlayerSize
locret_7DC0:

		rts
PlayerDeath:

		lda TimerControl
		cmp #$F0
		bcs ExitDeath
		jmp PlayerCtrlRoutine
DonePlayerTask:

		lda #0
		sta TimerControl
		lda #8
		sta GameEngineSubroutine
		rts
PlayerFireFlower:

		lda TimerControl
		cmp #$C0
		beq ResetPalFireFlower
		lda FrameCounter
		lsr
		lsr
CyclePlayerPalette:

		and #3
		sta TMP_0
		lda Player_SprAttrib
		and #$FC
		ora TMP_0
		sta Player_SprAttrib
		rts
ResetPalFireFlower:

		jsr DonePlayerTask
sub_7DF2:

		lda Player_SprAttrib
		and #$FC
		sta Player_SprAttrib
ExitDeath:

		rts
FlagpoleSlide:

		lda byte_1B
		cmp #$30
		bne NoFPObj
		lda FlagpoleSoundQueue
		sta Square1SoundQueue
		lda #0
		sta FlagpoleSoundQueue
		ldy SprObject_Y_Position
		cpy #$9E
		bcs SlidePlayer
		lda #4
SlidePlayer:

		jmp AutoControlPlayer
NoFPObj:

		inc GameEngineSubroutine
		rts
PlayerEndLevel:

		lda #1
		jsr AutoControlPlayer
		lda SprObject_Y_Position
		cmp #$AE
		bcc loc_7E35
		lda #0
		sta ScrollLock
		lda byte_7F6
		bne loc_7E35
		lda #$20
		sta EventMusicQueue
		inc byte_7F6
loc_7E35:

		lda Player_CollisionBits
		lsr
		bcs loc_7E48
		lda StarFlagTaskControl
		bne loc_7E43
		inc StarFlagTaskControl
loc_7E43:

		lda #$20
		sta Player_SprAttrib
loc_7E48:

		lda StarFlagTaskControl
		cmp #5
		bne locret_7E8F
		inc LevelNumber
		lda LevelNumber
		cmp #3
		bne loc_7E66
		ldy WorldNumber
		lda CoinTallyFor1Ups
		cmp #$A
		bcc loc_7E66
		inc Hidden1UpFlag
loc_7E66:

		inc AreaNumber
		lda WorldNumber
		cmp #8
		bne loc_7E7F
		lda LevelNumber
		cmp #4
		bne loc_7E7F
		lda #0
		sta LevelNumber
		sta AreaNumber
loc_7E7F:

		jsr LoadAreaPointer
		inc FetchNewGameTimerFlag
		jsr sub_7D6B
		sta HalfwayPage
		lda #$80
		sta EventMusicQueue
locret_7E8F:

		rts
PlayerMovementSubs:

		lda #0
		ldy PlayerSize
		bne SetCrouch
		lda Player_State
		bne ProcMove
		lda Up_Down_Buttons
		and #4
SetCrouch:

		sta CrouchingFlag
ProcMove:

		jsr PlayerPhysicsSub
		lda PlayerChangeSizeFlag
		bne NoMoveSub
		lda Player_State
		cmp #3
		beq MoveSubs
		ldy #$18
		sty ClimbSideTimer
MoveSubs:

		jsr JumpEngine
		.word OnGroundStateSub
		.word JumpSwimSub
		.word FallingSub
		.word ClimbingSub
NoMoveSub:

		rts
OnGroundStateSub:

		jsr GetPlayerAnimSpeed
		lda Left_Right_Buttons
		beq loc_7ECA
		sta PlayerFacingDir
loc_7ECA:

		jsr ImposeFriction
sub_7ECD:

		jsr MovePlayerHorizontally
		sta Player_X_Scroll
		lda LoadListIndex
		beq locret_7EDB
		jsr FinalizePlayerMovement
locret_7EDB:

		rts
FallingSub:

		lda VerticalForceDown
		sta VerticalForce
		jmp LRAir
JumpSwimSub:

		ldy Player_Y_Speed
		bpl loc_7EFC
		lda A_B_Buttons
		and #$80
		and PreviousA_B_Buttons
		bne loc_7F02
		lda JumpOrigin_Y_Position
		sec
		sbc SprObject_Y_Position
		cmp DiffToHaltJump
		bcc loc_7F02
loc_7EFC:

		lda VerticalForceDown
		sta VerticalForce
loc_7F02:

		lda SwimmingFlag
		beq LRAir
		jsr GetPlayerAnimSpeed
		lda SprObject_Y_Position
		cmp #$14
		bcs loc_7F15
		lda #$18
		sta VerticalForce
loc_7F15:

		lda Left_Right_Buttons
		beq LRAir
		sta PlayerFacingDir
LRAir:

		lda Left_Right_Buttons
		beq loc_7F22
		jsr ImposeFriction
loc_7F22:

		jsr sub_7ECD
		lda GameEngineSubroutine
		cmp #$B
		bne loc_7F30
		lda #$28
		sta VerticalForce
loc_7F30:

		jmp loc_8B1E
ClimbAdderLow:
		.byte $E
		.byte 4
		.byte $FC
		.byte $F2
ClimbAdderHigh:
		.byte 0
		.byte 0
		.byte $FF
		.byte $FF
ClimbingSub:

		lda Player_YMF_Dummy
		clc
		adc Player_Y_MoveForce
		sta Player_YMF_Dummy
		ldy #0
		lda Player_Y_Speed
		bpl loc_7F4C
		dey
loc_7F4C:

		sty TMP_0
		adc SprObject_Y_Position
		sta SprObject_Y_Position
		lda Player_Y_HighPos
		adc TMP_0
		sta Player_Y_HighPos
		lda Left_Right_Buttons
		and Player_CollisionBits
		beq InitCSTimer
		ldy ClimbSideTimer
		bne ExitCSub
		ldy #$18
		sty ClimbSideTimer
		ldx #0
		ldy PlayerFacingDir
		lsr
		bcs ClimbFD
		inx
		inx
ClimbFD:

		dey
		beq CSetFDir
		inx
CSetFDir:

		lda Player_X_Position
		clc
		adc ClimbAdderLow,x
		sta Player_X_Position
		lda Player_PageLoc
		adc ClimbAdderHigh,x
		sta Player_PageLoc
		lda Left_Right_Buttons
		eor #3
		sta PlayerFacingDir
ExitCSub:

		rts
InitCSTimer:

		sta ClimbSideTimer
		rts

PlayerYSpdData:
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FB
		.byte $FB
		.byte $FE
		.byte $FF
InitMForceData:
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte 0
		.byte $80
		.byte 0
MaxLeftXSpdData:
		.byte $D8
		.byte $E8
		.byte $F0
MaxRightXSpdData:
		.byte $28
		.byte $18
		.byte $10
		.byte $C
Climb_Y_SpeedData:
		.byte 0
		.byte $FF
		.byte 1
Climb_Y_MForceData:
		.byte 0
		.byte $20
		.byte $FF
PlayerPhysicsSub:

		lda Player_State
		cmp #3
		bne loc_7FE5
		ldy #0
		lda Up_Down_Buttons
		and Player_CollisionBits
		beq loc_7FD1
		iny
		and #8
		bne loc_7FD1
		iny
loc_7FD1:

		ldx Climb_Y_MForceData,y
		stx Player_Y_MoveForce
		lda #8
		ldx Climb_Y_SpeedData,y
		stx Player_Y_Speed
		bmi loc_7FE1
		lsr
loc_7FE1:

		sta PlayerAnimTimerSet
		rts
loc_7FE5:

		lda JumpspringAnimCtrl
		bne loc_7FF4
		lda A_B_Buttons
		and #$80
		beq loc_7FF4
		and PreviousA_B_Buttons
		beq loc_7FF7
loc_7FF4:

		jmp loc_8088
loc_7FF7:

		lda Player_State
		beq loc_800C
		lda SwimmingFlag
		beq loc_7FF4
		lda JumpSwimTimer
		bne loc_800C
		lda Player_Y_Speed
		bpl loc_800C
		jmp loc_8088
loc_800C:

		lda #$20
		sta JumpSwimTimer
		ldy #0
		sty Player_YMF_Dummy
		sty Player_Y_MoveForce
		lda Player_Y_HighPos
		sta JumpOrigin_Y_HighPos
		lda SprObject_Y_Position
		sta JumpOrigin_Y_Position
		lda #1
		sta Player_State
		lda Player_XSpeedAbsolute
		cmp #9
		bcc ChkWtr
		iny
		cmp #$10
		bcc ChkWtr
		iny
		cmp #$19
		bcc ChkWtr
		iny
		cmp #$1C
		bcc ChkWtr
		iny
ChkWtr:

		lda #1
		sta DiffToHaltJump
		lda SwimmingFlag
		beq GetYPhy
		ldy #5
		lda Whirlpool_Flag
		beq GetYPhy
		iny
GetYPhy:

		lda WRAM_JumpMForceData,y
		sta VerticalForce
		lda WRAM_FallMForceData,y
		sta VerticalForceDown
		lda InitMForceData,y
		sta Player_Y_MoveForce
		lda PlayerYSpdData,y
		sta Player_Y_Speed
		lda SwimmingFlag
		beq PJumpSnd
		lda #4
		sta Square1SoundQueue
		lda SprObject_Y_Position
		cmp #$14
		bcs loc_8088
		lda #0
		sta Player_Y_Speed
		jmp loc_8088
PJumpSnd:

		lda #1
		ldy PlayerSize
		beq loc_8086
		lda #$80
loc_8086:

		sta Square1SoundQueue
loc_8088:

		ldy #0
		sty TMP_0
		lda Player_State
		beq loc_8099
		lda Player_XSpeedAbsolute
		cmp #$19
		bcs GetXPhy
		bcc loc_80B1
loc_8099:

		iny
		lda AreaType
		beq loc_80B1
		dey
		lda Left_Right_Buttons
		cmp Player_MovingDir
		bne loc_80B1
		lda A_B_Buttons
		and #$40
		bne loc_80C5
		lda RunningTimer
		bne GetXPhy
loc_80B1:

		iny
		inc TMP_0
		lda RunningSpeed
		bne loc_80C0
		lda Player_XSpeedAbsolute
		cmp #$21
		bcc GetXPhy
loc_80C0:

		inc TMP_0
		jmp GetXPhy
loc_80C5:

		lda #$A
		sta RunningTimer
GetXPhy:

		lda MaxLeftXSpdData,y
		sta MaximumLeftSpeed
		lda GameEngineSubroutine
		cmp #7
		bne GetXPhy2
		ldy #3
GetXPhy2:

		lda MaxRightXSpdData,y
		sta MaximumRightSpeed
		ldy TMP_0
		lda WRAM_FrictionData,y
		sta FrictionAdderLow
		lda #0
		sta FrictionAdderHigh
		lda PlayerFacingDir
		cmp Player_MovingDir
		beq DoneWithFriction
;VOLDST_PatchMovementFriction:
;
; XXX Reimplemented.
;     Original SMB2J patches asl for retn if Luigi
;
		lda IsPlayingLuigi
		bne DoneWithFriction

		asl FrictionAdderLow
		rol FrictionAdderHigh
DoneWithFriction:
		rts

PlayerAnimTmrData:
		.byte 2, 4, 7
GetPlayerAnimSpeed:

		ldy #0
		lda Player_XSpeedAbsolute
		cmp #$1C
		bcs loc_8119
		iny
		cmp #$E
		bcs loc_810A
		iny
loc_810A:

		lda SavedJoypad1Bits
		and #$7F
		beq SetAnimSpd
		and #3
		cmp Player_MovingDir
		bne loc_811F
		lda #0
loc_8119:

		sta RunningSpeed
		jmp SetAnimSpd
loc_811F:

		lda Player_XSpeedAbsolute
		cmp #$B
		bcs SetAnimSpd
		lda PlayerFacingDir
		sta Player_MovingDir
		lda #0
		sta Player_X_Speed
		sta Player_X_MoveForce
SetAnimSpd:

		lda PlayerAnimTmrData,y
		sta PlayerAnimTimerSet
		rts
ImposeFriction:

		and Player_CollisionBits
		cmp #0
		bne loc_8147
		lda Player_X_Speed
		beq loc_818C
		bpl loc_8168
		bmi loc_814A
loc_8147:

		lsr
		bcc loc_8168
loc_814A:

		lda Player_X_MoveForce
		clc
		adc FrictionAdderLow
		sta Player_X_MoveForce
		lda Player_X_Speed
		adc FrictionAdderHigh
		sta Player_X_Speed
		cmp MaximumRightSpeed
		bmi loc_8183
		lda MaximumRightSpeed
		sta Player_X_Speed
		jmp loc_818C
loc_8168:

		lda Player_X_MoveForce
		sec
		sbc FrictionAdderLow
		sta Player_X_MoveForce
		lda Player_X_Speed
		sbc FrictionAdderHigh
		sta Player_X_Speed
		cmp MaximumLeftSpeed
		bpl loc_8183
		lda MaximumLeftSpeed
		sta Player_X_Speed
loc_8183:

		cmp #0
		bpl loc_818C
		eor #$FF
		clc
		adc #1
loc_818C:

		sta Player_XSpeedAbsolute
		rts
ProcFireball_Bubble:

		lda PlayerStatus
		cmp #2
		bcc loc_81DA
		lda A_B_Buttons
		and #$40
		beq loc_81D0
		and PreviousA_B_Buttons
		bne loc_81D0
		lda FireballCounter
		and #1
		tax
		lda $24,x
		bne loc_81D0
		ldy Player_Y_HighPos
		dey
		bne loc_81D0
		lda CrouchingFlag
		bne loc_81D0
		lda Player_State
		cmp #3
		beq loc_81D0
		lda #$20
		sta Square1SoundQueue
		lda #2
		sta $24,x
		ldy PlayerAnimTimerSet
		sty FireballThrowingTimer
		dey
		sty PlayerAnimTimer
		inc FireballCounter
loc_81D0:

		ldx #0
		jsr FireballObjCore
		ldx #1
		jsr FireballObjCore
loc_81DA:

		lda AreaType
		bne locret_81F2
		ldx #2
loc_81E1:

		stx ObjectOffset
		jsr sub_8265
		jsr loc_BE16
		jsr sub_BE76
		jsr sub_BABC
		dex
		bpl loc_81E1
locret_81F2:

		rts
FireballXSpdData:
		.byte $40
		.byte $C0
FireballObjCore:

		stx ObjectOffset
		lda Fireball_State,x
		asl
		bcs loc_825F
		ldy Fireball_State,x
		beq locret_825E
		dey
		beq loc_822A
		lda Player_X_Position
		adc #4
		sta $8D,x
		lda Player_PageLoc
		adc #0
		sta $74,x
		lda SprObject_Y_Position
		sta $D5,x
		lda #1
		sta $BC,x
		ldy PlayerFacingDir
		dey
		lda FireballXSpdData,y
		sta $5E,x
		lda #4
		sta $A6,x
		lda #7
		sta $4A0,x
		dec $24,x
loc_822A:

		txa
		clc
		adc #7
		tax
		lda #$50
		sta TMP_0
		lda #3
		sta byte_2
		lda #0
		jsr ImposeGravity
		jsr MoveObjectHorizontally
		ldx ObjectOffset
		jsr RelativeFireballPosition
		jsr GetFireballOffscreenBits
		jsr GetFireballBoundBox
		jsr FireballBGCollision
		lda FBall_OffscreenBits
		and #$CC
		bne loc_825A
		jsr sub_A319
		jmp loc_B9B9
loc_825A:

		lda #0
		sta $24,x
locret_825E:

		rts
loc_825F:

		jsr RelativeFireballPosition
		jmp DrawExplosion_Fireball
sub_8265:

		lda $7A8,x
		and #1
		sta unk_7
		lda $E4,x
		cmp #$F8
		bne loc_829E
		lda AirBubbleTimer
		bne locret_82B6
SetupBubble:

		ldy #0
		lda PlayerFacingDir
		lsr
		bcc loc_8280
		ldy #8
loc_8280:

		tya
		adc Player_X_Position
		sta Bubble_X_Position,x
		lda Player_PageLoc
		adc #0
		sta Bubble_PageLoc,x
		lda SprObject_Y_Position
		clc
		adc #8
		sta Bubble_Y_Position,x
		lda #1
		sta Bubble_Y_HighPos,x
		ldy unk_7
		lda BubbleTimerData,y
		sta AirBubbleTimer
loc_829E:

		ldy unk_7
		lda Bubble_YMF_Dummy,x
		sec
		sbc Bubble_MForceData,y
		sta Bubble_YMF_Dummy,x
		lda Bubble_Y_Position,x
		sbc #0
		cmp #$20
		bcs loc_82B4
		lda #$F8
loc_82B4:

		sta Bubble_Y_Position,x
locret_82B6:

		rts
Bubble_MForceData:
		.byte $FF
		.byte $50
BubbleTimerData:
		.byte $40
		.byte $20
RunGameTimer:

		lda OperMode
		beq locret_830F
		lda GameEngineSubroutine
		cmp #8
		bcc locret_830F
		cmp #$B
		beq locret_830F
		lda Player_Y_HighPos
		cmp #2
		bpl locret_830F
		lda GameTimerCtrlTimer
		bne locret_830F
		lda byte_7EC
		ora byte_7ED
		ora byte_7EE
		beq loc_8306
		ldy byte_7EC
		dey
		bne loc_82F2
		lda byte_7ED
		ora byte_7EE
		bne loc_82F2
		lda #$40
		sta EventMusicQueue
loc_82F2:

		lda #$18
		sta GameTimerCtrlTimer
		ldy #$17
		lda #$FF
		sta byte_139
		jsr DigitsMathRoutine
		lda #$A2
		jmp PrintStatusBarNumbers
loc_8306:

		sta PlayerStatus
		jsr loc_A58F
		inc GameTimerExpiredFlag
locret_830F:

		rts
WarpZoneObject:

		lda ScrollLock
		beq locret_830F
		lda SprObject_Y_Position
		and Player_Y_HighPos
		bne locret_830F
		sta ScrollLock
		jmp EraseEnemyObject
ProcessWhirlpools:

		lda AreaType
		bne locret_835D
		sta Whirlpool_Flag
		lda TimerControl
		bne locret_835D
		ldy #4
loc_8330:

		lda $471,y
		clc
		adc $477,y
		sta byte_2
		lda $46B,y
		beq loc_835A
		adc #0
		sta TMP_1
		lda Player_X_Position
		sec
		sbc $471,y
		lda Player_PageLoc
		sbc $46B,y
		bmi loc_835A
		lda byte_2
		sec
		sbc Player_X_Position
		lda TMP_1
		sbc Player_PageLoc
		bpl loc_835E
loc_835A:

		dey
		bpl loc_8330
locret_835D:

		rts
loc_835E:

		lda $477,y
		lsr
		sta TMP_0
		lda $471,y
		clc
		adc TMP_0
		sta TMP_1
		lda $46B,y
		adc #0
		sta TMP_0
		lda FrameCounter
		lsr
		bcc loc_83A4
		lda TMP_1
		sec
		sbc Player_X_Position
		lda TMP_0
		sbc Player_PageLoc
		bpl loc_8391
		lda Player_X_Position
		sec
		sbc #1
		sta Player_X_Position
		lda Player_PageLoc
		sbc #0
		jmp loc_83A2
loc_8391:

		lda Player_CollisionBits
		lsr
		bcc loc_83A4
		lda Player_X_Position
		clc
		adc #1
		sta Player_X_Position
		lda Player_PageLoc
		adc #0
loc_83A2:

		sta Player_PageLoc
loc_83A4:

		lda #$10
		sta TMP_0
		lda #1
		sta Whirlpool_Flag
		sta byte_2
		lsr
		tax
		jmp ImposeGravity
FlagpoleScoreMods:
		.byte 5
		.byte 2
		.byte 8
		.byte 4
		.byte 1
FlagpoleScoreDigits:
		.byte 3
		.byte 3
		.byte 4
		.byte 4
		.byte 4
FlagpoleRoutine:

		ldx #5
		stx ObjectOffset
		lda $16,x
		cmp #$30
		bne locret_842C
		lda GameEngineSubroutine
		cmp #4
		bne loc_83FF
		lda Player_State
		cmp #3
		bne loc_83FF
		lda $CF,x
		cmp #$AA
		bcs loc_8402
		lda SprObject_Y_Position
		cmp #$A2
		bcs loc_8402
		lda $417,x
		adc #$FF
		sta $417,x
		lda $CF,x
		adc #1
		sta $CF,x
		lda FlagpoleFNum_YMFDummy
		sec
		sbc #$FF
		sta FlagpoleFNum_YMFDummy
		lda FlagpoleFNum_Y_Pos
		sbc #1
		sta FlagpoleFNum_Y_Pos
loc_83FF:

		jmp loc_8423
loc_8402:

		ldy FlagpoleScore
		cpy #5
		bne loc_8413
		inc NumberofLives
		lda #$40
		sta Square2SoundQueue
		jmp loc_841F
loc_8413:

		lda FlagpoleScoreMods,y
		ldx FlagpoleScoreDigits,y
		sta $134,x
		jsr AddToScore
loc_841F:

		lda #5
		sta GameEngineSubroutine
loc_8423:

		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jsr sub_B1F1
locret_842C:

		rts
Jumpspring_Y_PosData:
		.byte 8
		.byte $10
		.byte 8
		.byte 0
JumpspringHandler:

		jsr GetEnemyOffscreenBits
		lda TimerControl
		bne loc_848E
		lda JumpspringAnimCtrl
		beq loc_848E
		tay
		dey
		tya
		and #2
		bne loc_844C
		inc SprObject_Y_Position
		inc SprObject_Y_Position
		jmp loc_8450
loc_844C:

		dec SprObject_Y_Position
		dec SprObject_Y_Position
loc_8450:

		lda $58,x
		clc
		adc Jumpspring_Y_PosData,y
		sta Enemy_Y_Position,x
		cpy #1
		bcc loc_8480
		lda A_B_Buttons
		and #$80
		beq loc_8480
		and PreviousA_B_Buttons
		bne loc_8480
		tya
		pha
		lda #$F4
		ldy WorldNumber
		cpy #1
		beq loc_8479
		cpy #2
		beq loc_8479
		cpy #6
		bne loc_847B
loc_8479:

		lda #$E0
loc_847B:

		sta JumpspringForce
		pla
		tay
loc_8480:

		cpy #3
		bne loc_848E
		lda JumpspringForce
		sta Player_Y_Speed
		lda #0
		sta JumpspringAnimCtrl
loc_848E:

		jsr RelativeEnemyPosition
		jsr EnemyGfxHandler
		jsr OffscreenBoundsCheck
		lda JumpspringAnimCtrl
		beq locret_84A9
		lda JumpspringTimer
		bne locret_84A9
		lda #4
		sta JumpspringTimer
		inc JumpspringAnimCtrl
locret_84A9:

		rts
Setup_Vine:

		lda #$2F
		sta Enemy_ID,x
		lda #1
		sta $F,x
		lda Block_PageLoc,y
		sta Enemy_PageLoc,x
		lda Block_X_Position,y
		sta Enemy_X_Position,x
		lda Block_Y_Position,y
		sta Enemy_Y_Position,x
		ldy VineFlagOffset
		bne loc_84C9
		sta VineStart_Y_Position
loc_84C9:

		txa
		sta VineObjOffset,y
		inc VineFlagOffset
		lda #4
		sta Square2SoundQueue
		rts
VineHeightData:
		.byte $30
		.byte $60
VineObjectHandler:

		cpx #5
		beq loc_84DC
		rts
loc_84DC:

		ldy VineFlagOffset
		dey
		lda VineHeight
		cmp VineHeightData,y
		beq loc_84F7
		lda FrameCounter
		lsr
		lsr
		bcc loc_84F7
		lda byte_D4
		sbc #1
		sta byte_D4
		inc VineHeight
loc_84F7:

		lda VineHeight
		cmp #8
		bcc loc_8544
		jsr RelativeEnemyPosition
		jsr GetEnemyOffscreenBits
		ldy #0
loc_8506:

		jsr DrawVine
		iny
		cpy VineFlagOffset
		bne loc_8506
		lda Enemy_OffscreenBits
		and #$C
		beq loc_8526
		dey
loc_8517:

		ldx $39A,y
		jsr EraseEnemyObject
		dey
		bpl loc_8517
		sta VineFlagOffset
		sta VineHeight
loc_8526:

		lda VineHeight
		cmp #$20
		bcc loc_8544
		ldx #6
		lda #1
		ldy #$1B
		jsr BlockBufferCollision
		ldy byte_2
		cpy #$D0
		bcs loc_8544
		lda (6),y
		bne loc_8544
		lda #$23
		sta (6),y
loc_8544:

		lda byte_8C
		sec
		sbc ScreenLeft_X_Pos
		tay
		lda byte_73
		sbc ScreenLeft_PageLoc
		bmi loc_8556
		cpy #9
		bcs loc_8582
loc_8556:

		lda #0
		sta byte_14
		lda byte_73
		and #1
		tay
		lda BlockBufferAddr,y
		sta byte_6
		lda BlockBufferAddr+2,y
		sta unk_7
		lda byte_8C
		lsr
		lsr
		lsr
		lsr
loc_856F:

		tay
		lda (6),y
		cmp #$23
		bne byte_857A
		lda #0
		sta (6),y
byte_857A:
		.byte $98
		clc
		adc #$10
		cmp #$D0
		bcc loc_856F
loc_8582:

		ldx ObjectOffset
		rts
CannonBitmasks:
		.byte $F
		.byte 7
ProcessCannons:

		lda AreaType
		beq locret_85FB
		ldx #2
loc_858E:

		stx ObjectOffset
		lda $F,x
		bne loc_85E5
		lda PseudoRandomBitReg+1,x
		ldy SecondaryHardMode
		and CannonBitmasks,y
		cmp #6
		bcs loc_85E5
		tay
		lda $46B,y
		beq loc_85E5
		lda $47D,y
		beq loc_85B4
		sbc #0
		sta $47D,y
		jmp loc_85E5
loc_85B4:

		lda TimerControl
		bne loc_85E5
		lda #$E
		sta $47D,y
		lda $46B,y
		sta $6E,x
		lda $471,y
		sta $87,x
		lda $477,y
		sec
		sbc #8
		sta $CF,x
		lda #1
		sta $B6,x
		sta $F,x
		lsr
		sta $1E,x
		lda #9
		sta $49A,x
		lda #$33
		sta $16,x
		jmp loc_85F8
loc_85E5:

		lda $16,x
		cmp #$33
		bne loc_85F8
		jsr OffscreenBoundsCheck
		lda $F,x
		beq loc_85F8
		jsr GetEnemyOffscreenBits
		jsr BulletBillHandler
loc_85F8:

		dex
		bpl loc_858E
locret_85FB:

		rts
BulletBillXSpdData:
		.byte $18
		.byte $E8
BulletBillHandler:

		lda TimerControl
		bne loc_8641
		lda Enemy_State,x
		bne loc_8635
		lda Enemy_OffscreenBits
		and #$C
		cmp #$C
		beq loc_8650
		ldy #1
		jsr PlayerEnemyDiff
		bmi loc_8618
		iny
loc_8618:

		sty $46,x
		dey
		lda BulletBillXSpdData,y
		sta $58,x
		lda TMP_0
		adc #$28
		cmp #$50
		bcc loc_8650
		lda #1
		sta $1E,x
		lda #$A
		sta $78A,x
		lda #8
		sta Square2SoundQueue
loc_8635:

		lda $1E,x
		and #$20
		beq loc_863E
		jsr sub_8B34
loc_863E:

		jsr MoveEnemyHorizontally
loc_8641:

		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jsr GetEnemyBoundBox
		jsr PlayerEnemyCollision
		jmp EnemyGfxHandler
loc_8650:

		jsr EraseEnemyObject
		rts
HammerEnemyOfsData:
		.byte 4
		.byte 4
		.byte 4
		.byte 5
		.byte 5
		.byte 5
		.byte 6
		.byte 6
		.byte 6
HammerXSpdData:
		.byte $10
		.byte $F0
SpawnHammerObj:

		lda PseudoRandomBitReg+1
		and #7
		bne SetMOfs
		lda PseudoRandomBitReg+1
		and #8
SetMOfs:

		tay
		lda Misc_State,y
		bne NoHammer
		ldx HammerEnemyOfsData,y
		lda $F,x
		bne NoHammer
		ldx ObjectOffset
		txa
		sta $6AE,y
		lda #$90
		sta $2A,y
		lda #7
		sta Misc_BoundBoxCtrl,y
		sec
		rts
NoHammer:

		ldx ObjectOffset
		clc
		rts
ProcHammerObj:

		lda TimerControl
		bne loc_86F6
		lda Misc_State,x
		and #$7F
		ldy HammerEnemyOffset,x
		cmp #2
		beq loc_86BE
		bcs loc_86D4
		txa
		clc
		adc #$D
		tax
		lda #$10
		sta TMP_0
		lda #$F
		sta TMP_1
		lda #4
		sta byte_2
		lda #0
		jsr ImposeGravity
		jsr MoveObjectHorizontally
		ldx ObjectOffset
		jmp loc_86F3
loc_86BE:

		lda #$FE
		sta Misc_Y_Speed,x
		lda Enemy_State,y
		and #$F7
		sta Enemy_State,y
		ldx Enemy_MovingDir,y
		dex
		lda HammerXSpdData,x
		ldx ObjectOffset
		sta Misc_X_Speed,x
loc_86D4:

		dec Misc_State,x
		lda Enemy_X_Position,y
		clc
		adc #2
		sta Misc_X_Position,x
		lda Enemy_PageLoc,y
		adc #0
		sta Misc_PageLoc,x
		lda Enemy_Y_Position,y
		sec
		sbc #$A
		sta Misc_Y_Position,x
		lda #1
		sta Misc_Y_HighPos,x
		bne loc_86F6
loc_86F3:

		jsr PlayerHammerCollision
loc_86F6:

		jsr GetMiscOffscreenBits
		jsr RelativeMiscPosition
		jsr GetMiscBoundBox
		jsr DrawHammer
		rts
CoinBlock:

		jsr sub_874F
		lda Block_PageLoc,x
		sta Misc_PageLoc,y
		lda Block_X_Position,x
		ora #5
		sta Misc_X_Position,y
		lda Block_Y_Position,x
		sbc #$10
		sta Misc_Y_Position,y
		jmp JCoinC
sub_871C:

		jsr sub_874F
		lda $3EA,x
		sta $7A,y
		lda byte_6
		asl
		asl
		asl
		asl
		ora #5
		sta $93,y
		lda byte_2
		adc #$20
		sta $DB,y
JCoinC:

		lda #$FB
		sta Misc_Y_Speed,y
		lda #1
		sta $C2,y
		sta $2A,y
		sta Square2SoundQueue
		stx ObjectOffset
		jsr sub_87C3
		inc CoinTallyFor1Ups
		rts
sub_874F:

		ldy #8
loc_8751:

		lda $2A,y
		beq loc_875D
		dey
		cpy #5
		bne loc_8751
		ldy #8
loc_875D:

		sty JumpCoinMiscOffset
		rts
MiscObjectsCore:

		ldx #8
loc_8763:

		stx ObjectOffset
		lda $2A,x
		beq loc_87BF
		asl
		bcc loc_8772
		jsr ProcHammerObj
		jmp loc_87BF
loc_8772:

		ldy $2A,x
		dey
		beq loc_8794
		inc $2A,x
		lda $93,x
		clc
		adc ScrollAmount
		sta $93,x
		lda $7A,x
		adc #0
		sta $7A,x
		lda $2A,x
		cmp #$30
		bne loc_87B3
		lda #0
		sta $2A,x
		jmp loc_87BF
loc_8794:

		txa
		clc
		adc #$D
		tax
		lda #$50
		sta TMP_0
		lda #6
		sta byte_2
		lsr
		sta TMP_1
		lda #0
		jsr ImposeGravity
		ldx ObjectOffset
		lda $AC,x
		cmp #5
		bne loc_87B3
		inc $2A,x
loc_87B3:

		jsr RelativeMiscPosition
		jsr GetMiscOffscreenBits
		jsr GetMiscBoundBox
		jsr JCoinGfxHandler
loc_87BF:

		dex
		bpl loc_8763
		rts
sub_87C3:

		lda #1
		sta byte_139
		ldy #$11
		jsr DigitsMathRoutine
		inc CoinTally
		lda CoinTally
		cmp #$64
		bne loc_87E3
		lda #0
		sta CoinTally
		inc NumberofLives
		lda #$40
		sta Square2SoundQueue
loc_87E3:

		lda #2
		sta byte_138
AddToScore:

		ldy #$B
		jsr DigitsMathRoutine
GetSBNybbles_RW:

		lda #1
UpdateNumber:

		jsr PrintStatusBarNumbers
		ldy VRAM_Buffer1_Offset
		lda $2FB,y
		bne loc_87FF
		lda #$24
		sta $2FB,y
loc_87FF:

		ldx ObjectOffset
		rts
SetupPowerUp:

		lda #$2E
		sta byte_1B
		lda $76,x
		sta byte_73
		lda $8F,x
		sta byte_8C
		lda #1
		sta byte_BB
		lda $D7,x
		sec
		sbc #8
		sta byte_D4
PwrUpJmp:

		lda #1
		sta byte_23
		sta byte_14
		lda #3
		sta byte_49F
		lda PowerUpType
		cmp #2
		bcs loc_8834
		lda PlayerStatus
		cmp #2
		bcc loc_8832
		lsr
loc_8832:

		sta PowerUpType
loc_8834:

		lda #$20
		sta byte_3CA
		lda #2
		sta Square2SoundQueue
		rts
PowerUpObjHandler:

		ldx #5
		stx ObjectOffset
		lda byte_23
		beq locret_88AB
		asl
		bcc loc_8874
		lda TimerControl
		bne loc_8899
		lda PowerUpType
		beq loc_886B
		cmp #3
		beq loc_886B
		cmp #4
		beq loc_886B
		cmp #5
		beq loc_886B
		cmp #2
		bne loc_8899
		jsr MoveJumpingEnemy
		jsr sub_ADF9
		jmp loc_8899
loc_886B:

		jsr MoveNormalEnemy
		jsr EnemyToBGCollisionDet
		jmp loc_8899
loc_8874:

		lda FrameCounter
		and #3
		bne loc_8893
		dec byte_D4
		lda byte_23
		inc byte_23
		cmp #$11
		bcc loc_8893
		lda #$10
		sta $58,x
		lda #$80
		sta byte_23
		asl
		sta byte_3CA
		rol
		sta $46,x
loc_8893:

		lda byte_23
		cmp #6
		bcc locret_88AB
loc_8899:

		jsr RelativeEnemyPosition
		jsr GetEnemyOffscreenBits
		jsr GetEnemyBoundBox
		jsr sub_B37D
		jsr PlayerEnemyCollision
		jsr OffscreenBoundsCheck
locret_88AB:

		rts
BlockYPosAdderData:
		.byte 4
		.byte $12
sub_88AE:

		pha
		lda #$11
		ldx SprDataOffset_Ctrl
		ldy PlayerSize
		bne loc_88BB
		lda #$12
loc_88BB:

		sta $26,x
		jsr DestroyBlockMetatile
		ldx SprDataOffset_Ctrl
		lda byte_2
		sta $3E4,x
		tay
		lda byte_6
		sta Block_BBuf_Low,x
		lda (6),y
		jsr BlockBumpedChk
		sta TMP_0
		ldy PlayerSize
		bne loc_88DB
		tya
loc_88DB:

		bcc loc_8902
		ldy #$11
		sty $26,x
		lda #$C5
		ldy TMP_0
		cpy #$56
		beq loc_88ED
		cpy #$5C
		bne loc_8902
loc_88ED:

		lda BrickCoinTimerFlag
		bne loc_88FA
		lda #$B
		sta BrickCoinTimer
		inc BrickCoinTimerFlag
loc_88FA:

		lda BrickCoinTimer
		bne loc_8901
		ldy #$C5
loc_8901:

		tya
loc_8902:

		sta $3E8,x
		jsr sub_8945
		ldy byte_2
		lda #$20
		sta (6),y
		lda #$10
		sta BlockBounceTimer
		pla
		sta byte_5
		ldy #0
		lda CrouchingFlag
		bne loc_8922
		lda PlayerSize
		beq loc_8923
loc_8922:

		iny
loc_8923:

		lda SprObject_Y_Position
		clc
		adc BlockYPosAdderData,y
		and #$F0
		sta Block_Y_Position,x
		ldy Block_State,x
		cpy #$11
		beq loc_8939
		jsr sub_89D3
		jmp loc_893C
loc_8939:

		jsr sub_895C
loc_893C:

		lda SprDataOffset_Ctrl
		eor #1
		sta SprDataOffset_Ctrl
		rts
sub_8945:

		lda Player_X_Position
		clc
		adc #8
		and #$F0
		sta $8F,x
		lda Player_PageLoc
		adc #0
		sta $76,x
		sta $3EA,x
		lda Player_Y_HighPos
		sta $BE,x
		rts
sub_895C:

		jsr CheckTopOfBlock
		lda #2
		sta Square1SoundQueue
		lda #0
		sta Block_X_Speed,x
		sta Block_Y_MoveForce,x
		sta Player_Y_Speed
		lda #$FE
		sta Block_Y_Speed,x
		lda byte_5
		jsr BlockBumpedChk
		bcc locret_89B3
		tya
		cmp #$D
		bcc loc_897E
		sbc #6
loc_897E:

		jsr JumpEngine
		.word MushFlowerBlock
		.word PoisonMushroom_MAYBE_NODIRECT+1
		.word CoinBlock
		.word CoinBlock
		.word ExtraLifeMushBlock_NODIRECT+1
		.word PoisonMushroom_MAYBE_NODIRECT+1
		.word MushFlowerBlock
		.word MushFlowerBlock
		.word PoisonMushroom_MAYBE_NODIRECT+1
		.word VineBlock
		.word StarBlock_NODIRECT+1
		.word CoinBlock
		.word ExtraLifeMushBlock_NODIRECT+1
MushFlowerBlock:

		lda #0
StarBlock_NODIRECT:

		bit byte_2A9
PoisonMushroom_MAYBE_NODIRECT:

		bit byte_4A9
ExtraLifeMushBlock_NODIRECT:

		bit byte_3A9
		sta PowerUpType
		jmp SetupPowerUp
VineBlock:

		ldx #5
		ldy SprDataOffset_Ctrl
		jsr Setup_Vine
locret_89B3:

		rts
BrickQBlockMetatiles:
		.byte $C1
		.byte $C2
		.byte $C0, $5E,	$5F, $60, $61, $52, $53, $54, $55, $56
		.byte $57, $58,	$59, $5A, $5B, $5C, $5D
BlockBumpedChk:

		ldy #$12
loc_89C9:

		cmp BrickQBlockMetatiles,y
		beq locret_89D2
		dey
		bpl loc_89C9
		clc
locret_89D2:

		rts
sub_89D3:

		jsr CheckTopOfBlock
		lda #1
		sta $3EC,x
		sta NoiseSoundQueue
		jsr sub_8A12
		lda #$FE
		sta Player_Y_Speed
		lda #5
		sta byte_139
		jsr AddToScore
		ldx SprDataOffset_Ctrl
		rts
CheckTopOfBlock:

		ldx SprDataOffset_Ctrl
		ldy byte_2
		beq locret_8A11
		tya
		sec
		sbc #$10
		sta byte_2
		tay
		lda (6),y
		cmp #$C3
		bne locret_8A11
		lda #0
		sta (6),y
		jsr RemoveCoin_Axe
		ldx SprDataOffset_Ctrl
		jsr sub_871C
locret_8A11:

		rts
sub_8A12:

		lda $8F,x
		sta $3F1,x
		lda #$F0
		sta $60,x
		sta $62,x
		lda #$FA
		sta $A8,x
		lda #$FC
		sta $AA,x
		lda #0
		sta $43C,x
		sta $43E,x
		lda $76,x
		sta $78,x
		lda $8F,x
		sta $91,x
		lda $D7,x
		clc
		adc #8
		sta $D9,x
		lda #$FA
		sta $A8,x
		rts
BlockObjectsCore:

		lda Block_State,x
		beq loc_8AA2
		and #$F
		pha
		tay
		txa
		clc
		adc #9
		tax
		dey
		beq loc_8A84
		jsr ImposeGravityBlock
		jsr MoveObjectHorizontally
		txa
		clc
		adc #2
		tax
		jsr ImposeGravityBlock
		jsr MoveObjectHorizontally
		ldx ObjectOffset
		jsr loc_BE3E
		jsr loc_BE9B
		jsr sub_B92E
		pla
		ldy $BE,x
		beq loc_8AA2
		pha
		lda #$F0
		cmp $D9,x
		bcs loc_8A7B
		sta $D9,x
loc_8A7B:

		lda $D7,x
		cmp #$F0
		pla
		bcc loc_8AA2
		bcs loc_8AA0
loc_8A84:

		jsr ImposeGravityBlock
		ldx ObjectOffset
		jsr loc_BE3E
		jsr loc_BE9B
		jsr sub_B8AC
		lda $D7,x
		and #$F
		cmp #5
		pla
		bcs loc_8AA2
		lda #1
		sta $3EC,x
loc_8AA0:

		lda #0
loc_8AA2:

		sta $26,x
		rts
BlockObjMT_Updater:

		ldx #1
loc_8AA7:

		stx ObjectOffset
		lda VRAM_Buffer1
		bne loc_8ACF
		lda $3EC,x
		beq loc_8ACF
		lda Block_BBuf_Low,x
		sta byte_6
		lda #5
		sta unk_7
		lda $3E4,x
		sta byte_2
		tay
		lda $3E8,x
		sta (6),y
		jsr ReplaceBlockMetatile
		lda #0
		sta $3EC,x
loc_8ACF:

		dex
		bpl loc_8AA7
		rts
MoveEnemyHorizontally:

		inx
		jsr MoveObjectHorizontally
		ldx ObjectOffset
		rts
MovePlayerHorizontally:

		lda JumpspringAnimCtrl
		bne locret_8B1D
		tax
MoveObjectHorizontally:

		lda $57,x
		asl
		asl
		asl
		asl
		sta TMP_1
		lda $57,x
		lsr
		lsr
		lsr
		lsr
		cmp #8
		bcc loc_8AF4
		ora #$F0
loc_8AF4:

		sta TMP_0
		ldy #0
		cmp #0
		bpl loc_8AFD
		dey
loc_8AFD:

		sty byte_2
		lda $400,x
		clc
		adc TMP_1
		sta $400,x
		lda #0
		rol
		pha
		ror
		lda $86,x
		adc TMP_0
		sta $86,x
		lda $6D,x
		adc byte_2
		sta $6D,x
		pla
		clc
		adc TMP_0
locret_8B1D:

		rts
loc_8B1E:

		ldx #0
		lda TimerControl
		bne loc_8B2A
		lda JumpspringAnimCtrl
		bne locret_8B1D
loc_8B2A:

		lda VerticalForce
		sta TMP_0
		lda #4
		jmp ImposeGravitySprObj
sub_8B34:

		ldy #$3D
		lda $1E,x
		cmp #5
		bne loc_8B3E
loc_8B3C:

		ldy #$20
loc_8B3E:

		jmp loc_8B65
loc_8B41:

		ldy #0
		jmp loc_8B48
loc_8B46:

		ldy #1
loc_8B48:

		inx
		lda #3
		sta TMP_0
		lda #6
		sta TMP_1
		lda #2
		sta byte_2
		tya
		jmp loc_8BA2
MoveDropPlatform:

		ldy #$7F
		bne loc_8B5F
MoveEnemySlowVert:

		ldy #$F
loc_8B5F:

		lda #2
		bne loc_8B67
MoveJ_EnemyVertically:

		ldy #$1C
loc_8B65:

		lda #3
loc_8B67:

		sty TMP_0
		inx
		jsr ImposeGravitySprObj
		ldx ObjectOffset
		rts
MaxSpdBlockData:
		.byte 6
		.byte 8
ResidualGravityCode:

		ldy #0
		.byte $2C
ImposeGravityBlock:

		ldy #1
		lda #$50
		sta TMP_0
		lda MaxSpdBlockData,y
ImposeGravitySprObj:

		sta byte_2
		lda #0
		jmp ImposeGravity
sub_8B85:

		lda #0
loc_8B87:

		bit byte_1A9
		pha
		ldy $16,x
		inx
		lda #5
		cpy #$29
		bne loc_8B96
		lda #9
loc_8B96:

		sta TMP_0
		lda #$A
		sta TMP_1
		lda #3
		sta byte_2
		pla
		tay
loc_8BA2:

		jsr ImposeGravity
		ldx ObjectOffset
		rts
ImposeGravity:

		pha
		lda $416,x
		clc
		adc $433,x
		sta $416,x
		ldy #0
		lda $9F,x
		bpl loc_8BBA
		dey
loc_8BBA:

		sty unk_7
		adc $CE,x
		sta $CE,x
		lda $B5,x
		adc unk_7
		sta $B5,x
		lda $433,x
		clc
		adc TMP_0
		sta $433,x
		lda $9F,x
		adc #0
		sta $9F,x
		cmp byte_2
		bmi loc_8BE9
		lda $433,x
		cmp #$80
		bcc loc_8BE9
		lda byte_2
		sta $9F,x
		lda #0
		sta $433,x
loc_8BE9:

		pla
		beq locret_8C17
		lda byte_2
		eor #$FF
		tay
		iny
		sty unk_7
		lda $433,x
		sec
		sbc TMP_1
		sta $433,x
		lda $9F,x
		sbc #0
		sta $9F,x
		cmp unk_7
		bpl locret_8C17
		lda $433,x
		cmp #$80
		bcs locret_8C17
		lda unk_7
		sta $9F,x
		lda #$FF
		sta $433,x
locret_8C17:

		rts
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
EnemiesAndLoopsCore:

		lda Enemy_Flag,x
		pha
		asl
		bcs loc_8C3B
		pla
		beq loc_8C2F
		jmp RunEnemyObjectsCore
loc_8C2F:

		lda AreaParserTaskNum
		and #7
		cmp #7
		beq locret_8C46
		jmp ProcLoopCommand
loc_8C3B:

		pla
		and #$F
		tay
		lda Enemy_Flag,y
		bne locret_8C46
		sta Enemy_Flag,x
locret_8C46:

		rts
LoopCmdWorldNumber:
		.byte 2
		.byte 2
		.byte 2
		.byte 2
		.byte 5
		.byte 5
		.byte 5
		.byte 5
		.byte 6
		.byte 7
		.byte 7
		.byte 4
LoopCmdPageNumber:
		.byte 3
		.byte 5
		.byte 8
		.byte 9
		.byte 3
		.byte 6
		.byte 7
		.byte $A
		.byte 5
		.byte 5
		.byte $B
		.byte 5
LoopCmdYPosition:
		.byte $B0
		.byte $B0
		.byte $40
		.byte $30
		.byte $B0
		.byte $30
		.byte $B0
		.byte $B0
		.byte $F0
		.byte $F0
		.byte $B0
		.byte $F0
LoopCmdMultiLoopPassCntr:
		.byte 2
		.byte 2
		.byte 2
		.byte 2
		.byte 2
		.byte 2
		.byte 2
		.byte 2
		.byte 1
		.byte 1
		.byte 1
		.byte 1
sub_8C77:

		lda Player_PageLoc
		sec
		sbc #4
		sta Player_PageLoc
		lda CurrentPageLoc
		sec
		sbc #4
		sta CurrentPageLoc
		lda ScreenLeft_PageLoc
		sec
		sbc #4
		sta ScreenLeft_PageLoc
		lda ScreenRight_PageLoc
		sec
		sbc #4
		sta ScreenRight_PageLoc
		lda AreaObjectPageLoc
		sec
		sbc #4
		sta AreaObjectPageLoc
		lda #0
		sta EnemyObjectPageSel
		sta AreaObjectPageSel
		sta EnemyDataOffset
		sta EnemyObjectPageLoc
		lda SWAPDATA_AreaDataOfsLoopback,y
		sta AreaDataOffset
		rts
ProcLoopCommand:

		lda LoopCommand
		beq loc_8D0C
		lda CurrentColumnPos
		bne loc_8D0C
		ldy #$C
FindLoop:

		dey
		bmi loc_8D0C
		lda WorldNumber
		cmp LoopCmdWorldNumber,y
		bne FindLoop
		lda CurrentPageLoc
		cmp LoopCmdPageNumber,y
		bne FindLoop
		lda SprObject_Y_Position
		cmp LoopCmdYPosition,y
		bne loc_8CE6
		lda Player_State
		cmp #0
		bne loc_8CE6
		inc MultiLoopCorrectCntr
loc_8CE6:

		inc MultiLoopPassCntr
		lda MultiLoopPassCntr
		cmp LoopCmdMultiLoopPassCntr,y
		bne loc_8D07
		lda MultiLoopCorrectCntr
		cmp LoopCmdMultiLoopPassCntr,y
		beq loc_8CFF
		jsr sub_8C77
		jsr sub_9CA6
loc_8CFF:

		lda #0
		sta MultiLoopPassCntr
		sta MultiLoopCorrectCntr
loc_8D07:

		lda #0
		sta LoopCommand
loc_8D0C:

		lda EnemyFrenzyQueue
		beq loc_8D21
		sta $16,x
		lda #1
		sta $F,x
		lda #0
		sta $1E,x
		sta EnemyFrenzyQueue
		jmp sub_8E03
loc_8D21:

		ldy EnemyDataOffset
		lda ($E9),y
		cmp #$FF
		bne loc_8D2D
		jmp loc_8DF3
loc_8D2D:

		and #$F
		cmp #$E
		beq loc_8D41
		cpx #5
		bcc loc_8D41
		iny
		lda ($E9),y
		and #$3F
		cmp #$2E
		beq loc_8D41
		rts
loc_8D41:

		lda ScreenRight_X_Pos
		clc
		adc #$30
		and #$F0
		sta unk_7
		lda ScreenRight_PageLoc
		adc #0
		sta byte_6
		ldy EnemyDataOffset
		iny
		lda ($E9),y
		asl
		bcc loc_8D66
		lda EnemyObjectPageSel
		bne loc_8D66
		inc EnemyObjectPageSel
		inc EnemyObjectPageLoc
loc_8D66:

		dey
		lda ($E9),y
		and #$F
		cmp #$F
		bne loc_8D88
		lda EnemyObjectPageSel
		bne loc_8D88
		iny
		lda ($E9),y
		and #$3F
		sta EnemyObjectPageLoc
		inc EnemyDataOffset
		inc EnemyDataOffset
		inc EnemyObjectPageSel
		jmp ProcLoopCommand
loc_8D88:

		lda EnemyObjectPageLoc
		sta $6E,x
		lda ($E9),y
		and #$F0
		sta $87,x
		cmp ScreenRight_X_Pos
		lda $6E,x
		sbc ScreenRight_PageLoc
		bcs loc_8DA8
		lda ($E9),y
		and #$F
		cmp #$E
		beq loc_8E0E
		jmp loc_8E34
loc_8DA8:

		lda unk_7
		cmp $87,x
		lda byte_6
		sbc $6E,x
		bcc loc_8DF3
		lda #1
		sta $B6,x
		lda ($E9),y
		asl
		asl
		asl
		asl
		sta $CF,x
		cmp #$E0
		beq loc_8E0E
		iny
		lda ($E9),y
		and #$40
		beq loc_8DCE
		lda SecondaryHardMode
		beq loc_8E42
loc_8DCE:

		lda ($E9),y
		and #$3F
		cmp #$37
		bcc loc_8DDA
		cmp #$3F
		bcc loc_8E0B
loc_8DDA:

		cmp #6
		bne loc_8DE5
		ldy PrimaryHardMode
		beq loc_8DE5
		lda #2
loc_8DE5:

		sta $16,x
		lda #1
		sta $F,x
		jsr sub_8E03
		lda $F,x
		bne loc_8E42
		rts
loc_8DF3:

		lda EnemyFrenzyBuffer
		bne loc_8E01
		lda VineFlagOffset
		cmp #1
		bne locret_8E0A
		lda #$2F
loc_8E01:

		sta $16,x
sub_8E03:

		lda #0
		sta $1E,x
		jsr CheckpointEnemyID
locret_8E0A:

		rts
loc_8E0B:

		jmp loc_932C
loc_8E0E:

		iny
		iny
		lda WorldNumber
		cmp #8
		beq loc_8E23
		lda ($E9),y
		lsr
		lsr
		lsr
		lsr
		lsr
		cmp WorldNumber
		bne loc_8E31
loc_8E23:

		dey
		lda ($E9),y
		sta AreaPointer
		iny
		lda ($E9),y
		and #$1F
		sta EntrancePage
loc_8E31:

		jmp loc_8E3F
loc_8E34:

		ldy EnemyDataOffset
		lda ($E9),y
		and #$F
		cmp #$E
		bne loc_8E42
loc_8E3F:

		inc EnemyDataOffset
loc_8E42:

		inc EnemyDataOffset
		inc EnemyDataOffset
		lda #0
		sta EnemyObjectPageSel
		ldx ObjectOffset
		rts
CheckpointEnemyID:

		lda Enemy_ID,x
		cmp #$15
		bcs InitEnemyRoutines
		tay
		lda Enemy_Y_Position,x
		adc #8
		sta Enemy_Y_Position,x
		lda #1
		sta EnemyOffscrBitsMasked,x
		tya
InitEnemyRoutines:

		jsr JumpEngine
		.word InitNormalEnemy
		.word InitNormalEnemy
		.word InitNormalEnemy
		.word InitRedKoopa
		.word loc_9398
		.word InitHammerBro
		.word InitGoomba
		.word InitBloober
		.word InitBulletBill
		.word NoInitCode
		.word InitCheepCheep
		.word InitCheepCheep
		.word InitPodoboo
		.word loc_9398
		.word InitJumpGPTroopa
		.word InitRedPTroopa
		.word InitHorizFlySwimEnemy
		.word InitLakitu
		.word InitEnemyFrenzy
		.word NoInitCode
		.word InitEnemyFrenzy
		.word InitEnemyFrenzy
		.word InitEnemyFrenzy
		.word InitEnemyFrenzy
		.word loc_93ED
		.word NoInitCode
		.word NoInitCode
		.word InitShortFirebar
		.word InitShortFirebar
		.word InitShortFirebar
		.word InitShortFirebar
		.word InitLongFirebar
		.word NoInitCode
		.word NoInitCode
		.word NoInitCode
		.word NoInitCode
		.word InitBalPlatform
		.word InitVertPlatform
		.word LargeLiftUp
		.word LargeLiftDown
		.word InitHoriPlatform
		.word InitDropPlatform
		.word InitHoriPlatform
		.word PlatLiftUp
		.word PlatLiftDown
		.word InitBowser_NEW_MAYBE
		.word PwrUpJmp
		.word Setup_Vine
		.word NoInitCode
		.word NoInitCode
		.word NoInitCode
		.word NoInitCode
		.word NoInitCode
		.word InitRetainerObj
		.word EndOfEnemyInitCode
NoInitCode:

		rts
InitGoomba:

		jsr InitNormalEnemy
		jmp SmallBBox
InitPodoboo:

		lda #2
		sta Enemy_Y_HighPos,x
		sta Enemy_Y_Position,x
		lsr
		sta EnemyIntervalTimer,x
		lsr
		sta Enemy_State,x
		jmp SmallBBox
InitRetainerObj:

		lda #$B8
		sta Enemy_Y_Position,x
		rts
NormalXSpdData:
		.byte $F8
		.byte $F4
InitNormalEnemy:

		ldy #1
		lda PrimaryHardMode
		bne GetESpd
		dey
GetESpd:

		lda NormalXSpdData,y
SetESpd:

		sta Enemy_X_Speed,x
		jmp TallBBox
InitRedKoopa:

		jsr InitNormalEnemy
		lda #1
		sta Enemy_State,x
		rts
HBroWalkingTimerData:
		.byte $80
		.byte $50
InitHammerBro:

		lda #0
		sta HammerThrowingTimer,x
		sta Enemy_X_Speed,x
		lda WorldNumber
		cmp #6
		bcs loc_8F23
		ldy SecondaryHardMode
		lda HBroWalkingTimerData,y
		sta EnemyIntervalTimer,x
loc_8F23:

		lda #$B
		jmp SetBBox
InitHorizFlySwimEnemy:

		lda #0
		jmp SetESpd
InitBloober:

		lda #0
		sta Enemy_X_Speed,x
SmallBBox:

		lda #9
		bne SetBBox
InitRedPTroopa:

		ldy #$30
		lda Enemy_Y_Position,x
		sta RedPTroopaOrigXPos,x
		bpl loc_8F40
		ldy #$E0
loc_8F40:

		tya
		adc Enemy_Y_Position,x
		sta Enemy_X_Speed,x
TallBBox:

		lda #3
SetBBox:

		sta Enemy_BoundBoxCtrl,x
		lda #2
		sta Enemy_MovingDir,x
InitVStf:

		lda #0
		sta ExplosionTimerCounter,x
		sta PiranhaPlantDownYPos,x
		rts
InitBulletBill:

		lda #2
		sta Enemy_MovingDir,x
		lda #9
		sta Enemy_BoundBoxCtrl,x
		rts
InitCheepCheep:

		jsr SmallBBox
		lda PseudoRandomBitReg,x
		and #$10
		sta Enemy_X_Speed,x
		lda Enemy_Y_Position,x
		sta PiranhaPlantDownYPos,x
		rts
InitLakitu:

		lda EnemyFrenzyBuffer
		bne KillLakitu
sub_8F75:

		lda #0
		sta LakituReappearTimer
		jsr InitHorizFlySwimEnemy
		jmp TallBBox2
KillLakitu:

		jmp EraseEnemyObject
PRDiffAdjustData:
		.byte $26
		.byte $2C
		.byte $32
		.byte $38
		.byte $20
		.byte $22
		.byte $24
		.byte $26
		.byte $13
		.byte $14
		.byte $15
		.byte $16
LakituAndSpinyHandler:

		lda FrenzyEnemyTimer
		bne locret_8FDE
		cpx #5
		bcs locret_8FDE
		lda #$80
		sta FrenzyEnemyTimer
		ldy #4
loc_8F9F:

		lda $16,y
		cmp #$11
		beq loc_8FDF
		dey
		bpl loc_8F9F
		inc LakituReappearTimer
		lda LakituReappearTimer
		cmp #3
		bcc locret_8FDE
		ldx #4
loc_8FB5:

		lda $F,x
		beq loc_8FBE
		dex
		bpl loc_8FB5
		bmi loc_8FDC
loc_8FBE:

		lda #0
		sta $1E,x
		lda #$11
		sta $16,x
		jsr sub_8F75
		lda #$20
		ldy IsPlayingExtendedWorlds
		bne loc_8FD7
		ldy WorldNumber
		cpy #6
		bcc loc_8FD9
loc_8FD7:

		lda #$60
loc_8FD9:

		jsr sub_91E9
loc_8FDC:

		ldx ObjectOffset
locret_8FDE:

		rts
loc_8FDF:

		lda SprObject_Y_Position
		cmp #$2C
		bcc locret_8FDE
		lda $1E,y
		bne locret_8FDE
		lda $6E,y
		sta $6E,x
		lda $87,y
		sta $87,x
		lda #1
		sta $B6,x
		lda $CF,y
		sec
		sbc #8
		sta $CF,x
		lda $7A7,x
		and #3
		tay
		ldx #2
DifLoop:

		lda PRDiffAdjustData,y
		sta 1,x
		iny
		iny
		iny
		iny
		dex
		bpl DifLoop
		ldx ObjectOffset
		jsr PlayerLakituDiff
		ldy Player_X_Speed
		cpy #8
		bcs loc_902D
		tay
		lda $7A8,x
		and #3
		beq loc_902C
		tya
		eor #$FF
		tay
		iny
loc_902C:

		tya
loc_902D:

		jsr SmallBBox
		ldy #2
		sta $58,x
		cmp #0
		bmi loc_9039
		dey
loc_9039:

		sty $46,x
		lda #$FD
		sta $A0,x
		lda #1
		sta $F,x
		lda #5
		sta $1E,x
locret_9047:

		rts
FirebarSpinSpdData:
		.byte $28
		.byte $38
		.byte $28
		.byte $38
		.byte $28
FirebarSpinDirData:
		.byte 0
		.byte 0
		.byte $10
		.byte $10
		.byte 0
InitLongFirebar:

		jsr DuplicateEnemyObj
InitShortFirebar:

		lda #0
		sta Enemy_X_Speed,x
		lda Enemy_ID,x
		sec
		sbc #$1B
		tay
loc_905F:

		lda FirebarSpinSpdData,y
		sta FirebarSpinSpeed,x
		lda FirebarSpinDirData,y
		sta FirebarSpinDirection,x
		lda Enemy_Y_Position,x
		clc
		adc #4
		sta Enemy_Y_Position,x
		lda Enemy_X_Position,x
		clc
		adc #4
		sta Enemy_X_Position,x
		lda Enemy_PageLoc,x
		adc #0
		sta Enemy_PageLoc,x
		jmp TallBBox2
FlyCCXPositionData:
		.byte $80
		.byte $30
		.byte $40
		.byte $80
		.byte $30
		.byte $50
		.byte $50
		.byte $70
		.byte $20
		.byte $40
		.byte $80
		.byte $A0
		.byte $70
		.byte $40
		.byte $90
		.byte $68
FlyCCXSpeedData:
		.byte $E
		.byte 5
		.byte 6
		.byte $E
		.byte $1C
		.byte $20
		.byte $10
		.byte $C
		.byte $1E
		.byte $22
		.byte $18
		.byte $14
FlyCCTimerData:
		.byte $10
		.byte $60
		.byte $20
		.byte $48
InitFlyingCheepCheep:

		lda FrenzyEnemyTimer
		bne locret_9047
		jsr SmallBBox
loc_90A9:

		lda $7A8,x
		and #3
		tay
		lda FlyCCTimerData,y
		sta FrenzyEnemyTimer
		ldy #3
		lda SecondaryHardMode
		beq loc_90BD
		iny
loc_90BD:

		sty TMP_0
		cpx TMP_0
		bcs locret_9047
		lda $7A7,x
		and #3
		sta TMP_0
		sta TMP_1
		lda #$FB
		sta $A0,x
		lda #0
		ldy Player_X_Speed
		beq loc_90DD
		lda #4
		cpy #$19
		bcc loc_90DD
		asl
loc_90DD:

		pha
		clc
		adc TMP_0
		sta TMP_0
		lda $7A8,x
		and #3
		beq loc_90F1
		lda $7A9,x
		and #$F
		sta TMP_0
loc_90F1:

		pla
		clc
		adc TMP_1
		tay
		lda FlyCCXSpeedData,y
		sta Enemy_X_Speed,x
		lda #1
		sta Enemy_MovingDir,x
		lda Player_X_Speed
		bne loc_9115
		ldy TMP_0
		tya
		and #2
		beq loc_9115
		lda Enemy_X_Speed,x
		eor #$FF
		clc
		adc #1
		sta Enemy_X_Speed,x
		inc Enemy_MovingDir,x
loc_9115:

		tya
		and #2
		beq loc_9129
		lda Player_X_Position
		clc
		adc FlyCCXPositionData,y
		sta Enemy_X_Position,x
		lda Player_PageLoc
		adc #0
		jmp loc_9135
loc_9129:

		lda Player_X_Position
		sec
		sbc FlyCCXPositionData,y
		sta Enemy_X_Position,x
		lda Player_PageLoc
		sbc #0
loc_9135:

		sta Enemy_PageLoc,x
		lda #1
		sta $F,x
		sta Enemy_Y_HighPos,x
		lda #$F8
		sta Enemy_Y_Position,x
		rts
InitBowser_NEW_MAYBE:

		ldy #4
loc_9144:

		cpy ObjectOffset
		beq loc_9157
		lda Enemy_ID,y
		cmp #$2D
		bne loc_9157
		lda #0
		sta Enemy_ID,y
		sta Enemy_Flag,y
loc_9157:

		dey
		bpl loc_9144
		jsr DuplicateEnemyObj
		stx BowserFront_Offset
		lda #0
		sta BowserBodyControls
		sta BridgeCollapseOffset
		lda $87,x
		sta BowserOrigXPos
		lda #$DF
		sta BowserFireBreathTimer
		sta $46,x
		lda #$20
		sta BowserFeetCounter
		sta $78A,x
		lda #5
		sta BowserHitPoints
		lsr
		sta BowserMovementSpeed
		rts
DuplicateEnemyObj:

		ldy #$FF
loc_9188:

		iny
		lda $F,y
		bne loc_9188
		sty DuplicateObj_Offset
		txa
		ora #$80
		sta $F,y
		lda $6E,x
		sta $6E,y
		lda $87,x
		sta $87,y
		lda #1
		sta $F,x
		sta $B6,y
		lda $CF,x
		sta $CF,y
locret_91AD:

		rts
FlameYPosData:
		.byte $90
		.byte $80
		.byte $70
		.byte $90
FlameYMFAdderData:
		.byte $FF
		.byte 1
InitBowserFlame:

		lda FrenzyEnemyTimer
		bne locret_91AD
		sta $434,x
		lda NoiseSoundQueue
		ora #2
		sta NoiseSoundQueue
		ldy BowserFront_Offset
		lda $16,y
		cmp #$2D
		beq loc_91FD
		jsr sub_9E0E
		clc
		adc #$20
		ldy SecondaryHardMode
		beq loc_91DA
		sec
		sbc #$10
loc_91DA:

		sta FrenzyEnemyTimer
		lda PseudoRandomBitReg,x
		and #3
		sta PiranhaPlantUpYPos,x
		tay
		lda FlameYPosData,y
sub_91E9:

		sta Enemy_Y_Position,x
		lda ScreenRight_X_Pos
		clc
		adc #$20
		sta Enemy_X_Position,x
		lda ScreenRight_PageLoc
		adc #0
		sta Enemy_PageLoc,x
		jmp loc_9230
loc_91FD:

		lda Enemy_X_Position,y
		sec
		sbc #$E
		sta Enemy_X_Position,x
		lda Enemy_PageLoc,y
		sta Enemy_PageLoc,x
		lda Enemy_Y_Position,y
		clc
		adc #8
		sta Enemy_Y_Position,x
		lda $7A7,x
		and #3
		sta $417,x
		tay
		lda FlameYPosData,y
		ldy #0
		cmp Enemy_Y_Position,x
		bcc loc_9225
		iny
loc_9225:

		lda FlameYMFAdderData,y
		sta $434,x
		lda #0
		sta EnemyFrenzyBuffer
loc_9230:

		lda #8
		sta $49A,x
		lda #1
		sta $B6,x
		sta $F,x
		lsr
		sta $401,x
		sta $1E,x
		rts
FireworksXPosData:
		.byte 0
		.byte $30
		.byte $60
		.byte $60
		.byte 0
		.byte $20
FireworksYPosData:
		.byte $60
		.byte $40
		.byte $70
		.byte $40
		.byte $60
		.byte $30
InitFireworks:

		lda FrenzyEnemyTimer
		bne locret_929A
		lda #$20
		sta FrenzyEnemyTimer
		dec FireworksCounter
		ldy #6
loc_925D:

		dey
		lda $16,y
		cmp #$31
		bne loc_925D
		lda $87,y
		sec
		sbc #$30
		pha
		lda $6E,y
		sbc #0
		sta TMP_0
		lda FireworksCounter
		clc
		adc $1E,y
		tay
		pla
		clc
		adc FireworksXPosData,y
		sta $87,x
		lda TMP_0
		adc #0
		sta $6E,x
		lda FireworksYPosData,y
		sta $CF,x
		lda #1
		sta $B6,x
		sta $F,x
		lsr
		sta $58,x
		lda #8
		sta $A0,x
locret_929A:

		rts
Bitmasks:
		.byte 1
		.byte 2
		.byte 4
		.byte 8
		.byte $10
		.byte $20
		.byte $40
		.byte $80
Enemy17YPosData:
		.byte $40
		.byte $30
		.byte $90
		.byte $50
		.byte $20
		.byte $60
		.byte $A0
		.byte $70
SwimCC_IDData:
		.byte $A
		.byte $B
BulletBillCheepCheep:

		lda FrenzyEnemyTimer
		bne locret_9321
		lda AreaType
		bne loc_930E
		cpx #3
		bcs locret_9321
		ldy #0
		lda PseudoRandomBitReg,x
loc_92C0:

		cmp #$AA
		bcc loc_92C5
		iny
loc_92C5:

		lda WorldNumber
		cmp #1
		beq loc_92CD
		iny
loc_92CD:

		tya
		and #1
		tay
		lda SwimCC_IDData,y
loc_92D4:

		sta $16,x
		lda BitMFilter
		cmp #$FF
		bne loc_92E2
		lda #0
		sta BitMFilter
loc_92E2:

		lda $7A7,x
		and #7
loc_92E7:

		tay
		lda Bitmasks,y
		bit BitMFilter
		beq loc_92F7
		iny
		tya
		and #7
		jmp loc_92E7
loc_92F7:

		ora BitMFilter
		sta BitMFilter
		lda Enemy17YPosData,y
		jsr sub_91E9
		sta $417,x
		lda #$20
		sta FrenzyEnemyTimer
		jmp CheckpointEnemyID
loc_930E:

		ldy #$FF
loc_9310:

		iny
		cpy #5
		bcs loc_9322
		lda $F,y
		beq loc_9310
		lda $16,y
		cmp #8
		bne loc_9310
locret_9321:

		rts
loc_9322:

		lda Square2SoundQueue
		ora #8
		sta Square2SoundQueue
		lda #8
		bne loc_92D4
loc_932C:

		ldy #0
		sec
		sbc #$37
		pha
		cmp #4
		bcs loc_9341
		pha
		ldy #6
		lda PrimaryHardMode
		beq loc_9340
		ldy #2
loc_9340:

		pla
loc_9341:

		sty TMP_1
		ldy #$B0
		and #2
		beq loc_934B
		ldy #$70
loc_934B:

		sty TMP_0
		lda ScreenRight_PageLoc
		sta byte_2
		lda ScreenRight_X_Pos
		sta byte_3
		ldy #2
		pla
		lsr
		bcc loc_935E
		iny
loc_935E:

		sty NumberofGroupEnemies
loc_9361:

		ldx #$FF
loc_9363:

		inx
		cpx #5
		bcs loc_9395
		lda $F,x
		bne loc_9363
		lda TMP_1
		sta $16,x
		lda byte_2
		sta $6E,x
		lda byte_3
		sta $87,x
		clc
		adc #$18
		sta byte_3
		lda byte_2
		adc #0
		sta byte_2
		lda TMP_0
		sta $CF,x
		lda #1
		sta $B6,x
		sta $F,x
		jsr CheckpointEnemyID
		dec NumberofGroupEnemies
		bne loc_9361
loc_9395:

		jmp loc_8E42
loc_9398:

		lda #$22
loc_939A:

		sta TMP_0
		lda #$13
		sta TMP_1
		lda IsPlayingExtendedWorlds
		bne loc_93B2
		lda WorldNumber
		cmp #3
		bcs loc_93B2
		dec TMP_0
		lda #$21
		sta TMP_1
loc_93B2:

		lda TMP_0
		sta WRAM_PiranhaPlantAttributeData
		lda TMP_1
		sta WRAM_PiranhaPlantDist
		lda #1
		sta Enemy_X_Speed,x
		lsr
		sta Enemy_State,x
		sta ExplosionTimerCounter,x
		lda Enemy_Y_Position,x
		sta PiranhaPlantDownYPos,x
		sec
		sbc #$18
		sta PiranhaPlantUpYPos,x
		lda #9
		jmp SetBBox2
InitEnemyFrenzy:

		lda Enemy_ID,x
		sta EnemyFrenzyBuffer
		sec
		sbc #$12
		jsr JumpEngine
		.word LakituAndSpinyHandler
		.word NoFrenzyCode
		.word InitFlyingCheepCheep
		.word InitBowserFlame
		.word InitFireworks
		.word BulletBillCheepCheep
NoFrenzyCode:

		rts
loc_93ED:

		ldy #5
loc_93EF:

		lda Enemy_ID,y
		cmp #$11
		bne loc_93FB
		lda #1
		sta Enemy_State,y
loc_93FB:

		dey
		bpl loc_93EF
		lda #0
		sta EnemyFrenzyBuffer
		sta Enemy_Flag,x
		rts
InitJumpGPTroopa:

		lda #2
		sta Enemy_MovingDir,x
		lda #$F4
		sta Enemy_X_Speed,x
TallBBox2:

		lda #3
SetBBox2:

		sta Enemy_BoundBoxCtrl,x
		rts
InitBalPlatform:

		dec Enemy_Y_Position,x
		dec Enemy_Y_Position,x
		ldy SecondaryHardMode
		bne loc_9422
		ldy #2
		jsr PosPlatform
loc_9422:

		ldy #$FF
		lda BalPlatformAlignment
		sta $1E,x
		bpl loc_942D
		txa
		tay
loc_942D:

		sty BalPlatformAlignment
		lda #0
		sta $46,x
		tay
		jsr PosPlatform
InitDropPlatform:

		lda #$FF
		sta HammerThrowingTimer,x
		jmp CommonPlatCode
InitHoriPlatform:

		lda #0
		sta Enemy_X_Speed,x
		jmp CommonPlatCode
InitVertPlatform:

		ldy #$40
		lda Enemy_Y_Position,x
		bpl loc_9454
		eor #$FF
		clc
		adc #1
		ldy #$C0
loc_9454:

		sta $401,x
		tya
		clc
		adc $CF,x
		sta $58,x
CommonPlatCode:

		jsr InitVStf
SPBBox:

		lda #5
		ldy AreaType
		cpy #3
		beq loc_9470
		ldy SecondaryHardMode
		bne loc_9470
		lda #6
loc_9470:

		sta $49A,x
		rts
LargeLiftUp:

		jsr PlatLiftUp
		jmp LargeLiftBBox
LargeLiftDown:

		jsr PlatLiftDown
LargeLiftBBox:

		jmp SPBBox
PlatLiftUp:

		lda #$10
		sta PiranhaPlantDownYPos,x
		lda #$FF
		sta ExplosionTimerCounter,x
		jmp CommonSmallLift
PlatLiftDown:

		lda #$F0
		sta $434,x
		lda #0
		sta $A0,x
CommonSmallLift:

		ldy #1
		jsr PosPlatform
		lda #4
		sta $49A,x
		rts
PlatPosDataLow:
		.byte 8
		.byte $C
		.byte $F8
PlatPosDataHigh:
		.byte 0
		.byte 0
		.byte $FF
PosPlatform:

		lda Enemy_X_Position,x
		clc
		adc PlatPosDataLow,y
		sta Enemy_X_Position,x
		lda Enemy_PageLoc,x
		adc PlatPosDataHigh,y
		sta Enemy_PageLoc,x
		rts
EndOfEnemyInitCode:

		rts
RunEnemyObjectsCore:

		ldx ObjectOffset
		lda #0
		ldy Enemy_ID,x
		cpy #$15
		bcc JmpEO
		tya
		sbc #$14
JmpEO:

		jsr JumpEngine
		.word RunNormalEnemies
		.word RunBowserFlame
		.word RunFireworks
		.word NoRunCode
		.word NoRunCode
		.word NoRunCode
		.word NoRunCode
		.word RunFirebarObj
		.word RunFirebarObj
		.word RunFirebarObj
		.word RunFirebarObj
		.word RunFirebarObj
		.word RunFirebarObj
		.word RunFirebarObj
		.word RunFirebarObj
		.word NoRunCode
		.word RunLargePlatform
		.word RunLargePlatform
		.word RunLargePlatform
		.word RunLargePlatform
		.word RunLargePlatform
		.word RunLargePlatform
		.word RunLargePlatform
		.word RunSmallPlatform
		.word RunSmallPlatform
		.word RunBowser
		.word PowerUpObjHandler
		.word VineObjectHandler
		.word NoRunCode
		.word RunStarFlagObj
		.word JumpspringHandler
		.word NoRunCode
		.word WarpZoneObject
		.word RunRetainerObj
NoRunCode:

		rts
RunRetainerObj:

		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jmp EnemyGfxHandler
RunNormalEnemies:

		lda #0
		sta Enemy_SprAttrib,x
		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jsr EnemyGfxHandler
		jsr GetEnemyBoundBox
		jsr EnemyToBGCollisionDet
		jsr EnemiesCollision
		jsr PlayerEnemyCollision
		ldy TimerControl
		bne SkipMove
		jsr EnemyMovementSubs
SkipMove:

		jmp OffscreenBoundsCheck
EnemyMovementSubs:

		lda Enemy_ID,x
		jsr JumpEngine
		.word MoveNormalEnemy
		.word MoveNormalEnemy
		.word MoveNormalEnemy
		.word MoveNormalEnemy
		.word loc_C4BF+1
		.word ProcHammerBro
		.word MoveNormalEnemy
		.word MoveBloober
		.word MoveBulletBill
		.word NoMoveCode
		.word MoveSwimmingCheepCheep
		.word MoveSwimmingCheepCheep
		.word MovePodoboo
		.word MovePiranhaPlant
		.word MoveJumpingEnemy
		.word ProcMoveRedPTroopa
		.word MoveFlyGreenPTroopa
		.word MoveLakitu
		.word MoveNormalEnemy
		.word NoMoveCode
		.word MoveFlyingCheepCheep
NoMoveCode:

		rts
RunBowserFlame:

		jsr ProcBowserFlame
		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jsr GetEnemyBoundBox
		jsr PlayerEnemyCollision
		jmp OffscreenBoundsCheck
RunFirebarObj:

		jsr ProcFirebar
		jmp OffscreenBoundsCheck
RunSmallPlatform:

		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jsr SmallPlatformBoundBox
		jsr SmallPlatformCollision
		jsr RelativeEnemyPosition
		jsr DrawSmallPlatform
		jsr MoveSmallPlatform
		jmp OffscreenBoundsCheck
RunLargePlatform:

		jsr GetEnemyOffscreenBits
		jsr RelativeEnemyPosition
		jsr LargePlatformBoundBox
		jsr LargePlatformCollision
		lda TimerControl
		bne loc_95AE
		jsr LargePlatformSubroutines
loc_95AE:

		jsr RelativeEnemyPosition
		jsr DrawLargePlatform
		jmp OffscreenBoundsCheck
LargePlatformSubroutines:

		lda Enemy_ID,x
		sec
		sbc #$24
		jsr JumpEngine
		.word BalancePlatform
		.word YMovingPlatform
		.word MoveLargeLiftPlat
		.word MoveLargeLiftPlat
		.word XMovingPlatform
		.word DropPlatform
		.word RightPlatform
EraseEnemyObject:

		lda #0
		sta Enemy_Flag,x
		sta Enemy_ID,x
		sta Enemy_State,x
		sta FloateyNum_Control,x
		sta EnemyIntervalTimer,x
		sta ShellChainCounter,x
		sta Enemy_SprAttrib,x
		sta EnemyFrameTimer,x
		rts
MovePodoboo:

		lda EnemyIntervalTimer,x
		bne loc_9600
		jsr InitPodoboo
		lda PseudoRandomBitReg+1,x
		ora #$80
		sta $434,x
		and #$F
		ora #6
		sta $796,x
		lda #$F9
		sta $A0,x
loc_9600:

		jmp MoveJ_EnemyVertically
HammerThrowTmrData:
		.byte $30
		.byte $1C
XSpeedAdderData:
		.byte 0
		.byte $E8
		.byte 0
		.byte $18
RevivedXSpeed:
		.byte 8
		.byte $F8
		.byte $C
		.byte $F4
ProcHammerBro:

		lda Enemy_State,x
		and #$20
		beq loc_9616
		jmp loc_971A
loc_9616:

		lda HammerBroJumpTimer,x
		beq loc_9647
		dec HammerBroJumpTimer,x
		lda Enemy_OffscreenBits
		and #$C
		bne loc_968D
		lda $3A2,x
		bne loc_963F
		ldy SecondaryHardMode
		lda HammerThrowTmrData,y
		sta $3A2,x
		jsr SpawnHammerObj
		bcc loc_963F
		lda $1E,x
		ora #8
		sta $1E,x
		jmp loc_968D
loc_963F:

		dec $3A2,x
		jmp loc_968D
HammerBroJumpLData:
		.byte $20, $37
loc_9647:

		lda $1E,x
		and #7
		cmp #1
		beq loc_968D
		lda #0
		sta TMP_0
		ldy #$FA
		lda $CF,x
		bmi loc_966C
		ldy #$FD
		cmp #$70
		inc TMP_0
		bcc loc_966C
		dec TMP_0
		lda $7A8,x
		and #1
		bne loc_966C
		ldy #$FA
loc_966C:

		sty $A0,x
		lda $1E,x
		ora #1
		sta $1E,x
		lda TMP_0
		and $7A9,x
		tay
		lda SecondaryHardMode
		bne loc_9680
		tay
loc_9680:

		lda HammerBroJumpLData,y
		sta $78A,x
		lda $7A8,x
		ora #$C0
		sta $3C,x
loc_968D:

		ldy #$FC
		lda FrameCounter
		and #$40
		bne loc_9697
		ldy #4
loc_9697:

		sty $58,x
		ldy #1
		jsr PlayerEnemyDiff
		bmi loc_96AA
		iny
		lda $796,x
		bne loc_96AA
		lda #$F8
		sta $58,x
loc_96AA:

		sty $46,x
MoveNormalEnemy:

		ldy #0
		lda $1E,x
		and #$40
		bne loc_96CD
		lda $1E,x
		asl
		bcs loc_96E9
		lda $1E,x
		and #$20
		bne loc_971A
		lda $1E,x
		and #7
		beq loc_96E9
		cmp #5
		beq loc_96CD
		cmp #3
		bcs loc_96FD
loc_96CD:

		jsr sub_8B34
		ldy #0
		lda $1E,x
		cmp #2
		beq loc_96E4
		and #$40
		beq loc_96E9
		lda $16,x
		cmp #$2E
		beq loc_96E9
		bne loc_96E7
loc_96E4:

		jmp MoveEnemyHorizontally
loc_96E7:

		ldy #1
loc_96E9:

		lda $58,x
		pha
		bpl loc_96F0
		iny
		iny
loc_96F0:

		clc
		adc XSpeedAdderData,y
		sta $58,x
		jsr MoveEnemyHorizontally
		pla
		sta $58,x
		rts
loc_96FD:

		lda $796,x
		bne loc_9720
		sta $1E,x
		lda FrameCounter
		and #1
		tay
		iny
		sty $46,x
		dey
		lda PrimaryHardMode
		beq loc_9714
		iny
		iny
loc_9714:

		lda RevivedXSpeed,y
		sta $58,x
		rts
loc_971A:

		jsr sub_8B34
		jmp MoveEnemyHorizontally
loc_9720:

		cmp #$E
		bne locret_972D
		lda $16,x
		cmp #6
		bne locret_972D
		jsr EraseEnemyObject
locret_972D:

		rts
MoveJumpingEnemy:

		jsr MoveJ_EnemyVertically
		jmp MoveEnemyHorizontally
ProcMoveRedPTroopa:

		lda ExplosionTimerCounter,x
		ora PiranhaPlantDownYPos,x
		bne loc_974E
		sta PiranhaPlantUpYPos,x
		lda Enemy_Y_Position,x
		cmp RedPTroopaOrigXPos,x
		bcs loc_974E
		lda FrameCounter
		and #7
		bne locret_974D
		inc Enemy_Y_Position,x
locret_974D:

		rts
loc_974E:

		lda Enemy_Y_Position,x
		cmp Enemy_X_Speed,x
		bcc loc_9757
		jmp loc_8B46
loc_9757:

		jmp loc_8B41
MoveFlyGreenPTroopa:

		jsr XMoveCntr_GreenPTroopa
		jsr MoveWithXMCntrs
		ldy #1
		lda FrameCounter
		and #3
		bne locret_9779
		lda FrameCounter
		and #$40
		bne loc_9770
		ldy #$FF
loc_9770:

		sty TMP_0
		lda Enemy_Y_Position,x
		clc
		adc TMP_0
		sta Enemy_Y_Position,x
locret_9779:

		rts
XMoveCntr_GreenPTroopa:

		lda #$13
XMoveCntr_Platform:

		sta TMP_1
		lda FrameCounter
		and #3
		bne locret_9791
		ldy $58,x
		lda $A0,x
		lsr
		bcs loc_9795
		cpy TMP_1
		beq loc_9792
		inc $58,x
locret_9791:

		rts
loc_9792:

		inc $A0,x
		rts
loc_9795:

		tya
		beq loc_9792
		dec $58,x
		rts
MoveWithXMCntrs:

		lda $58,x
		pha
		ldy #1
		lda $A0,x
		and #2
		bne loc_97B1
		lda $58,x
		eor #$FF
		clc
		adc #1
		sta $58,x
		ldy #2
loc_97B1:

		sty $46,x
		jsr MoveEnemyHorizontally
		sta TMP_0
		pla
		sta $58,x
		rts
BlooberBitmasks:
		.byte $3F
		.byte 3
MoveBloober:

		lda Enemy_State,x
		and #$20
		bne loc_9811
		ldy SecondaryHardMode
		lda $7A8,x
		and BlooberBitmasks,y
		bne loc_97E1
		txa
		lsr
		bcc loc_97D7
		ldy Player_MovingDir
		bcs loc_97DF
loc_97D7:

		ldy #2
		jsr PlayerEnemyDiff
		bpl loc_97DF
		dey
loc_97DF:

		sty $46,x
loc_97E1:

		jsr sub_9814
		lda $CF,x
		sec
		sbc $434,x
		cmp #$20
		bcc loc_97F0
		sta $CF,x
loc_97F0:

		ldy $46,x
		dey
		bne loc_9803
		lda $87,x
		clc
		adc $58,x
		sta $87,x
		lda $6E,x
		adc #0
		sta $6E,x
		rts
loc_9803:

		lda $87,x
		sec
		sbc $58,x
		sta $87,x
		lda $6E,x
		sbc #0
		sta $6E,x
		rts
loc_9811:

		jmp MoveEnemySlowVert
sub_9814:

		lda $A0,x
		and #2
		bne loc_9851
		lda FrameCounter
		and #7
		pha
		lda $A0,x
		lsr
		bcs loc_9839
		pla
		bne locret_9838
		lda $434,x
		clc
		adc #1
		sta $434,x
		sta $58,x
		cmp #2
		bne locret_9838
		inc $A0,x
locret_9838:

		rts
loc_9839:

		pla
		bne locret_9850
		lda $434,x
		sec
		sbc #1
		sta $434,x
		sta $58,x
		bne locret_9850
		inc $A0,x
		lda #2
		sta $796,x
locret_9850:

		rts
loc_9851:

		lda $796,x
		beq loc_985E
loc_9856:

		lda FrameCounter
		lsr
		bcs locret_985D
		inc $CF,x
locret_985D:

		rts
loc_985E:

		lda $CF,x
		adc #$10
		cmp SprObject_Y_Position
		bcc loc_9856
		lda #0
		sta $A0,x
		rts
MoveBulletBill:

		lda Enemy_State,x
		and #$20
		beq loc_9874
		jmp MoveJ_EnemyVertically
loc_9874:

		lda #$E8
		sta Enemy_X_Speed,x
		jmp MoveEnemyHorizontally
SwimCCXMoveData:
		.byte $40
		.byte $80
		.byte 4
		.byte 4
MoveSwimmingCheepCheep:

		lda $1E,x
		and #$20
		beq loc_9888
		jmp MoveEnemySlowVert
loc_9888:

		sta byte_3
		lda $16,x
		sec
		sbc #$A
		tay
		lda SwimCCXMoveData,y
		sta byte_2
		lda $401,x
		sec
		sbc byte_2
		sta $401,x
		lda $87,x
		sbc #0
		sta $87,x
		lda $6E,x
		sbc #0
		sta $6E,x
		lda #$40
		sta byte_2
		cpx #2
		bcc locret_98FB
		lda $58,x
		cmp #$10
		bcc loc_98CE
		lda $417,x
		clc
		adc byte_2
		sta $417,x
		lda $CF,x
		adc byte_3
		sta $CF,x
		lda $B6,x
		adc #0
		jmp loc_98E1
loc_98CE:

		lda $417,x
		sec
		sbc byte_2
		sta $417,x
		lda $CF,x
		sbc byte_3
		sta $CF,x
		lda $B6,x
		sbc #0
loc_98E1:

		sta $B6,x
		ldy #0
		lda $CF,x
		sec
		sbc $434,x
		bpl loc_98F4
		ldy #$10
		eor #$FF
		clc
		adc #1
loc_98F4:

		cmp #$F
		bcc locret_98FB
		tya
		sta $58,x
locret_98FB:

		rts
FirebarPosLookupTbl:
		.byte 0
		.byte 1
		.byte 3
		.byte 4
		.byte 5
		.byte 6
		.byte 7
		.byte 7
		.byte 8
		.byte 0
		.byte 3
		.byte 6
		.byte 9
		.byte $B
		.byte $D
		.byte $E
		.byte $F
		.byte $10
		.byte 0
		.byte 4
		.byte 9
		.byte $D
		.byte $10
		.byte $13
		.byte $16
		.byte $17
		.byte $18
		.byte 0
		.byte 6
		.byte $C
		.byte $12
		.byte $16
		.byte $1A
		.byte $1D
		.byte $1F
		.byte $20
		.byte 0
		.byte 7
		.byte $F
		.byte $16
		.byte $1C
		.byte $21
		.byte $25
		.byte $27
		.byte $28
		.byte 0
		.byte 9
		.byte $12
		.byte $1B
		.byte $21
		.byte $27
		.byte $2C
		.byte $2F
		.byte $30
		.byte 0
		.byte $B
		.byte $15
		.byte $1F
		.byte $27
		.byte $2E
		.byte $33
		.byte $37
		.byte $38
		.byte 0
		.byte $C
		.byte $18
		.byte $24
		.byte $2D
		.byte $35
		.byte $3B
		.byte $3E
		.byte $40
		.byte 0
		.byte $E
		.byte $1B
		.byte $28
		.byte $32
		.byte $3B
		.byte $42
		.byte $46
		.byte $48
		.byte 0
		.byte $F
		.byte $1F
		.byte $2D
		.byte $38
		.byte $42
		.byte $4A
		.byte $4E
		.byte $50
		.byte 0
		.byte $11
		.byte $22
		.byte $31
		.byte $3E
		.byte $49
		.byte $51
		.byte $56
		.byte $58
FirebarMirrorData:
		.byte 1
		.byte 3
		.byte 2
		.byte 0
FirebarTblOffsets:
		.byte 0
		.byte 9
		.byte $12
		.byte $1B
		.byte $24
		.byte $2D
		.byte $36
		.byte $3F
		.byte $48
		.byte $51
		.byte $5A
		.byte $63
FirebarYPos:
		.byte $C
		.byte $18
ProcFirebar:

		jsr GetEnemyOffscreenBits
		lda Enemy_OffscreenBits
		and #8
		bne locret_99EF
		lda TimerControl
		bne loc_998A
		lda $388,x
		jsr sub_A043
		and #$1F
		sta $A0,x
loc_998A:

		lda $A0,x
		ldy $16,x
		cpy #$1F
		bcc loc_999F
		cmp #8
		beq loc_999A
		cmp #$18
		bne loc_999F
loc_999A:

		clc
		adc #1
		sta $A0,x
loc_999F:

		sta byte_EF
		jsr RelativeEnemyPosition
		jsr sub_9AC3
		ldy $6E5,x
		lda Enemy_Rel_YPos
		sta $200,y
		sta unk_7
		lda Enemy_Rel_XPos
		sta $203,y
		sta byte_6
		lda #1
		sta TMP_0
		jsr FirebarCollision
		ldy #5
		lda $16,x
		cmp #$1F
		bcc loc_99CB
		ldy #$B
loc_99CB:

		sty byte_ED
		lda #0
		sta TMP_0
loc_99D1:

		lda byte_EF
		jsr sub_9AC3
		jsr sub_99F0
		lda TMP_0
		cmp #4
		bne loc_99E7
		ldy DuplicateObj_Offset
		lda $6E5,y
		sta byte_6
loc_99E7:

		inc TMP_0
		lda TMP_0
		cmp byte_ED
		bcc loc_99D1
locret_99EF:

		rts
sub_99F0:

		lda byte_3
		sta byte_5
		ldy byte_6
		lda TMP_1
		lsr byte_5
		bcs loc_9A00
		eor #$FF
		adc #1
loc_9A00:

		clc
		adc Enemy_Rel_XPos
		sta $203,y
		sta byte_6
		cmp Enemy_Rel_XPos
		bcs loc_9A17
		lda Enemy_Rel_XPos
		sec
		sbc byte_6
		jmp loc_9A1B
loc_9A17:

		sec
		sbc Enemy_Rel_XPos
loc_9A1B:

		cmp #$59
		bcc loc_9A23
		lda #$F8
		bne loc_9A38
loc_9A23:

		lda Enemy_Rel_YPos
		cmp #$F8
		beq loc_9A38
		lda byte_2
		lsr byte_5
		bcs loc_9A34
		eor #$FF
		adc #1
loc_9A34:

		clc
		adc Enemy_Rel_YPos
loc_9A38:

		sta $200,y
		sta unk_7
FirebarCollision:

		jsr DrawFirebar
		tya
		pha
		lda StarInvincibleTimer
		ora TimerControl
		bne loc_9ABA
		sta byte_5
		ldy Player_Y_HighPos
		dey
		bne loc_9ABA
		ldy SprObject_Y_Position
		lda PlayerSize
		bne loc_9A5D
		lda CrouchingFlag
		beq loc_9A66
loc_9A5D:

		inc byte_5
		inc byte_5
		tya
		clc
		adc #$18
		tay
loc_9A66:

		tya
loc_9A67:

		sec
		sbc unk_7
		bpl loc_9A71
		eor #$FF
		clc
		adc #1
loc_9A71:

		cmp #8
		bcs loc_9A91
		lda byte_6
		cmp #$F0
		bcs loc_9A91
		lda byte_207
		clc
		adc #4
		sta byte_4
		sec
		sbc byte_6
		bpl loc_9A8D
		eor #$FF
		clc
		adc #1
loc_9A8D:

		cmp #8
		bcc loc_9AA4
loc_9A91:

		lda byte_5
		cmp #2
		beq loc_9ABA
		ldy byte_5
		lda SprObject_Y_Position
		clc
		adc FirebarYPos,y
		inc byte_5
		jmp loc_9A67
loc_9AA4:

		ldx #1
		lda byte_4
		cmp byte_6
		bcs loc_9AAD
		inx
loc_9AAD:

		stx Enemy_MovingDir
		ldx #0
		lda TMP_0
		pha
		jsr loc_A587
		pla
		sta TMP_0
loc_9ABA:

		pla
		clc
		adc #4
		sta byte_6
		ldx ObjectOffset
		rts
sub_9AC3:

		pha
		and #$F
		cmp #9
		bcc loc_9ACF
		eor #$F
		clc
		adc #1
loc_9ACF:

		sta TMP_1
		ldy TMP_0
		lda FirebarTblOffsets,y
		clc
		adc TMP_1
		tay
		lda FirebarPosLookupTbl,y
		sta TMP_1
		pla
		pha
		clc
		adc #8
		and #$F
		cmp #9
		bcc loc_9AEF
		eor #$F
		clc
		adc #1
loc_9AEF:

		sta byte_2
		ldy TMP_0
		lda FirebarTblOffsets,y
		clc
		adc byte_2
		tay
		lda FirebarPosLookupTbl,y
		sta byte_2
		pla
		lsr
		lsr
		lsr
		tay
		lda FirebarMirrorData,y
		sta byte_3
		rts
PRandomSubtracter:
		.byte $F8
		.byte $A0
		.byte $70
		.byte $BD
		.byte 0
FlyCCBPriority:
		.byte $20
		.byte $20
		.byte $20
		.byte 0
		.byte 0
MoveFlyingCheepCheep:

		lda Enemy_State,x
		and #$20
		beq loc_9B22
		lda #0
		sta Enemy_SprAttrib,x
		jmp MoveJ_EnemyVertically
loc_9B22:

		jsr MoveEnemyHorizontally
		ldy #$D
		lda #5
		jsr loc_8B67
		lda $434,x
		lsr
		lsr
		lsr
		lsr
		tay
		lda Enemy_Y_Position,x
		sec
		sbc PRandomSubtracter,y
		bpl loc_9B41
		eor #$FF
		clc
		adc #1
loc_9B41:

		cmp #8
		bcs loc_9B53
		lda $434,x
		clc
		adc #$10
		sta $434,x
		lsr
		lsr
		lsr
		lsr
		tay
loc_9B53:

		lda FlyCCBPriority,y
		sta Enemy_SprAttrib,x
		rts
LakituDiffAdj:
		.byte $15
		.byte $30
		.byte $40
MoveLakitu:

		lda Enemy_State,x
		and #$20
		beq loc_9B66
		jmp sub_8B34
loc_9B66:

		lda Enemy_State,x
		beq loc_9B75
		lda #0
		sta $A0,x
		sta EnemyFrenzyBuffer
		lda #$10
		bne loc_9B88
loc_9B75:

		lda #$12
		sta EnemyFrenzyBuffer
		ldy #2
loc_9B7C:

		lda LakituDiffAdj,y
		sta 1,y
		dey
		bpl loc_9B7C
		jsr PlayerLakituDiff
loc_9B88:

		sta $58,x
		ldy #1
		lda $A0,x
		and #1
		bne loc_9B9C
		lda $58,x
		eor #$FF
		clc
		adc #1
		sta $58,x
		iny
loc_9B9C:

		sty $46,x
		jmp MoveEnemyHorizontally
PlayerLakituDiff:

		ldy #0
		jsr PlayerEnemyDiff
		bpl loc_9BB2
		iny
		lda TMP_0
		eor #$FF
		clc
		adc #1
		sta TMP_0
loc_9BB2:

		lda TMP_0
		cmp #$3C
		bcc loc_9BD4
		lda #$3C
		sta TMP_0
		lda $16,x
		cmp #$11
		bne loc_9BD4
		tya
		cmp $A0,x
		beq loc_9BD4
		lda $A0,x
		beq loc_9BD1
		dec $58,x
		lda $58,x
		bne locret_9C11
loc_9BD1:

		tya
		sta $A0,x
loc_9BD4:

		lda TMP_0
		and #$3C
		lsr
		lsr
		sta TMP_0
		ldy #0
		lda Player_X_Speed
		beq loc_9C06
		lda ScrollAmount
		beq loc_9C06
		iny
		lda Player_X_Speed
		cmp #$19
		bcc loc_9BF6
		lda ScrollAmount
		cmp #2
		bcc loc_9BF6
		iny
loc_9BF6:

		lda $16,x
		cmp #$12
		bne loc_9C00
		lda Player_X_Speed
		bne loc_9C06
loc_9C00:

		lda $A0,x
		bne loc_9C06
		ldy #0
loc_9C06:

		lda 1,y
		ldy TMP_0
loc_9C0B:

		sec
		sbc #1
		dey
		bpl loc_9C0B
locret_9C11:

		rts
BridgeCollapseData:
		.byte $1A
byte_9C13:
		.byte $58
		.byte $98
		.byte $96
		.byte $94
		.byte $92
		.byte $90
		.byte $8E
		.byte $8C
		.byte $8A
		.byte $88
		.byte $86
		.byte $84
		.byte $82
		.byte $80
BridgeCollapse:

		ldx BowserFront_Offset
		lda Enemy_ID,x
		cmp #$2D
		bne loc_9C3A
		stx ObjectOffset
		lda $1E,x
		beq loc_9C4A
		and #$40
		beq loc_9C3A
		lda $CF,x
		cmp #$E0
		bcc loc_9C44
loc_9C3A:

		lda #$80
		sta EventMusicQueue
		inc OperMode_Task
		jmp sub_9CA6
loc_9C44:

		jsr MoveEnemySlowVert
		jmp loc_9DB0
loc_9C4A:

		dec BowserFeetCounter
		bne loc_9C93
		lda #4
		sta BowserFeetCounter
		lda BowserBodyControls
		eor #1
		sta BowserBodyControls
		lda #$22
		sta byte_5
		ldy BridgeCollapseOffset
		lda BridgeCollapseData,y
		sta byte_4
		ldy VRAM_Buffer1_Offset
		iny
		ldx #$C
		jsr loc_69AA
		ldx ObjectOffset
		jsr loc_696C
		lda #8
		sta Square2SoundQueue
		lda #1
		sta NoiseSoundQueue
		inc BridgeCollapseOffset
		lda BridgeCollapseOffset
		cmp #$F
		bne loc_9C93
		jsr InitVStf
		lda #$40
		sta $1E,x
		lda #$80
		sta Square2SoundQueue
loc_9C93:

		jmp loc_9DB0
PRandomRange:
		.byte $21
		.byte $41
		.byte $11
		.byte $31
RunBowser:

		lda Enemy_State,x
		and #$20
		beq loc_9CB4
		lda Enemy_Y_Position,x
		cmp #$E0
		bcc loc_9C44
sub_9CA6:

		ldx #4
loc_9CA8:

		jsr EraseEnemyObject
		dex
		bpl loc_9CA8
		sta EnemyFrenzyBuffer
		ldx ObjectOffset
		rts
loc_9CB4:

		lda #0
		sta EnemyFrenzyBuffer
		lda TimerControl
		beq loc_9CC1
		jmp loc_9D6E
loc_9CC1:

		lda BowserBodyControls
		bpl loc_9CC9
		jmp loc_9D44
loc_9CC9:

		dec BowserFeetCounter
		bne loc_9CDB
		lda #$20
		sta BowserFeetCounter
		lda BowserBodyControls
		eor #1
		sta BowserBodyControls
loc_9CDB:

		lda FrameCounter
		and #$F
		bne loc_9CE5
		lda #2
		sta $46,x
loc_9CE5:

		lda $78A,x
		beq loc_9D06
		jsr PlayerEnemyDiff
		bpl loc_9D06
		lda #1
		sta $46,x
		lda #2
		sta BowserMovementSpeed
		lda #$20
		sta $78A,x
		sta BowserFireBreathTimer
		lda $87,x
		cmp #$C8
		bcs loc_9D44
loc_9D06:

		lda FrameCounter
		and #3
		bne loc_9D44
		lda $87,x
		cmp BowserOrigXPos
		bne loc_9D1F
		lda $7A7,x
		and #3
		tay
		lda PRandomRange,y
		sta MaxRangeFromOrigin
loc_9D1F:

		lda $87,x
		clc
		adc BowserMovementSpeed
		sta $87,x
		ldy $46,x
		cpy #1
		beq loc_9D44
		ldy #$FF
		sec
		sbc BowserOrigXPos
		bpl loc_9D3C
		eor #$FF
		clc
		adc #1
		ldy #1
loc_9D3C:

		cmp MaxRangeFromOrigin
		bcc loc_9D44
		sty BowserMovementSpeed
loc_9D44:

		lda $78A,x
		bne loc_9D71
		jsr MoveEnemySlowVert
		lda WorldNumber
		cmp #5
		bcc loc_9D5C
		lda FrameCounter
		and #3
		bne loc_9D5C
		jsr SpawnHammerObj
loc_9D5C:

		lda $CF,x
		cmp #$80
		bcc loc_9D7E
		lda $7A7,x
		and #3
		tay
		lda PRandomRange,y
		sta $78A,x
loc_9D6E:

		jmp loc_9D7E
loc_9D71:

		cmp #1
		bne loc_9D7E
		dec $CF,x
		jsr InitVStf
		lda #$FE
		sta $A0,x
loc_9D7E:

		lda WorldNumber
		cmp #7
		beq loc_9D89
		cmp #5
		bcs loc_9DB0
loc_9D89:

		lda BowserFireBreathTimer
		bne loc_9DB0
		lda #$20
		sta BowserFireBreathTimer
		lda BowserBodyControls
		eor #$80
		sta BowserBodyControls
		bmi loc_9D7E
		jsr sub_9E0E
		ldy SecondaryHardMode
		beq loc_9DA8
		sec
		sbc #$10
loc_9DA8:

		sta BowserFireBreathTimer
		lda #$15
		sta EnemyFrenzyBuffer
loc_9DB0:

		jsr sub_9DF1
		ldy #$10
		lda $46,x
		lsr
		bcc loc_9DBC
		ldy #$F0
loc_9DBC:

		tya
		clc
		adc $87,x
		ldy DuplicateObj_Offset
		sta $87,y
		lda $CF,x
		clc
		adc #8
		sta $CF,y
		lda $1E,x
		sta $1E,y
		lda $46,x
		sta $46,y
		lda ObjectOffset
		pha
		ldx DuplicateObj_Offset
		stx ObjectOffset
		lda #$2D
		sta $16,x
		jsr sub_9DF1
		pla
		sta ObjectOffset
		tax
		lda #0
		sta BowserGfxFlag
locret_9DF0:
		rts
sub_9DF1:
		inc BowserGfxFlag
		jsr RunRetainerObj
		lda $1E,x
		bne locret_9DF0
		lda #$A
		sta $49A,x
		jsr GetEnemyBoundBox
		jmp PlayerEnemyCollision

FlameTimerData:
		.byte $BF
		.byte $40
		.byte $BF
		.byte $BF
		.byte $BF
		.byte $40
		.byte $40
		.byte $BF

sub_9E0E:
		ldy BowserFlameTimerCtrl
		inc BowserFlameTimerCtrl
		lda BowserFlameTimerCtrl
		and #7
		sta BowserFlameTimerCtrl
		lda FlameTimerData,y
locret_9E1F:
		rts

ProcBowserFlame:
		lda TimerControl
		bne loc_9E55
		lda #$40
		ldy SecondaryHardMode
		beq loc_9E2E
		lda #$60
loc_9E2E:
		sta TMP_0
		lda $401,x
		sec
		sbc TMP_0
		sta $401,x
		lda Enemy_X_Position,x
		sbc #1
		sta Enemy_X_Position,x
		lda Enemy_PageLoc,x
		sbc #0
		sta Enemy_PageLoc,x
		ldy $417,x
		lda Enemy_Y_Position,x
		cmp FlameYPosData,y
		beq loc_9E55
		clc
		adc $434,x
		sta Enemy_Y_Position,x
loc_9E55:
		jsr RelativeEnemyPosition
		lda Enemy_State,x
		bne locret_9E1F
		lda #$51
		sta TMP_0
		ldy #2
		lda FrameCounter
		and #2
		beq loc_9E6A
		ldy #$82
loc_9E6A:
		sty TMP_1
		ldy $6E5,x
		ldx #0
loc_9E71:
		lda Enemy_Rel_YPos
		sta $200,y
		lda TMP_0
		sta $201,y
		inc TMP_0
		lda TMP_1
		sta $202,y
		lda Enemy_Rel_XPos
		sta $203,y
		clc
		adc #8
		sta Enemy_Rel_XPos
		iny
		iny
		iny
		iny
		inx
		cpx #3
		bcc loc_9E71
		ldx ObjectOffset
		jsr GetEnemyOffscreenBits
		ldy $6E5,x
		lda Enemy_OffscreenBits
		lsr
		pha
		bcc loc_9EAC
		lda #$F8
		sta $20C,y
loc_9EAC:
		pla
		lsr
		pha
		bcc loc_9EB6
		lda #$F8
		sta $208,y
loc_9EB6:
		pla
		lsr
		pha
		bcc loc_9EC0
		lda #$F8
		sta $204,y
loc_9EC0:
		pla
		lsr
		bcc locret_9EC9
		lda #$F8
		sta $200,y
locret_9EC9:
		rts

RunFireworks:
		dec ExplosionTimerCounter,x
		bne loc_9EDA
		lda #8
		sta ExplosionTimerCounter,x
		inc Enemy_X_Speed,x
		lda Enemy_X_Speed,x
		cmp #3
		bcs loc_9EF2
loc_9EDA:
		jsr RelativeEnemyPosition
		lda Enemy_Rel_YPos
		sta Fireball_Rel_YPos
		lda Enemy_Rel_XPos
		sta Fireball_Rel_XPos
		ldy $6E5,x
		lda $58,x
		jsr DrawExplosion_Fireworks
		rts
loc_9EF2:
		lda #0
		sta $F,x
		lda #8
		sta Square2SoundQueue
		lda #5
		sta byte_138
		jmp EndAreaPoints_MAYBE

StarFlagYPosAdder:
		.byte 0
		.byte 0
		.byte 8
		.byte 8
StarFlagXPosAdder:
		.byte 0
		.byte 8
		.byte 0
		.byte 8
StarFlagTileData:
		.byte $54
		.byte $55
		.byte $56
		.byte $57

RunStarFlagObj:
		lda #0
		sta EnemyFrenzyBuffer
		lda StarFlagTaskControl
		cmp #5
		bcs StarFlagExit
		jsr JumpEngine
		.word StarFlagExit
		.word GameTimerFireworks_NEW
		.word GameTimerFireworks
		.word RaiseFlagSetoffFWorks
		.word DelayToAreaEnd

GameTimerFireworks_NEW:
		lda byte_7EE
		cmp byte_7E8
		bne loc_9F3F
		and #1
		beq loc_9F39
		ldy #3
		lda #3
		bne loc_9F43
loc_9F39:
		ldy #0
		lda #6
		bne loc_9F43
loc_9F3F:
		ldy #0
		lda #$FF
loc_9F43:
		sta FireworksCounter
		sty $1E,x
loc_9F48:
		inc StarFlagTaskControl
StarFlagExit:
		rts

GameTimerFireworks:
		lda byte_7EC
		ora byte_7ED
		ora byte_7EE
		beq loc_9F48
sub_9F57:
		lda FrameCounter
		and #4
		beq loc_9F61
		lda #$10
		sta Square2SoundQueue
loc_9F61:
		ldy #$17
		lda #$FF
		sta byte_139
		jsr DigitsMathRoutine
		lda #5
		sta byte_139

EndAreaPoints_MAYBE:
		ldy #$B
		jsr DigitsMathRoutine
		lda #2
		jmp UpdateNumber

RaiseFlagSetoffFWorks:
		lda Enemy_Y_Position,x
		cmp #$72
		bcc loc_9F85
		dec $CF,x
		jmp DrawStarFlag
loc_9F85:
		lda FireworksCounter
		beq loc_9FC2
		bmi loc_9FC2
		lda #$16
		sta EnemyFrenzyBuffer

DrawStarFlag:
		jsr RelativeEnemyPosition
		ldy $6E5,x
		ldx #3
loc_9F99:
		lda Enemy_Rel_YPos
		clc
		adc StarFlagYPosAdder,x
		sta $200,y
		lda StarFlagTileData,x
		sta $201,y
		lda #$22
		sta $202,y
		lda Enemy_Rel_XPos
		clc
		adc StarFlagXPosAdder,x
		sta $203,y
		iny
		iny
		iny
		iny
		dex
		bpl loc_9F99
		ldx ObjectOffset
		rts
loc_9FC2:

		jsr DrawStarFlag
		lda #6
		sta $796,x
loc_9FCA:

		inc StarFlagTaskControl
		rts

DelayToAreaEnd:
		jsr DrawStarFlag
		lda EnemyIntervalTimer,x
		bne locret_9FDB
		lda EventMusicBuffer
		beq loc_9FCA
locret_9FDB:
		rts

MovePiranhaPlant:
		lda Enemy_State,x
		bne loc_A03D
		lda EnemyFrameTimer,x
		bne loc_A03D
		lda ExplosionTimerCounter,x
		bne loc_A00C
		lda Enemy_X_Speed,x
		bmi loc_A001
		jsr PlayerEnemyDiff
		bpl loc_9FFB
		lda TMP_0
		eor #$FF
		clc
		adc #1
		sta TMP_0
loc_9FFB:

		lda TMP_0
		cmp WRAM_PiranhaPlantDist
		bcc loc_A03D
loc_A001:

		lda $58,x
		eor #$FF
		clc
		adc #1
		sta $58,x
		inc $A0,x
loc_A00C:

		lda $434,x
		ldy $58,x
		bpl loc_A016
		lda $417,x
loc_A016:

		sta TMP_0
		lda WRAM_PiranhaPlantAttributeData
		cmp #$22
		beq loc_A024
		lda FrameCounter
		lsr
		bcc loc_A03D
loc_A024:

		lda TimerControl
		bne loc_A03D
		lda $CF,x
		clc
		adc $58,x
		sta $CF,x
		cmp TMP_0
		bne loc_A03D
		lda #0
		sta $A0,x
		lda #$40
		sta $78A,x
loc_A03D:

		lda #$20
		sta $3C5,x
		rts
sub_A043:

		sta unk_7
		lda $34,x
		bne loc_A057
		ldy #$18
		lda $58,x
		clc
		adc unk_7
		sta $58,x
		lda $A0,x
		adc #0
		rts
loc_A057:

		ldy #8
		lda $58,x
		sec
		sbc unk_7
		sta $58,x
sub_A060:

		lda $A0,x
		sbc #0
		rts
BalancePlatform:

		lda Enemy_Y_HighPos,x
		cmp #3
		bne loc_A06E
		jmp EraseEnemyObject
loc_A06E:

		lda $1E,x
		bpl loc_A073
locret_A072:

		rts
loc_A073:

		tay
		lda $16,y
		cmp #$24
		bne locret_A072
		lda $3A2,x
		sta TMP_0
		lda $46,x
		beq loc_A087
		jmp loc_A1F5
loc_A087:

		lda #$2D
		cmp $CF,x
		bcc loc_A09C
		cpy TMP_0
		beq loc_A099
		clc
		adc #2
		sta $CF,x
		jmp sub_A1EB
loc_A099:

		jmp loc_A1D2
loc_A09C:

		cmp $CF,y
		bcc loc_A0AE
		cpx TMP_0
		beq loc_A099
		clc
		adc #2
		sta $CF,y
		jmp sub_A1EB
loc_A0AE:

		lda $CF,x
		pha
		lda $3A2,x
		bpl loc_A0CE
		lda $434,x
		clc
		adc #5
		sta TMP_0
		lda $A0,x
		adc #0
		bmi loc_A0DE
		bne loc_A0D2
		lda TMP_0
		cmp #$B
		bcc loc_A0D8
		bcs loc_A0D2
loc_A0CE:

		cmp ObjectOffset
		beq loc_A0DE
loc_A0D2:

		jsr loc_8B87+1
		jmp loc_A0E1
loc_A0D8:

		jsr sub_A1EB
		jmp loc_A0E1
loc_A0DE:

		jsr sub_8B85
loc_A0E1:

		ldy $1E,x
		pla
		sec
		sbc $CF,x
		clc
		adc $CF,y
		sta $CF,y
		lda $3A2,x
		bmi loc_A0F7
		tax
		jsr PositionPlayerOnVPlat
loc_A0F7:

		ldy ObjectOffset
		lda $A0,y
		ora $434,y
		beq loc_A178
		ldx VRAM_Buffer1_Offset
		cpx #$20
		bcs loc_A178
		lda $A0,y
		pha
		pha
		jsr sub_A17B
		lda TMP_1
		sta $301,x
		lda TMP_0
		sta $302,x
		lda #2
		sta $303,x
		lda $A0,y
		bmi loc_A131
		lda #$A2
		sta $304,x
		lda #$A3
		sta $305,x
		jmp loc_A139
loc_A131:

		lda #$24
		sta $304,x
		sta $305,x
loc_A139:

		lda $1E,y
		tay
		pla
		eor #$FF
		jsr sub_A17B
		lda TMP_1
		sta $306,x
		lda TMP_0
		sta $307,x
		lda #2
		sta $308,x
		pla
		bpl loc_A162
		lda #$A2
		sta $309,x
		lda #$A3
		sta $30A,x
		jmp loc_A16A
loc_A162:

		lda #$24
		sta $309,x
		sta $30A,x
loc_A16A:

		lda #0
		sta $30B,x
		lda VRAM_Buffer1_Offset
		clc
		adc #$A
		sta VRAM_Buffer1_Offset
loc_A178:

		ldx ObjectOffset
		rts
sub_A17B:

		pha
		lda $87,y
		clc
		adc #8
		ldx SecondaryHardMode
		bne loc_A18A
		clc
		adc #$10
loc_A18A:

		pha
		lda $6E,y
		adc #0
		sta byte_2
		pla
		and #$F0
		lsr
		lsr
		lsr
		sta TMP_0
		ldx $CF,y
		pla
		bpl loc_A1A4
		txa
		clc
		adc #8
		tax
loc_A1A4:

		txa
		ldx VRAM_Buffer1_Offset
		asl
		rol
		pha
		rol
		and #3
		ora #$20
		sta TMP_1
		lda byte_2
		and #1
		asl
		asl
		ora TMP_1
		sta TMP_1
		pla
		and #$E0
		clc
		adc TMP_0
		sta TMP_0
		lda $CF,y
		cmp #$E8
		bcc locret_A1D1
		lda TMP_0
		and #$BF
		sta TMP_0
locret_A1D1:

		rts
loc_A1D2:

		tya
		tax
		jsr GetEnemyOffscreenBits
		lda #6
		jsr SetupFloateyNumber
		lda Player_Rel_XPos
		sta $117,x
		lda SprObject_Y_Position
		sta $11E,x
		lda #1
		sta $46,x
sub_A1EB:

		jsr InitVStf
		sta $A0,y
		sta $434,y
		rts
loc_A1F5:

		tya
		pha
		jsr loc_8B3C
		pla
		tax
		jsr loc_8B3C
		ldx ObjectOffset
		lda $3A2,x
		bmi loc_A20A
		tax
		jsr PositionPlayerOnVPlat
loc_A20A:

		ldx ObjectOffset
		rts
YMovingPlatform:

		lda ExplosionTimerCounter,x
		ora PiranhaPlantDownYPos,x
		bne loc_A229
		sta PiranhaPlantUpYPos,x
		lda Enemy_Y_Position,x
		cmp RedPTroopaOrigXPos,x
		bcs loc_A229
		lda FrameCounter
		and #7
		bne loc_A226
		inc Enemy_Y_Position,x
loc_A226:

		jmp ChkYPCollision
loc_A229:

		lda $CF,x
		cmp $58,x
		bcc loc_A235
		jsr loc_8B87+1
		jmp ChkYPCollision
loc_A235:

		jsr sub_8B85
ChkYPCollision:

		lda $3A2,x
		bmi locret_A240
		jsr PositionPlayerOnVPlat
locret_A240:

		rts
XMovingPlatform:

		lda #$E
		jsr XMoveCntr_Platform
		jsr MoveWithXMCntrs
		lda HammerThrowingTimer,x
		bmi locret_A26A
PositionPlayerOnHPlat:

		lda Player_X_Position
		clc
		adc TMP_0
		sta Player_X_Position
		lda Player_PageLoc
		ldy TMP_0
		bmi loc_A260
		adc #0
		jmp loc_A262
loc_A260:

		sbc #0
loc_A262:

		sta Player_PageLoc
		sty Platform_X_Scroll
		jsr PositionPlayerOnVPlat
locret_A26A:
		rts

DropPlatform:
		lda HammerThrowingTimer,x
		bmi locret_A276
		jsr MoveDropPlatform
		jsr PositionPlayerOnVPlat
locret_A276:
		rts

RightPlatform:
		jsr MoveEnemyHorizontally
		sta TMP_0
		lda HammerThrowingTimer,x
		bmi locret_A288
		lda #$10
		sta Enemy_X_Speed,x
		jsr PositionPlayerOnHPlat
locret_A288:
		rts

MoveLargeLiftPlat:
		jsr MoveLiftPlatforms
		jmp ChkYPCollision

MoveSmallPlatform:
		jsr MoveLiftPlatforms
		jmp ChkSmallPlatCollision

MoveLiftPlatforms:
		lda TimerControl
		bne locret_A2B3
		lda $417,x
		clc
		adc $434,x
		sta $417,x
		lda $CF,x
		adc $A0,x
		sta $CF,x
		rts

ChkSmallPlatCollision:
		lda $3A2,x
		beq locret_A2B3
		jsr PositionPlayerOnS_Plat
locret_A2B3:
		rts

OffscreenBoundsCheck:
		lda $16,x
		cmp #$14
		beq locret_A317
		lda ScreenLeft_X_Pos
		ldy $16,x
		cpy #5
		beq loc_A2CB
		cpy #4
		beq loc_A2CB
		cpy #$D
		bne loc_A2CD
loc_A2CB:
		adc #$38
loc_A2CD:
		sbc #$48
		sta TMP_1
		lda ScreenLeft_PageLoc
		sbc #0
		sta TMP_0
		lda ScreenRight_X_Pos
		adc #$48
		sta byte_3
		lda ScreenRight_PageLoc
		adc #0
		sta byte_2
		lda $87,x
		cmp TMP_1
		lda $6E,x
		sbc TMP_0
		bmi loc_A314
		lda $87,x
		cmp byte_3
		lda $6E,x
		sbc byte_2
		bmi locret_A317
		lda $1E,x
		cmp #5
		beq locret_A317
		cpy #$D
		beq locret_A317
		cpy #4
		beq locret_A317
		cpy #$30
		beq locret_A317
		cpy #$31
		beq locret_A317
		cpy #$32
		beq locret_A317
loc_A314:

		jsr EraseEnemyObject
locret_A317:

		rts
		.byte $FF
sub_A319:

		lda $24,x
		beq loc_A373
		asl
		bcs loc_A373
		lda FrameCounter
		lsr
		bcs loc_A373
		txa
		asl
		asl
		clc
		adc #$1C
		tay
		ldx #4
loc_A32E:

		stx TMP_1
		tya
		pha
		lda $1E,x
		and #$20
		bne loc_A36C
		lda $F,x
		beq loc_A36C
		lda $16,x
		cmp #$24
		bcc loc_A346
		cmp #$2B
		bcc loc_A36C
loc_A346:

		cmp #6
		bne loc_A350
		lda $1E,x
		cmp #2
		bcs loc_A36C
loc_A350:

		lda $3D8,x
		bne loc_A36C
		txa
		asl
		asl
		clc
		adc #4
		tax
		jsr sub_AFC5
		ldx ObjectOffset
		bcc loc_A36C
		lda #$80
		sta $24,x
		ldx TMP_1
		jsr sub_A37F
loc_A36C:

		pla
		tay
		ldx TMP_1
		dex
		bpl loc_A32E
loc_A373:

		ldx ObjectOffset
		rts
BowserIdentities:
		.byte 6
		.byte 0
		.byte 2
		.byte $12
		.byte $11
		.byte 7
		.byte 5
		.byte $2D
		.byte $2D
sub_A37F:

		jsr RelativeEnemyPosition
		ldx TMP_1
		lda $F,x
		bpl loc_A393
		and #$F
		tax
		lda $16,x
		cmp #$2D
		beq loc_A39D
		ldx TMP_1
loc_A393:

		lda $16,x
		cmp #2
		beq locret_A40F
		cmp #$2D
		bne loc_A3CA
loc_A39D:

		dec BowserHitPoints
		bne locret_A40F
		jsr InitVStf
		sta Enemy_X_Speed,x
		sta EnemyFrenzyBuffer
		lda #$FE
		sta $A0,x
		ldy WorldNumber
		lda BowserIdentities,y
		sta $16,x
		lda #$20
		cpy #3
		bcs loc_A3BE
		ora #3
loc_A3BE:

		sta $1E,x
		lda #$80
		sta Square2SoundQueue
		ldx TMP_1
		lda #9
		bne loc_A408
loc_A3CA:

		cmp #8
		beq locret_A40F
		cmp #$C
		beq locret_A40F
		cmp #$15
		bcs locret_A40F
loc_A3D6:

		lda $16,x
		cmp #4
		beq loc_A3E0
		cmp #$D
		bne loc_A3ED
loc_A3E0:

		tay
		lda $CF,x
		adc #$18
		cpy #4
		bne loc_A3EB
		sbc #$31
loc_A3EB:

		sta $CF,x
loc_A3ED:

		jsr sub_ACA3
		lda $1E,x
		and #$1F
		ora #$20
		sta $1E,x
		lda #2
		ldy $16,x
		cpy #5
		bne loc_A402
		lda #6
loc_A402:

		cpy #6
		bne loc_A408
		lda #1
loc_A408:

		jsr SetupFloateyNumber
		lda #8
		sta Square1SoundQueue
locret_A40F:

		rts
PlayerHammerCollision:

		lda FrameCounter
		lsr
		bcc locret_A44E
		lda Player_OffscreenBits
		ora TimerControl
		ora Misc_OffscreenBits
		bne locret_A44E
		txa
		asl
		asl
		clc
		adc #$24
		tay
		jsr sub_AFC3
		ldx ObjectOffset
		bcc loc_A449
		lda $6BE,x
		bne locret_A44E
		lda #1
		sta $6BE,x
		lda $64,x
		eor #$FF
		clc
		adc #1
		sta $64,x
		lda StarInvincibleTimer
		bne locret_A44E
		jmp loc_A587
loc_A449:

		lda #0
		sta $6BE,x
locret_A44E:

		rts
loc_A44F:

		jsr EraseEnemyObject
		lda PowerUpType
		cmp #4
		bne loc_A45B
		jmp loc_A587
loc_A45B:

		lda #6
		jsr SetupFloateyNumber
		lda #$20
		sta Square2SoundQueue
		lda PowerUpType
		cmp #2
		bcc loc_A478
		cmp #3
		beq loc_A492
		lda #$23
		sta StarInvincibleTimer
		lda #$40
		sta AreaMusicQueue
		rts
loc_A478:

		lda PlayerStatus
		beq loc_A498
		cmp #1
		bne locret_A4A4
		ldx ObjectOffset
		lda #2
		sta PlayerStatus
		jsr GetPlayerColors_RW
		ldx ObjectOffset
		lda #$C
		jmp loc_A49F
loc_A492:

		lda #$B
		sta $110,x
		rts
loc_A498:

		lda #1
		sta PlayerStatus
		lda #9
loc_A49F:

		ldy #0
		jsr sub_A5A6
locret_A4A4:

		rts
		.byte $18
		.byte $E8
KickedShellXSpdData:
		.byte $30
		.byte $D0
DemotedKoopaXSpdData:
		.byte 8
		.byte $F8
PlayerEnemyCollision:

		lda FrameCounter
		lsr
		bcs locret_A4A4
		jsr CheckPlayerVertical
		bcs locret_A4D8
		lda $3D8,x
		bne locret_A4D8
		lda GameEngineSubroutine
		cmp #8
		bne locret_A4D8
		lda $1E,x
		and #$20
		bne locret_A4D8
		jsr sub_A8C0
		jsr sub_AFC3
		ldx ObjectOffset
		bcs loc_A4D9
		lda $491,x
		and #$FE
		sta $491,x
locret_A4D8:

		rts
loc_A4D9:

		ldy $16,x
		cpy #$2E
		bne loc_A4E2
		jmp loc_A44F
loc_A4E2:

		lda StarInvincibleTimer
		beq loc_A4ED
		jmp loc_A3D6
KickedShellPtsData:

		.byte $A
		.byte 6
		.byte 4
loc_A4ED:

		lda $491,x
		and #1
		ora $3D8,x
		bne locret_A554
		lda #1
		ora $491,x
		sta $491,x
		cpy #$12
		beq loc_A555
		cpy #$33
		beq loc_A555
		cpy #$D
		beq loc_A587
		cpy #4
		beq loc_A587
		cpy #$C
		beq loc_A587
		cpy #$15
		bcs loc_A587
		lda AreaType
		beq loc_A587
		lda $1E,x
		asl
		bcs loc_A555
		lda $1E,x
		and #7
		cmp #2
		bcc loc_A555
		lda $16,x
		cmp #6
		beq locret_A554
		lda #8
		sta Square1SoundQueue
		lda Enemy_State,x
		ora #$80
		sta Enemy_State,x
		jsr EnemyFacePlayer
		lda KickedShellXSpdData,y
		sta $58,x
		lda #3
		clc
		adc StompChainCounter
		ldy $796,x
		cpy #3
		bcs loc_A551
		lda KickedShellPtsData,y
loc_A551:

		jsr SetupFloateyNumber
locret_A554:

		rts
loc_A555:

		ldy Player_Y_Speed
		dey
		bpl loc_A5C7
		lda $16,x
		cmp #7
		bcc loc_A569
		lda SprObject_Y_Position
		clc
		adc #$C
		cmp $CF,x
		bcc loc_A5C7
loc_A569:

		lda StompTimer
		bne loc_A5C7
		lda InjuryTimer
		bne loc_A5B3
		lda Player_Rel_XPos
		cmp Enemy_Rel_XPos
		bcc loc_A57E
		jmp loc_A65F
loc_A57E:

		lda $46,x
		cmp #1
		bne loc_A587
		jmp loc_A668
loc_A587:

		lda InjuryTimer
		ora StarInvincibleTimer
		bne loc_A5B3
loc_A58F:

		ldx PlayerStatus
		beq loc_A5B6
		sta PlayerStatus
		lda #8
		sta InjuryTimer
		asl
		sta Square1SoundQueue
		jsr GetPlayerColors_RW
		lda #$A
loc_A5A4:

		ldy #1
sub_A5A6:

		sta GameEngineSubroutine
		sty Player_State
		ldy #$FF
		sty TimerControl
		iny
		sty ScrollAmount
loc_A5B3:

		ldx ObjectOffset
		rts
loc_A5B6:

		stx Player_X_Speed
		inx
		stx EventMusicQueue
		lda #$FC
		sta Player_Y_Speed
		lda #$B
		bne loc_A5A4
StompedEnemyPtsData:
		.byte 2, 6,	5, 6
loc_A5C7:

		lda $16,x
		cmp #$12
		beq loc_A587
		lda #4
		sta Square1SoundQueue
		lda $16,x
		ldy #0
		cmp #$14
		beq loc_A5F4
		cmp #8
		beq loc_A5F4
		cmp #$33
		beq loc_A5F4
		cmp #$C
		beq loc_A5F4
		iny
		cmp #5
		beq loc_A5F4
		iny
		cmp #$11
		beq loc_A5F4
		iny
		cmp #7
		bne loc_A60F
loc_A5F4:

		lda StompedEnemyPtsData,y
		jsr SetupFloateyNumber
		lda Enemy_MovingDir,x
		pha
		jsr loc_ACC1
		pla
		sta $46,x
		lda #$20
		sta $1E,x
		jsr InitVStf
		sta $58,x
		jmp sub_A64E
loc_A60F:

		cmp #9
		bcc HandleStompedShellE
		jsr sub_A64E
		and #1
		sta $16,x
		lda #0
		sta $1E,x
		lda #3
		jsr SetupFloateyNumber
		jsr InitVStf
		jsr EnemyFacePlayer
		lda DemotedKoopaXSpdData,y
		sta $58,x
		rts
RevivalRateData:
		.byte $10
		.byte $B
HandleStompedShellE:

		lda #4
		sta $1E,x
		inc StompChainCounter
		lda StompChainCounter
		clc
		adc StompTimer
		jsr SetupFloateyNumber
		inc StompTimer
		ldy PrimaryHardMode
		lda RevivalRateData,y
		sta $796,x
sub_A64E:

		ldy #$FA
		lda $16,x
		cmp #$F
		beq loc_A65A
		cmp #$10
		bne loc_A65C
loc_A65A:

		ldy #$F8
loc_A65C:

		sty Player_Y_Speed
		rts
loc_A65F:

		lda $46,x
		cmp #1
		bne loc_A668
		jmp loc_A587
loc_A668:

		jsr sub_A78D
		jmp loc_A587
EnemyFacePlayer:

		ldy #1
		jsr PlayerEnemyDiff
		bpl loc_A676
		iny
loc_A676:

		sty $46,x
		dey
		rts
SetupFloateyNumber:

		sta $110,x
		lda #$30
		sta $12C,x
		lda $CF,x
		sta $11E,x
		lda Enemy_Rel_XPos
		sta $117,x
locret_A68D:

		rts
SetBitsMask:
		.byte $80
		.byte $40
		.byte $20
		.byte $10
		.byte 8
		.byte 4
		.byte 2
ClearBitsMask:
		.byte $7F
		.byte $BF
		.byte $DF
		.byte $EF
		.byte $F7
		.byte $FB
		.byte $FD
EnemiesCollision:
		lda FrameCounter
		lsr
		bcc locret_A68D
		lda AreaType
		beq locret_A68D
		lda $16,x
		cmp #$15
		bcs loc_A722
		cmp #$11
		beq loc_A722
		cmp #$D
		beq loc_A722
		cmp #4
		beq loc_A722
		lda $3D8,x
		bne loc_A722
		jsr sub_A8C0
		dex
		bmi loc_A722
loc_A6C3:
		stx TMP_1
		tya
		pha
		lda $F,x
		beq loc_A71B
		lda $16,x
		cmp #$15
		bcs loc_A71B
		cmp #$11
		beq loc_A71B
		cmp #$D
		beq loc_A71B
		cmp #4
		beq loc_A71B
		lda $3D8,x
		bne loc_A71B
		txa
		asl
		asl
		clc
		adc #4
		tax
		jsr sub_AFC5
		ldx ObjectOffset
		ldy TMP_1
		bcc loc_A712
		lda $1E,x
		ora $1E,y
		and #$80
		bne loc_A70C
		lda Enemy_CollisionBits,y
		and SetBitsMask,x
		bne loc_A71B
		lda Enemy_CollisionBits,y
		ora SetBitsMask,x
		sta Enemy_CollisionBits,y
loc_A70C:
		jsr sub_A725
		jmp loc_A71B
loc_A712:
		lda Enemy_CollisionBits,y
		and ClearBitsMask,x
		sta Enemy_CollisionBits,y
loc_A71B:
		pla
		tay
		ldx TMP_1
		dex
		bpl loc_A6C3
loc_A722:
		ldx ObjectOffset
		rts
sub_A725:
		lda $1E,y
		ora $1E,x
		and #$20
		bne locret_A761
		lda $1E,x
		cmp #6
		bcc loc_A762
		lda $16,x
		cmp #5
		beq locret_A761
		lda $1E,y
		asl
		bcc loc_A74A
		lda #6
		jsr SetupFloateyNumber
		jsr loc_A3D6
		ldy TMP_1
loc_A74A:
		tya
		tax
		jsr loc_A3D6
		ldx ObjectOffset
		lda $125,x
		clc
		adc #4
		ldx TMP_1
		jsr SetupFloateyNumber
		ldx ObjectOffset
		inc $125,x
locret_A761:
		rts
loc_A762:
		lda $1E,y
		cmp #6
		bcc loc_A786
		lda $16,y
		cmp #5
		beq locret_A761
		jsr loc_A3D6
		ldy TMP_1
		lda $125,y
		clc
		adc #4
		ldx ObjectOffset
		jsr SetupFloateyNumber
		ldx TMP_1
		inc $125,x
		rts
loc_A786:
		tya
		tax
		jsr sub_A78D
		ldx ObjectOffset
sub_A78D:
		lda $16,x
		cmp #$D
		beq locret_A7B9
		cmp #4
		beq locret_A7B9
		cmp #$11
		beq locret_A7B9
		cmp #5
		beq locret_A7B9
		cmp #$12
		beq loc_A7AB
		cmp #$E
		beq loc_A7AB
		cmp #7
		bcs locret_A7B9
loc_A7AB:
		lda $58,x
		eor #$FF
		tay
		iny
		sty $58,x
		lda $46,x
		eor #3
		sta $46,x
locret_A7B9:
		rts

LargePlatformCollision:
		lda #$FF
		sta HammerThrowingTimer,x
		lda TimerControl
		bne loc_A7ED
		lda Enemy_State,x
		bmi loc_A7ED
		lda Enemy_ID,x
		cmp #$24
		bne ChkForPlayerC_LargeP
		lda Enemy_State,x
		tax
		jsr ChkForPlayerC_LargeP
ChkForPlayerC_LargeP:
		jsr CheckPlayerVertical
		bcs loc_A7ED
		txa
		jsr loc_A8C2
		lda $CF,x
		sta TMP_0
		txa
		pha
		jsr sub_AFC3
		pla
		tax
		bcc loc_A7ED
		jsr loc_A831
loc_A7ED:
		ldx ObjectOffset
		rts

SmallPlatformCollision:
		lda TimerControl
		bne loc_A82C
		sta $3A2,x
		jsr CheckPlayerVertical
		bcs loc_A82C
		lda #2
		sta TMP_0
loc_A801:
		ldx ObjectOffset
		jsr sub_A8C0
		and #2
		bne loc_A82C
		lda $4AD,y
		cmp #$20
		bcc loc_A816
		jsr sub_AFC3
		bcs loc_A82F
loc_A816:
		lda $4AD,y
		clc
		adc #$80
		sta $4AD,y
		lda $4AF,y
		clc
		adc #$80
		sta $4AF,y
		dec TMP_0
		bne loc_A801
loc_A82C:
		ldx ObjectOffset
		rts
loc_A82F:
		ldx ObjectOffset
loc_A831:
		lda $4AF,y
		sec
		sbc BoundingBox_UL_YPos
		cmp #4
		bcs loc_A844
		lda Player_Y_Speed
		bpl loc_A844
		lda #1
		sta Player_Y_Speed
loc_A844:
		lda BoundingBox_DR_YPos
		sec
		sbc $4AD,y
		cmp #6
		bcs loc_A86A
		lda Player_Y_Speed
		bmi loc_A86A
		lda TMP_0
		ldy $16,x
		cpy #$2B
		beq loc_A860
		cpy #$2C
		beq loc_A860
		txa
loc_A860:

		ldx ObjectOffset
		sta $3A2,x
		lda #0
		sta Player_State
		rts
loc_A86A:

		lda #1
		sta TMP_0
		lda BoundingBox_LR_Corner
		sec
		sbc $4AC,y
		cmp #8
		bcc loc_A886
		inc TMP_0
		lda $4AE,y
		clc
		sbc BoundingBox_UL_Corner
		cmp #9
		bcs loc_A889
loc_A886:

		jsr sub_ABD4
loc_A889:

		ldx ObjectOffset
		rts

PlayerPosSPlatData:
		.byte $80
		.byte 0

PositionPlayerOnS_Plat:
		tay
		lda Enemy_Y_Position,x
		clc
		adc PlayerPosSPlatData-1,y
		.byte $2c ; BIT $ABS
PositionPlayerOnVPlat:
		lda Enemy_Y_Position,x 
		ldy GameEngineSubroutine
		cpy #$B
		beq locret_A8B5
		ldy Enemy_Y_HighPos,x
		cpy #1
		bne locret_A8B5
		sec
		sbc #$20
		sta SprObject_Y_Position
		tya
		sbc #0
		sta Player_Y_HighPos
		lda #0
		sta Player_Y_Speed
		sta Player_Y_MoveForce
locret_A8B5:
		rts

CheckPlayerVertical:
		lda Player_OffscreenBits
		and #$F0
		clc
		beq locret_A8BF
		sec
locret_A8BF:
		rts

sub_A8C0:
		lda ObjectOffset
loc_A8C2:
		asl
		asl
		clc
		adc #4
		tay
		lda Enemy_OffscreenBits
		and #$F
		cmp #$F
		rts
PlayerBGUpperExtent:
		.byte $20, $10
sub_A8D2:

		lda DisableCollisionDet
		bne locret_A905
		lda GameEngineSubroutine
		cmp #$B
		beq locret_A905
		cmp #4
		bcc locret_A905
		lda #1
		ldy SwimmingFlag
		bne loc_A8F2
		lda Player_State
		beq loc_A8F0
		cmp #3
		bne loc_A8F4
loc_A8F0:

		lda #2
loc_A8F2:

		sta Player_State
loc_A8F4:

		lda Player_Y_HighPos
		cmp #1
		bne locret_A905
		lda #$FF
		sta Player_CollisionBits
loc_A8FF:

		lda SprObject_Y_Position
		cmp #$CF
		bcc loc_A906
locret_A905:

		rts
loc_A906:

		ldy #2
		lda CrouchingFlag
		bne loc_A919
		lda PlayerSize
		bne loc_A919
		dey
		lda SwimmingFlag
		bne loc_A919
		dey
loc_A919:

		lda BlockBufferAdderData,y
		sta byte_EB
		tay
		ldx PlayerSize
		lda CrouchingFlag
		beq loc_A928
		inx
loc_A928:

		lda SprObject_Y_Position
		cmp PlayerBGUpperExtent,x
		bcc loc_A964
		jsr BlockBufferColli_Head
		beq loc_A964
		jsr CheckForCoinMTiles
		bcs loc_A988
		ldy Player_Y_Speed
		bpl loc_A964
		ldy byte_4
		cpy #4
		bcc loc_A964
		jsr sub_AC18
		bcs loc_A958
		ldy AreaType
		beq loc_A960
		ldy BlockBounceTimer
		bne loc_A960
		jsr sub_88AE
		jmp loc_A964
loc_A958:

		cmp #$23
		beq loc_A960
		lda #2
		sta Square1SoundQueue
loc_A960:

		lda #1
		sta Player_Y_Speed
loc_A964:

		ldy byte_EB
		lda SprObject_Y_Position
		cmp #$CF
		bcs loc_A9CC
		jsr sub_B086
		jsr CheckForCoinMTiles
		bcs loc_A988
		pha
		jsr sub_B086
		sta TMP_0
		pla
		sta TMP_1
		bne loc_A98B
		lda TMP_0
		beq loc_A9CC
		jsr CheckForCoinMTiles
		bcc loc_A98B
loc_A988:

		jmp loc_AA73
loc_A98B:

		jsr CheckForClimbMTiles
		bcs loc_A9CC
		ldy Player_Y_Speed
		bmi loc_A9CC
		cmp #$C6
		bne loc_A99B
		jmp loc_AA7C
loc_A99B:

		jsr sub_AB40
		beq loc_A9CC
		ldy JumpspringAnimCtrl
		bne loc_A9C8
		ldy byte_4
		cpy #5
		bcc loc_A9B2
		lda Player_MovingDir
		sta TMP_0
		jmp sub_ABD4
loc_A9B2:

		jsr sub_AB4F
		lda #$F0
		and SprObject_Y_Position
		sta SprObject_Y_Position
		jsr sub_AB76
		lda #0
		sta Player_Y_Speed
		sta Player_Y_MoveForce
		sta StompChainCounter
loc_A9C8:

		lda #0
		sta Player_State
loc_A9CC:

		ldy byte_EB
		iny
		iny
		lda #2
		sta TMP_0
loc_A9D4:

		iny
		sty byte_EB
		lda SprObject_Y_Position
		cmp #$20
		bcc loc_A9F3
		cmp #$E4
		bcs locret_AA09
		jsr BlockBufferColli_Side+1
		beq loc_A9F3
		cmp #$19
		beq loc_A9F3
		cmp #$6D
		beq loc_A9F3
		jsr CheckForClimbMTiles
		bcc loc_AA0A
loc_A9F3:

		ldy byte_EB
		iny
		lda SprObject_Y_Position
		cmp #8
		bcc locret_AA09
		cmp #$D0
		bcs locret_AA09
		jsr BlockBufferColli_Side+1
		bne loc_AA0A
		dec TMP_0
		bne loc_A9D4
locret_AA09:

		rts
loc_AA0A:

		jsr sub_AB40
		beq locret_AA70
		jsr CheckForClimbMTiles
		bcc loc_AA17
		jmp HandleClimbing
loc_AA17:

		jsr CheckForCoinMTiles
		bcs loc_AA73
		jsr sub_AB6B
		bcc loc_AA29
		lda JumpspringAnimCtrl
		bne locret_AA70
		jmp loc_AA6D
loc_AA29:

		ldy Player_State
		cpy #0
		bne loc_AA6D
		ldy PlayerFacingDir
		dey
		bne loc_AA6D
		cmp #$6E
		beq loc_AA3C
		cmp #$1C
		bne loc_AA6D
loc_AA3C:

		lda Player_SprAttrib
		bne loc_AA45
		ldy #$10
		sty Square1SoundQueue
loc_AA45:

		ora #$20
		sta Player_SprAttrib
		lda Player_X_Position
		and #$F
		beq loc_AA5E
		ldy #0
		lda ScreenLeft_PageLoc
		beq loc_AA58
		iny
loc_AA58:

		lda AreaChangeTimerData,y
		sta ChangeAreaTimer
loc_AA5E:

		lda GameEngineSubroutine
		cmp #7
		beq locret_AA70
		cmp #8
		bne locret_AA70
		lda #2
		sta GameEngineSubroutine
		rts
loc_AA6D:

		jsr sub_ABD4
locret_AA70:

		rts
AreaChangeTimerData:

		.byte $A0
		.byte $34
loc_AA73:

		jsr sub_AA8D
		inc CoinTallyFor1Ups
		jmp sub_87C3
loc_AA7C:

		lda #0
		sta OperMode_Task
		lda #2
		sta OperMode
		jsr PlayerIsMarioPatch
		lda #$18
		sta Player_X_Speed
sub_AA8D:

		ldy byte_2
		lda #0
		sta (6),y
		jmp RemoveCoin_Axe
ClimbXPosAdder:
		.byte $F9
		.byte 7
ClimbPLocAdder:
		.byte $FF
		.byte 0
FlagpoleYPosData:
		.byte $18
		.byte $22
		.byte $50
		.byte $68
		.byte $90
HandleClimbing:

		ldy byte_4
		cpy #6
		bcc ExHC
		cpy #$A
		bcc ChkForFlagpole
ExHC:

		rts
ChkForFlagpole:

		cmp #$21
		beq FlagpoleCollision
		cmp #$22
		bne loc_AAFD
FlagpoleCollision:

		lda GameEngineSubroutine
		cmp #5
		beq loc_AB0B
		lda #1
		sta PlayerFacingDir
		inc ScrollLock
		lda GameEngineSubroutine
		cmp #4
		beq loc_AAF6
		lda #$33
		jsr sub_756D
		lda #$80
		sta EventMusicQueue
		lsr
		sta FlagpoleSoundQueue
		ldx #4
		lda SprObject_Y_Position
		sta FlagpoleCollisionYPos
loc_AAD9:

		cmp FlagpoleYPosData,x
		bcs loc_AAE1
		dex
		bne loc_AAD9
loc_AAE1:

		stx FlagpoleScore
		lda byte_7E7
		cmp byte_7E8
		bne loc_AAF6
		cmp byte_7EE
		bne loc_AAF6
		lda #5
		sta FlagpoleScore
loc_AAF6:

		lda #4
		sta GameEngineSubroutine
		jmp loc_AB0B
loc_AAFD:

		cmp #$23
		bne loc_AB0B
		lda SprObject_Y_Position
		cmp #$20
		bcs loc_AB0B
		lda #1
		sta GameEngineSubroutine
loc_AB0B:

		lda #3
		sta Player_State
		lda #0
		sta Player_X_Speed
		sta Player_X_MoveForce
		lda Player_X_Position
		sec
		sbc ScreenLeft_X_Pos
		cmp #$10
		bcs loc_AB24
		lda #2
		sta PlayerFacingDir
loc_AB24:

		ldy PlayerFacingDir
		lda byte_6
		asl
		asl
		asl
		asl
		clc
		adc ClimbXPosAdder-1,y
		sta Player_X_Position
		lda byte_6
		bne locret_AB3F
		lda ScreenRight_PageLoc
		clc
		adc ClimbPLocAdder-1,y
		sta Player_PageLoc
locret_AB3F:

		rts
sub_AB40:

		cmp #$5E
		beq locret_AB4E
		cmp #$5F
		beq locret_AB4E
		cmp #$60
		beq locret_AB4E
		cmp #$61
locret_AB4E:

		rts
sub_AB4F:

		jsr sub_AB6B
		bcc locret_AB6A
		lda #$70
		sta VerticalForce
		sta VerticalForceDown
		lda #$F9
		sta JumpspringForce
		lda #3
		sta JumpspringTimer
		lsr
		sta JumpspringAnimCtrl
locret_AB6A:

		rts
sub_AB6B:

		cmp #$68
		beq loc_AB74
		cmp #$69
		clc
		bne locret_AB75
loc_AB74:

		sec
locret_AB75:

		rts
sub_AB76:

		lda Up_Down_Buttons
		and #4
		beq locret_ABD3
		lda TMP_0
		cmp #$11
		bne locret_ABD3
		lda TMP_1
		cmp #$10
		bne locret_ABD3
		lda #$30
		sta ChangeAreaTimer
		lda #3
		sta GameEngineSubroutine
		lda #$10
		sta Square1SoundQueue
		lda #$20
		sta Player_SprAttrib
		lda WarpZoneControl
		beq locret_ABD3
		and #$F
		tax
		lda NEW_WarpZoneNumbers_MAYBE,x
		ldy IsPlayingExtendedWorlds
		beq loc_ABAD
		sec
		sbc #9
loc_ABAD:

		tay
		dey
		sty WorldNumber
		ldx WorldAddrOffsets,y
		lda AreaAddrOffsets,x
		sta AreaPointer
		lda #$80
		sta EventMusicQueue
		lda #0
		sta EntrancePage
		sta AreaNumber
		sta LevelNumber
		sta AltEntranceControl
		inc Hidden1UpFlag
		inc FetchNewGameTimerFlag
locret_ABD3:

		rts
sub_ABD4:

		lda #0
		ldy Player_X_Speed
		ldx TMP_0
		dex
		bne loc_ABE7
		inx
		cpy #0
		bmi loc_AC0A
		lda #$FF
		jmp loc_ABEF
loc_ABE7:

		ldx #2
		cpy #1
		bpl loc_AC0A
		lda #1
loc_ABEF:

		ldy #$10
		sty SideCollisionTimer
		ldy #0
		sty Player_X_Speed
		cmp #0
		bpl loc_ABFD
		dey
loc_ABFD:

		sty TMP_0
		clc
		adc Player_X_Position
		sta Player_X_Position
		lda Player_PageLoc
		adc TMP_0
		sta Player_PageLoc
loc_AC0A:

		txa
		eor #$FF
		and Player_CollisionBits
		sta Player_CollisionBits
		rts
SolidMTileUpperExt:
		.byte $10
		.byte $62
		.byte $88
		.byte $C5
sub_AC18:

		jsr GetMTileAttrib
		cmp SolidMTileUpperExt,x
		rts
ClimbMTileUpperExt:
		.byte $21
		.byte $6F
		.byte $8D
		.byte $C7
CheckForClimbMTiles:

		jsr GetMTileAttrib
		cmp ClimbMTileUpperExt,x
		rts
CheckForCoinMTiles:

		cmp #$C3
		beq loc_AC34
		cmp #$C4
		beq loc_AC34
		clc
		rts
loc_AC34:

		lda #1
		sta Square2SoundQueue
		rts
GetMTileAttrib:

		tay
		and #$C0
		asl
		rol
		rol
		tax
		tya
locret_AC41:

		rts
EnemyBGCStateData:
		.byte 1
		.byte 1
		.byte 2
		.byte 2
		.byte 2
		.byte 5
EnemyBGCXSpdData:
		.byte $10
		.byte $F0
EnemyToBGCollisionDet:

		lda Enemy_State,x
		and #$20
		bne locret_AC41
		jsr SubtEnemyYPos
		bcc locret_AC41
		ldy $16,x
		cpy #$12
		bne loc_AC61
		lda $CF,x
		cmp #$25
		bcc locret_AC41
loc_AC61:

		cpy #$E
		bne loc_AC68
		jmp sub_ADF9
loc_AC68:

		cpy #5
		bne loc_AC70
		jmp loc_AE1B
locret_AC6F:

		rts
loc_AC70:

		cpy #$12
		beq loc_AC80
		cpy #$2E
		beq loc_AC80
		cpy #4
		beq locret_AC6F
		cpy #7
		bcs locret_AC6F
loc_AC80:

		jsr sub_AE44
		bne loc_AC88
loc_AC85:

		jmp loc_AD78
loc_AC88:

		jsr sub_AE4B
		beq loc_AC85
		cmp #$20
		bne loc_ACFD
		lda $16,x
		cmp #$15
loc_AC95:

		bcs sub_ACA3
		cmp #6
		bne loc_AC9E
		jsr sub_AE24
loc_AC9E:

		lda #1
		jsr SetupFloateyNumber
sub_ACA3:

		lda $16,x
		cmp #9
		bcc loc_ACC1
		cmp #$11
		bcs loc_ACC1
		cmp #$D
		beq loc_ACC1
		cmp #4
		beq loc_ACC1
		cmp #$A
		bcc loc_ACBD
		cmp #$D
		bcc loc_ACC1
loc_ACBD:

		and #1
		sta $16,x
loc_ACC1:

		cmp #$2E
		beq loc_ACCD
		cmp #6
		beq loc_ACCD
		lda #2
		sta $1E,x
loc_ACCD:

		dec $CF,x
		dec $CF,x
		lda $16,x
		cmp #7
		beq loc_ACDE
		lda #$FD
		ldy AreaType
		bne loc_ACE0
loc_ACDE:

		lda #$FF
loc_ACE0:

		sta $A0,x
		ldy #1
		jsr PlayerEnemyDiff
		bpl loc_ACEA
		iny
loc_ACEA:

		lda $16,x
		cmp #$33
		beq loc_ACF6
		cmp #8
		beq loc_ACF6
		sty $46,x
loc_ACF6:

		dey
		lda EnemyBGCXSpdData,y
		sta $58,x
		rts
loc_ACFD:

		lda byte_4
		sec
		sbc #8
		cmp #5
		bcs loc_AD78
		lda Enemy_State,x
		and #$40
		bne loc_AD63
		lda Enemy_State,x
		asl
		bcc loc_AD14
loc_AD11:

		jmp loc_AD94
loc_AD14:

		lda Enemy_State,x
		beq loc_AD11
		cmp #5
		beq loc_AD3B
		cmp #3
		bcs locret_AD3A
		lda $1E,x
		cmp #2
		bne loc_AD3B
		lda #$10
		ldy $16,x
		cpy #$12
		bne loc_AD30
		lda #0
loc_AD30:

		sta EnemyIntervalTimer,x
		lda #3
		sta $1E,x
		jsr sub_ADE5
locret_AD3A:

		rts
loc_AD3B:

		lda $16,x
		cmp #6
		beq loc_AD63
		cmp #$12
		bne loc_AD53
		lda #1
		sta $46,x
		lda #8
		sta $58,x
		lda FrameCounter
		and #7
		beq loc_AD63
loc_AD53:

		ldy #1
		jsr PlayerEnemyDiff
		bpl loc_AD5B
		iny
loc_AD5B:

		tya
		cmp $46,x
		bne loc_AD63
		jsr sub_ADBA
loc_AD63:

		jsr sub_ADE5
		lda $1E,x
		and #$80
		bne loc_AD71
		lda #0
		sta $1E,x
		rts
loc_AD71:

		lda $1E,x
		and #$BF
		sta $1E,x
		rts
loc_AD78:

		lda $16,x
		cmp #3
		bne loc_AD82
		lda $1E,x
		beq sub_ADBA
loc_AD82:

		lda $1E,x
		tay
		asl
		bcc loc_AD8F
		lda $1E,x
		ora #$40
		jmp loc_AD92
loc_AD8F:

		lda EnemyBGCStateData,y
loc_AD92:

		sta $1E,x
loc_AD94:

		lda $CF,x
		cmp #$20
		bcc locret_ADB9
		ldy #$16
		lda #2
		sta byte_EB
loc_ADA0:

		lda byte_EB
		cmp $46,x
		bne loc_ADB2
		lda #1
		jsr sub_B026
		beq loc_ADB2
		jsr sub_AE4B
		bne sub_ADBA
loc_ADB2:

		dec byte_EB
		iny
		cpy #$18
		bcc loc_ADA0
locret_ADB9:

		rts
sub_ADBA:

		cpx #5
		beq loc_ADC7
		lda $1E,x
		asl
		bcc loc_ADC7
		lda #2
		sta Square1SoundQueue
loc_ADC7:

		lda $16,x
		cmp #5
		bne loc_ADD6
		lda #0
		sta TMP_0
		ldy #$FA
		jmp loc_966C
loc_ADD6:

		jmp loc_A7AB
PlayerEnemyDiff:

		lda $87,x
		sec
		sbc Player_X_Position
		sta TMP_0
		lda $6E,x
		sbc Player_PageLoc
		rts
sub_ADE5:

		jsr InitVStf
		lda $CF,x
		and #$F0
		ora #8
		sta $CF,x
		rts
SubtEnemyYPos:

		lda $CF,x
		clc
		adc #$3E
		cmp #$44
		rts
sub_ADF9:

		jsr SubtEnemyYPos
		bcc loc_AE18
		lda $A0,x
		clc
		adc #2
		cmp #3
		bcc loc_AE18
		jsr sub_AE44
		beq loc_AE18
		jsr sub_AE4B
		beq loc_AE18
		jsr sub_ADE5
		lda #$FD
		sta $A0,x
loc_AE18:

		jmp loc_AD94
loc_AE1B:

		jsr sub_AE44
		beq loc_AE3D
		cmp #$20
		bne loc_AE2C
sub_AE24:

		jsr loc_A3D6
		lda #$FC
		sta $A0,x
		rts
loc_AE2C:

		lda $78A,x
		bne loc_AE3D
		lda $1E,x
		and #$88
		sta $1E,x
		jsr sub_ADE5
		jmp loc_AD94
loc_AE3D:

		lda $1E,x
		ora #1
		sta $1E,x
		rts
sub_AE44:

		lda #0
		ldy #$15
		jmp sub_B026
sub_AE4B:

		cmp #$23
		beq locret_AE65
		cmp #$C3
		beq locret_AE65
		cmp #$C4
		beq locret_AE65
		cmp #$5E
		beq locret_AE65
		cmp #$5F
		beq locret_AE65
		cmp #$60
		beq locret_AE65
		cmp #$61
locret_AE65:

		rts
FireballBGCollision:

		lda $D5,x
		cmp #$18
		bcc loc_AE8D
		jsr sub_B03A
		beq loc_AE8D
		jsr sub_AE4B
		beq loc_AE8D
		lda $A6,x
		bmi loc_AE92
		lda $3A,x
		bne loc_AE92
		lda #$FD
		sta $A6,x
		lda #1
		sta $3A,x
		lda $D5,x
		and #$F8
		sta $D5,x
		rts
loc_AE8D:

		lda #0
		sta $3A,x
		rts
loc_AE92:

		lda #$80
		sta $24,x
		lda #2
		sta Square1SoundQueue
		rts
BoundBoxCtrlData:
		.byte 2
		.byte 8
		.byte $E
		.byte $20
		.byte 3
		.byte $14
		.byte $D
		.byte $20
		.byte 2
		.byte $14
		.byte $E
		.byte $20
		.byte 2
		.byte 9
		.byte $E
		.byte $15
		.byte 0
		.byte 0
		.byte $18
		.byte 6
		.byte 0
		.byte 0
		.byte $20
		.byte $D
		.byte 0
		.byte 0
		.byte $30
		.byte $D
		.byte 0
		.byte 0
		.byte 8
		.byte 8
		.byte 6
		.byte 4
		.byte $A
		.byte 8
		.byte 3
		.byte $E
		.byte $D
		.byte $16
		.byte 0
		.byte 2
		.byte $10
		.byte $15
		.byte 4
		.byte 4
		.byte $C
		.byte $1C
GetFireballBoundBox:

		txa
		clc
		adc #7
		tax
		ldy #2
		bne loc_AEDB
GetMiscBoundBox:

		txa
		clc
		adc #9
		tax
		ldy #6
loc_AEDB:

		jsr BoundingBoxCore
		jmp loc_AF7C
GetEnemyBoundBox:

		ldy #$48
		sty TMP_0
		ldy #$44
		jmp GetMaskedOffScrBits
SmallPlatformBoundBox:

		ldy #8
		sty TMP_0
		ldy #4
GetMaskedOffScrBits:

		lda Enemy_X_Position,x
		sec
		sbc ScreenLeft_X_Pos
		sta TMP_1
		lda $6E,x
		sbc ScreenLeft_PageLoc
		bmi loc_AF05
		ora TMP_1
		beq loc_AF05
		ldy TMP_0
loc_AF05:

		tya
		and Enemy_OffscreenBits
		sta $3D8,x
		bne loc_AF27
		jmp loc_AF1A
LargePlatformBoundBox:

		inx
		jsr GetXOffscreenBits
		dex
		cmp #$FE
		bcs loc_AF27
loc_AF1A:

		txa
		clc
		adc #1
		tax
		ldy #1
		jsr BoundingBoxCore
		jmp loc_AF7C
loc_AF27:

		txa
		asl
		asl
		tay
		lda #$FF
		sta $4B0,y
		sta $4B1,y
		sta $4B2,y
		sta $4B3,y
		rts
BoundingBoxCore:

		stx TMP_0
		lda Player_Rel_YPos,y
		sta byte_2
		lda Player_Rel_XPos,y
		sta TMP_1
		txa
		asl
		asl
		pha
		tay
		lda Player_BoundBoxCtrl,x
		asl
		asl
		tax
		lda TMP_1
		clc
		adc BoundBoxCtrlData,x
		sta BoundingBox_UL_Corner,y
		lda TMP_1
		clc
		adc BoundBoxCtrlData+2,x
		sta BoundingBox_LR_Corner,y
		inx
		iny
		lda byte_2
		clc
		adc BoundBoxCtrlData,x
		sta BoundingBox_UL_Corner,y
		lda byte_2
		clc
		adc BoundBoxCtrlData+2,x
		sta BoundingBox_LR_Corner,y
		pla
		tay
		ldx TMP_0
		rts
loc_AF7C:

		lda ScreenLeft_X_Pos
		clc
		adc #$80
		sta byte_2
		lda ScreenLeft_PageLoc
		adc #0
		sta TMP_1
		lda $86,x
		cmp byte_2
		lda $6D,x
		sbc TMP_1
		bcc loc_AFAA
		lda $4AE,y
		bmi loc_AFA7
		lda #$FF
		ldx $4AC,y
		bmi loc_AFA4
		sta $4AC,y
loc_AFA4:

		sta $4AE,y
loc_AFA7:

		ldx ObjectOffset
		rts
loc_AFAA:

		lda $4AC,y
		bpl loc_AFC0
		cmp #$A0
		bcc loc_AFC0
		lda #0
		ldx $4AE,y
		bpl loc_AFBD
		sta $4AE,y
loc_AFBD:

		sta $4AC,y
loc_AFC0:

		ldx ObjectOffset
		rts
sub_AFC3:

		ldx #0
sub_AFC5:

		sty byte_6
		lda #1
		sta unk_7
loc_AFCB:

		lda $4AC,y
		cmp $4AC,x
		bcs loc_AFFD
		cmp $4AE,x
		bcc loc_AFEA
		beq loc_B01C
		lda $4AE,y
		cmp $4AC,y
		bcc loc_B01C
		cmp $4AC,x
		bcs loc_B01C
		ldy byte_6
		rts
loc_AFEA:

		lda $4AE,x
		cmp $4AC,x
		bcc loc_B01C
		lda $4AE,y
		cmp $4AC,x
		bcs loc_B01C
		ldy byte_6
		rts
loc_AFFD:

		cmp $4AC,x
		beq loc_B01C
		cmp $4AE,x
		bcc loc_B01C
		beq loc_B01C
		cmp $4AE,y
		bcc loc_B018
		beq loc_B018
		lda $4AE,y
		cmp $4AC,x
		bcs loc_B01C
loc_B018:

		clc
		ldy byte_6
		rts
loc_B01C:

		inx
		iny
		dec unk_7
		bpl loc_AFCB
		sec
		ldy byte_6
		rts
sub_B026:

		pha
		txa
		clc
		adc #1
		tax
		pla
		jmp loc_B043
		txa
		clc
		adc #$D
		tax
		ldy #$1B
		jmp loc_B041
sub_B03A:

		ldy #$1A
		txa
		clc
		adc #7
		tax
loc_B041:

		lda #0
loc_B043:

		jsr BlockBufferCollision
		ldx ObjectOffset
		cmp #0
		rts
BlockBufferAdderData:
		.byte 0
		.byte 7
		.byte $E
BlockBuffer_X_Adder:
		.byte 8
		.byte 3
		.byte $C
		.byte 2
		.byte 2
		.byte $D
		.byte $D
		.byte 8
		.byte 3
		.byte $C
		.byte 2
		.byte 2
		.byte $D
		.byte $D
		.byte 8
		.byte 3
		.byte $C
		.byte 2
		.byte 2
		.byte $D
		.byte $D
		.byte 8
		.byte 0
		.byte $10
		.byte 4
		.byte $14
		.byte 4
		.byte 4
BlockBuffer_Y_Adder:
		.byte 4
		.byte $20
		.byte $20
		.byte 8
		.byte $18
		.byte 8
		.byte $18
		.byte 2
		.byte $20
		.byte $20
		.byte 8
		.byte $18
		.byte 8
		.byte $18
		.byte $12
		.byte $20
		.byte $20
		.byte $18
		.byte $18
		.byte $18
		.byte $18
		.byte $18
		.byte $14
		.byte $14
		.byte 6
		.byte 6
		.byte 8
		.byte $10
sub_B086:

		iny
BlockBufferColli_Head:

		lda #0
BlockBufferColli_Side:

		bit byte_1A9
		ldx #0
BlockBufferCollision:

		pha
		sty byte_4
		lda BlockBuffer_X_Adder,y
		clc
		adc $86,x
		sta byte_5
		lda $6D,x
		adc #0
		and #1
		lsr
		ora byte_5
		ror
		lsr
		lsr
		lsr
		jsr GetBlockBufferAddr
		ldy byte_4
		lda $CE,x
		clc
		adc BlockBuffer_Y_Adder,y
		and #$F0
		sec
		sbc #$20
		sta byte_2
		tay
		lda (6),y
		sta byte_3
		ldy byte_4
		pla
		bne loc_B0C7
		lda $CE,x
		jmp loc_B0C9
loc_B0C7:

		lda $86,x
loc_B0C9:

		and #$F
		sta byte_4
		lda byte_3
		rts
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
VineYPosAdder:
		.byte 0
		.byte $30
DrawVine:

		sty TMP_0
		lda Enemy_Rel_YPos
		clc
		adc VineYPosAdder,y
		ldx VineObjOffset,y
		ldy Enemy_SprDataOffset,x
		sty byte_2
		jsr sub_B152
		lda Enemy_Rel_XPos
		sta $203,y
		sta $20B,y
		sta $213,y
		clc
		adc #6
		sta $207,y
		sta $20F,y
		sta $217,y
		lda #$21
		sta $202,y
		sta $20A,y
		sta $212,y
		ora #$40
		sta $206,y
		sta $20E,y
		sta $216,y
		ldx #5
loc_B11D:

		lda #$E1
		sta $201,y
		iny
		iny
		iny
		iny
		dex
		bpl loc_B11D
		ldy byte_2
		lda TMP_0
		bne loc_B134
		lda #$E0
		sta $201,y
loc_B134:

		ldx #0
loc_B136:

		lda VineStart_Y_Position
		sec
		sbc $200,y
		cmp #$64
		bcc loc_B146
		lda #$F8
		sta $200,y
loc_B146:

		iny
		iny
		iny
		iny
		inx
		cpx #6
		bne loc_B136
		ldy TMP_0
		rts
sub_B152:

		ldx #6
loc_B154:

		sta $200,y
		clc
		adc #8
		iny
		iny
		iny
		iny
		dex
		bne loc_B154
		ldy byte_2
		rts
FirstSprXPos:
		.byte 4
		.byte 0
		.byte 4
		.byte 0
FirstSprYPos:
		.byte 0
		.byte 4
		.byte 0
		.byte 4
SecondSprXPos:
		.byte 0
		.byte 8
		.byte 0
		.byte 8
SecondSprYPos:
		.byte 8
		.byte 0
		.byte 8
		.byte 0
FirstSprTilenum:
		.byte $80
		.byte $82
		.byte $81
		.byte $83
SecondSprTilenum:
		.byte $81
		.byte $83
		.byte $80
		.byte $82
HammerSprAttrib:
		.byte 3
		.byte 3
		.byte $C3
		.byte $C3
DrawHammer:

		ldy $6F3,x
		lda TimerControl
		bne loc_B190
		lda $2A,x
		and #$7F
		cmp #1
		beq loc_B194
loc_B190:

		ldx #0
		beq loc_B19B
loc_B194:

		lda FrameCounter
		lsr
		lsr
		and #3
		tax
loc_B19B:

		lda Misc_Rel_YPos
		clc
		adc FirstSprYPos,x
		sta Sprite_Y_Position,y
		clc
		adc SecondSprYPos,x
		sta $204,y
		lda Misc_Rel_XPos
		clc
		adc FirstSprXPos,x
		sta Sprite_X_Position,y
		clc
		adc SecondSprXPos,x
		sta byte_207,y
		lda FirstSprTilenum,x
		sta $201,y
		lda SecondSprTilenum,x
		sta $205,y
		lda HammerSprAttrib,x
		sta $202,y
		sta $206,y
		ldx ObjectOffset
		lda Misc_OffscreenBits
		and #$FC
		beq locret_B1E4
		lda #0
		sta $2A,x
		lda #$F8
		jsr DumpTwoSpr
locret_B1E4:

		rts
FlagpoleScoreNumTiles:
		.byte $F9
		.byte $50
		.byte $F7
		.byte $50
		.byte $FA
		.byte $FB
		.byte $F8
		.byte $FB
		.byte $F6
		.byte $FB
		.byte $FD
		.byte $FE
sub_B1F1:

		ldy $6E5,x
		lda Enemy_Rel_XPos
		sta $203,y
		clc
		adc #8
		sta $207,y
		sta $20B,y
		clc
		adc #$C
		sta byte_5
		lda $CF,x
		jsr DumpTwoSpr
		adc #8
		sta $208,y
		lda FlagpoleFNum_Y_Pos
		sta byte_2
		lda #1
		sta byte_3
		sta byte_4
		sta $202,y
		sta $206,y
		sta $20A,y
		lda #$7E
		sta $201,y
		sta $209,y
		lda #$7F
		sta $205,y
		lda FlagpoleCollisionYPos
		beq loc_B24D
		tya
		clc
		adc #$C
		tay
		lda FlagpoleScore
		asl
		tax
		lda FlagpoleScoreNumTiles,x
		sta TMP_0
		lda FlagpoleScoreNumTiles+1,x
		jsr DrawOneSpriteRow
loc_B24D:

		ldx ObjectOffset
		ldy $6E5,x
		lda Enemy_OffscreenBits
		and #$E
		beq locret_B26D
loc_B259:

		lda #$F8
sub_B25B:

		sta $214,y
		sta $210,y
loc_B261:

		sta $20C,y
loc_B264:

		sta $208,y
DumpTwoSpr:

		sta $204,y
		sta $200,y
locret_B26D:

		rts
DrawLargePlatform:

		ldy $6E5,x
		sty byte_2
		iny
		iny
		iny
		lda Enemy_Rel_XPos
		jsr sub_B152
		ldx ObjectOffset
		lda $CF,x
		jsr loc_B261
		ldy AreaType
		cpy #3
		beq loc_B28F
		ldy SecondaryHardMode
		beq loc_B291
loc_B28F:

		lda #$F8
loc_B291:

		ldy $6E5,x
		sta $210,y
		sta $214,y
		lda #$5B
		ldx CloudTypeOverride
		beq loc_B2A3
		lda #$75
loc_B2A3:

		ldx ObjectOffset
		iny
		jsr sub_B25B
		lda #2
		iny
		jsr sub_B25B
		inx
		jsr GetXOffscreenBits
		dex
		ldy $6E5,x
		asl
		pha
		bcc loc_B2C0
		lda #$F8
		sta $200,y
loc_B2C0:

		pla
		asl
		pha
		bcc loc_B2CA
		lda #$F8
		sta $204,y
loc_B2CA:

		pla
		asl
		pha
		bcc loc_B2D4
		lda #$F8
		sta $208,y
loc_B2D4:

		pla
		asl
		pha
		bcc loc_B2DE
		lda #$F8
		sta $20C,y
loc_B2DE:

		pla
		asl
		pha
		bcc loc_B2E8
		lda #$F8
		sta $210,y
loc_B2E8:

		pla
		asl
		bcc loc_B2F1
		lda #$F8
		sta $214,y
loc_B2F1:

		lda Enemy_OffscreenBits
		asl
		bcc locret_B2FA
		jsr loc_B259
locret_B2FA:

		rts
loc_B2FB:

		lda FrameCounter
		lsr
		bcs loc_B302
		dec $DB,x
loc_B302:

		lda $DB,x
		jsr DumpTwoSpr
		lda Misc_Rel_XPos
		sta $203,y
		clc
		adc #8
		sta $207,y
		lda #2
		sta $202,y
		sta $206,y
		lda #$F7
		sta $201,y
		lda #$FB
		sta $205,y
		jmp locret_B363
JumpingCoinTiles:
		.byte $60
		.byte $61
		.byte $62
		.byte $63
JCoinGfxHandler:

		ldy Misc_SprDataOffset,x
		lda Misc_State,x
		cmp #2
		bcs loc_B2FB
		lda Misc_Y_Position,x
		sta $200,y
		clc
		adc #8
		sta $204,y
		lda Misc_Rel_XPos
		sta $203,y
		sta $207,y
		lda FrameCounter
		lsr
		and #3
		tax
		lda JumpingCoinTiles,x
		iny
		jsr DumpTwoSpr
		dey
		lda #2
		sta $202,y
		lda #$82
		sta $206,y
		ldx ObjectOffset
locret_B363:

		rts
PowerUpGfxTable:
		.byte $D8
		.byte $DA
		.byte $DB
		.byte $FF
		.byte $D6
		.byte $D6
		.byte $D9
		.byte $D9
		.byte $8D
		.byte $8D
		.byte $E4
		.byte $E4
		.byte $D8
		.byte $DA
		.byte $DB
		.byte $FF
		.byte $D8
		.byte $DA
		.byte $DB
		.byte $FF
PowerUpAttributes:
		.byte 2
		.byte 1
		.byte 2
		.byte 1
		.byte 3
sub_B37D:

		ldy byte_6EA
		lda Enemy_Rel_YPos
		clc
		adc #8
		sta byte_2
		lda Enemy_Rel_XPos
		sta byte_5
		ldx PowerUpType
		lda PowerUpAttributes,x
		ora byte_3CA
		sta byte_4
		txa
		pha
		asl
		asl
		tax
		lda #1
		sta unk_7
		sta byte_3
loc_B3A2:

		lda PowerUpGfxTable,x
		sta TMP_0
		lda PowerUpGfxTable+1,x
		jsr DrawOneSpriteRow
		dec unk_7
		bpl loc_B3A2
		ldy byte_6EA
		pla
		beq loc_B3EA
		cmp #3
		beq loc_B3EA
		cmp #4
		beq loc_B3EA
		sta TMP_0
		lda FrameCounter
		lsr
		and #3
		ora byte_3CA
		sta $202,y
		sta $206,y
		ldx TMP_0
		dex
		beq loc_B3DA
		sta $20A,y
		sta $20E,y
loc_B3DA:

		lda $206,y
		ora #$40
		sta $206,y
		lda $20E,y
		ora #$40
		sta $20E,y
loc_B3EA:

		jmp loc_B83F
EnemyGraphicsTable:
		.byte $FC
		.byte $FC
		.byte $AA
byte_B3F0:
		.byte $AB
		.byte $AC
		.byte $AD
		.byte $FC
		.byte $FC
		.byte $AE
		.byte $AF
		.byte $B0
		.byte $B1
		.byte $FC
		.byte $A5
		.byte $A6
		.byte $A7
		.byte $A8
		.byte $A9
		.byte $FC
		.byte $A0
		.byte $A1
		.byte $A2
		.byte $A3
		.byte $A4
		.byte $69
		.byte $A5
		.byte $6A
		.byte $A7
		.byte $A8
		.byte $A9
		.byte $6B
		.byte $A0
		.byte $6C
		.byte $A2
		.byte $A3
		.byte $A4
		.byte $FC
		.byte $FC
		.byte $96
		.byte $97
		.byte $98
		.byte $99
		.byte $FC
		.byte $FC
		.byte $9A
		.byte $9B
		.byte $9C
		.byte $9D
		.byte $FC
		.byte $FC
		.byte $8F
		.byte $8E
		.byte $8E
		.byte $8F
		.byte $FC
		.byte $FC
		.byte $95
		.byte $94
		.byte $94
		.byte $95
		.byte $FC
		.byte $FC
		.byte $DC
		.byte $DC
		.byte $DF
		.byte $DF
		.byte $DC
		.byte $DC
		.byte $DD
		.byte $DD
		.byte $DE
		.byte $DE
		.byte $FC
		.byte $FC
		.byte $B2
		.byte $B3
		.byte $B4
		.byte $B5
		.byte $FC
		.byte $FC
		.byte $B6
		.byte $B3
		.byte $B7
		.byte $B5
		.byte $FC
		.byte $FC
		.byte $70
		.byte $71
		.byte $72
		.byte $73
		.byte $FC
		.byte $FC
		.byte $6E
		.byte $6E
		.byte $6F
		.byte $6F
		.byte $FC
		.byte $FC
		.byte $6D
		.byte $6D
		.byte $6F
		.byte $6F
		.byte $FC
		.byte $FC
		.byte $6F
		.byte $6F
		.byte $6E
		.byte $6E
		.byte $FC
		.byte $FC
		.byte $6F
		.byte $6F
		.byte $6D
		.byte $6D
		.byte $FC
		.byte $FC
		.byte $F4
		.byte $F4
		.byte $F5
		.byte $F5
		.byte $FC
		.byte $FC
		.byte $F4
		.byte $F4
		.byte $F5
		.byte $F5
		.byte $FC
		.byte $FC
		.byte $F5
		.byte $F5
		.byte $F4
		.byte $F4
		.byte $FC
		.byte $FC
		.byte $F5
		.byte $F5
		.byte $F4
		.byte $F4
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $EF
		.byte $EF
		.byte $B9
		.byte $B8
		.byte $BB
		.byte $BA
		.byte $BC
		.byte $BC
		.byte $FC
		.byte $FC
		.byte $BD
		.byte $BD
		.byte $BC
		.byte $BC
		.byte $76
		.byte $79
		.byte $77
		.byte $77
		.byte $78
		.byte $78
		.byte $CD
		.byte $CD
		.byte $CE
		.byte $CE
		.byte $CF
		.byte $CF
		.byte $7D
		.byte $7C
		.byte $D1
		.byte $8C
		.byte $D3
		.byte $D2
		.byte $7D
		.byte $7C
		.byte $89
		.byte $88
		.byte $8B
		.byte $8A
		.byte $D5
		.byte $D4
		.byte $E3
		.byte $E2
		.byte $D3
		.byte $D2
		.byte $D5
		.byte $D4
		.byte $E3
		.byte $E2
		.byte $8B
		.byte $8A
		.byte $E5
		.byte $E5
		.byte $E6
		.byte $E6
		.byte $EB
		.byte $EB
		.byte $EC
		.byte $EC
		.byte $ED
		.byte $ED
		.byte $EE
		.byte $EE
		.byte $FC
		.byte $FC
		.byte $D0
		.byte $D0
		.byte $D7
		.byte $D7
		.byte $BF
		.byte $BE
		.byte $C1
		.byte $C0
		.byte $C2
		.byte $FC
		.byte $C4
		.byte $C3
		.byte $C6
		.byte $C5
		.byte $C8
		.byte $C7
		.byte $BF
		.byte $BE
		.byte $CA
		.byte $C9
		.byte $C2
		.byte $FC
		.byte $C4
		.byte $C3
		.byte $C6
		.byte $C5
		.byte $CC
		.byte $CB
		.byte $FC
		.byte $FC
		.byte $E8
		.byte $E7
		.byte $EA
		.byte $E9
		.byte $F2
		.byte $F2
		.byte $F3
		.byte $F3
		.byte $F2
		.byte $F2
		.byte $F1
		.byte $F1
		.byte $F1
		.byte $F1
		.byte $FC
		.byte $FC
		.byte $F0
		.byte $F0
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
EnemyGfxTableOffsets:
		.byte $C
		.byte $C
		.byte 0
		.byte $C
		.byte $C0
		.byte $A8
		.byte $54
		.byte $3C
		.byte $EA
		.byte $18
		.byte $48
		.byte $48
		.byte $CC
		.byte $C0
		.byte $18
		.byte $18
		.byte $18
		.byte $90
		.byte $24
		.byte $FF
		.byte $48
		.byte $9C
		.byte $D2
		.byte $D8
		.byte $F0
		.byte $F6
		.byte $FC
EnemyAnimTimingBMask:
		.byte 8
		.byte $18
JumpspringFrameOffsets:
		.byte $18
		.byte $19
		.byte $1A
		.byte $19
		.byte $18
EnemyGfxHandler:

		lda #2
		ldy WorldNumber
		cpy #1
		beq loc_B53D
		cpy #2
		beq loc_B53D
		cpy #6
		bne loc_B53E
loc_B53D:
		lsr
loc_B53E:
		sta WRAM_UnknownAttributeData0
		sta WRAM_UnknownAttributeData1
		sta WRAM_UnknownAttributeData2
		lda $CF,x
		sta byte_2
		lda Enemy_Rel_XPos
		sta byte_5
		ldy $6E5,x
		sty byte_EB
		lda #0
		sta VerticalFlipFlag
		lda $46,x
		sta byte_3
		lda $3C5,x
		sta byte_4
		lda $16,x
		cmp #$D
		bne loc_B573
		ldy $58,x
		bmi loc_B573
		ldy $78A,x
		beq loc_B573
		rts
loc_B573:

		lda $1E,x
		sta byte_ED
		and #$1F
		tay
		lda $16,x
		cmp #$35
		bne loc_B588
		ldy #0
		lda #1
		sta byte_3
		lda #$15
loc_B588:

		cmp #$33
		bne loc_B59F
		dec byte_2
		lda #3
		ldy $78A,x
		beq loc_B597
		ora #$20
loc_B597:

		sta byte_4
		ldy #0
		sty byte_ED
		lda #8
loc_B59F:

		cmp #$32
		bne loc_B5AB
		ldy #3
		ldx JumpspringAnimCtrl
		lda JumpspringFrameOffsets,x
loc_B5AB:

		sta byte_EF
		sty byte_EC
		ldx ObjectOffset
		cmp #$C
		bne loc_B5BC
		lda $A0,x
		bmi loc_B5BC
		inc VerticalFlipFlag
loc_B5BC:

		lda BowserGfxFlag
		beq loc_B5CA
		ldy #$16
		cmp #1
		beq loc_B5C8
		iny
loc_B5C8:

		sty byte_EF
loc_B5CA:

		ldy byte_EF
		cpy #6
		bne loc_B5ED
		lda $1E,x
		cmp #2
		bcc loc_B5DA
		ldx #4
		stx byte_EC
loc_B5DA:

		and #$20
		ora TimerControl
		bne loc_B5ED
		lda FrameCounter
		and #8
		bne loc_B5ED
		lda byte_3
		eor #3
		sta byte_3
loc_B5ED:

		lda WRAM_EnemyAttributeData,y
		ora byte_4
		sta byte_4
		lda EnemyGfxTableOffsets,y
		tax
		ldy byte_EC
		lda BowserGfxFlag
		beq loc_B62F
		cmp #1
		bne loc_B616
		lda BowserBodyControls
		bpl loc_B60A
		ldx #$DE
loc_B60A:

		lda byte_ED
		and #$20
		beq loc_B613
loc_B610:

		stx VerticalFlipFlag
loc_B613:

		jmp loc_B71B
loc_B616:

		lda BowserBodyControls
		and #1
		beq loc_B61F
		ldx #$E4
loc_B61F:

		lda byte_ED
		and #$20
		beq loc_B613
		lda byte_2
		sec
		sbc #$10
		sta byte_2
		jmp loc_B610
loc_B62F:

		cpx #$24
		bne loc_B644
		cpy #5
		bne loc_B641
		ldx #$30
		lda #2
		sta byte_3
		lda #5
		sta byte_EC
loc_B641:

		jmp loc_B694
loc_B644:

		cpx #$90
		bne loc_B65A
		lda byte_ED
		and #$20
		bne loc_B657
		lda FrenzyEnemyTimer
		cmp #$10
		bcs loc_B657
		ldx #$96
loc_B657:

		jmp loc_B701
loc_B65A:

		lda byte_EF
		cmp #4
		bcs loc_B670
		cpy #2
		bcc loc_B670
		ldx #$5A
		ldy byte_EF
		cpy #2
		bne loc_B670
		ldx #$7E
		inc byte_2
loc_B670:

		lda byte_EC
		cmp #4
		bne loc_B694
		ldx #$72
		inc byte_2
		ldy byte_EF
		cpy #2
		beq loc_B684
		ldx #$66
		inc byte_2
loc_B684:

		cpy #6
		bne loc_B694
		ldx #$54
		lda byte_ED
		and #$20
		bne loc_B694
		ldx #$8A
		dec byte_2
loc_B694:

		ldy ObjectOffset
		lda byte_EF
		cmp #5
		bne loc_B6A8
		lda byte_ED
		beq CheckToAnimateEnemy
		and #8
		beq loc_B701
		ldx #$B4
		bne CheckToAnimateEnemy
loc_B6A8:

		cpx #$48
		beq CheckToAnimateEnemy
		lda $796,y
		cmp #5
		bcs loc_B701
		cpx #$3C
		bne CheckToAnimateEnemy
		cmp #1
		beq loc_B701
		inc byte_2
		inc byte_2
		inc byte_2
		jmp CheckAnimationStop
CheckToAnimateEnemy:

		lda byte_EF
		cmp #6
		beq loc_B701
		cmp #8
		beq loc_B701
		cmp #$C
		beq loc_B701
		cmp #$18
		bcs loc_B701
		ldy #0
		cmp #$15
		bne CheckForSecondFrame
		iny
		lda #3
		sta byte_EC
		lda WorldNumber
		cmp #7
		bcs loc_B701
		ldx #$A2
		bne loc_B701
CheckForSecondFrame:

		lda FrameCounter
		and EnemyAnimTimingBMask,y
		bne loc_B701
CheckAnimationStop:

		lda byte_ED
		and #$A0
		ora TimerControl
		bne loc_B701
		txa
		clc
		adc #6
		tax
loc_B701:

		lda byte_EF
		cmp #4
		beq loc_B713
		lda byte_ED
		and #$20
		beq loc_B71B
		lda byte_EF
		cmp #4
		bcc loc_B71B
loc_B713:

		ldy #1
		sty VerticalFlipFlag
		dey
		sty byte_EC
loc_B71B:

		ldy byte_EB
		jsr DrawEnemyObjRow
		jsr DrawEnemyObjRow
		jsr DrawEnemyObjRow
		ldx ObjectOffset
		ldy $6E5,x
		lda byte_EF
		cmp #8
		bne loc_B734
loc_B731:

		jmp loc_B83F
loc_B734:

		lda VerticalFlipFlag
		beq loc_B77A
		lda $202,y
		ora #$80
		iny
		iny
		jsr sub_B25B
		dey
		dey
		tya
		tax
		lda byte_EF
		cmp #5
		beq loc_B75E
		cmp #4
		beq loc_B75E
		cmp #$11
		beq loc_B75E
		cmp #$15
		bcs loc_B75E
		txa
		clc
		adc #8
		tax
loc_B75E:

		lda $201,x
		pha
		lda $205,x
		pha
		lda $211,y
		sta $201,x
		lda $215,y
		sta $205,x
		pla
		sta $215,y
		pla
		sta $211,y
loc_B77A:

		lda BowserGfxFlag
		bne loc_B731
		lda byte_EF
		ldx byte_EC
		cmp #5
		bne loc_B78A
		jmp loc_B83F
loc_B78A:

		cmp #7
		beq loc_B7AF
		cmp #$D
		beq loc_B7AF
		cmp #4
		beq loc_B7AF
		cmp #$C
		beq loc_B7AF
		cmp #$12
		bne loc_B7A2
		cpx #5
		bne loc_B7EA
loc_B7A2:

		cmp #$15
		bne loc_B7AB
		lda #$42
		sta $216,y
loc_B7AB:

		cpx #2
		bcc loc_B7EA
loc_B7AF:

		lda BowserGfxFlag
		bne loc_B7EA
		lda $202,y
		and #$A3
		sta $202,y
		sta $20A,y
		sta $212,y
		ora #$40
		cpx #5
		bne loc_B7CA
		ora #$80
loc_B7CA:

		sta $206,y
		sta $20E,y
		sta $216,y
		cpx #4
		bne loc_B7EA
		lda $20A,y
		ora #$80
		sta $20A,y
		sta $212,y
		ora #$40
		sta $20E,y
		sta $216,y
loc_B7EA:

		lda byte_EF
		cmp #$11
		bne loc_B826
		lda VerticalFlipFlag
		bne loc_B816
		lda $212,y
		and #$81
		sta $212,y
		lda $216,y
		ora #$41
		sta $216,y
		ldx FrenzyEnemyTimer
		cpx #$10
		bcs loc_B83F
		sta $20E,y
		and #$81
		sta $20A,y
		bcc loc_B83F
loc_B816:

		lda $202,y
		and #$81
		sta $202,y
		lda $206,y
		ora #$41
		sta $206,y
loc_B826:

		lda byte_EF
		cmp #$18
		bcc loc_B83F
		lda #$80
		ora WRAM_UnknownAttributeData0
		sta $20A,y
		sta $212,y
		ora #$40
		sta $20E,y
		sta $216,y
loc_B83F:

		ldx ObjectOffset
		lda Enemy_OffscreenBits
		lsr
		lsr
		lsr
		pha
		bcc loc_B84F
		lda #4
		jsr sub_B89C
loc_B84F:

		pla
		lsr
		pha
		bcc loc_B859
		lda #0
		jsr sub_B89C
loc_B859:

		pla
		lsr
		lsr
		pha
		bcc loc_B864
		lda #$10
		jsr MoveESprRowOffscreen
loc_B864:

		pla
		lsr
		pha
		bcc loc_B86E
		lda #8
		jsr MoveESprRowOffscreen
loc_B86E:

		pla
		lsr
		bcc ExEGHandler
		jsr MoveESprRowOffscreen
		lda $16,x
		cmp #$C
		beq ExEGHandler
		lda $B6,x
		cmp #2
		bne ExEGHandler
		jsr EraseEnemyObject
ExEGHandler:

		rts
DrawEnemyObjRow:

		lda EnemyGraphicsTable,x
		sta TMP_0
		lda EnemyGraphicsTable+1,x
DrawOneSpriteRow:

		sta TMP_1
		jmp DrawSpriteObject
MoveESprRowOffscreen:

		clc
		adc $6E5,x
		tay
		lda #$F8
		jmp DumpTwoSpr
sub_B89C:

		clc
		adc $6E5,x
		tay
		jsr sub_B925
		sta $210,y
		rts
DefaultBlockObjTiles:
		.byte $85
unk_B8A9:
		.byte $85
		.byte $86
		.byte $86
sub_B8AC:

		lda Block_Rel_YPos
		sta byte_2
		lda Block_Rel_XPos
		sta byte_5
		lda #3
		sta byte_4
		lsr
		sta byte_3
		ldy $6EC,x
		ldx #0
loc_B8C2:

		lda DefaultBlockObjTiles,x
		sta TMP_0
		lda DefaultBlockObjTiles+1,x
		jsr DrawOneSpriteRow
		cpx #4
		bne loc_B8C2
		ldx ObjectOffset
		ldy $6EC,x
		lda AreaType
		cmp #1
		beq loc_B8E5
		lda #$86
		sta $201,y
		sta $205,y
loc_B8E5:

		lda $3E8,x
		cmp #$C5
		bne loc_B910
		lda #$87
		iny
		jsr loc_B261
		dey
		lda #3
		ldx AreaType
		dex
		beq loc_B8FC
		lsr
loc_B8FC:

		ldx ObjectOffset
		sta $202,y
		ora #$40
		sta $206,y
		ora #$80
		sta $20E,y
		and #$83
		sta $20A,y
loc_B910:

		lda Block_OffscreenBits
		pha
		and #4
		beq loc_B920
		lda #$F8
		sta $204,y
		sta $20C,y
loc_B920:

		pla
sub_B921:

		and #8
		beq locret_B92D
sub_B925:

		lda #$F8
		sta $200,y
		sta $208,y
locret_B92D:

		rts
sub_B92E:

		lda #2
		sta TMP_0
		lda #$75
		ldy GameEngineSubroutine
		cpy #5
		beq loc_B940
		lda #3
		sta TMP_0
		lda #$84
loc_B940:

		ldy $6EC,x
		iny
		jsr loc_B261
		lda FrameCounter
		asl
		asl
		asl
		asl
		and #$C0
		ora TMP_0
		iny
		jsr loc_B261
		dey
		dey
		lda Block_Rel_YPos
		jsr DumpTwoSpr
		lda Block_Rel_XPos
		sta $203,y
		lda $3F1,x
		sec
		sbc ScreenLeft_X_Pos
		sta TMP_0
		sec
		sbc Block_Rel_XPos
		adc TMP_0
		adc #6
		sta $207,y
		lda byte_3BD
		sta $208,y
		sta $20C,y
		lda byte_3B2
		sta $20B,y
		lda TMP_0
		sec
		sbc byte_3B2
		adc TMP_0
		adc #6
		sta $20F,y
		lda Block_OffscreenBits
		jsr sub_B921
		lda Block_OffscreenBits
		asl
		bcc loc_B9A4
		lda #$F8
		jsr DumpTwoSpr
loc_B9A4:

		lda TMP_0
		bpl locret_B9B8
		lda $203,y
		cmp $207,y
		bcc locret_B9B8
		lda #$F8
		sta $204,y
		sta $20C,y
locret_B9B8:

		rts
loc_B9B9:

		ldy $6F1,x
		lda Fireball_Rel_YPos
		sta $200,y
		lda Fireball_Rel_XPos
		sta $203,y
DrawFirebar:

		lda FrameCounter
		lsr
		lsr
		pha
		and #1
		eor #$64
		sta $201,y
		pla
		lsr
		lsr
		lda #2
		bcc loc_B9DD
		ora #$C0
loc_B9DD:

		sta $202,y
		rts
ExplosionTiles:
		.byte $68
		.byte $67
		.byte $66
DrawExplosion_Fireball:

		ldy Alt_SprDataOffset,x
		lda Fireball_State,x
		inc Fireball_State,x
		lsr
		and #7
		cmp #3
		bcs loc_BA3C
DrawExplosion_Fireworks:

		tax
		lda ExplosionTiles,x
		iny
		jsr loc_B261
		dey
		ldx ObjectOffset
		lda Fireball_Rel_YPos
		sec
		sbc #4
		sta $200,y
		sta $208,y
		clc
		adc #8
		sta $204,y
		sta $20C,y
		lda Fireball_Rel_XPos
		sec
		sbc #4
		sta $203,y
		sta $207,y
		clc
		adc #8
		sta $20B,y
		sta $20F,y
		lda #2
		sta $202,y
		lda #$82
		sta $206,y
		lda #$42
		sta $20A,y
		lda #$C2
		sta $20E,y
		rts
loc_BA3C:

		lda #0
		sta $24,x
		rts
DrawSmallPlatform:

		ldy $6E5,x
		lda #$5B
		iny
		jsr sub_B25B
		iny
		lda #2
		jsr sub_B25B
		dey
		dey
		lda Enemy_Rel_XPos
		sta $203,y
		sta $20F,y
		clc
		adc #8
		sta $207,y
		sta $213,y
		clc
		adc #8
		sta $20B,y
		sta $217,y
		lda $CF,x
		tax
		pha
		cpx #$20
		bcs loc_BA77
		lda #$F8
loc_BA77:

		jsr loc_B264
		pla
		clc
		adc #$80
		tax
		cpx #$20
		bcs loc_BA85
		lda #$F8
loc_BA85:

		sta $20C,y
		sta $210,y
		sta $214,y
		lda Enemy_OffscreenBits
		pha
		and #8
		beq loc_BA9E
		lda #$F8
		sta $200,y
		sta $20C,y
loc_BA9E:

		pla
		pha
		and #4
		beq loc_BAAC
		lda #$F8
		sta $204,y
		sta $210,y
loc_BAAC:

		pla
		and #2
		beq loc_BAB9
		lda #$F8
		sta $208,y
		sta $214,y
loc_BAB9:

		ldx ObjectOffset
		rts
sub_BABC:

		ldy Player_Y_HighPos
		dey
		bne locret_BAE1
		lda Bubble_OffscreenBits
		and #8
		bne locret_BAE1
		ldy $6EE,x
		lda Bubble_Rel_XPos
		sta $203,y
		lda Bubble_Rel_YPos
		sta $200,y
		lda #$74
		sta $201,y
		lda #2
		sta $202,y
locret_BAE1:

		rts
PlayerGfxTblOffsets:
		.byte $20
		.byte $28
		.byte $C8
		.byte $18
		.byte 0
		.byte $40
		.byte $50
		.byte $58
		.byte $80
		.byte $88
		.byte $B8
		.byte $78
		.byte $60
		.byte $A0
		.byte $B0
		.byte $B8
PlayerGraphicsTable:
		.byte 0
		.byte 1
		.byte 2
		.byte 3
		.byte 4
		.byte 5
		.byte 6
		.byte 7
		.byte 8
		.byte 9
		.byte $A
		.byte $B
		.byte $C
		.byte $D
		.byte $E
		.byte $F
		.byte $10
		.byte $11
		.byte $12
		.byte $13
		.byte $14
		.byte $15
		.byte $16
		.byte $17
		.byte $18
		.byte $19
		.byte $1A
		.byte $1B
		.byte $1C
		.byte $1D
		.byte $1E
		.byte $1F
		.byte $20
		.byte $21
		.byte $22
		.byte $23
		.byte $24
		.byte $25
		.byte $26
		.byte $27
		.byte 8
		.byte 9
		.byte $28
		.byte $29
		.byte $2A
		.byte $2B
		.byte $2C
		.byte $2D
		.byte 8
		.byte 9
		.byte $A
		.byte $B
		.byte $C
		.byte $30
		.byte $2C
		.byte $2D
		.byte 8
		.byte 9
		.byte $A
		.byte $B
		.byte $2E
		.byte $2F
		.byte $2C
		.byte $2D
		.byte 8
		.byte 9
		.byte $28
		.byte $29
		.byte $2A
		.byte $2B
		.byte $5C
		.byte $5D
		.byte 8
		.byte 9
		.byte $A
		.byte $B
		.byte $C
		.byte $D
		.byte $5E
		.byte $5F
		.byte $FC
		.byte $FC
		.byte 8
		.byte 9
		.byte $58
		.byte $59
		.byte $5A
		.byte $5A
		.byte 8
		.byte 9
		.byte $28
		.byte $29
		.byte $2A
		.byte $2B
		.byte $E
		.byte $F
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $32
		.byte $33
		.byte $34
		.byte $35
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $36
		.byte $37
		.byte $38
		.byte $39
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $3A
		.byte $37
		.byte $3B
		.byte $3C
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $3D
		.byte $3E
		.byte $3F
		.byte $40
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $32
		.byte $41
		.byte $42
		.byte $43
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $32
		.byte $33
		.byte $44
		.byte $45
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $32
		.byte $33
		.byte $44
		.byte $47
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $32
		.byte $33
byte_BB90:
		.byte $48
		.byte $49
		.byte $FC
byte_BB93:
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $32
		.byte $33
		.byte $90
		.byte $91
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $3A
		.byte $37
		.byte $92
		.byte $93
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $9E
		.byte $9E
		.byte $9F
		.byte $9F
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $FC
		.byte $3A
		.byte $37
		.byte $4F
		.byte $4F
		.byte $FC
		.byte $FC
		.byte 0
		.byte 1
		.byte $4C
		.byte $4D
		.byte $4E
		.byte $4E
		.byte 0
		.byte 1
		.byte $4C
		.byte $4D
		.byte $4A
		.byte $4A
		.byte $4B
		.byte $4B
NEW_SomethingWithPlayerGraphics:
		.byte $31
		.byte $46
PlayerGfxHandler:

		lda InjuryTimer
		beq loc_BBCE
		lda FrameCounter
		lsr
		bcs locret_BC0E
loc_BBCE:

		lda GameEngineSubroutine
		cmp #$B
		beq loc_BC1B
		lda PlayerChangeSizeFlag
		bne loc_BC15
		ldy SwimmingFlag
		beq sub_BC0F
		lda Player_State
		cmp #0
		beq sub_BC0F
		jsr sub_BC0F
		lda FrameCounter
		and #4
		bne locret_BC0E
		tax
		ldy Player_SprDataOffset
		lda PlayerFacingDir
		lsr
		bcs loc_BBFA
		iny
		iny
		iny
		iny
loc_BBFA:

		lda PlayerSize
		beq loc_BC08
		lda $219,y
		cmp byte_BB90
		beq locret_BC0E
		inx
loc_BC08:

		lda NEW_SomethingWithPlayerGraphics,x
		sta $219,y
locret_BC0E:

		rts
sub_BC0F:

		jsr sub_BCC7
		jmp loc_BC20
loc_BC15:

		jsr sub_BD95
		jmp loc_BC20
loc_BC1B:

		ldy #$E
		lda PlayerGfxTblOffsets,y
loc_BC20:

		sta PlayerGfxOffset
		lda #4
		jsr RenderPlayerSub
		jsr ChkForPlayerAttrib
		lda FireballThrowingTimer
		beq loc_BC55
		ldy #0
		lda PlayerAnimTimer
		cmp FireballThrowingTimer
		sty FireballThrowingTimer
		bcs loc_BC55
		sta FireballThrowingTimer
		ldy #7
		lda PlayerGfxTblOffsets,y
		sta PlayerGfxOffset
		ldy #4
		lda Player_X_Speed
		ora Left_Right_Buttons
		beq loc_BC51
		dey
loc_BC51:

		tya
		jsr RenderPlayerSub
loc_BC55:

		lda Player_OffscreenBits
		lsr
		lsr
		lsr
		lsr
		sta TMP_0
		ldx #3
		lda Player_SprDataOffset
		clc
		adc #$18
		tay
loc_BC67:

		lda #$F8
		lsr TMP_0
		bcc loc_BC70
		jsr DumpTwoSpr
loc_BC70:

		tya
		sec
		sbc #8
		tay
		dex
		bpl loc_BC67
		rts
IntermediatePlayerData:
		.byte $58
		.byte 1
		.byte 0
		.byte $60
		.byte $FF
		.byte 4
DrawPlayer_Intermediate:

		ldx #5
loc_BC81:

		lda IntermediatePlayerData,x
		sta 2,x
		dex
		bpl loc_BC81
		ldx #$B8
loc_BC8B:

		ldy #4
		jsr loc_BCB7
		lda byte_226
		ora #$40
		sta byte_222
		rts
RenderPlayerSub:

		sta unk_7
		lda Player_Rel_XPos
		sta Player_Pos_ForScroll
		sta byte_5
		lda Player_Rel_YPos
		sta byte_2
		lda PlayerFacingDir
		sta byte_3
		lda Player_SprAttrib
		sta byte_4
		ldx PlayerGfxOffset
		ldy Player_SprDataOffset
loc_BCB7:

		lda PlayerGraphicsTable,x
		sta TMP_0
		lda PlayerGraphicsTable+1,x
		jsr DrawOneSpriteRow
		dec unk_7
		bne loc_BCB7
		rts
sub_BCC7:

		lda Player_State
		cmp #3
		beq loc_BD29
		cmp #2
		beq loc_BD19
		cmp #1
		bne loc_BCE6
		lda SwimmingFlag
		bne loc_BD35
		ldy #6
		lda CrouchingFlag
		bne loc_BD0D
		ldy #0
		jmp loc_BD0D
loc_BCE6:

		ldy #6
		lda CrouchingFlag
		bne loc_BD0D
		ldy #2
		lda Player_X_Speed
		ora Left_Right_Buttons
		beq loc_BD0D
		lda Player_XSpeedAbsolute
		cmp #9
		bcc loc_BD21
		lda Player_MovingDir
		and PlayerFacingDir
		bne loc_BD21
		lda GameEngineSubroutine
		cmp #9
		bcs loc_BD0C
		lda #$80
		sta NoiseSoundQueue
loc_BD0C:

		iny
loc_BD0D:

		jsr sub_BD76
		lda #0
		sta PlayerAnimCtrl
		lda PlayerGfxTblOffsets,y
		rts
loc_BD19:

		ldy #4
		jsr sub_BD76
		jmp sub_BD47
loc_BD21:

		ldy #4
		jsr sub_BD76
		jmp loc_BD4D
loc_BD29:

		ldy #5
		lda Player_Y_Speed
		beq loc_BD0D
		jsr sub_BD76
		jmp loc_BD52
loc_BD35:

		ldy #1
		jsr sub_BD76
		lda JumpSwimTimer
		ora PlayerAnimCtrl
		bne loc_BD4D
		lda A_B_Buttons
		asl
		bcs loc_BD4D
sub_BD47:

		lda PlayerAnimCtrl
		jmp loc_BDB5
loc_BD4D:

		lda #3
		jmp loc_BD54
loc_BD52:

		lda #2
loc_BD54:

		sta TMP_0
		jsr sub_BD47
		pha
		lda PlayerAnimTimer
		bne loc_BD74
		lda PlayerAnimTimerSet
		sta PlayerAnimTimer
		lda PlayerAnimCtrl
		clc
		adc #1
		cmp TMP_0
		bcc loc_BD71
		lda #0
loc_BD71:

		sta PlayerAnimCtrl
loc_BD74:

		pla
		rts
sub_BD76:

		lda PlayerSize
		beq locret_BD80
		tya
		clc
		adc #8
		tay
locret_BD80:

		rts
ChangeSizeOffsetAdder:
		.byte 0
		.byte 1
		.byte 0
		.byte 1
		.byte 0
		.byte 1
		.byte 2
		.byte 0
		.byte 1
		.byte 2
		.byte 2
		.byte 0
		.byte 2
		.byte 0
		.byte 2
		.byte 0
		.byte 2
		.byte 0
		.byte 2
		.byte 0
sub_BD95:

		ldy PlayerAnimCtrl
		lda FrameCounter
		and #3
		bne loc_BDAB
		iny
		cpy #$A
		bcc loc_BDA8
		ldy #0
		sty PlayerChangeSizeFlag
loc_BDA8:

		sty PlayerAnimCtrl
loc_BDAB:

		lda PlayerSize
		bne loc_BDBC
		lda ChangeSizeOffsetAdder,y
		ldy #$F
loc_BDB5:

		asl
		asl
		asl
		adc PlayerGfxTblOffsets,y
		rts
loc_BDBC:

		tya
		clc
		adc #$A
		tax
		ldy #9
		lda ChangeSizeOffsetAdder,x
		bne loc_BDCA
		ldy #1
loc_BDCA:

		lda PlayerGfxTblOffsets,y
		rts
ChkForPlayerAttrib:

		ldy Player_SprDataOffset
		lda GameEngineSubroutine
		cmp #$B
		beq loc_BDEA
		lda PlayerGfxOffset
		cmp #$50
		beq loc_BDFC
		cmp #$B8
		beq loc_BDFC
		cmp #$C0
		beq loc_BDFC
		cmp #$C8
		bne locret_BE0E
loc_BDEA:

		lda $212,y
		and #$3F
		sta $212,y
		lda $216,y
		and #$3F
		ora #$40
		sta $216,y
loc_BDFC:

		lda $21A,y
		and #$3F
		sta $21A,y
		lda $21E,y
		and #$3F
		ora #$40
		sta $21E,y
locret_BE0E:

		rts
RelativePlayerPosition:

		ldx #0
		ldy #0
		jmp RelWOfs
loc_BE16:

		ldy #1
		jsr GetProperObjOffset
		ldy #3
		jmp RelWOfs
RelativeFireballPosition:

		ldy #0
		jsr GetProperObjOffset
		ldy #2
RelWOfs:

		jsr GetObjRelativePosition
		ldx ObjectOffset
		rts
RelativeMiscPosition:

		ldy #2
		jsr GetProperObjOffset
		ldy #6
		jmp RelWOfs
RelativeEnemyPosition:

		lda #1
		ldy #1
		jmp loc_BE4A
loc_BE3E:

		lda #9
		ldy #4
		jsr loc_BE4A
		inx
		inx
		lda #9
		iny
loc_BE4A:

		stx TMP_0
		clc
		adc TMP_0
		tax
		jsr GetObjRelativePosition
		ldx ObjectOffset
		rts
GetObjRelativePosition:

		lda SprObject_Y_Position,x
		sta Player_Rel_YPos,y
		lda Player_X_Position,x
		sec
		sbc ScreenLeft_X_Pos
		sta Player_Rel_XPos,y
		rts
GetPlayerOffscreenBits:

		ldx #0
		ldy #0
		jmp GetOffScreenBitsSet
GetFireballOffscreenBits:

		ldy #0
		jsr GetProperObjOffset
		ldy #2
		jmp GetOffScreenBitsSet
sub_BE76:

		ldy #1
		jsr GetProperObjOffset
		ldy #3
		jmp GetOffScreenBitsSet
GetMiscOffscreenBits:

		ldy #2
		jsr GetProperObjOffset
		ldy #6
		jmp GetOffScreenBitsSet
ObjOffsetData:
		.byte 7
		.byte $16
		.byte $D
GetProperObjOffset:

		txa
		clc
		adc ObjOffsetData,y
		tax
		rts
GetEnemyOffscreenBits:

		lda #1
		ldy #1
		jmp SetOffscrBitsOffset
loc_BE9B:

		lda #9
		ldy #4
SetOffscrBitsOffset:

		stx TMP_0
		clc
		adc TMP_0
		tax
GetOffScreenBitsSet:

		tya
		pha
		jsr sub_BEBC
		asl
		asl
		asl
		asl
		ora TMP_0
		sta TMP_0
		pla
		tay
		lda TMP_0
		sta Player_OffscreenBits,y
		ldx ObjectOffset
		rts
sub_BEBC:

		jsr GetXOffscreenBits
		lsr
		lsr
		lsr
		lsr
		sta TMP_0
		jmp GetYOffscreenBits
XOffscreenBitsData:
		.byte $7F
		.byte $3F
		.byte $1F
		.byte $F
		.byte 7
		.byte 3
		.byte 1
		.byte 0
		.byte $80
		.byte $C0
		.byte $E0
		.byte $F0
		.byte $F8
		.byte $FC
		.byte $FE
		.byte $FF
DefaultXOnscreenOfs:
		.byte 7
		.byte $F
		.byte 7
GetXOffscreenBits:

		stx byte_4
		ldy #1
loc_BEDF:

		lda ScreenLeft_X_Pos,y
		sec
		sbc Player_X_Position,x
		sta unk_7
		lda ScreenLeft_PageLoc,y
		sbc Player_PageLoc,x
		ldx DefaultXOnscreenOfs,y
		cmp #0
		bmi loc_BF03
		ldx DefaultXOnscreenOfs+1,y
		cmp #1
		bpl loc_BF03
		lda #$38
		sta byte_6
		lda #8
		jsr DividePDiff
loc_BF03:

		lda XOffscreenBitsData,x
		ldx byte_4
		cmp #0
		bne locret_BF0F
		dey
		bpl loc_BEDF
locret_BF0F:

		rts
YOffscreenBitsData:
		.byte $F
		.byte 7
		.byte 3
		.byte 1
		.byte 0
word_BF15:
		.word $C08
		.byte $E
		.byte 0
DefaultYOnscreenOfs:
		.byte 4
		.byte 0
		.byte 4
HighPosUnitData:
		.byte 0
		.byte $FF
GetYOffscreenBits:

		stx byte_4
		ldy #1
loc_BF22:

		lda HighPosUnitData,y
		sec
		sbc SprObject_Y_Position,x
		sta unk_7
		lda #1
		sbc Player_Y_HighPos,x
		ldx DefaultYOnscreenOfs,y
		cmp #0
		bmi loc_BF45
		ldx DefaultYOnscreenOfs+1,y
		cmp #1
		bpl loc_BF45
		lda #$20
		sta byte_6
		lda #4
		jsr DividePDiff
loc_BF45:

		lda YOffscreenBitsData,x
		ldx byte_4
		cmp #0
		bne locret_BF51
		dey
		bpl loc_BF22
locret_BF51:

		rts
DividePDiff:

		sta byte_5
		lda unk_7
		cmp byte_6
		bcs locret_BF66
		lsr
		lsr
		lsr
		and #7
		cpy #1
		bcs loc_BF65
		adc byte_5
loc_BF65:

		tax
locret_BF66:

		rts
DrawSpriteObject:

		lda byte_3
		lsr
		lsr
		lda TMP_0
		bcc loc_BF7B
		sta $205,y
		lda TMP_1
		sta $201,y
		lda #$40
		bne loc_BF85
loc_BF7B:

		sta $201,y
		lda TMP_1
		sta $205,y
		lda #0
loc_BF85:

		ora byte_4
		sta $202,y
		sta $206,y
		lda byte_2
		sta $200,y
		sta $204,y
		lda byte_5
		sta $203,y
		clc
		adc #8
		sta $207,y
		lda byte_2
		clc
		adc #8
		sta byte_2
		tya
		clc
		adc #8
		tay
		inx
		inx
		rts
		.byte $FF
TitleScreenMode:

		lda OperMode_Task
		jsr JumpEngine
		.word TitleInitializeFdsLoads
		.word PrepareDrawTitleScreen
		.word ScreenRoutines
		.word PrimaryGameSetup
		.word GameMenuRoutine_NEW
		.word FinalizeTitleScreen

FinalizeTitleScreen:
		lda FdsOperTask
		jsr JumpEngine
		.word PrepareFdsLoad
		.word SwapToGameData
		.word WaitFDSReady
		.word MoreFDSStuff
		.word FDSResetZero

SwapToGameData:
		lda IsPlayingExtendedWorlds
		beq loc_BFE6
		lda #3 ; SM2DATA4
		sta LoadListIndex
		jsr LoadFilesFromFDS
		bne loc_C038
		jsr sub_C0CA
		bne loc_C036
loc_BFE6:

		jsr LoadAreaPointer
		lda IsPlayingExtendedWorlds
		beq loc_BFF1
		jsr XXX_PatchSomeData
loc_BFF1:

		inc Hidden1UpFlag
		inc FetchNewGameTimerFlag
		inc OperMode
		lda #0
		sta FdsOperTask
		sta OperMode_Task
		sta DemoTimer
		rts

TitleInitializeFdsLoads:
		lda FdsOperTask
		jsr JumpEngine
		.word PrepareFdsLoad
		.word LoadCorrectWorldFiles
		.word WaitFDSReady
		.word MoreFDSStuff
		.word FDSResetZero

LoadCorrectWorldFiles:
		lda ContinueWorld
		beq loc_C03E
		lda IsPlayingExtendedWorlds
		bne loc_C027
		lda WorldNumber
		cmp #4
		bcc loc_C03E
loc_C027:

		lda #0
		sta LoadListIndex
		jsr LoadFilesFromFDS
		bne loc_C038
		jsr sub_C0CA
		beq loc_C03E
loc_C036:

		lda #$40
loc_C038:

		inc FdsOperTask
REMOVEME_DiskError:
		jmp REMOVEME_DiskError

loc_C03E:

		lda #1
		sta ContinueWorld
		lsr
		sta WorldNumber
		sta IsPlayingExtendedWorlds
		jmp FdsOperationDone
LoadCorrectData:

		lda FdsOperTask
		jsr JumpEngine
		.word PrepareFdsLoad
		.word LoadBaseOnWorld
		.word WaitFDSReady
		.word MoreFDSStuff
		.word FDSResetZero
LoadBaseOnWorld:

		lda WorldNumber
		cmp #4
		bcc FdsOperationDone
		lda LoadListIndex
		bne FdsOperationDone
		lda #1
		sta LoadListIndex
		jsr LoadFilesFromFDS
		bne loc_C038
		jsr sub_C0CA
		bne loc_C036
FdsOperationDone:

		lda #0
		sta FdsOperTask
Increase_OperMode_Task:

		inc OperMode_Task
		rts
InitializeWorldEndTimer:

		lda #$10
		sta WorldEndTimer
		bne Increase_OperMode_Task
CheckWorldEndTimer:

		lda WorldEndTimer
		beq Increase_OperMode_Task
		rts
FdsLoadFile_SM2DATA3:

		lda FdsOperTask
		jsr JumpEngine
		.word PrepareFdsLoad
		.word LoadFdsFileIndex2
		.word WaitFDSReady
		.word MoreFDSStuff
		.word FDSResetZero
LoadFdsFileIndex2:

		lda #2
		sta LoadListIndex
		jsr LoadFilesFromFDS
		bne loc_C038
		jsr sub_C0CA
		beq loc_C0B2
		lda #0
		sta WRAM_NumberOfStars
loc_C0B2:

		lda WRAM_NumberOfStars
		clc
		adc #1
		cmp #$19
		bcc loc_C0BE
		lda #$18
loc_C0BE:
		sta WRAM_NumberOfStars
		jsr InitializeNameTables
		jsr FdsOperationDone
		jmp byte_C858
sub_C0CA:
		tya
		ldy LoadListIndex
		cmp word_C0F0,y
		rts

word_C0F0:
		.word $103
		.word $103
LoadFilesFromFDS:
		jmp LoadFilesFromFDS

byte_C10B:
		.byte $3F
		.byte 0
		.byte 4
		.byte $F
		.byte $30
		.byte $30
		.byte $F
		.byte 0

PrepareFdsLoad:
		lda #0
		sta Mirror_PPU_CTRL_REG2
		sta PPU_CTRL_REG2
		sta Sprite0HitDetectFlag
		inc DisableScreenFlag
		lda #$1A
		sta VRAM_Buffer_AddrCtrl
		jmp TitleNextTask

WaitFDSReady:
		;
		; TODO: This entire callback can be killed.
		;
		lda #0
		sta UseNtBase2400
		sta DisableScreenFlag
TitleNextTask:
		inc FdsOperTask
TitleExitNow:
		rts

MoreFDSStuff:
		; used to wait for drive status
		jmp TitleNextTask

FDSResetZero:
		lda #0
		sta FdsOperTask
		sta LoadListIndex
		rts


byte_C1BD:
		.byte $5B
		.byte 2
		.byte $48
byte_C1C0:
		.byte $77
		.byte $8F
loc_C1C2:

		lda SavedJoypad1Bits
		and #$10
		bne loc_C1F6
		lda SavedJoypad1Bits
		and #$20
		beq loc_C1E1
		ldx SelectTimer
		bne loc_C1E1
		lsr
		sta SelectTimer
		lda GameTimerDisplay_OBSOLETE
		eor #1
		sta GameTimerDisplay_OBSOLETE
loc_C1E1:

		ldy #2
loc_C1E3:

		lda byte_C1BD,y
		sta $201,y
		dey
		bpl loc_C1E3
		ldy GameTimerDisplay_OBSOLETE
		lda byte_C1C0,y
		sta Sprite_Y_Position
		rts
loc_C1F6:

		lda GameTimerDisplay_OBSOLETE
		beq loc_C203
		lda #0
		sta byte_7FA
		jmp sub_708D
loc_C203:

		ldy #2
		sty NumberofLives
		sta LevelNumber
		sta AreaNumber
		sta CoinTally
		ldy #$B
loc_C213:

		sta $7DD,y
		dey
		bpl loc_C213
		inc Hidden1UpFlag
		jmp loc_709D

MarioOrLuigiPhysics:
		;
		; Mario Physics
		;
		.byte $20, $20, $1E, $28
		.byte $28, $0D, $04, $70
		.byte $70, $60, $90, $90
		.byte $0A, $09, $E4, $98
		.byte $D0
		;
		; Luigi Physics
		;
		.byte $18, $18, $18, $22
		.byte $22, $0D, $04, $42
		.byte $42, $3E, $5D, $5D
		.byte $0A, $09, $B4, $68
		.byte $A0

PatchLuigiOrMarioPhysics_NEW:
		; ldx #$60
		ldy #$21
		lda IsPlayingLuigi
		bne PlayerIsLuigiPath
PlayerIsMarioPatch:
		; ldx #$E
		ldy #$10
PlayerIsLuigiPath:
		; stx VOLDST_PatchMovementFriction
		ldx #$10
loc_C253:
		lda MarioOrLuigiPhysics,y
		sta WRAM_JumpMForceData,x
		dey
		dex
		bpl loc_C253
		rts
		.byte $FF
		.byte $FF
unk_C260:
		.byte $FF
unk_C261:
		.byte $90
		.byte $31
		.byte $39
		.byte $F1
		.byte $BF
		.byte $37
		.byte $33
		.byte $E7
		.byte $A3
		.byte 3
		.byte $A7
		.byte 3
		.byte $CD
		.byte $41
		.byte $F
		.byte $A6
		.byte $ED
		.byte $47
		.byte $FD
byte_C274:
		.byte $38
		.byte $11
		.byte $F
		.byte $26
		.byte $AD
		.byte $40
		.byte $3D
		.byte $C7
		.byte $FD
byte_C27D:
		.byte $10
		.byte 0
		.byte $B
		.byte $13
		.byte $5B
		.byte $14
		.byte $6A
		.byte $42
		.byte $C7
		.byte $12
		.byte $C6
		.byte $42
		.byte $1B
		.byte $94
		.byte $2A
		.byte $42
		.byte $53
		.byte $13
		.byte $62
		.byte $41
		.byte $97
		.byte $17
		.byte $A6
		.byte $45
		.byte $6E
		.byte $81
		.byte $8F
		.byte $37
		.byte 2
		.byte $E8
		.byte $12
		.byte $3A
		.byte $68
		.byte $7A
		.byte $DE
		.byte $F
		.byte $6D
		.byte $C5
		.byte $FD
LoadAreaPointer:

		jsr FindAreaPointer
		sta AreaPointer
GetAreaType:

		and #$60
		asl
		rol
		rol
		rol
		sta AreaType
		rts
FindAreaPointer:

		ldy WorldNumber
		lda WorldAddrOffsets,y
		clc
		adc AreaNumber
		tay
		lda AreaAddrOffsets,y
		rts
GetAreaDataAddrs_NEW:

		lda AreaPointer
		jsr GetAreaType
		tay
		lda AreaPointer
		and #$1F
		sta AreaAddrsLOffset
		lda EnemyAddrHOffsets,y
		clc
		adc AreaAddrsLOffset
		asl
		tay
		lda EnemyDataAddrLow+1,y
		sta EnemyDataHigh
		lda EnemyDataAddrLow,y
		sta EnemyDataLow
		ldy AreaType
		lda AreaDataHOffsets,y
		clc
		adc AreaAddrsLOffset
		asl
		tay
		lda AreaDataAddrLow+1,y
		sta AreaDataHigh
		lda AreaDataAddrLow,y
		sta AreaDataLow
		ldy #0
		lda ($E7),y
		pha
		and #7
		cmp #4
		bcc loc_C30B
		sta BackgroundColorCtrl
		lda #0
loc_C30B:

		sta ForegroundScenery
		pla
		pha
		and #$38
		lsr
		lsr
		lsr
		sta PlayerEntranceCtrl
		pla
		and #$C0
		clc
		rol
		rol
		rol
		sta GameTimerSetting
		iny
		lda ($E7),y
		pha
		and #$F
		sta TerrainControl
		pla
		pha
		and #$30
		lsr
		lsr
		lsr
		lsr
		sta BackgroundScenery
		pla
		and #$C0
		clc
		rol
		rol
		rol
		cmp #3
		bne loc_C346
		sta CloudTypeOverride
		lda #0
loc_C346:

		sta AreaStyle
		lda AreaDataLow
		clc
		adc #2
		sta AreaDataLow
		lda AreaDataHigh
		adc #0
		sta AreaDataHigh
		rts
WorldAddrOffsets:
		.byte 0
		.byte 5
		.byte 9
		.byte $E
		.byte $12
		.byte $17
		.byte $1C
		.byte $20
		.byte $24
AreaAddrOffsets:
		.byte $20
		.byte $29
		.byte $40
		.byte $21
		.byte $60
World1Areas:
		.byte $22
		.byte $23
		.byte $24
		.byte $61
		.byte $25
		.byte $29
		.byte 0
		.byte $26
		.byte $62
		.byte $27
		.byte $28
		.byte $2A
		.byte $63
		.byte $2B
		.byte $29
		.byte $43
		.byte $2C
		.byte $64
		.byte $2D
		.byte $29
		.byte 1
		.byte $2E
		.byte $65
		.byte $2F
		.byte $30
		.byte $31
		.byte $66
		.byte $32
		.byte $35
		.byte $36
		.byte $67
		.byte $38
		.byte 6
		.byte $68
		.byte 7
SWAPDATA_AreaDataOfsLoopback:
		.byte $C
		.byte $C
		.byte $42
		.byte $42
		.byte $10
		.byte $10
		.byte $30
		.byte $30
		.byte 6
		.byte $C
		.byte $54
		.byte 6
EnemyAddrHOffsets:
		.byte $2C
		.byte $A
		.byte $27
		.byte 0
EnemyDataAddrLow:
		.word unk_C790
		.word byte_C7AF
		.word byte_C7D6
		.word unk_C7E9
		.word PrepareInitializeArea
		.word loc_C609
		.word unk_C630
		.word unk_C66F
		.word unk_CA80
		.word unk_CA8A
		.word unk_C81E
		.word byte_C844
		.word byte_C867
		.word unk_C890
		.word unk_C8C6
		.word unk_C8DD
		.word unk_C907
		.word unk_C92C
		.word SWAPDATA_C943
		.word unk_C260
		.word unk_C965
		.word unk_C6AF
		.word unk_C6E0
		.word unk_C708
		.word unk_C72C
		.word unk_C749
		.word unk_C77A
		.word unk_C7A6
		.word unk_C7BF
		.word unk_C988
		.word unk_C260
XXX_PatchSomeData:
		.word unk_C7E7
		.word unk_C80A
		.word unk_C831
		.word unk_CA90
		.word unk_CA94
		.word unk_CA94
		.word unk_C260
		.word byte_C832
		.word unk_C994
		.word unk_C9BA
		.word unk_C9C4
		.word byte_C83B
		.word byte_C85C
		.word unk_C9DE
		.word SWAPDATA_C876
		.word unk_CA04
		.word unk_C8A6
		.word unk_C8B4
		.word unk_CA94
		.word unk_CAB5
		.word unk_CABA
AreaDataHOffsets:
		.byte $2C
		.byte $A
		.byte $27
		.byte 0
AreaDataAddrLow:
		.word unk_CA14
		.word unk_CA73
		.word unk_CAFE
		.word unk_CB95
		.word unk_C8C9
		.word unk_C996
		.word unk_CA25
		.word unk_CAB8
		.word unk_CACB
		.word unk_CB2E
		.word unk_CC0A
		.word byte_CC65
		.word byte_CCB4
		.word byte_CD2D
		.word byte_CDAA
		.word byte_CE09
		.word byte_CE88
		.word byte_CEE7
		.word byte_CF5E
		.word byte_C274
		.word unk_CFBF
		.word byte_CB8F
		.word unk_CC30
		.word byte_CC8F
		.word unk_CD0E
		.word byte_CD7B
		.word byte_CDFE
		.word unk_CE5B
		.word byte_CED6
		.word byte_D008
		.word byte_C27D
		.word unk_CF4B
		.word byte_CFB6
		.word unk_D01A
		.word unk_CB3F
		.word unk_CB4E
		.word unk_CB4F
		.word unk_C261
		.word unk_D01B
		.word unk_D021
		.word unk_D0E2
		.word unk_D11D
		.word unk_D052
		.word unk_D11F
		.word unk_D168
		.word unk_D160
		.word unk_D21B
		.word unk_D229
		.word unk_D242
		.word unk_CB50
		.word unk_CB97
		.word unk_CBDA
		.word $FFFF

GameMenuRoutine_NEW:
		lda SavedJoypad1Bits
		and #$10
		beq loc_C494
GameMenuRoutineInner_NEW:
		lda #0
		sta byte_7FA
		sta FdsOperTask
		sta IsPlayingExtendedWorlds
		lda WRAM_NumberOfStars
		cmp #8
		bcc loc_C491
		lda SavedJoypad1Bits
		and #$80
		beq loc_C491
		inc IsPlayingExtendedWorlds
loc_C491:
		jmp loc_C4EC
loc_C494:
		lda SavedJoypad1Bits
		cmp #$20
		beq loc_C4AA
		ldx DemoTimer
		bne loc_C4CF
		sta SelectTimer
		jsr loc_C553
		bcs loc_C4DD
		bcc loc_C4D4
loc_C4AA:

		lda DemoTimer
		beq loc_C4DD
		lda #$18
		sta DemoTimer
		lda FrameCounter
		and #$FE
		sta FrameCounter
		lda SelectTimer
		bne loc_C4CF
loc_C4BF:

		lda #$10
		sta SelectTimer
		lda IsPlayingLuigi
		eor #1
		sta IsPlayingLuigi
		jsr MoveTitlescreenMushroom_NEW
loc_C4CF:

		lda #0
		sta SavedJoypad1Bits
loc_C4D4:

		jsr GameCoreRoutine_RW
		lda GameEngineSubroutine
		cmp #6
		bne locret_C510
loc_C4DD:

		lda #0
		sta OperMode
		sta OperMode_Task
		sta Sprite0HitDetectFlag
		inc DisableScreenFlag
		rts

loc_C4EC:
		lda DemoTimer
		beq loc_C4DD
		inc OperMode_Task
		jsr PatchToMarioOrLuigi
		lda #0
		sta WorldNumber
		lda #0
FinalizePlayerMovement:
		sta LevelNumber
		lda #0
		sta AreaNumber
		ldx #$B
		lda #0
loc_C50A:
		sta PlayerScoreDisplay,x
		dex
		bpl loc_C50A
locret_C510:
		rts

NothingOrMushroomTile:
		.byte $CE
		.byte $24
		.byte $CE

MoveTitlescreenMushroom_NEW:
		lda #$1C
		sta VRAM_Buffer_AddrCtrl
MoveTitlescreenMushroomCurrAddr_NEW:
		ldy IsPlayingLuigi
loc_C523:
		lda NothingOrMushroomTile,y
		sta WRAM_SelectMario
		lda NothingOrMushroomTile+1,y
		sta WRAM_SelectLuigi
		rts

DemoActionData:
		.byte 1
		.byte $81
		.byte 1
		.byte $81
		.byte 1
		.byte $81
		.byte 2
		.byte 1
		.byte $81
		.byte 0
		.byte $81
		.byte 0
		.byte $80
		.byte 1
		.byte $81
		.byte 1
		.byte 0
DemoTimingData:
		.byte $B0
		.byte $10
		.byte $10
		.byte $10
		.byte $28
		.byte $10
		.byte $28
		.byte 6
		.byte $10
		.byte $10
		.byte $C
		.byte $80
		.byte $10
		.byte $28
		.byte 8
func_C550_DATA2:
		.byte $90
		.byte $FF
		.byte 0
loc_C553:

		ldx DemoAction
		lda DemoActionTimer
		bne loc_C568
		inx
		inc DemoAction
		sec
		lda DemoTimingData-1,x
		sta DemoActionTimer
		beq locret_C572
loc_C568:

		lda DemoActionData-1,x
		sta SavedJoypad1Bits
		dec DemoActionTimer
		clc
locret_C572:
		rts

ClearBuffersDrawIcon:
		lda OperMode
		bne loc_C58F
		ldx #0
loc_C57A:
		sta $300,x
		sta $400,x
		dex
		bne loc_C57A
		jsr MoveTitlescreenMushroom_NEW
		inc ScreenRoutineTask
		rts

WriteTopScore:
		lda #$FA
		jsr UpdateNumber
		jsr RenderStars
loc_C58F:
		jmp Next_OperMode_Task

PrepareDrawTitleScreen:
		lda #0
		sta byte_7FA
		sta IsPlayingExtendedWorlds
		sta IsPlayingLuigi
		jsr PatchToMarioOrLuigi
		jsr MoveTitlescreenMushroomCurrAddr_NEW
		ldy #$6F
		jsr InitializeMemory
		ldy #$1F
loc_C5CA:
		sta $7B0,y
		dey
		bpl loc_C5CA

PrepareInitializeArea:
		lda #$18
		sta DemoTimer
		jsr LoadAreaPointer
		jmp InitializeArea

RenderStars:
		;
		; Also add stars to title screen.
		; This is orignally done in PrepareDrawTitleScreen,
		; but reqiures volatile title screen and I can't
		; be arsed with that.
		;
		lda OperMode
		bne NotOnTitleScreen

		ldx VRAM_Buffer1_Offset
		lda #$20
		sta VRAM_Buffer1, x
		inx
		lda #$D0
		sta VRAM_Buffer1, x
		inx
		lda #$0C
		sta VRAM_Buffer1, x 
		inx
		lda #$C
		ldy #$0
		sta TMP_0
WriteMoreStars:
		lda #$26
		cpy WRAM_NumberOfStars
		bcs DontWriteAStar
		lda #$F1
DontWriteAStar:
		sta VRAM_Buffer1,x
		inx
		dec TMP_0
		bne StarRowNotFull
		lda #$20
		sta VRAM_Buffer1, x
		inx
		lda #$F0
		sta VRAM_Buffer1, x
		inx
		lda #$0C
		sta VRAM_Buffer1, x
		inx
StarRowNotFull:
		iny
		cpy #$18
		bne WriteMoreStars
		stx VRAM_Buffer1_Offset
NotOnTitleScreen:
		rts

PrimaryGameSetup:
		lda #1
		sta FetchNewGameTimerFlag
		sta PlayerSize
		lda #2
		sta NumberofLives
		jmp SecondaryGameSetup

MarioOrLuigiNames:
		.byte $16, $0A, $1B, $12, $18 ; Mario
		.byte $15, $1E, $12, $10, $12 ; Luigi
MarioOrLuigiColors:
		.byte $22, $16, $27, $18 ; Mario
		.byte $22, $30, $27, $19 ; Luigi
NameOffsets:
		.byte 4
AlternateInitScreen:
		.byte 9

PatchToMarioOrLuigi:
		ldy IsPlayingLuigi
		lda NameOffsets,y
		pha
		iny
		sty TMP_0
loc_C609:

		tay
		ldx #4
loc_C60C:

		lda MarioOrLuigiNames,y
		sta WRAM_PatchMarioName0,x
		sta WRAM_PatchMarioName1,x
		dey
		dex
		bpl loc_C60C
		pla
		sec
		sbc TMP_0
		tay
		ldx #3
loc_C620:

		lda MarioOrLuigiColors,y
		sta WRAM_PlayerColors,x
		dey
		dex
		bpl loc_C620
		rts
SWAPDATA_C62B:
		.byte $20
		.byte $84
		.byte 1
		.byte $44
		.byte $20
unk_C630:
		.byte $85
		.byte $57
		.byte $48
		.byte $20
		.byte $9C
		.byte 1
		.byte $49
		.byte $20
		.byte $A4
		.byte $C9
		.byte $46
		.byte $20
		.byte $A5
		.byte $57
		.byte $26
		.byte $20
		.byte $BC
		.byte $C9
AlternatePrintVictoryMessages:
		.byte $4A
		.byte $20
		.byte $A5
		.byte $A
		.byte $D0
		.byte $D1
		.byte $D8
		.byte $D8
		.byte $DE
		.byte $D1
		.byte $D0
		.byte $DA
		.byte $DE
		.byte $D1
		.byte $20
		.byte $C5
		.byte $17
		.byte $D2
		.byte $D3
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $D9
		.byte $DB
		.byte $DC
		.byte $DB
		.byte $DF
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $20
		.byte $E5
		.byte $17
		.byte $D4
		.byte $D5
unk_C66F:
		.byte $D4
		.byte $D9
		.byte $DB
		.byte $E2
		.byte $D4
		.byte $DA
		.byte $DB
		.byte $E0
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $26
		.byte $21
		.byte 5
AlternatePlayerEndWorld:
		.byte $57
		.byte $26
		.byte $21
		.byte 5
		.byte $A
		.byte $D6
		.byte $D7
		.byte $D6
		.byte $D7
		.byte $E1
		.byte $26
		.byte $D6
		.byte $DD
		.byte $E1
		.byte $E1
		.byte $21
		.byte $25
		.byte $17
		.byte $D0
		.byte $E8
		.byte $D1
		.byte $D0
		.byte $D1
		.byte $DE
		.byte $D1
		.byte $D8
		.byte $D0
		.byte $D1
		.byte $26
		.byte $DE
		.byte $D1
		.byte $DE
		.byte $D1
		.byte $D0
		.byte $D1
		.byte $D0
		.byte $D1
		.byte $26
		.byte $26
		.byte $D0
		.byte $D1
unk_C6AF:
		.byte $21
		.byte $45
		.byte $17
		.byte $DB
		.byte $42
		.byte $42
		.byte $DB
		.byte $42
		.byte $DB
		.byte $42
		.byte $DB
		.byte $DB
		.byte $42
		.byte $26
		.byte $DB
		.byte $42
		.byte $DB
		.byte $42
		.byte $DB
		.byte $42
		.byte $DB
		.byte $42
		.byte $26
		.byte $26
		.byte $DB
		.byte $42
		.byte $21
UNK_C6CA:
		.byte $65
		.byte $46
		.byte $DB
		.byte $21
		.byte $6B
		.byte $11
		.byte $DF
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $26
		.byte $DB
		.byte $DF
		.byte $DB
		.byte $DF
		.byte $DB
		.byte $DB
		.byte $E4
		.byte $E5
		.byte $26
		.byte $26
		.byte $EC
unk_C6E0:
		.byte $ED
		.byte $21
		.byte $85
		.byte $17
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $DE
		.byte $43
		.byte $DB
		.byte $E0
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $26
		.byte $DB
		.byte $E3
		.byte $DB
		.byte $E0
		.byte $DB
		.byte $DB
		.byte $E6
		.byte $E3
		.byte $26
		.byte $26
		.byte $EE
		.byte $EF
		.byte $21
		.byte $A5
		.byte $17
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $42
		.byte $DB
		.byte $DB
		.byte $DB
		.byte $D4
		.byte $D9
unk_C708:
		.byte $26
		.byte $DB
		.byte $D9
		.byte $DB
		.byte $DB
		.byte $D4
		.byte $D9
		.byte $D4
XXX_CopySomethingAndReset:
		.byte $D9
		.byte $E7
		.byte $26
		.byte $DE
		.byte $DA
		.byte $21
		.byte $C4
		.byte $19
		.byte $5F
		.byte $95
		.byte $95
		.byte $95
		.byte $95
		.byte $95
		.byte $95
		.byte $95
		.byte $95
		.byte $97
		.byte $98
		.byte $78
		.byte $95
		.byte $96
		.byte $95
XXX_SomethingOrOther:
		.byte $95
		.byte $97
		.byte $98
		.byte $97
		.byte $98
unk_C72C:
		.byte $95
		.byte $78
		.byte $95
		.byte $F0
		.byte $7A
		.byte $21
		.byte $EF
		.byte $E
		.byte $CF
		.byte 1
		.byte 9
		.byte 8
FdsWriteFile_SM2SAVE:
		.byte 6
		.byte $24
		.byte $17
		.byte $12
		.byte $17
		.byte $1D
		.byte $E
		.byte $17
		.byte $D
		.byte $18
		.byte $22
		.byte $4D
		.byte $A
		.byte $16
		.byte $A
		.byte $1B
		.byte $12
unk_C749:
		.byte $18
		.byte $24
		.byte $10
		.byte $A
		.byte $16
		.byte $E
		.byte $22
		.byte $8D
		.byte $A
		.byte $15
		.byte $1E
		.byte $12
		.byte $10
		.byte $12
		.byte $24
		.byte $10
		.byte $A
		.byte $16
		.byte $E
		.byte $22
		.byte $EB
		.byte 4
		.byte $1D
		.byte $18
		.byte $19
		.byte $28
		.byte $22
		.byte $F5
		.byte 1
		.byte 0
		.byte $23
		.byte $C9
		.byte $47
		.byte $55
		.byte $23
		.byte $D1
		.byte $47
		.byte $55
		.byte $23
		.byte $D9
		.byte $47
		.byte $55
		.byte $23
		.byte $CC
		.byte $43
		.byte $F5
		.byte $23
		.byte $D6
		.byte 1
unk_C77A:
		.byte $DD
		.byte $23
		.byte $DE
		.byte 1
		.byte $5D
		.byte $23
		.byte $E2
		.byte 4
		.byte $55
		.byte $AA
		.byte $AA
		.byte $AA
		.byte $23
		.byte $EA
		.byte 4
		.byte $95
		.byte $AA
		.byte $AA
		.byte $2A
		.byte 0
		.byte $FF
		.byte $FF
unk_C790:
		.byte $35
		.byte $9D
		.byte $55
		.byte $9B
		.byte $C9
		.byte $1B
		.byte $59
		.byte $9D
		.byte $45
		.byte $9B
		.byte $C5
		.byte $1B
		.byte $26
		.byte $80
		.byte $45
		.byte $1B
		.byte $B9
		.byte $1D
		.byte $F0
		.byte $15
		.byte $59
		.byte $9D
unk_C7A6:
		.byte $F
		.byte 8
		.byte $78
		.byte $2D
		.byte $96
		.byte $28
		.byte $90
		.byte $B5
		.byte $FF
byte_C7AF:
		.byte $74
		.byte $80
		.byte $F0
		.byte $38
		.byte $A0
		.byte $BB
		.byte $40
		.byte $BC
		.byte $8C
		.byte $1D
		.byte $C9
		.byte $9D
		.byte 5
		.byte $9B
		.byte $1C
		.byte $C
unk_C7BF:
		.byte $59
		.byte $1B
		.byte $B5
		.byte $1D
		.byte $2C
		.byte $8C
		.byte $40
		.byte $15
		.byte $7C
		.byte $1B
		.byte $DC
		.byte $1D
		.byte $6C
		.byte $8C
		.byte $BC
		.byte $C
		.byte $78
		.byte $AD
		.byte $A5
		.byte $28
		.byte $90
		.byte $B5
		.byte $FF
byte_C7D6:
		.byte $F
		.byte 4
		.byte $9C
		.byte $C
		.byte $F
		.byte 7
		.byte $C5
		.byte $1B
		.byte $65
		.byte $9D
		.byte $49
		.byte $9D
		.byte $5C
		.byte $8C
		.byte $78
		.byte $2D
		.byte $90
unk_C7E7:
		.byte $B5
		.byte $FF
unk_C7E9:
		.byte $49
		.byte $9F
		.byte $67
		.byte 3
		.byte $79
		.byte $9D
		.byte $A0
		.byte $3A
		.byte $57
		.byte $9F
		.byte $BB
		.byte $1D
		.byte $D5
		.byte $25
		.byte $F
		.byte 5
		.byte $18
		.byte $1D
		.byte $74
		.byte 0
		.byte $84
		.byte 0
		.byte $94
		.byte 0
		.byte $C6
		.byte $29
		.byte $49
		.byte $9D
		.byte $DB
		.byte 5
		.byte $F
		.byte 8
		.byte 5
unk_C80A:
		.byte $9B
		.byte 9
		.byte $1D
		.byte $B0
		.byte $38
		.byte $80
		.byte $95
		.byte $C0
		.byte $3C
		.byte $EC
		.byte $A8
		.byte $CC
		.byte $8C
		.byte $4A
		.byte $9B
		.byte $78
		.byte $2D
		.byte $90
		.byte $B5
		.byte $FF
unk_C81E:
		.byte 7
		.byte $8E
		.byte $47
		.byte 3
		.byte $F
		.byte 3
		.byte $10
		.byte $38
		.byte $1B
		.byte $80
		.byte $53
		.byte 6
		.byte $77
		.byte $E
		.byte $83
		.byte $83
		.byte $A0
		.byte $3D
		.byte $90
unk_C831:
		.byte $3B
byte_C832:
		.byte $90
		.byte $B7
		.byte $60
		.byte $BC
		.byte $B7
		.byte $E
		.byte $EE
		.byte $42
		.byte 0
byte_C83B:
		.byte $F7
		.byte $80
		.byte $6B
		.byte $83
		.byte $1B
		.byte $83
		.byte $AB
		.byte 6
		.byte $FF
byte_C844:
		.byte $96
		.byte $A4
		.byte $F9
		.byte $24
		.byte $D3
		.byte $83
		.byte $3A
		.byte $83
		.byte $5A
		.byte 3
		.byte $95
		.byte 7
		.byte $F4
		.byte $F
		.byte $69
		.byte $A8
		.byte $33
		.byte $87
		.byte $86
		.byte $24
byte_C858:
		.byte $C9
		.byte $24
		.byte $4B
		.byte $83
byte_C85C:
		.byte $67
		.byte $83
		.byte $17
		.byte $83
		.byte $56
		.byte $28
		.byte $95
		.byte $24
		.byte $A
		.byte $A4
		.byte $FF
byte_C867:
		.byte $F
		.byte 2
		.byte $47
		.byte $E
		.byte $87
		.byte $E
		.byte $C7
		.byte $E
		.byte $F7
		.byte $E
		.byte $27
		.byte $8E
		.byte $EE
		.byte $42
		.byte $25
SWAPDATA_C876:
		.byte $F
		.byte 6
		.byte $AC
		.byte $28
		.byte $8C
		.byte $A8
		.byte $4E
		.byte $B3
		.byte $20
SWAPDATA_C87F:
		.byte $8B
		.byte $8E
		.byte $F7
		.byte $90
		.byte $36
		.byte $90
		.byte $E5
		.byte $8E
byte_C887:
		.byte $32
		.byte $8E
		.byte $C2
		.byte 6
		.byte $D2
		.byte 6
		.byte $E2
		.byte 6
		.byte $FF
unk_C890:
		.byte $15
		.byte $8E
		.byte $9B
SWAPDATA_C893:
		.byte 6
		.byte $E0
		.byte $37
		.byte $80
		.byte $BC
		.byte $F
		.byte 4
		.byte $2B
		.byte $3B
		.byte $AB
		.byte $E
		.byte $EB
		.byte $E
		.byte $F
		.byte 6
		.byte $F0
		.byte $37
		.byte $4B
		.byte $8E
unk_C8A6:
		.byte $6B
		.byte $80
		.byte $BB
		.byte $3C
		.byte $4B
SWAPDATA_C8AB:
		.byte $BB
		.byte $EE
		.byte $42
		.byte $20
		.byte $1B
		.byte $BC
		.byte $CB
		.byte 0
		.byte $AB
unk_C8B4:
		.byte $83
		.byte $EB
		.byte $BB
		.byte $F
		.byte $E
		.byte $1B
		.byte 3
		.byte $9B
		.byte $37
		.byte $D4
		.byte $E
		.byte $A3
		.byte $86
SWAPDATA_C8C1:
		.byte $B3
		.byte 6
		.byte $C3
		.byte 6
		.byte $FF
unk_C8C6:
		.byte $C0
		.byte $BE
		.byte $F
unk_C8C9:
		.byte 3
		.byte $38
		.byte $E
		.byte $15
		.byte $8F
		.byte $AA
		.byte $83
		.byte $F8
		.byte 7
		.byte $F
		.byte 7
		.byte $96
		.byte $10
		.byte $F
SWAPDATA_C8D7:
		.byte 9
		.byte $48
		.byte $10
		.byte $BA
		.byte 3
		.byte $FF
unk_C8DD:
		.byte $87
		.byte $85
		.byte $A3
		.byte 5
		.byte $DB
		.byte $83
		.byte $FB
		.byte 3
		.byte $93
		.byte $8F
		.byte $BB
		.byte 3
		.byte $CE
		.byte $42
SWAPDATA_C8EB:
		.byte $42
		.byte $9B
		.byte $83
		.byte $AE
		.byte $B3
		.byte $40
		.byte $DB
		.byte 0
		.byte $F4
		.byte $F
		.byte $33
		.byte $8F
		.byte $74
		.byte $F
		.byte $10
		.byte $BC
		.byte $F5
SWAPDATA_C8FC:
		.byte $F
		.byte $2E
		.byte $C2
		.byte $45
		.byte $B7
		.byte 3
		.byte $F7
		.byte 3
		.byte $C8
		.byte $90
		.byte $FF
unk_C907:
		.byte $80
		.byte $BE
		.byte $83
		.byte 3
		.byte $92
		.byte $10
		.byte $4B
		.byte $80
		.byte $B0
		.byte $3C
		.byte 7
		.byte $80
SWAPDATA_C913:
		.byte $B7
		.byte $24
		.byte $C
		.byte $A4
		.byte $96
		.byte $A9
		.byte $1B
		.byte $83
		.byte $7B
		.byte $24
		.byte $B7
		.byte $24
		.byte $97
		.byte $83
		.byte $E2
		.byte $F
		.byte $A9
		.byte $A9
		.byte $38
		.byte $A9
		.byte $F
		.byte $B
		.byte $74
		.byte $8F
SWAPDATA_C92B:
		.byte $FF
unk_C92C:
		.byte $E2
		.byte $91
		.byte $F
		.byte 3
		.byte $42
		.byte $11
		.byte $F
		.byte 6
		.byte $72
		.byte $11
		.byte $F
		.byte 8
		.byte $EE
		.byte 2
		.byte $60
		.byte 2
		.byte $91
		.byte $EE
		.byte $B3
		.byte $60
		.byte $D3
		.byte $86
		.byte $FF
SWAPDATA_C943:
		.byte $F
		.byte 2
		.byte $9B
		.byte 2
		.byte $AB
		.byte 2
		.byte $F
		.byte 4
		.byte $13
		.byte 3
		.byte $92
		.byte $11
		.byte $60
		.byte $B7
		.byte 0
		.byte $BC
		.byte 0
		.byte $BB
		.byte $B
		.byte $83
		.byte $CB
		.byte 3
		.byte $7B
		.byte $85
		.byte $9E
SWAPDATA_C95C:
		.byte $C2
		.byte $60
		.byte $E6
		.byte 5
		.byte $F
		.byte $C
		.byte $62
		.byte $10
		.byte $FF
unk_C965:
		.byte $E6
		.byte $A9
		.byte $57
		.byte $A8
		.byte $B5
		.byte $24
		.byte $19
		.byte $A4
		.byte $76
		.byte $28
		.byte $A2
		.byte $F
		.byte $95
		.byte $8F
		.byte $9D
		.byte $A8
		.byte $F
		.byte 7
		.byte 9
		.byte $29
		.byte $55
		.byte $24
		.byte $8B
		.byte $17
SWAPDATA_C97D:
		.byte $A9
		.byte $24
		.byte $DB
		.byte $83
		.byte 4
		.byte $A9
		.byte $24
		.byte $8F
		.byte $65
		.byte $F
		.byte $FF
unk_C988:
		.byte $A
		.byte $AA
		.byte $1E
		.byte $22
		.byte $29
		.byte $1E
		.byte $25
		.byte $49
		.byte $2E
		.byte $27
		.byte $66
		.byte $FF
unk_C994:
		.byte $A
		.byte $8E
unk_C996:
		.byte $DE
		.byte $B4
		.byte 0
		.byte $E0
		.byte $37
		.byte $5B
		.byte $82
		.byte $2B
		.byte $A9
		.byte $AA
		.byte $29
		.byte $29
		.byte $A9
		.byte $A8
		.byte $29
		.byte $F
		.byte 8
		.byte $F0
		.byte $3C
		.byte $79
		.byte $A9
		.byte $C5
		.byte $26
		.byte $CD
		.byte $26
		.byte $EE
		.byte $3B
		.byte 1
		.byte $67
		.byte $B4
		.byte $F
		.byte $C
		.byte $2E
		.byte $C1
		.byte 0
		.byte $FF
unk_C9BA:
		.byte 9
		.byte $A9
		.byte $19
		.byte $A9
		.byte $DE
		.byte $42
SWAPDATA_C9C0:
		.byte 2
		.byte $7B
		.byte $83
		.byte $FF
unk_C9C4:
		.byte $1E
		.byte $A0
		.byte $A
		.byte $1E
		.byte $23
		.byte $2B
		.byte $1E
		.byte $28
		.byte $6B
		.byte $F
		.byte 3
		.byte $1E
		.byte $40
		.byte 8
		.byte $1E
		.byte $25
		.byte $4E
		.byte $F
		.byte 6
		.byte $1E
		.byte $22
		.byte $25
		.byte $1E
		.byte $25
		.byte $45
		.byte $FF
unk_C9DE:
		.byte $F
		.byte 1
		.byte $2A
		.byte 7
		.byte $2E
		.byte $3B
		.byte $41
		.byte $E9
		.byte 7
		.byte $F
		.byte 3
		.byte $6B
		.byte 7
		.byte $F9
		.byte 7
		.byte $B8
		.byte $80
		.byte $2A
		.byte $87
		.byte $4A
		.byte $87
		.byte $B3
		.byte $F
		.byte $84
		.byte $87
		.byte $47
		.byte $83
		.byte $87
		.byte 7
		.byte $A
		.byte $87
		.byte $42
		.byte $87
		.byte $1B
		.byte $87
		.byte $6B
		.byte 3
		.byte $FF
unk_CA04:
		.byte $1E
		.byte $A7
		.byte $6A
		.byte $5B
		.byte $82
		.byte $74
		.byte 7
		.byte $D8
		.byte 7
		.byte $E8
		.byte 2
		.byte $F
		.byte 4
		.byte $26
		.byte 7
		.byte $FF
unk_CA14:
		.byte $9B
		.byte 7
		.byte 5
		.byte $32
		.byte 6
		.byte $33
		.byte 7
		.byte $34
		.byte $33
		.byte $8E
		.byte $4E
		.byte $A
		.byte $7E
		.byte 6
		.byte $9E
		.byte $A
		.byte $CE
unk_CA25:
		.byte 6
		.byte $E3
		.byte 0
		.byte $EE
		.byte $A
		.byte $1E
		.byte $87
		.byte $53
		.byte $E
		.byte $8E
		.byte 2
		.byte $9C
		.byte 0
		.byte $C7
		.byte $E
		.byte $D7
		.byte $37
		.byte $57
		.byte $8E
		.byte $6C
		.byte 5
		.byte $DA
		.byte $60
		.byte $E9
		.byte $61
		.byte $F8
		.byte $62
		.byte $FE
		.byte $B
		.byte $43
		.byte $8E
		.byte $C3
		.byte $E
		.byte $43
		.byte $8E
		.byte $B7
		.byte $E
		.byte $EE
		.byte 9
		.byte $FE
		.byte $A
		.byte $3E
		.byte $86
		.byte $57
		.byte $E
		.byte $6E
		.byte $A
		.byte $7E
		.byte 6
		.byte $AE
		.byte $A
		.byte $BE
		.byte 6
		.byte $FE
		.byte 7
		.byte $15
		.byte $E2
		.byte $55
		.byte $62
		.byte $95
		.byte $62
		.byte $FE
		.byte $A
		.byte $D
		.byte $C4
		.byte $CD
		.byte $43
		.byte $CE
		.byte 9
		.byte $DE
		.byte $B
		.byte $DD
		.byte $42
		.byte $FE
		.byte 2
		.byte $5D
		.byte $C7
		.byte $FD
unk_CA73:
		.byte $9B
		.byte 7
		.byte 5
		.byte $32
		.byte 6
		.byte $33
		.byte 7
		.byte $34
		.byte 3
		.byte $E2
		.byte $E
		.byte 6
		.byte $1E
unk_CA80:
		.byte $C
		.byte $7E
		.byte $A
		.byte $8E
		.byte 5
		.byte $8E
		.byte $82
byte_CA87:
		.byte $8A
		.byte $8E
		.byte $8E
unk_CA8A:
		.byte $A
		.byte $EE
		.byte 2
		.byte $A
		.byte $E0
		.byte $19
unk_CA90:
		.byte $61
		.byte $23
		.byte 6
		.byte $28
unk_CA94:
		.byte $62
		.byte $2E
		.byte $B
		.byte $7E
		.byte $A
		.byte $81
		.byte $62
		.byte $87
		.byte $30
		.byte $8E
		.byte 4
		.byte $A7
		.byte $31
		.byte $C7
		.byte $E
		.byte $D7
		.byte $33
		.byte $FE
		.byte 3
		.byte 3
		.byte $8E
		.byte $E
		.byte $A
		.byte $11
		.byte $62
		.byte $1E
		.byte 4
		.byte $27
		.byte $32
		.byte $4E
		.byte $A
		.byte $51
		.byte $62
unk_CAB5:
		.byte $57
		.byte $E
		.byte $5E
unk_CAB8:
		.byte 4
		.byte $67
unk_CABA:
		.byte $34
		.byte $9E
		.byte $A
		.byte $A1
		.byte $62
		.byte $AE
		.byte 3
		.byte $B3
		.byte $E
		.byte $BE
		.byte $B
		.byte $EE
		.byte 9
		.byte $FE
		.byte $A
		.byte $2E
		.byte $82
unk_CACB:
		.byte $7A
		.byte $E
		.byte $7E
		.byte $A
		.byte $97
		.byte $31
		.byte $BE
		.byte 4
		.byte $DA
		.byte $E
		.byte $EE
		.byte $A
		.byte $F1
		.byte $62
		.byte $FE
		.byte 2
		.byte $3E
		.byte $8A
		.byte $7E
		.byte 6
		.byte $AE
		.byte $A
		.byte $CE
		.byte 6
		.byte $FE
		.byte $A
		.byte $D
		.byte $C4
		.byte $11
		.byte $53
		.byte $21
		.byte $52
		.byte $24
		.byte $B
		.byte $51
		.byte $52
		.byte $61
		.byte $52
		.byte $CD
		.byte $43
		.byte $CE
		.byte 9
		.byte $DD
		.byte $42
		.byte $DE
		.byte $B
		.byte $FE
		.byte 2
		.byte $5D
		.byte $C7
		.byte $FD
unk_CAFE:
		.byte $5B
		.byte 9
		.byte 5
		.byte $34
		.byte 6
		.byte $35
		.byte $6E
		.byte 6
		.byte $7E
		.byte $A
		.byte $AE
		.byte 2
		.byte $FE
		.byte 2
		.byte $D
		.byte 1
		.byte $E
		.byte $E
		.byte $2E
		.byte $A
		.byte $6E
		.byte 9
		.byte $BE
		.byte $A
		.byte $ED
		.byte $4B
		.byte $E4
		.byte $60
		.byte $EE
		.byte $D
		.byte $5E
		.byte $82
		.byte $78
		.byte $72
		.byte $A4
		.byte $3D
		.byte $A5
		.byte $3E
		.byte $A6
		.byte $3F
		.byte $A3
		.byte $BE
		.byte $A6
		.byte $3E
		.byte $A9
		.byte $32
		.byte $E9
		.byte $3A
unk_CB2E:
		.byte $9C
		.byte $80
		.byte $A3
		.byte $33
		.byte $A6
		.byte $33
		.byte $A9
		.byte $33
		.byte $E5
		.byte 6
		.byte $ED
		.byte $4B
		.byte $F3
		.byte $30
		.byte $F6
		.byte $30
		.byte $F9
unk_CB3F:
		.byte $30
		.byte $FE
		.byte 2
		.byte $D
		.byte 5
		.byte $3C
		.byte 1
		.byte $57
		.byte $73
		.byte $7C
		.byte 2
		.byte $93
		.byte $30
		.byte $A7
		.byte $73
unk_CB4E:
		.byte $B3
unk_CB4F:
		.byte $37
unk_CB50:
		.byte $CC
		.byte 1
		.byte 7
		.byte $83
		.byte $17
		.byte 3
		.byte $27
		.byte 3
		.byte $37
		.byte 3
		.byte $64
		.byte $3B
		.byte $77
		.byte $3A
		.byte $C
		.byte $80
		.byte $2E
		.byte $E
		.byte $9E
		.byte 2
		.byte $A5
		.byte $62
		.byte $B6
		.byte $61
		.byte $CC
		.byte 2
		.byte $C3
		.byte $33
		.byte $ED
		.byte $4B
		.byte 3
		.byte $B7
		.byte 7
		.byte $37
		.byte $83
		.byte $37
		.byte $87
		.byte $37
		.byte $DD
		.byte $4B
		.byte 3
		.byte $B5
		.byte 7
		.byte $35
		.byte $5E
		.byte $A
		.byte $8E
		.byte 2
		.byte $AE
		.byte $A
		.byte $DE
		.byte 6
		.byte $FE
		.byte $A
		.byte $D
		.byte $C4
		.byte $CD
		.byte $43
		.byte $CE
		.byte 9
		.byte $DD
		.byte $42
		.byte $DE
byte_CB8F:
		.byte $B
		.byte $FE
byte_CB91:
		.byte 2
		.byte $5D
		.byte $C7
		.byte $FD
unk_CB95:
		.byte $9B
		.byte 7
unk_CB97:
		.byte 5
		.byte $32
		.byte 6
		.byte $33
		.byte 7
		.byte $34
		.byte $4E
		.byte 3
		.byte $5C
		.byte 2
		.byte $C
		.byte $F1
		.byte $27
		.byte 0
		.byte $3C
		.byte $74
		.byte $47
		.byte $E
		.byte $FC
		.byte 0
		.byte $FE
		.byte $B
		.byte $77
		.byte $8E
		.byte $EE
		.byte 9
		.byte $FE
		.byte $A
		.byte $45
		.byte $B2
		.byte $55
		.byte $E
		.byte $99
		.byte $32
		.byte $B9
		.byte $E
		.byte $FE
		.byte 2
		.byte $E
		.byte $85
		.byte $FE
		.byte 2
		.byte $16
		.byte $8E
		.byte $2E
		.byte $C
		.byte $AE
		.byte $A
		.byte $EE
		.byte 5
		.byte $1E
		.byte $82
		.byte $47
		.byte $E
		.byte 7
		.byte $BD
		.byte $C4
		.byte $72
		.byte $DE
		.byte $A
		.byte $FE
		.byte 2
		.byte 3
		.byte $8E
		.byte 7
		.byte $E
		.byte $13
unk_CBDA:
		.byte $3C
		.byte $17
		.byte $3D
		.byte $E3
		.byte 3
		.byte $EE
		.byte $A
		.byte $F3
		.byte 6
		.byte $F7
		.byte 3
		.byte $FE
		.byte $E
		.byte $FE
		.byte $8A
		.byte $38
		.byte $E4
		.byte $4A
		.byte $72
		.byte $68
		.byte $64
		.byte $37
		.byte $B0
		.byte $98
		.byte $64
		.byte $A8
		.byte $64
		.byte $E8
		.byte $64
		.byte $F8
		.byte $64
		.byte $D
		.byte $C4
		.byte $71
		.byte $64
		.byte $CD
		.byte $43
		.byte $CE
		.byte 9
		.byte $DD
		.byte $42
		.byte $DE
		.byte $B
		.byte $FE
		.byte 2
		.byte $5D
		.byte $C7
		.byte $FD
unk_CC0A:
		.byte $50
		.byte $31
		.byte $F
		.byte $26
		.byte $13
		.byte $E4
		.byte $23
		.byte $24
		.byte $27
		.byte $23
		.byte $37
		.byte 7
		.byte $66
		.byte $61
		.byte $AC
		.byte $74
		.byte $C7
		.byte 1
		.byte $B
		.byte $F1
		.byte $77
		.byte $73
		.byte $B6
		.byte 4
		.byte $DB
		.byte $71
		.byte $5C
		.byte $82
		.byte $83
		.byte $2D
		.byte $A2
		.byte $47
		.byte $A7
		.byte $A
		.byte $B7
		.byte $29
		.byte $4F
		.byte $B3
unk_CC30:
		.byte $87
		.byte $B
		.byte $93
		.byte $23
		.byte $CC
		.byte 6
		.byte $E3
		.byte $2C
		.byte $3A
		.byte $E0
		.byte $7C
		.byte $71
		.byte $97
		.byte 1
		.byte $AC
		.byte $73
		.byte $E6
		.byte $61
		.byte $E
		.byte $B1
		.byte $B7
		.byte $F3
		.byte $DC
		.byte 2
		.byte $D3
		.byte $25
		.byte 7
		.byte $FB
		.byte $2C
		.byte 1
		.byte $E7
		.byte $73
		.byte $2C
		.byte $F2
		.byte $34
		.byte $72
		.byte $57
		.byte 0
		.byte $7C
		.byte 2
		.byte $39
		.byte $F1
		.byte $BF
		.byte $37
		.byte $33
		.byte $E7
		.byte $CD
		.byte $41
		.byte $F
		.byte $A6
		.byte $ED
		.byte $47
		.byte $FD
byte_CC65:
		.byte $50
		.byte $11
		.byte $F
		.byte $26, $FE,	$10, $47, $92, $56, $40, $AC, $16, $AF
		.byte $12, $F, $95, $73, $16, $82, $44,	$EC, $48, $BC
		.byte $C2, $1C,	$B1, $B3, $16, $C2, $44, $86, $C0, $9C
		.byte $14, $9F,	$12, $A6, $40, $DF, $15, $B, $96
byte_CC8F:
		.byte $43
		.byte $12, $97,	$31, $D3, $12, 3, $92, $27, $14, $63, 0
		.byte $C7, $15,	$D6, $43, $AC, $97, $AF, $11, $1F, $96
		.byte $64, $13,	$E3
		.byte $12
		.byte $2E
		.byte $91
		.byte $9D
		.byte $41
		.byte $AE
		.byte $42
		.byte $DF
		.byte $20
		.byte $CD
		.byte $C7
		.byte $FD
byte_CCB4:
		.byte $52
		.byte $21
		.byte $F
byte_CCB7:
		.byte $20
		.byte $6E
		.byte $64
		.byte $4F
		.byte $B2
		.byte $7C
		.byte $5F
		.byte $7C
		.byte $3F
		.byte $7C
		.byte $D8
		.byte $7C
		.byte $38
		.byte $83
		.byte 2
		.byte $A3
		.byte 0
		.byte $C3
		.byte 2
		.byte $F7
		.byte $16
		.byte $5C
		.byte $D6
		.byte $CF
		.byte $35
		.byte $D3
		.byte $20
		.byte $E3
		.byte $A
		.byte $F3
		.byte $20
		.byte $25
		.byte $B5
		.byte $2C
		.byte $53
		.byte $6A
		.byte $7A
		.byte $8C
		.byte $54
		.byte $DA
		.byte $72
		.byte $FC
		.byte $50
		.byte $C
		.byte $D2
		.byte $39
		.byte $73
		.byte $5C
		.byte $54
		.byte $AA
		.byte $72
		.byte $CC
		.byte $53
		.byte $F7
		.byte $16
		.byte $33
		.byte $83
		.byte $40
		.byte 6
		.byte $5C
		.byte $5B
		.byte 9
		.byte $93
		.byte $27
		.byte $F
		.byte $3C
		.byte $5C
		.byte $A
		.byte $B0
		.byte $63
		.byte $27
		.byte $78
		.byte $72
		.byte $93
		.byte 9
		.byte $97
		.byte 3
		.byte $A7
		.byte 3
		.byte $B7
		.byte $22
		.byte $47
		.byte $81
		.byte $5C
		.byte $72
		.byte $2A
		.byte $B0
unk_CD0E:
		.byte $28
		.byte $F
		.byte $3C
		.byte $5F
		.byte $58
		.byte $31
		.byte $B8
		.byte $31
		.byte $28
		.byte $B1
		.byte $3C
		.byte $5B
		.byte $98
		.byte $31
		.byte $FA
		.byte $30
		.byte 3
		.byte $B2
		.byte $20
		.byte 4
		.byte $7F
		.byte $B7
		.byte $F3
		.byte $67
		.byte $8D
		.byte $C1
		.byte $BF
		.byte $26
		.byte $AD
		.byte $C7
		.byte $FD
byte_CD2D:
		.byte $54
		.byte $11
		.byte $F
		.byte $26
		.byte $38
		.byte $F2
		.byte $AB
		.byte $71
		.byte $B
		.byte $F1
		.byte $96
		.byte $42
		.byte $CE
		.byte $10
		.byte $1E
		.byte $91
		.byte $29
		.byte $61
		.byte $3A
		.byte $60
		.byte $4E
		.byte $10
		.byte $78
		.byte $74
		.byte $8E
		.byte $11
		.byte 6
		.byte $C3
		.byte $1A
		.byte $E0
		.byte $1E
		.byte $10
		.byte $5E
		.byte $11
		.byte $67
		.byte $63
		.byte $77
		.byte $63
		.byte $88
		.byte $62
		.byte $99
		.byte $61
		.byte $AA
		.byte $60
		.byte $BE
		.byte $10
		.byte $A
		.byte $F2
		.byte $15
		.byte $45
		.byte $7E
		.byte $11
		.byte $7A
		.byte $31
		.byte $9A
		.byte $E0
		.byte $AC
		.byte 2
		.byte $D9
		.byte $61
		.byte $D4
		.byte $A
		.byte $EC
		.byte 1
		.byte $D6
		.byte $C2
		.byte $84
		.byte $C3
		.byte $98
		.byte $FA
		.byte $D3
		.byte 7
		.byte $D7
		.byte $B
		.byte $E9
		.byte $61
		.byte $EE
		.byte $10
byte_CD7B:
		.byte $2E
		.byte $91
		.byte $39
		.byte $71
		.byte $93
		.byte 3
		.byte $A6
		.byte 3
		.byte $BE
		.byte $10
		.byte $E1
		.byte $71
		.byte $E3
		.byte $31
		.byte $5E
		.byte $91
		.byte $69
		.byte $61
		.byte $E6
		.byte $41
		.byte $28
		.byte $E2
		.byte $99
		.byte $71
		.byte $AE
		.byte $10
		.byte $CE
		.byte $11
		.byte $BE
		.byte $90
		.byte $D6
		.byte $32
		.byte $3E
		.byte $91
		.byte $5F
		.byte $37
		.byte $66
		.byte $60
		.byte $D3
		.byte $67
		.byte $6D
		.byte $C1
		.byte $AF
		.byte $26
		.byte $9D
		.byte $C7
		.byte $FD
byte_CDAA:
		.byte $54
		.byte $11
		.byte $F
		.byte $26
		.byte $AF
		.byte $32
		.byte $D8
		.byte $62
		.byte $E8
		.byte $62
		.byte $F8
		.byte $62
		.byte $FE
		.byte $10
		.byte $C
		.byte $BE
		.byte $F8
		.byte $64
		.byte $D
		.byte $C8
		.byte $2C
		.byte $43
		.byte $98
		.byte $64
		.byte $AC
		.byte $39
		.byte $48
		.byte $E4
		.byte $6A
		.byte $62
		.byte $7C
		.byte $47
		.byte $FA
		.byte $62
		.byte $3C
		.byte $B7
		.byte $EA
		.byte $62
		.byte $FC
		.byte $4D
		.byte $F6
		.byte 2
		.byte 3
		.byte $80
		.byte 6
		.byte 2
		.byte $13
		.byte 2
		.byte $DA
		.byte $62
		.byte $D
		.byte $C8
		.byte $B
		.byte $17
		.byte $97
		.byte $16
		.byte $2C
		.byte $B1
		.byte $33
		.byte $43
		.byte $6C
		.byte $31
		.byte $AC
		.byte $31
		.byte $17
		.byte $93
		.byte $73
		.byte $12
		.byte $CC
		.byte $31
		.byte $1A
		.byte $E2
		.byte $2C
		.byte $4B
		.byte $67
		.byte $48
		.byte $EA
		.byte $62
		.byte $D
		.byte $CA
		.byte $17
		.byte $12
		.byte $53
		.byte $12
byte_CDFE:
		.byte $BE
		.byte $11
		.byte $1D
		.byte $C1
		.byte $3E
		.byte $42
		.byte $6F
		.byte $20
		.byte $4D
		.byte $C7
		.byte $FD
byte_CE09:
		.byte $52
		.byte $B1
		.byte $F
		.byte $20
		.byte $6E
		.byte $75
		.byte $53
		.byte $AA
		.byte $57
		.byte $25
		.byte $B7
		.byte $A
		.byte $C7
		.byte $23
		.byte $C
		.byte $83
		.byte $5C
		.byte $72
		.byte $87
		.byte 1
		.byte $C3
		.byte 0
		.byte $C7
		.byte $20
		.byte $DC
		.byte $65
		.byte $C
		.byte $87
		.byte $C3
byte_CE26:
		.byte $22
		.byte $F3
		.byte 3
		.byte 3
		.byte $A2
		.byte $27
		.byte $7B
		.byte $33
		.byte 3
		.byte $43
		.byte $23
		.byte $52
		.byte $42
		.byte $9C
		.byte 6
		.byte $A7
		.byte $20
		.byte $C3
		.byte $23
		.byte 3
		.byte $A2
		.byte $C
		.byte 2
		.byte $33
		.byte 9
		.byte $39
		.byte $71
		.byte $43
		.byte $23
		.byte $77
		.byte 6
		.byte $83
		.byte $67
		.byte $A7
		.byte $73
		.byte $5C
		.byte $82
		.byte $C9
		.byte $11
		.byte 7
		.byte $80
		.byte $1C
		.byte $71
		.byte $98
		.byte $11
		.byte $9A
		.byte $10
		.byte $F3
		.byte 4
		.byte $16
		.byte $F4
		.byte $3C
		.byte 2
unk_CE5B:
		.byte $68
		.byte $7A
		.byte $8C
		.byte 1
		.byte $A7
		.byte $73
		.byte $E7
		.byte $73
		.byte $AC
		.byte $83
		.byte 9
		.byte $8F
		.byte $1C
		.byte 3
		.byte $9F
		.byte $37
		.byte $13
		.byte $E7
		.byte $7C
		.byte 2
		.byte $AD
		.byte $41
		.byte $EF
		.byte $26
		.byte $D
		.byte $E
		.byte $39
		.byte $71
		.byte $7F
		.byte $37
		.byte $F2
		.byte $68
		.byte 2
		.byte $E8
		.byte $12
		.byte $3A
		.byte $1C
		.byte 0
		.byte $68
		.byte $7A
		.byte $DE
		.byte $3F
		.byte $6D
		.byte $C5
		.byte $FD
byte_CE88:
		.byte $55
		.byte $10
		.byte $B
		.byte $1F
		.byte $F, $26, $D6, $12, 7, $9F, $33, $1A, $FB,	$1F, $F7
		.byte $94, $53,	$94, $71, $71, $CC, $15, $CF, $13, $1F
		.byte $98, $63,	$12, $9B, $13, $A9, $71, $FB, $17, 9, $F1
		.byte $13, $13,	$21, $42, $59, $F, $EB,	$13, $33, $93
		.byte $40, 6, $8C, $14,	$8F, $17, $93, $40, $CF, $13, $B
		.byte $94, $57,	$15, 7,	$93, $19, $F3, $C6, $43, $C7, $13
		.byte $D3, 3, $E3, 3, $33, $B0,	$4A, $72, $55, $46
byte_CED6:
		.byte $73
		.byte $31
		.byte $A8
		.byte $74, $E3,	$12, $8E, $91, $AD, $41, $CE, $42, $EF
		.byte $20, $DD,	$C7, $FD
byte_CEE7:
		.byte $52
		.byte $21
		.byte $F
		.byte $20
		.byte $6E
		.byte $63
		.byte $A9
		.byte $F1
		.byte $FB
		.byte $71
		.byte $22
		.byte $83
		.byte $37
		.byte $B
		.byte $36
		.byte $50
		.byte $39
		.byte $51
		.byte $B8
		.byte $62
		.byte $57
		.byte $F3
		.byte $E8
		.byte 2
		.byte $F8
		.byte 2
		.byte 8
		.byte $82
		.byte $18
		.byte 2
		.byte $2D
		.byte $4A
		.byte $28
		.byte 2
		.byte $38
		.byte 2
		.byte $48
		.byte 0
		.byte $A8
		.byte $F
		.byte $AA
		.byte $30
		.byte $BC
		.byte $5A
		.byte $6A
		.byte $B0
		.byte $4F
		.byte $B6
		.byte $B7
		.byte 4
		.byte $9A
		.byte $B0
		.byte $AC
		.byte $71
		.byte $C7
		.byte 1
		.byte $E6
		.byte $74
		.byte $D
		.byte 9
		.byte $46
		.byte 2
		.byte $56
		.byte 0
		.byte $6C
		.byte 1
		.byte $84
		.byte $79
		.byte $86
		.byte 2
		.byte $96
		.byte 2
		.byte $A4
		.byte $71
		.byte $A6
		.byte 2
		.byte $B6
		.byte 2
		.byte $C4
		.byte $71
		.byte $C6
		.byte 2
		.byte $D6
		.byte 2
		.byte $39
		.byte $F1
		.byte $6C
		.byte 0
		.byte $77
		.byte 2
		.byte $A3
		.byte 9
		.byte $AC
		.byte 0
		.byte $B8
		.byte $72
		.byte $DC
		.byte 1
		.byte 7
		.byte $F3
unk_CF4B:
		.byte $4C
		.byte 0
		.byte $6F
		.byte $37
		.byte $E3
		.byte 3
		.byte $E6
		.byte 3
		.byte $5D
		.byte $CA
		.byte $6C
		.byte 0
		.byte $7D
		.byte $41
		.byte $CF
		.byte $26
		.byte $9D
		.byte $C7
		.byte $FD
byte_CF5E:
		.byte $50
		.byte $A1
		.byte $F
		.byte $26
		.byte $17
		.byte $91
		.byte $19
		.byte $11
		.byte $48
		.byte 0
		.byte $68
		.byte $11
		.byte $6A
		.byte $10
		.byte $96
		.byte $14
		.byte $D8, $A, $E8, 2, $F8, 2, $DC, $81, $6C, $81, $89
		.byte $F, $9C, 0, $C3, $29, $F8, $62, $47, $A7,	$C6, $61
		.byte $D, 7, $56, $74, $B7, 0, $B9, $11, $CC, $76, $ED
		.byte $4A, $1C,	$80, $37, 1, $3A, $10, $DE, $20, $E9, $B
		.byte $EE, $21,	$C8, $BC, $9C, $F6, $BC, 0, $CB, $7A, $EB
		.byte $72, $C, $82, $39, $71, $B7, $63,	$CC, 3,	$E6, $60
		.byte $26, $E0,	$4A, $30, $53
byte_CFB5:
		.byte $31
byte_CFB6:
		.byte $5C
		.byte $58
		.byte $ED
		.byte $41
		.byte $2F
		.byte $A6
		.byte $1D
		.byte $C7
		.byte $FD
unk_CFBF:
		.byte $50
		.byte $11
		.byte $F
		.byte $26
		.byte $FE
		.byte $10
		.byte $8B
		.byte $93
		.byte $A9
		.byte $F
		.byte $14
		.byte $C1
		.byte $CC
		.byte $16
		.byte $CF
		.byte $11
		.byte $2F
		.byte $95
		.byte $B7
		.byte $14
		.byte $C7
		.byte $96
		.byte $D6
		.byte $44
		.byte $2B
		.byte $92
		.byte $39
		.byte $F
		.byte $72
		.byte $41
		.byte $A7
		.byte 0
		.byte $1B
		.byte $95
		.byte $97
		.byte $13
		.byte $6C
		.byte $95
		.byte $6F
		.byte $11
		.byte $A2
		.byte $40
		.byte $BF
		.byte $15
		.byte $C2
		.byte $40
		.byte $B
		.byte $9F
		.byte $53
		.byte $16
		.byte $62
		.byte $44
		.byte $72
		.byte $C2
		.byte $9B
		.byte $1D
		.byte $B7
		.byte $E0
		.byte $ED
		.byte $4A
		.byte 3
		.byte $E0
		.byte $8E
		.byte $11
		.byte $9D
		.byte $41
		.byte $BE
		.byte $42
		.byte $EF
		.byte $20
		.byte $CD
		.byte $C7
		.byte $FD
byte_D008:
		.byte 0
		.byte $C1
		.byte $4C
		.byte 0
		.byte 3
		.byte $CF
		.byte 0
		.byte $D7
		.byte $23
		.byte $4D
		.byte 7
		.byte $AF
		.byte $2A
		.byte $4C
		.byte 3
		.byte $CF
		.byte $3E
		.byte $80
unk_D01A:
		.byte $F3
unk_D01B:
		.byte $4A
		.byte $BB
		.byte $C2
		.byte $BD
		.byte $C7
		.byte $FD
unk_D021:
		.byte $48
		.byte $F
byte_D023:
		.byte $E
		.byte 1
		.byte $5E
		.byte 2
		.byte $A
		.byte $B0
		.byte $1C
		.byte $54
		.byte $6A
		.byte $30
		.byte $7F
		.byte $34
		.byte $C6
		.byte $64
		.byte $D6
		.byte $64
		.byte $E6
		.byte $64
		.byte $F6
		.byte $64
		.byte $FE
		.byte 0
		.byte $F0
		.byte 7
		.byte 0
		.byte $A1
		.byte $1E
		.byte 2
		.byte $47
		.byte $73
		.byte $7E
		.byte 4
		.byte $84
		.byte $52
		.byte $94
		.byte $50
		.byte $95
		.byte $B
		.byte $96
		.byte $50
		.byte $A4
		.byte $52
		.byte $AE
		.byte 5
		.byte $B8
		.byte $51
		.byte $C8
unk_D052:
		.byte $51
		.byte $CE
		.byte 1
		.byte $17
		.byte $F3
		.byte $45
		.byte 3
		.byte $52
		.byte 9
		.byte $62
		.byte $21
		.byte $6F
		.byte $34
		.byte $81
		.byte $21
		.byte $9E
		.byte 2
		.byte $B6
		.byte $64
		.byte $C6
		.byte $64
		.byte $C0
		.byte $C
		.byte $D6
		.byte $64
		.byte $D0
		.byte 7
		.byte $E6
		.byte $64
		.byte $E0
		.byte $C
		.byte $F0
		.byte 7
		.byte $FE
		.byte $A
		.byte $D
		.byte 6
		.byte $E
		.byte 1
		.byte $4E
		.byte 4
		.byte $67
		.byte $73
		.byte $8E
		.byte 2
		.byte $B7
		.byte $A
		.byte $BC
		.byte 3
		.byte $C4
		.byte $72
		.byte $C7
		.byte $22
		.byte 8
		.byte $F2
		.byte $2C
		.byte 2
		.byte $59
		.byte $71
		.byte $7C
		.byte 1
		.byte $96
		.byte $74
		.byte $BC
		.byte 1
		.byte $D8
		.byte $72
		.byte $FC
		.byte 1
		.byte $39
		.byte $F1
		.byte $4E
		.byte 1
		.byte $9E
		.byte 4
		.byte $A7
		.byte $52
		.byte $B7
		.byte $B
		.byte $B8
		.byte $51
		.byte $C7
		.byte $51
		.byte $D7
		.byte $50
		.byte $DE
		.byte 2
		.byte $3A
		.byte $E0
		.byte $3E
		.byte $A
		.byte $9E
		.byte 0
		.byte 8
		.byte $D4
		.byte $18
		.byte $54
		.byte $28
		.byte $54
		.byte $48
		.byte $54
		.byte $6E
		.byte 6
		.byte $9E
		.byte 1
		.byte $A8
		.byte $52
		.byte $AF
		.byte $47
		.byte $B8
		.byte $52
		.byte $C8
		.byte $52
		.byte $D8
		.byte $52
		.byte $DE
		.byte $F
		.byte $4D
		.byte $C7
		.byte $CE
		.byte 1
		.byte $DC
		.byte 1
		.byte $F9
		.byte $79
		.byte $1C
		.byte $82
		.byte $48
		.byte $72
		.byte $7F
		.byte $37
		.byte $F2
		.byte $68
		.byte 1
		.byte $E9
		.byte $11
		.byte $3A
		.byte $68
		.byte $7A
		.byte $DE
		.byte $F
		.byte $6D
		.byte $C5
		.byte $FD
unk_D0E2:
		.byte $B
		.byte $F
		.byte $E
		.byte 1
		.byte $9C
		.byte $71
		.byte $B7
		.byte 0
		.byte $BE
		.byte 0
		.byte $3E
		.byte $81
		.byte $47
		.byte $73
		.byte $5E
		.byte 0
		.byte $63
		.byte $42
		.byte $8E
		.byte 1
		.byte $A7
		.byte $73
		.byte $BE
		.byte 0
		.byte $7E
		.byte $81
		.byte $88
		.byte $72
		.byte $F0
		.byte $59
		.byte $FE
		.byte 0
		.byte 0
		.byte $D9
		.byte $E
		.byte 1
		.byte $39
		.byte $79
		.byte $A7
		.byte 3
		.byte $AE
		.byte 0
		.byte $B4
		.byte 3
		.byte $DE
		.byte $F
		.byte $D
		.byte 5
		.byte $E
		.byte 2
		.byte $68
		.byte $7A
		.byte $BE
		.byte 1
		.byte $DE
		.byte $F
		.byte $6D
		.byte $C5
		.byte $FD
unk_D11D:
		.byte 8
		.byte $8F
unk_D11F:
		.byte $E
		.byte 1
		.byte $17
		.byte 5
		.byte $2E
		.byte 2
		.byte $30
		.byte 7
		.byte $37
		.byte 3
		.byte $3A
		.byte $49
		.byte $44
		.byte 3
		.byte $58
		.byte $47
		.byte $DF
		.byte $4A
		.byte $6D
		.byte $C7
		.byte $E
		.byte $81
		.byte 0
		.byte $5A
		.byte $2E
		.byte 2
		.byte $87
		.byte $52
		.byte $97
		.byte $2F
		.byte $99
		.byte $4F
		.byte $A
		.byte $90
		.byte $93
		.byte $56
		.byte $A3
		.byte $B
		.byte $A7
		.byte $50
		.byte $B3
		.byte $55
		.byte $DF
		.byte $4A
		.byte $6D
		.byte $C7
		.byte $E
		.byte $81
		.byte 0
		.byte $5A
		.byte $2E
		.byte 0
		.byte $3E
		.byte 2
		.byte $41
		.byte $56
		.byte $57
		.byte $25
		.byte $56
		.byte $45
		.byte $68
		.byte $51
		.byte $7A
		.byte $43
		.byte $B7
unk_D160:
		.byte $B
		.byte $B8
		.byte $51
		.byte $DF
		.byte $4A
		.byte $6D
		.byte $C7
		.byte $FD
unk_D168:
		.byte $41
		.byte 1
		.byte 3
		.byte $B4
		.byte 4
		.byte $34
		.byte 5
		.byte $34
		.byte $5C
		.byte 2
		.byte $83
		.byte $37
		.byte $84
		.byte $37
		.byte $85
		.byte $37
		.byte 9
		.byte $C2
		.byte $C
		.byte 2
		.byte $1D
		.byte $49
		.byte $FA
		.byte $60
		.byte 9
		.byte $E1
		.byte $18
		.byte $62
		.byte $20
		.byte $63
		.byte $27
		.byte $63
		.byte $33
		.byte $37
		.byte $37
		.byte $63
		.byte $47
		.byte $63
		.byte $5C
		.byte 5
		.byte $79
		.byte $43
		.byte $FE
		.byte 6
		.byte $35
		.byte $D2
		.byte $46
		.byte $48
		.byte $91
		.byte $53
		.byte $D6
		.byte $51
		.byte $FE
		.byte 1
		.byte $C
		.byte $83
		.byte $6C
		.byte 4
		.byte $B4
		.byte $62
		.byte $C4
		.byte $62
		.byte $D4
		.byte $62
		.byte $E4
		.byte $62
		.byte $F4
		.byte $62
		.byte $18
		.byte $D2
		.byte $79
		.byte $51
		.byte $F4
		.byte $66
		.byte $FE
		.byte 2
		.byte $C
		.byte $8A
		.byte $1D
		.byte $49
		.byte $31
		.byte $55
		.byte $56
		.byte $41
		.byte $77
		.byte $41
		.byte $98
		.byte $41
		.byte $C5
		.byte $55
		.byte $FE
		.byte 1
		.byte 7
		.byte $E3
		.byte $17
		.byte $63
		.byte $27
		.byte $63
		.byte $37
		.byte $63
		.byte $47
		.byte $63
		.byte $57
		.byte $63
		.byte $67
		.byte $63
		.byte $78
		.byte $62
		.byte $89
		.byte $61
		.byte $9A
		.byte $60
		.byte $BC
		.byte 7
		.byte $CA
		.byte $42
		.byte $3A
		.byte $B3
		.byte $46
		.byte $53
		.byte $63
		.byte $34
		.byte $66
		.byte $44
		.byte $7C
		.byte 1
		.byte $9A
		.byte $33
		.byte $B7
		.byte $52
		.byte $DC
		.byte 1
		.byte $FA
		.byte $32
		.byte 5
		.byte $D4
		.byte $2C
		.byte $D
		.byte $43
		.byte $37
		.byte $47
		.byte $35
		.byte $B7
		.byte $30
		.byte $C3
		.byte $64
		.byte $23
		.byte $E4
		.byte $29
		.byte $45
		.byte $33
		.byte $64
		.byte $43
		.byte $64
		.byte $53
		.byte $64
		.byte $63
		.byte $64
		.byte $73
		.byte $64
		.byte $9A
		.byte $60
		.byte $A9
		.byte $61
		.byte $B8
		.byte $62
		.byte $BE
		.byte $B
		.byte $D4
		.byte $31
		.byte $D5
		.byte $D
		.byte $DE
		.byte $F
		.byte $D
		.byte $CA
		.byte $7D
		.byte $47
		.byte $FD
unk_D21B:
		.byte 1
		.byte 1
		.byte $78
		.byte $52
		.byte $B5
		.byte $55
		.byte $DA
		.byte $60
byte_D223:
		.byte $E9
		.byte $61
		.byte $F8
		.byte $62
		.byte $FE
		.byte $B
unk_D229:
		.byte $FE
		.byte $81
		.byte $A
		.byte $CF
		.byte $36
		.byte $49
		.byte $62
		.byte $43
		.byte $FE
		.byte 7
		.byte $36
		.byte $C9
		.byte $FE
		.byte 1
		.byte $C
		.byte $84
		.byte $65
		.byte $55
		.byte $97
		.byte $52
		.byte $9A
		.byte $32
		.byte $A9
		.byte $31
		.byte $B8
unk_D242:
		.byte $30
		.byte $C7
		.byte $63
		.byte $CE
		.byte $F
		.byte $D5
		.byte $D
		.byte $7D
		.byte $C7
		.byte $FD
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF
		.byte $FF


control_bank