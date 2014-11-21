;; NOTES:
;; We use rsp for the parameter stack (as normal)
;; and use rbp for the return stack which is in bss
        
;; All registers
;; rsp  parameter stack
;; rbp  return stack pointer
;; rsi  program counter

        BUFSIZE equ 13
        WORDBUFSIZE equ 255
        
        
%macro NEXT 0
;; rsi points to a memory address
;; that memory address gets read into rax
;; then rsi is incremented (or decremented depending on the direction flag)
        lodsq
;; then we jump into what rax points to
        jmp [rax]
%endmacro

%macro PUSHRSP 1
;; save a register onto the return stack
        lea rbp,[rbp-8] ; decrease rbp
        mov [rbp],%1 ; put it in there
%endmacro

%macro POPRSP 1
        mov %1,[rbp]
        lea rbp,[rbp+8]
%endmacro



%define F_IMMED 0x80
%define F_HIDDEN 0x20
%define F_LENMASK 0x1f ; length mask

;Store the chain of links.
%define link 0

%macro defcode 4
section .data ; %1=name %2=namelen %3=flags $5=label
name_%4:
        dq link
        %define link name_%4
        db %3+%2
        db %1
ALIGN 8
%4:
        dq code_%4
section .text
code_%4:
;; assembly code follows
%endmacro

%macro defword 4
section .data ; %1=name %2=namelen %3=flags $5=label
name_%4:
        dq link
        %define link name_%4
        db %3+%2
        db %1
ALIGN 8
%4:
        dq DOCOL
;; forth words follow
%endmacro

%macro defvar 5 ;; same as defcode but then name and initial value
        defcode %1,%2,%3,%4
        push var_%4
        NEXT
section .data
var_%4 :
        dq %5
%endmacro


section .data
        okaystr db 'okaykid'
        nopestr db 'nope!!!'
        newlinestr db 0x0A

cold_start dq THING

section .bss
;ALIGN 4096
        return_stack resq 8192
return_stack_top:

        buf resb BUFSIZE
        bufidx resq 1
        buflen resq 1

        wordbuf resb WORDBUFSIZE
        wordlen resq 1

        hex_buffer resb 16+2
        hex_buffer_end resb 1

section .text
DOCOL:
        PUSHRSP rsi
        add rax,8
        mov rsi,rax
        NEXT

global _start
_start:
        ;; run brk to find the break location
        mov rax,12    ;; brk
        xor rdi,rdi   ;; 0
        syscall
        
        ;; increase brk allocating space for the return stack
        mov rbx,rax
        mov rdi,rax
        mov rax,12
        add rdi,0x2000
        syscall
        
        cld ;; clear the direction flag meaning that our second stack grows up
        mov rbp,return_stack_top
        
        mov rsi,cold_start
	NEXT ; Run interpreter

        defcode "LIT",3,0,LIT
