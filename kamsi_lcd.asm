; This program is created by Dikamsi Young Udochi
; The function of this program is to output data
; transmitted over the 8051's TXD pin to an LCD module 
; connected via Port 1.



	; Main code starts here
	; Here each code is divided into subroutines
	; to mimmick high-level programming language syntax
	setupUart:
		call setMemoryLocation
		call setSerialMode
		call setBaudrate
	receive:
		call startReceive	
	display:
		call initializeLcdVariables
		call setLcdFourBitMode
		call setupLcdDisplay
		call lcdDisplayCharacters
	reset:
		call clearMemory
		; End of program


;______________________________________________________________________________

; Functions used in the main code are defined here

; Set Memory Location
setMemoryLocation:
	mov R1, #50h				; R1 holds the location of where the received bytes are stored (50h)
	ret

; Set Serial Mode
setSerialMode:
	mov SCON, #50h  			; Serial mode is set to 8-bit plus 1-bit start/stop addons and Receive is enabled (REN)
	ret							; TH1 sets the baudrate.

; Set Baudrate
setBaudrate:
	mov A, PCON					;|
	setb acc.7					;|
	mov PCON, A 				;| A baudrate of twice its original value is set
	mov TMOD, #20h
	mov TH1, #-3				; A baudrate of 9600 is set. It is then doubled by SMOD to 19,200
	mov TL1, #-3
	ret

; Start Receive
startReceive:  
	setb TR1					; Start timer 1
  receiveByte:
	jnb RI, $
	clr RI
	mov A, SBUF					; Retrieve data from the bidirectional Serial Buffer register (SBUF)
	cjne A, #0dh, storeByte
	jmp endReceive
  storeByte:
	mov @R1, A					; Store byte in Memory Location (50h+)
	inc R1
	jmp receiveByte
  endReceive:
	clr TR1						; Reset timer facility
	mov TMOD, #20h
	mov TH1, #00h
	mov TL1, #00h
	ret

; Initialize LCD Variables
initializeLcdVariables:
	RS equ P1.3					; Here I assign names to pins in Port 1 as it relates the corresponding LCD pins
	EN equ P1.2
	upperNibble equ 7Ch			; Here I assign names to RAM locations that would contain portstate and nibbles to be sent to port
	lowerNibble equ 7Dh
	portState equ 7Eh
	lcdCharacter equ 7Fh
	ret

; Set LCD 4-Bit Mode
setLcdFourBitMode:
	call sendLcdCommand			; Subroutine clears RS and sets LCD to command mode
	mov A, #28h					; LCD command byte to activate 4-bit mode
	call lcdByteSplitter		; In 4-bit mode, LCD module only take one nibble at a time. This subroutine splits the command byte into nibbles
	call lcdSendUpperNibble
	call lcdEnable				; The enable signal allows the data to be read temporarily
	call lcdInputDelay			; The LCD is slower in processing than the 8051 and hence needs some timeout
	call lcdEnable				; This enable signal alerts the LCD that another signal is coming in
	call lcdSendLowerNibble		
	call lcdEnable				; This enable signal allows data into the LCD temporarily
	call lcdInputDelay			; This delay is used for inputs as it is shorter.
	ret

; Setup LCD Display
setupLcdDisplay:
	call sendLcdCommand
	mov A, #06h					; This command byte clears the LCD
	call sendToLcdPort
	mov A, #0Fh					; This command byte turns on the LCD display
	call sendToLcdPort
	ret
		
; LCD Display Characters
lcdDisplayCharacters:
	call setMemoryLocation		; Memory location is defined in R1 (50h)
  displayNextCharacter:
	mov A, @R1
	call checkCharacter			; Checks whether ' ' or '\n' was inputted
  continue:
	mov A, @R1
	jz finish
	call sendLcdData			; Set LCD to display mode
	call sendToLcdPort			; Sends each byte to LCD port
	inc R1
	mov A, @R1
	jnz displayNextCharacter	; Clear memory location when process is complete

  checkCharacter:
	cjne A, #' ', isClearScreen	; Compare with current byte in A with ' ' and jump if not equal
	call lcdNewLine				; call subroutine to display new line
	inc R1
	jmp displayNextCharacter

  isClearScreen: 
	cjne A, #0ah, continue		; Compare with current byte in A with '\n' and jump if not equal
	call lcdInputDelay			; Delay is called to allow users view their name for a longer period of time. (Good User Experience)
	call clearScreen			; call subroutine to clear screen
	inc R1
	jmp displayNextCharacter

  clearScreen:
	call sendLcdCommand
	mov A, #01h					; LCD command byte to clear screen and return cursor to top
	call sendToLcdPort
	call lcdProcessingDelay		; This delay subroutine is called because the clearing process takes longer time than the data input
	ret

  lcdNewLine:
	call sendLcdCommand
	mov A, #0C0h				; LCD command byte to go to new line
	call sendToLcdPort
	ret
  finish:
	jmp reset		


;_____________________________________________________________________________

; Other subroutines that function with the main subroutines

; Send LCD Data
sendLcdData:
	setb RS						; LCD goes to display mode when its RS (Register Select) pin is set
	ret

; Send To LCD Port
sendToLcdPort:
	call lcdByteSplitter
	call lcdSendUpperNibble
	call lcdEnable
	call lcdSendLowerNibble
	call lcdEnable
	call lcdInputDelay			; LCD Input Delay is called because the time taken for input delay is less
	ret

; Send Upper Nibble
lcdSendUpperNibble:
	mov portState, P1			; This subroutine aims to save the current state of the LCD since its RS and EN pins
	anl portState, #0fh			; are connected to the lower pins of Port 1. By ANDing the content of P1 with #0fh, 
	mov A, upperNibble			; the state of the LCD is saved. This can then be ORed with upperNibble and lowerNibble and sent to LCD, 
	orl portState, A			; still retaining the state of the LCD.
	mov P1, portState
	ret

; Send Lower Nibble
lcdSendLowerNibble:
	anl portState, #0fh			; This subroutine has similar function as lcdSendUpperNibble
	mov A, lowerNibble
	orl portState, A
	mov P1, portState
	ret

; Byte Splitter
lcdByteSplitter:
	mov upperNibble, A			; This subroutine splits the command and data bytes into upper and lower nibbles.
	anl upperNibble, #0F0h		; It performs an AND operation to remove the lower nibble and upper nibbles respectively
	swap A
	anl A, #0F0h
	mov lowerNibble, A
	ret

; LCD Input Delay
lcdInputDelay:					; Used for input delays
	mov R0, #50h
	djnz R0, $
	ret

; LCD Processing Delay
lcdProcessingDelay:				;  Process runs longer than lcdInputDelay. Used when LCD is reset command is called.
	mov R0, #05h
	loop2: mov R2, #0ffh
	loop1: djnz R2, $
	djnz R0, loop2
	ret 

; LCD Enable
lcdEnable:						; The trailing edge of a clock cycle activates the Enable pin of the LCD
	setb EN
	clr EN
	ret

; Send LCD Command
sendLcdCommand:
	clr RS
	ret

; Clear memory
clearMemory:					; This subroutine clears the contents stored in the memory location (50h+) defined with setMemoryLocation,
	mov R1, #50h				; subroutine.
  loop:
	mov A, @R1
	cjne A, #00h, clear
	jmp done
  clear:
	clr A
	mov @R1, A
	inc R1
	jmp loop
  done:
	jmp receive
		
		
		
