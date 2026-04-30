.extern input_buf, process_count, proc_buf          # from schedsim.s
.extern parse_input, append_char                    # from parser.s

.section .text
.global pf_algo

pf_algo:
    # callee-saved registers
    push    %rbx
    push    %r12
    push    %r13
    push    %r14
    push    %r15

    # call parse_input
    leaq    input_buf(%rip), %rsi
    addq    $3, %rsi        # skip 'PF '
    mov     $4, %rdx        # algo has 4 fields (ID & burst & arrival & priority)
    call    parse_input

    # compute total burst (we stop when we have done that many real cycles)
    xor     %r14d, %r14d    # sum of bursts
    xor     %ecx, %ecx      # index for loop
    movl    process_count(%rip), %edx

.pf_sum_of_bursts:
    cmpl    %edx, %ecx      # process_count vs index
    jge     .pf_sum_done
    leaq    proc_buf(%rip), %rsi
    movl    %ecx, %eax
    shl     $4, %eax
    addq    %rax, %rsi
    addl    4(%rsi), %r14d  # add burst to sum
    incl    %ecx
    jmp     .pf_sum_of_bursts

.pf_sum_done:
    xor     %r12d, %r12d    # time worked actually
    xor     %r13d, %r13d    # current_time

.pf_main_loop:
    cmpl    %r14d, %r12d    # done all real work?
    jge     .pf_exit

    # initialise "best" with sentinel values
    movl    $-1, %r11d              # best index
    movl    $0x7FFFFFFF, %r10d      # best priority
    movl    $0x7FFFFFFF, %r9d       # best remaining
    xor     %ecx, %ecx              # scanner index
    movl    process_count(%rip), %r8d

.pf_scan_loop:
    cmpl    %r8d, %ecx      # process_count vs scanner index
    jge     .pf_scan_done

    # find the process
    leaq    proc_buf(%rip), %rsi
    movl    %ecx, %eax
    shl     $4, %eax
    addq    %rax, %rsi

    # arrived yet?
    movl    8(%rsi), %edi   # arrival
    cmpl    %r13d, %edi
    jg      .pf_skip        # arrival > current_time -> not yet

    # still has work?
    movl    4(%rsi), %edx   # remaining
    testl   %edx, %edx
    jz      .pf_skip

    # compare priority first
    movl    12(%rsi), %edi  # priority
    cmpl    %r10d, %edi
    jl      .pf_replace     # strictly better priority -> take it
    jg      .pf_skip        # strictly worse -> ignore
    # priorities equal -> compare remaining (SRTF tie-break)
    cmpl    %r9d, %edx
    jge     .pf_skip        # remaining >= best -> earlier index wins

.pf_replace:
    movl    %edi, %r10d     # new best priority
    movl    %edx, %r9d      # new best remaining
    movl    %ecx, %r11d     # new best index

.pf_skip:
    incl    %ecx
    jmp     .pf_scan_loop

.pf_scan_done:
    cmpl    $-1, %r11d      # any candidate?
    je      .pf_idle

    # find the chosen process
    leaq    proc_buf(%rip), %rsi
    movl    %r11d, %eax
    shl     $4, %eax
    addq    %rax, %rsi

    # run it for one cycle
    movb    (%rsi), %al
    call    append_char
    decl    4(%rsi)         # remaining--
    incl    %r12d           # actual work done++
    incl    %r13d           # current_time++
    jmp     .pf_main_loop

.pf_idle:
    movb    $'X', %al
    call    append_char
    incl    %r13d
    jmp     .pf_main_loop

.pf_exit:
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx
    ret
