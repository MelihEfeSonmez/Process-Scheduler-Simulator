.extern input_buf, process_count, proc_buf          # from schedsim.s
.extern parse_input, sort_processes, append_char    # from parser.s

.section .text
.global fcfs_algo

fcfs_algo:
    # calle-saved registers
    push    %rbx
    push    %r12
    push    %r13
    push    %r14 
    push    %r15

    # call parse_input
    leaq    input_buf(%rip), %rsi
    addq    $5, %rsi
    mov     $3, %rdx
    call    parse_input

    # call sort_processes
    mov     $8, %rdi
    call    sort_processes

    # reset registers
    xor     %r12d, %r12d    # current_time
    xor     %r13d, %r13d    # index for loop
    movl    process_count(%rip), %r14d

.fcfs_loop:
    cmpl    %r14d, %r13d    # index vs. current time 
    jge     .fcfs_exit

    # pass the next process
    leaq    proc_buf(%rip), %r15    
    movl    %r13d, %eax
    shl     $4, %eax
    addq    %rax, %r15
    
    # get arrival time
    movl    8(%r15), %ebx

.fcfs_idle:
    cmpl    %ebx, %r12d     # current_time vs arrival
    jge     .fcfs_run_process
    mov     'X', %al
    call    append_char     # append to output_buf
    incl    %r12d           # increment current_time
    jmp     fcfs_loop

.fcfs_run_process:
    movb    (%r15), %bl     # get ID
    movl    4(%r15), %ecx   # get arrival time

.fcfs_burst:
    testl   %ecx, %ecx      # determine ZF
    jz      .fcfs_next
    movb    %bl, %al
    call    append_char     # append to output_buf
    incl    %r12d           # increment current_time
    decl    %ecx            # decrement burst time
    jmp     .fcfs_burst

.fcfs_next:
    incl    %r13d           # next process
    jmp     .fcfs_loop

.fcfs_exit:
    pop     %r15
    pop     %r14
    pop     %r13       
    pop     %r12
    pop     %rbx
    ret
