        BUFSIZE equ 13
        WORDBUFSIZE equ 255
        
section .data
        nl db 0xA
        
section .bss
        buf resb BUFSIZE
        bufidx resq 1
        buflen resq 1

        wordbuf resb WORDBUFSIZE
        wordlen resq 1

        hex_buffer resb 16+2
        hex_buffer_end resb 1

section .text
global _start
_start:
        call myword
        call printword
        call newline
        jmp _start

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

newline:
        mov rax,1
        mov rdx,1
        mov rsi,nl
        mov rdi,1
        syscall
        ret

printkey:
        mov [nl],al
        mov rax,1
        mov rdx,1
        mov rsi,nl
        mov rdi,1
        syscall
        mov byte [nl],0xA
        ret

printword:
        mov rax,1
        mov rdi,1
        mov rsi,wordbuf
        mov rdx,[wordlen]
        syscall
        ret
        
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
        dec rsi
        inc rdx
        mov byte [rsi],'x'
        dec rsi
        inc rdx
        mov byte [rsi],'0'
        mov rax,1
        mov rdi,1
        syscall
        pop rax
        ret
