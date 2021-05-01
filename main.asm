;; Boot sector setup
org 7C00h

;; Constants
VIDMEM            equ 0B800h
SCREENW           equ 80
SCREENH           equ 25
BGCOLOR           equ 0020h
TIMER             equ 046Ch

;; Saves index of tones to be played (0, 2, 4, ... 22)
Tone1 dw 0
Tone2 dw 0

;; Input array, stores converted integers of input
KEY_IN DB 0, 0

;;
;; ---Logic---
;;
init:
    ;; Set video mode to 80*25 text, 16 colors (VGA 0x03)
    mov ax, 0003h
    int 10h

    ;; Set up Video memory
    mov ax, VIDMEM
    mov es, ax          ; ES:DI <- Video memory (0B800:0000 or B8000)

    call clear_vmem     ; Blanks out screen

    mov bx, standby     ; Prints "Press any key"
    call print

;; Waits for a key to be pressed, then continues with generating the pseudo-random tones
startloop:
    mov ah, 1
    int 16h         ; get keyboard input
    jz startloop    ; loops if no input

;; Generates two "random" tones
gettones:
    ;; Random first tone
    xor ah, ah
    int 1Ah			        ; Timer ticks since midnight in CX:DX
    mov ax, dx		        ; Lower half of timer ticks
    xor dx, dx		        ; Clear out upper half of dividend
    mov cx, 12
    div cx			        ; (DX:AX) / CX; AX = quotient, DX = remainder (0-11)
    add dx, dx              ; multiply dx by two to get sound index value from 0-22
    mov word [Tone1], dx

    ;; "Random" second tone (rotate timer input)
    rol ax, 1
    xor dx, dx		        ; Clear out upper half of dividend
    div cx                  ; cx should still be 12
    add dx, dx              ; multiply dx by two to get sound index value from 0-22
    mov word [Tone2], dx

;; Gets the semitone difference (interval) between the two tones
getdiff:
    mov ax, word [Tone1]             ; get first tone
    mov bx, word [Tone2]             ; get second tone

    mov cx, 2                        ; divisor
    xor dx, dx                       ; clear upper half of dividend

    cmp ax, bx                       ; see if first tone is higher or equal
    jae .onehigher
    jb .twohigher

    .onehigher:
        sub ax, bx                  ; subtract second tone from first
        jmp .div

    .twohigher:
        sub bx, ax                  ; subtract first tone from second
        mov ax, bx                  ; move result for division
    
    .div:
        ; ax == difference to be divided by 2
        ; cx == 2
        ; dx == empty
        div cx
        ; result goes into ax
        mov byte [DIFF], al         ; move difference to memory

;; Waits two ticks, then resets all previous keyboard input values (only necessary for loop mode)
reset_input:
    call delay_two_ticks
    mov byte [KEY_IN], 0
    mov byte [KEY_IN+1], 0

;; Prints "Enter the amount of semitone steps heard"
printinfo:
    mov bx, quest
    call print

;; Plays the two random tones two times
mov cx, 2   ; Loop counter (play 2x)
mainloop:
    ;; Play first tone
    xor di, di                  ; Empty index
    mov di, [Tone1]             ; Move tone index to di
    mov bx, [TONES + di]        ; Move tone value to bx

    call playsound              ; Play tone
    call delay_two_ticks        ; wait two ticks
    
    xor di, di                  ; (Same thing with tone 2)
    mov di, [Tone2]
    mov bx, [TONES + di]

    call playsound
    call delay_two_ticks
    
loop mainloop                   ; Loop if not finished playing 2x
call stopsound                  ; Stop the speaker when the tones finished playing