; rsi points to the next command, but in this case it points to the next
; literal 32 bit integer.  Get that literal into rax and increment rsi.
; On x86, it's a convenient single byte instruction!  (cf. NEXT macro)
	lodsq
	push rax		; push the literal number on to stack
	NEXT

	defcode "DROP",4,0,DROP
	pop rax
	NEXT

	defcode "SWAP",4,0,SWAP
	pop rax
	pop rbx
	push rax
	push rbx
	NEXT

	defcode "DUP",3,0,DUP
	mov rax,[rsp]
	push rax
	NEXT
        
	defcode "EXIT",4,0,EXIT
	POPRSP rsi		; pop return stack into rsi
	NEXT

        defcode "!",1,0,STORE
	pop rbx		; address to store at
	pop rax		; data to store there
	mov [rbx],rax	; store it
	NEXT
        
	defcode "@",1,0,FETCH
	pop rbx		; address to fetch
	mov rax,[rbx]	; fetch it
	push rax	; push value onto stack
	NEXT
        
	defcode "@B",2,0,FETCHBYTE
	pop rbx		; address to fetch
	movzx rax,byte [rbx]	; fetch it
	push rax	; push value onto stack
	NEXT

        defcode "+",1,0,ADD
	pop rax
	add [rsp],rax
	NEXT
        
	defcode "SYS_EXIT",8,0,SYS_EXIT
        xor rdi,rdi
        mov rax,60
        syscall
	NEXT

	defcode "OKAY",4,0,OKAY
        push rsi
        mov rax,1
        mov rdi,1
        mov rsi,okaystr
        mov rdx,5
        syscall
        pop rsi
	NEXT

        defcode "WORD",4,0,MYWORD
        push rsi
        call myword
        pop rsi
        mov rax,[wordlen]
        push rax
        push wordbuf
        NEXT
        
	defcode "NL",2,0,NL
        push rsi
        mov rax,1
        mov rdi,1
        mov rsi,newlinestr
        mov rdx,1
        syscall
        pop rsi
	NEXT
        
	defcode "NOPE",4,0,NOPE
        push rsi
        mov rax,1
        mov rdi,1
        mov rsi,nopestr
        mov rdx,5
        syscall
        pop rsi
	NEXT
        
        defword "YEAH",4,0,YEAH
        dq OKAY,OKAY,OKAY
        dq EXIT
        
        defword "THING",5,0,THING
        dq YEAH
        dq NOPE
        dq OKAY
        dq LIT,0x77777777,PRINTHEX
        dq LIT,0x77777777,LIT,0x17171717,ADD,PRINTHEX
        dq NL
        dq LIT,0x78914715637
        dq PRINTHEX
        dq NL
        dq LIT,0x78914715637,PRINTHEX
        dq NL
        dq FOO,FETCH,PRINTHEX
        dq NL
        dq LIT,0x77777777,PRINTHEX
        dq NL
        dq FOO,FETCH,PRINTHEX
        dq NL
        dq LINK,FETCH,PRINTWORD
        dq NL
        dq LINK,FETCH,FETCH,PRINTWORD
        dq NL
        dq LINK,FETCH,FETCH,FETCH,PRINTWORD
        dq NL
        dq NL
        dq MYWORD,PRINTSTR
        dq NL
        dq MYWORD,PRINTSTR
        dq NL
        dq SYS_EXIT
        dq EXIT

        defcode "PRINTHEX",8,0,PRINTHEX
        pop rax
        push rsi; we have to save this or NEXT will jump to an insane location
        call print_hex
        pop rsi
        NEXT

        defcode "PRINTSTR",8,0,PRINTSTR
        pop rax
        pop rdx
        push rsi
        mov rsi,rax
        mov rax,1
        mov rdi,1
        syscall
        pop rsi
        NEXT

        defword "PRINTWORD",9,0,PRINTWORD
        dq DUP,GETWORDLEN,SWAP,GETWORD
        dq PRINTSTR
        dq EXIT
        
        defword "GETWORDLEN",10,0,GETWORDLEN
        dq LIT,8,ADD,FETCHBYTE
        dq EXIT

        defword "GETWORD",7,0,GETWORD
        dq LIT,9,ADD
        dq EXIT

        defvar "FOO",3,0,FOO,0x77777777
        
        defvar "LINK",3,0,LINK,link

print_hex:
        push rax
        mov rsi,hex_buffer_end
        mov rdx,0
.loop:
        dec rsi
        inc rdx
        test rax,rax
        jz .done
        mov bl,0xF
        and byte bl,al
        cmp bl,9
        jle .skip
        add bl,'a'-'0'-10
.skip:
        add bl,'0'
        mov byte [rsi],bl
        shr rax,4
        jmp .loop
.done:
        mov byte [rsi],'x'
        dec rsi
        inc rdx
        mov byte [rsi],'0'
        mov rax,1
        mov rdi,1
        syscall
        pop rax
        ret



        
        ;; MY CODE FOR READING WORDS

key:
        mov rax,[bufidx]
        cmp rax,[buflen]
        jb .skip

        xor rax,rax
        mov [bufidx],rax
        
        call sys_read
        test rax,rax
        jbe .die
        mov [buflen],rax
.skip:
        mov rax,[bufidx]
        add qword [bufidx],1
        mov rax,[rax+buf]

        ret        
.die:
        call sys_exit

myword:
        call key
        cmp byte al,' '
        je myword
        cmp byte al,0xA
        je myword

        mov rcx,0
        push rcx ; these pushes and pops suck but i dont know how else
.loop:
        pop rcx
        mov byte [rcx+wordbuf],al
        inc rcx
        push rcx

        call key
        cmp byte al,' '
        je .done
        cmp byte al,0xA
        jne .loop

.done:
        pop rcx
        mov qword [wordlen],rcx
        ret

sys_read:
        xor rax,rax
        mov rdi,0
        mov rsi,buf
        mov rdx,BUFSIZE
        syscall
        ret

sys_exit:
        xor rdi,rdi
        mov rax,60
        syscall
