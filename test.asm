    ; func putch ch
    jmp __function_putch_end
__function_putch:
    ; 	addr ch
    mov ax, 4096
    ; 	asm mov si, ax
    mov si, ax 
    ; 	asm mov bx, [si]
    mov bx, [si] 
    ; 	asm mov ah, 0x0E
    mov ah, 0x0E 
    ; 	asm mov al, bl
    mov al, bl 
    ; 	asm int 0x10
    int 0x10 
    ; endf
    ret
__function_putch_end:
    ; func exit
    jmp __function_exit_end
__function_exit:
    ; 	asm mov ah, 0x4C
    mov ah, 0x4C 
    ; 	asm int 0x21
    int 0x21 
    ; endf
    ret
__function_exit_end:
    ; func add n1 n2
    jmp __function_add_end
__function_add:
    ; 	addr n1
    mov ax, 4096
    ; 	asm mov si, ax
    mov si, ax 
    ; 	asm mov bx, [si]
    mov bx, [si] 
    ; 	addr n2
    mov ax, 4098
    ; 	asm mov si, ax
    mov si, ax 
    ; 	asm mov ax, [si]
    mov ax, [si] 
    ; 	asm add ax, bx
    add ax, bx 
    ; endf
    ret
__function_add_end:
    ; int num1
    ; int num2
    ; int sum
    ; putch 65
    mov word [4102], 65
    call __function_putch
    ; set num1 32
    mov bx, 32
    mov [4096], bx
    ; set num2 33
    mov bx, 33
    mov [4098], bx
    ; add $num1 $num2
    mov bx, [4096]
    mov word [4104], bx
    mov bx, [4098]
    mov word [4106], bx
    call __function_add
    ; to sum
    mov [4100], ax
    ; putch $sum
    mov bx, [4100]
    mov word [4108], bx
    call __function_putch
    ; exit
    call __function_exit