;; Get the keyboard input
xor cx, cx                      ; Empty counter                      
xor ax, ax                      ; Empty ax
await_input:
    cmp cx, 2                   ; After two keytrokes, the input will be checked (there can't be more than two digits in the result)
    je get_input

    mov ah, 1                   ; Checks keyboard input, loops if there isn't any
    int 16h           
    jz await_input    

    xor ah, ah                  ; Gets keyboard input. al = ASCII char; ah = scan code
    int 16h
    
    cmp al, 13                  ; Check final result if input is Enter key / Carriage return
    je get_input

    call process_keystroke      ; Process keystroke if not

inc cx                          ; Increments input counter
jmp await_input                 ; Jumps back

;; Prints key input and puts it (ASCII char) into input array
process_keystroke:
    ; al: input char

    ;; Displays character (Last screen row)
    mov ah, 02h                     ; move color to char
    mov di, 3840                    ; char start (Line 79)
    add di, cx                      ; char offset (Column 0 for first, Column 1 for second)
    add di, cx
    mov word [ES:DI], ax            ; Put Color + Char into vmem

    ;; Add input to array
    mov bx, cx                      ; can't use cx as pointer
    mov byte [KEY_IN + bx], al      ; moves char to input array
    ret                             ; returns to await_input

;; Process input after two keystrokes / Enter press
get_input:
    mov al, byte [KEY_IN + 1]       ; Check if second input char is null
    cmp al, 0

    jne get_two_digit_nbr           ; if not, add 10 to second char input

    mov al, byte [KEY_IN]           ; If the second input is null, the output is only the first input char
    sub al, 30h                     ; Convert first input char to integer
    jmp get_result                  ; Gets final result

;; Get result (Compare input with actual interval)
;; al == input integer
;; byte [DIFF] == actual difference
get_result:
    mov ah, byte [DIFF]                 ; Moves calculated difference to ah
    cmp al, ah                          ; Compares input to result
    jne reset_input                     ; resets if input is wrong (plays same tones again)

    endloop:                            ; End of game
        mov bx, win                     ; Prints "Correct"
        call print                      
        call delay_two_ticks            ; Waits two ticks
        int 18h                         ; The reboot ending (Shady boot interrupt. Might work, might not; should restart system from next device)
        ; jmp endloop                   ; The "do nothing" ending
        ; jmp init                      ; The "repeat game forever" ending
    

;; Gets second input char, converts it to integer, adds 10.
get_two_digit_nbr:
    mov al, byte [KEY_IN + 1]     ; Get second input char 
    sub al, 30h                   ; Char to int
    add al, 10                    ; Add 10, because it can't be anything else. Results in 21 == 11 but that doesn't matter
    jmp get_result                ; Gets result
    
;; Plays sound via PC speaker
playsound:
    ; bx == Frequency
    mov al, 182
    out 43h, al             ; Send Speaker init code 182 to address 43h

    mov ax, bx              ; Set Frequency to play

    out 42h, al             ; Send low frequency byte to 42h

    mov al, ah
    out 42h, al             ; Send high frequency byte to 42h

    in  al, 61h             ; Get value from 61h. Only bits 1 and 0 need to be set to 1, the rest must stay as is

    or  al, 00000011b       ; Set bits 1 and 0

    out 61h, al             ; Send new value for 61h
    ret

;; Stops the PC speaker from whatever it's doing
stopsound:
    in al, 61h              ; Get value from 61h
    and al, 11111100b       ; Sets last bits to 0
    out 61h, al             ; returns value to 61h
    ret

;; Wait two ticks for whatever comes next
delay_two_ticks:
    mov bx, [TIMER]
    add bx, 4           ; Ticks to wait goes here
    .delay:
            cmp [TIMER], bx
            jl .delay
    ret

;; Print routine (overrides start of vmem)
;; bx: pointer to string start
;; cx: current string word
print:
    call clear_vmem
    xor di, di                  ; Start video mem addressing at 0
    xor cx, cx                  ; Stores character (cl == ascii char, ch = color)
    .strloop:
        mov cl, byte [bx]       ; move raw string value in cx

        cmp cl, 3h              ; see if character is end character, end print if so
        je .endprint            
        
        mov ch, 02h             ; add color to string
        mov word [ES:DI], cx    ; Put CX into vram
        inc bx                  ; next character in string
        inc di
        inc di                  ; next Vmem adress
        jmp .strloop
    .endprint:
        ret

;; Clear VMem (blank out screen)
clear_vmem:
    mov ax, BGCOLOR             ; Get Background Color
    xor di, di
    mov cx, SCREENW*SCREENH
    rep stosw                   ; mov [ES:DI], ax & inc di
    ret

;; ---- DATA ---
;; Strings
standby db "Press any key", 3h
quest db "Enter the amount of semitone steps heard", 3h
win db "Correct", 3h

;; Semitone difference
DIFF db 0   

;; Tone array C, C#, D, D#, E, F, F#, G, G#, A, B, H | Range 0, 22
TONES DW 4560, 4304, 4063, 3834, 3619, 3416, 3224, 3043, 2873, 2711, 2559, 2415



;; Boot sector padding
times 510 - ($-$$) db 0
dw 0AA55h