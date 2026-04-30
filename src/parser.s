.extern input_buf, output_buf, proc_buf, process_count

.section .bss
    .global output_pos
output_pos:     .space 4               # number of chars written to output_buf

.section .text

atoi_advance:
    xor     %rax, %rax
.atoi_loop:
    movzbl  (%rsi), %ecx               # load current byte
    subl    $'0', %ecx                 # ASCII -> digit value
    cmpl    $9, %ecx
    ja      .atoi_done                 # not 0..9 -> stop (unsigned cmp)
    imulq   $10, %rax
    addq    %rcx, %rax
    inc     %rsi
    jmp     .atoi_loop
.atoi_done:
    ret

parse_one_process:
    push    %r12
    push    %r13
    mov     %rdi, %r12                 # slot pointer
    mov     %rdx, %r13                 # field count

    # Zero the slot so omitted fields read as 0.
    movq    $0, (%r12)
    movq    $0, 8(%r12)

    # Field 0: single-char ID
    movb    (%rsi), %al
    movb    %al, (%r12)
    inc     %rsi                        # past ID
    inc     %rsi                        # past '-'

    # Field 1: burst (always present)
    call    atoi_advance
    movl    %eax, 4(%r12)
    cmpq    $2, %r13
    je      .pop_done

    inc     %rsi                        # past '-'
    # Field 2: arrival
    call    atoi_advance
    movl    %eax, 8(%r12)
    cmpq    $3, %r13
    je      .pop_done

    inc     %rsi                        # past '-'
    # Field 3: priority
    call    atoi_advance
    movl    %eax, 12(%r12)

.pop_done:
    pop     %r13
    pop     %r12
    ret

.global parse_input 
parse_input: 
    push    %rbx
    push    %r12
    push    %r13
    push    %r14

    mov     %rdx, %r13                 # field count, persisted
    xor     %r14, %r14                 # quantum accumulator

    movl    $0, process_count(%rip)
    leaq    proc_buf(%rip), %r12       # next free slot

.pi_next:
    # Skip spaces between tokens.
.pi_skip_spaces:
    movb    (%rsi), %al
    cmp     $' ', %al
    jne     .pi_check_end
    inc     %rsi
    jmp     .pi_skip_spaces

.pi_check_end:
    # End of input on NUL / LF / CR.
    test    %al, %al
    je      .pi_end
    cmp     $10, %al
    je      .pi_end
    cmp     $13, %al
    je      .pi_end

    # Look ahead: does this token contain '-'?
    mov     %rsi, %rbx
.pi_scan_token:
    movb    (%rbx), %al
    test    %al, %al
    je      .pi_quantum
    cmp     $' ', %al
    je      .pi_quantum
    cmp     $10, %al
    je      .pi_quantum
    cmp     $13, %al
    je      .pi_quantum
    cmp     $'-', %al
    je      .pi_descriptor
    inc     %rbx
    jmp     .pi_scan_token

.pi_descriptor:
    mov     %r12, %rdi                 # destination slot
    mov     %r13, %rdx                 # field count
    call    parse_one_process
    addq    $16, %r12                  # advance to next slot
    incl    process_count(%rip)
    jmp     .pi_next

.pi_quantum:
    # Pure integer token => RR quantum.
    call    atoi_advance
    mov     %rax, %r14
    jmp     .pi_next

.pi_end:
    mov     %r14, %rax
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

.global sort_processes 
sort_processes: 
    push    %rbx
    push    %r12
    push    %r13
    push    %r14
    push    %r15

    mov     %rdi, %r15                 # field offset
    movl    process_count(%rip), %r12d
    cmp     $1, %r12d
    jle     .sp_done                   # 0 or 1 elements: nothing to do

    xor     %r13d, %r13d               # i = 0
.sp_outer:
    cmp     %r12d, %r13d
    jge     .sp_done

    # Inner-loop bound: j in [0, n-1-i)
    movl    %r12d, %r14d
    decl    %r14d
    subl    %r13d, %r14d
    xor     %ebx, %ebx                 # j = 0

.sp_inner:
    cmp     %r14d, %ebx
    jge     .sp_outer_next

    # Compute &proc[j] and &proc[j+1].
    leaq    proc_buf(%rip), %rsi
    movl    %ebx, %eax
    shl     $4, %eax
    addq    %rax, %rsi
    mov     %rsi, %rdi
    addq    $16, %rdi

    # Compare key fields; swap on strict greater (stable).
    movl    (%rsi, %r15), %eax
    movl    (%rdi, %r15), %edx
    cmp     %edx, %eax
    jle     .sp_no_swap

    # Swap two 16-byte structs via four 8-byte temporaries.
    movq    0(%rsi), %r8
    movq    8(%rsi), %r9
    movq    0(%rdi), %r10
    movq    8(%rdi), %r11
    movq    %r10, 0(%rsi)
    movq    %r11, 8(%rsi)
    movq    %r8,  0(%rdi)
    movq    %r9,  8(%rdi)

.sp_no_swap:
    incl    %ebx
    jmp     .sp_inner

.sp_outer_next:
    incl    %r13d
    jmp     .sp_outer

.sp_done:
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

.global append_char 
append_char: 
    push    %rcx
    push    %rdi
    movl    output_pos(%rip), %ecx
    leaq    output_buf(%rip), %rdi
    movb    %al, (%rdi, %rcx)
    incl    %ecx
    movl    %ecx, output_pos(%rip)
    pop     %rdi
    pop     %rcx
    ret

.global print_output 
print_output:
    movl    output_pos(%rip), %ecx
    leaq    output_buf(%rip), %rdi
    movb    $10, (%rdi, %rcx)          # trailing '\n'
    incl    %ecx

    mov     %rcx, %rdx                 # length
    mov     $1, %rax                   # sys_write
    mov     $1, %rdi                   # stdout fd
    leaq    output_buf(%rip), %rsi
    syscall
    ret
