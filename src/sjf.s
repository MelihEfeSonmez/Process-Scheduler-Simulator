.extern input_buf, process_count, proc_buf          # from schedsim.s
.extern parse_input, sort_processes, append_char    # from parser.s

.section .text
.global sjf_algo

sjf_algo:
    # calle-saved registers
    push    %rbx
    push    %r12
    push    %r13
    push    %r14 
    push    %r15

    # call parse_input
    leaq    input_buf(%rip), %rsi
    addq    $4, %rsi        # skip 'SJF'
    mov     $2, %rdx        # algo has 2 fields (ID & burst time)
    call    parse_input

    # call sort_processes
    mov     $4, %rdi
    call    sort_processes

    # reset registers (no need to current_time)
    xor     %r13d, %r13d    # index for loop
    movl    process_count(%rip), %r14d

.sjf_loop:
    cmpl    %r14d, %r13d    # process_count vs. index
    jge     .sjf_exit

    # find the process
    leaq    proc_buf(%rip), %r15    
    movl    %r13d, %eax
    shl     $4, %eax
    addq    %rax, %r15
    
    # get ID and burst time
    movb    (%r15), %bl 
    movl    4(%12), ecx

.sjf_burst:
    testl   %ecx, %ecx      # determine ZF
    jz      .sjf_next
    movb    %bl, %al
    call    append_char     # append to output_buf
    decl    %ecx            # decrement burst time
    jmp     .sjf_burst

.sjf_next:
    incl    %r13d           # next process
    jmp     .sjf_loop

.sjf_exit:
    pop     %r15
    pop     %r14
    pop     %r13       
    pop     %r12
    pop     %rbx
    ret
