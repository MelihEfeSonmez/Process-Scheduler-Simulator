.extern input_buf, process_count, proc_buf          # from schedsim.s
.extern rr_queue, rr_head, rr_tail                  # from schedsim.s
.extern parse_input, append_char                    # from parser.s

.section .text
.global rr_algo

rr_algo:
    # callee-saved registers
    push    %rbx
    push    %r12
    push    %r13
    push    %r14
    push    %r15

    # call parse_input ; quantum returned in %rax
    leaq    input_buf(%rip), %rsi
    addq    $3, %rsi        # skip 'RR '
    mov     $2, %rdx        # algo has 2 fields (ID & burst time)
    call    parse_input
    mov     %rax, %r15      # r15 = quantum

    # seed the queue with indices 0..n-1 in input order
    xor     %ecx, %ecx
    movl    process_count(%rip), %edx
    leaq    rr_queue(%rip), %rdi

.rr_seed_loop:
    cmpl    %edx, %ecx
    jge     .rr_seed_done
    movl    %ecx, (%rdi, %rcx, 4)
    incl    %ecx
    jmp     .rr_seed_loop

.rr_seed_done:
    movl    $0, rr_head(%rip)
    movl    %edx, rr_tail(%rip)

.rr_turn_loop:
    # queue empty?
    movl    rr_head(%rip), %eax
    cmpl    rr_tail(%rip), %eax
    jge     .rr_exit

    # dequeue: r14d = process index
    leaq    rr_queue(%rip), %rdi
    movl    %eax, %ecx
    andl    $15, %ecx
    movl    (%rdi, %rcx, 4), %r14d 
    incl    %eax
    movl    %eax, rr_head(%rip)

    # rsi = &proc[idx]
    leaq    proc_buf(%rip), %rsi
    movl    %r14d, %eax
    shl     $4, %eax
    addq    %rax, %rsi

    # run = min(remaining, quantum)
    movl    4(%rsi), %ebx   # remaining
    movl    %r15d, %r12d    # r12d = run = quantum
    cmpl    %r12d, %ebx
    jge     .rr_have_run    # remaining >= quantum -> use quantum
    movl    %ebx, %r12d     # remaining < quantum -> run = remaining

.rr_have_run:
    # emit ID for `run` cycles
    movb    (%rsi), %r13b   # ID
    movl    %r12d, %ecx

.rr_emit_loop:
    testl   %ecx, %ecx
    jz      .rr_emit_done
    movb    %r13b, %al
    call    append_char
    decl    %ecx
    jmp     .rr_emit_loop

.rr_emit_done:
    # remaining = remaining - run
    subl    %r12d, 4(%rsi)

    # finished or re-enqueue?
    movl    4(%rsi), %eax
    testl   %eax, %eax
    jz      .rr_pad

    # re-enqueue at the back
    movl    rr_tail(%rip), %eax
    movl    %eax, %ecx
    andl    $15, %ecx
    leaq    rr_queue(%rip), %rdi
    movl    %r14d, (%rdi, %rcx, 4)
    incl    %eax
    movl    %eax, rr_tail(%rip)
    jmp     .rr_turn_loop

.rr_pad:
    # process finished: emit (quantum - run) 'X' chars at end of slot
    movl    %r15d, %ecx     # quantum
    subl    %r12d, %ecx     # quantum - run

.rr_pad_loop:
    testl   %ecx, %ecx
    jz      .rr_turn_loop
    movb    $'X', %al
    call    append_char
    decl    %ecx
    jmp     .rr_pad_loop

.rr_exit:
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx
    ret
