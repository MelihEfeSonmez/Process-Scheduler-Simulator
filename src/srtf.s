.extern input_buf, process_count, proc_buf          # from schedsim.s
.extern parse_input, sort_processes, append_char    # from parser.s

.section .text
.global srtf_algo

srtf_algo:
    # calle-saved registers
    push    %rbx
    push    %r12
    push    %r13
    push    %r14 
    push    %r15

    # call parse_input
    leaq    input_buf(%rip), %rsi
    addq    $5, %rsi        # skip 'SRTF'
    mov     $3, %rdx        # algo has 3 fields (ID & burst time & arrival time)
    call    parse_input

    # reset registers
    xor     %r14d, %r14d    # sum
    xor     %ecx, %ecx      # index for loop

    movl    process_count(%rip), %edx

.srtf_sum_of_bursts:
    cmpl    %edx, %ecx      # process_count vs. index
    jge     .srtf_sum_done  
    leaq    proc_buf(%rip), %rsi
    movl    %ecx, %eax
    shl     $4, %eax
    addq    %rax, %rsi
    addl    4(%rsi), %r14d  # add to sum
    incl    %ecx            # increment index
    jmp     .srtf_sum_of_bursts

.srtf_sum_done:
    xor     %r12d, %r12d    # time worked actually
    xor     %r13d, %r13d    # current_time

.srtf_main_loop:
    cmpl    %r14d, %r12d    # time worked actually vs sum of bursts
    jge     .srtf_exit

    # determine dummy process with biggest integer
    movl    $-1, %r11d
    movl    $0x7FFFFFFF, %r10d
    xor     %ecx, %ecx      # reset scanner index  
    movl    process_count(%rip), %r9d 

.srtf_scan_loop:
    cmpl    %r9d, %ecx      # process_count vs scanner index
    jge     .srtf_scan_done

    # find the process
    leaq    proc_buf(%rip), %rsi
    movl    %ecx, %eax
    shl     $4, %eax
    addq    %rax, %rsi

    movl    8(%rsi), %edi   # arrival time
    cmpl    %r13d, %edi     # current_time vs arrival
    jg      .srtf_skip

    movl    4(%rsi), %edx   # remaining time
    testl   %edx, %edx      
    jz      .srtf_skip      # determine ZF

    cmpl    %r10d, %edx     # least remaining vs remaining 
    jge     .srtf_skip
    movl    %edx, %r10d     # assign new least remaining
    movl    %ecx, %r11d     # assign new least remaining index

.srtf_skip:
    incl    %ecx            # increment scanner index
    jmp     .srtf_scan_loop

.srtf_scan_done:
    cmpl    $-1, %r11d      # is there a new least remaining?
    je      .srtf_idle

    # find the process
    leaq    proc_buf(%rip), %rsi
    movl    %r11d, %eax 
    shl     $4, %eax
    addq    %rax, %rsi

    # get ID and append to output
    movb    (%rsi), %al
    call    append_char

    decl    4(%rsi)         # decrement remaining
    incl    %r12d           # increment time worked actually
    incl    %r13d           # increment current_time
    jmp     .srtf_main_loop

.srtf_idle:
    movb    $'X', %al
    call    append_char     # append to output_buf
    incl    %r13d           # increment current_time
    jmp     .srtf_main_loop

.srtf_exit:
    pop     %r15
    pop     %r14
    pop     %r13       
    pop     %r12
    pop     %rbx
    ret
