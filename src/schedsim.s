extern fcfs_algo, sjf_algo, srtf_algo, pf_algo, rr_algo

.section .bss
input_buf:      .space 256
output_buf:     .space 1024
temp_buf:       .space 256
proc_buf:       .space 160
process_count:  .space 4
current_time:   .space 4

# Round Robin helpers (optional)
rr_queue:       .space 64
rr_head:        .space 4
rr_tail:        .space 4

.section .data
newline:        .asciz "\n"

.section .text
.global _start

_start:
    # READ INPUT
    mov     $0, %rax
    mov     $0, %rdi
    lea     input_buf(%rip), %rsi
    mov     $256, %rdx
    syscall

    # check the first letter of input to determine 
    # which algorithm will be applied
    leaq    input_buf(%rip), %rdi
    movb    %rdi, %al

    cmp     $'F', %al
    je      .fcfs_condition
    cmp     $'P', %al
    je      .pf_condition    
    cmp     $'R', %al
    je      .rr_condition
    cmp     $'S', %al
    jne     .exit

    # check the second letter of input to determine 
    # which algorithm will be applied (for sjf & srtf)
    movb    1(%rdi), %al 

    cmp     $'J', %al  
    je      .sjf_condition
    cmp     $'R', %al
    je      .srtf_condition
    jmp     .exit

# algorithm conditions
.fcfs_condition:
    call     fcfs_algo
    jmp      .exit

.sjf_condition:
    call     sjf_algo
    jmp      .exit

.srtf_condition:
    call     srtf_algo
    jmp      .exit

.pf_condition:
    call     pf_algo
    jmp      .exit

.rr_condition:
    call     rr_algo
    jmp      .exit

##################################
# EXIT SYSCALL
##################################
.exit:
    mov     $60, %rax
    xor     %rdi, %rdi
    syscall