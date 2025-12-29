# Prove that you can't win at tic-tac-toe.
#
# Board: 0 | 1 | 2
#        ---------
#        3 | 4 | 5
#        ---------
#        6 | 7 | 8
#
# Only first moves 0, 1, and 4 are solved since other first moves are reflections
#
# The app takes an optional argument:
#    - the number of iterations to run. Default is defaultIterations.
#
# This version unrolls the loop for better performance

 # ebx: local scratchpad
 # ecx: depth 0..8
 # edx: move 0..8
 # esi: thread-global move count
 # edi: thread-global board pointer

.equ minimum_score, 2
.equ maximum_score, 9
.equ win_score, 6
.equ lose_score, 4
.equ tie_score, 5
.equ x_piece, 1
.equ o_piece, 2
.equ blank_piece, 0                           # not referenced in the code below, but it is assumed to be 0
.equ default_iterations, 1
                                         
# minmax_x argument offsets [ebp + X] where X = 2 to 1+N DWORDs passed on the stack

.equ ARG_ALPHA_OFFSET, 4 * 2
.equ ARG_BETA_OFFSET,  4 * 3

# minmax_x local variable offsets [ebp - X] where X = 1 to N where N is the number of DWORDs

.equ LOCAL_VALUE_OFFSET, -4 * 1               # the value of a board position
.equ LOCAL_I_OFFSET,     -4 * 2               # i in the for loop 0..8

.data
.p2align 8                                    # some intel CPUs have effective cache lines of 256 bytes (e.g. i5-2430M)
board0: .byte 1,0,0,0,0,0,0,0,0
.p2align 8
board1: .byte 0,1,0,0,0,0,0,0,0
.p2align 8
board4: .byte 0,0,0,0,1,0,0,0,0

.p2align 8
loopCount: .long default_iterations
moveCount: .long 0

.p2align 8
.section .rodata
WINPROCS: 
    .long proc0
    .long proc1
    .long proc2
    .long proc3
    .long proc4
    .long proc5
    .long proc6
    .long proc7
    .long proc8
.p2align 4
NEXTMIN:  
    .long minmax_min_try_1
    .long minmax_min_try_2
    .long minmax_min_try_3
    .long minmax_min_try_4
    .long minmax_min_try_5
    .long minmax_min_try_6
    .long minmax_min_try_7
    .long minmax_min_try_8
    .long minmax_min_loadv_done
.p2align 4
NEXTMAX:  
    .long minmax_max_try_1
    .long minmax_max_try_2
    .long minmax_max_try_3
    .long minmax_max_try_4
    .long minmax_max_try_5
    .long minmax_max_try_6
    .long minmax_max_try_7
    .long minmax_max_try_8
    .long minmax_max_loadv_done

.p2align 4
moves_string: .asciz " moves\n"

.text
.p2align 4
.global _start
_start:
    push    %ebp
    mov     %esp, %ebp
    sub     $32 + 4 * 4, %esp

    movl    4(%ebp), %eax
    cmp     $1, %eax                          # is there a loop count?
    je      _runit
    movl    12(%ebp), %edi
    call    atou32
    cmp     $0, %eax
    je      _runit                            # if malformed, use the default
    movl    %eax, (loopCount)

  _runit:    
    movl    $0, (moveCount)

    mov     $0, %ecx                          # solve for board 0
    call    TTTThreadProc

    mov     $1, %ecx                          # solve for board 1
    call    TTTThreadProc

    mov     $4, %ecx                          # solve for board 4
    call    TTTThreadProc

    mov     (moveCount), %ecx
    call    print_uint32

    movl    $4, %eax                          # write
    movl    $1, %ebx
    lea     moves_string, %ecx
    movl    $7, %edx
    int     $0x80

    mov     $1, %eax                          # exit
    xor     %ebx, %ebx
    int     $0x80

.p2align 4
TTTThreadProc:
    push    %ebp
    mov     %esp, %ebp
    push    (loopCount)
    
    xor     %esi, %esi                        # esi has the move count

    cmp     $0, %ecx
    jne     TTTThreadProc_try1
    lea     board0, %edi
    jmp     TTTThreadProc_for

  TTTThreadProc_try1:
    cmp     $1, %ecx
    jne     TTTThreadProc_try4
    lea     board1, %edi
    jmp     TTTThreadProc_for

  TTTThreadProc_try4:                         # don't validate it's four -- just assume it
    lea     board4, %edi
    mov     $4, %ecx                          # ensure this is the case

  TTTThreadProc_for:
    mov     %ecx, %edx                        # move in edx

.p2align 4
  TTTThreadProc_loop:
    push    %edx                              # save the initial move board position
    xor     %ecx, %ecx                        # depth 0
    push    $maximum_score                    # push beta
    push    $minimum_score                    # push alpha

    call    minmax_min                        # call min, because X just moved and now O moves should be minimized
    pop     %edx                              # restore the initial move position

    decl    (%esp)                            # decrement loop count
    jne     TTTThreadProc_loop

    lock add %esi, (moveCount)                # do this locked update once here at the end instead of for each iteration
    xor     %eax, %eax

    leave
    ret

# Odd depth = maximize for X in subsequent moves, O just took a move in edx
.p2align 4
minmax_max:
    inc     %esi                              # r13 is a global variable with the # of calls to minmax_max and minmax_min

    cmp     $3, %ecx                          # # of pieces on board is 1 + depth. So >= 4 means at least 5 moves played
    jle     minmax_max_skip_winner            # if too few moves, there can't be a winner yet

    # the win procs expect the board in edi
    mov     $o_piece, %eax                    # rax contains the player with the latest move on input
    call    *WINPROCS(,%edx,4)                # call the proc that checks for wins starting with last piece added

    cmp     $o_piece, %eax                    # did O win?
    jne     minmax_max_skip_winner
    mov     $lose_score, %eax
    ret     $8

.p2align 4
  minmax_max_skip_winner:
    push    %ebp
    mov     %esp, %ebp
    sub     $8, %esp                          # save space for value and loop variable i

    movl    $minimum_score, LOCAL_VALUE_OFFSET(%ebp)        # minimum possible score. maximizing, so find a score higher than this
    inc     %ecx                              # next depth 1..8

    xor     %edx, %edx                        # moves start at 0
    cmpb    $0, (%edi)
    je      minmax_max_move
  minmax_max_try_1:
    inc     %edx
    cmpb    $0, 1(%edi)
    je      minmax_max_move
  minmax_max_try_2:
    inc     %edx
    cmpb    $0, 2(%edi)
    je      minmax_max_move
  minmax_max_try_3:
    inc     %edx
    cmpb    $0, 3(%edi)
    je      minmax_max_move
  minmax_max_try_4:
    inc     %edx
    cmpb    $0, 4(%edi)
    je      minmax_max_move
  minmax_max_try_5:
    inc     %edx
    cmpb    $0, 5(%edi)
    je      minmax_max_move
  minmax_max_try_6:
    inc     %edx
    cmpb    $0, 6(%edi)
    je      minmax_max_move
  minmax_max_try_7:
    inc     %edx
    cmpb    $0, 7(%edi)
    je      minmax_max_move
  minmax_max_try_8:
    inc     %edx
    cmpb    $0, 8(%edi)
    jne     minmax_max_loadv_done

.p2align 4
  minmax_max_move:
    movb    $x_piece, (%edi,%edx)             # make the move
    mov     %edx, LOCAL_I_OFFSET(%ebp)
    push    ARG_BETA_OFFSET( %ebp )
    push    ARG_ALPHA_OFFSET( %ebp )
    call    minmax_min
    mov     LOCAL_I_OFFSET(%ebp), %edx
    movb    $0, (%edi, %edx)
    cmp     $win_score, %eax                  # compare score with the winning score
    je      minmax_max_depth_done             # can't do better than winning score when maximizing
    cmp     LOCAL_VALUE_OFFSET(%ebp), %eax    # compare score with value
    jle     minmax_max_next
    cmp     ARG_BETA_OFFSET(%ebp), %eax       # compare value with beta
    jge     minmax_max_depth_done             # beta pruning
    mov     %eax, LOCAL_VALUE_OFFSET(%ebp)    # update value with score
    lea     ARG_ALPHA_OFFSET(%ebp), %ebx      # save the address of slpha
    cmp     (%ebx), %eax                      # compare value with alpha
    jle     minmax_max_next
    mov     %eax, (%ebx)                      # update alpha
  minmax_max_next:
    jmp     *NEXTMAX(,%edx,4)

.p2align 4
  minmax_max_loadv_done:
    mov     LOCAL_VALUE_OFFSET(%ebp), %eax    # load value then return

.p2align 4
  minmax_max_depth_done:
    dec     %ecx                              # restore depth to the current level
    leave
    ret $8

# Even depth = mininize for X in subsequent moves, X just took a move in edx
.p2align 4
minmax_min:
    inc     %esi                              # r13 is a global variable with the # of calls to minmax_max and minmax_min

    cmp     $3, %ecx                          # # of pieces on board is 1 + depth. So >= 4 means at least 5 moves played
    jle     minmax_min_skip_winner            # if too few moves, there can't be a winner yet

    # the win procs expect the board in edi
    mov     $x_piece, %eax                    # rax contains the player with the latest move on input
    call    *WINPROCS(,%edx, 4)               # call the proc that checks for wins starting with last piece added

    cmp     $x_piece, %eax                    # did X win? 
    jne     minmax_min_check_tail
    mov     $win_score, %eax                  
    ret     $8

  minmax_min_check_tail:
    cmp     $8, %ecx                          # recursion can only go 8 deep before the board is full
    jne     minmax_min_skip_winner
    mov     $tie_score, %eax                  
    ret     $8

.p2align 4
  minmax_min_skip_winner:
    push    %ebp
    mov     %esp, %ebp
    sub     $8, %esp                          # save space for value and loop variable i

    movl    $maximum_score, LOCAL_VALUE_OFFSET(%ebp)
    inc     %ecx                              # next depth 1..8

    xor     %edx, %edx                        # moves start at 0
    cmpb    $0, (%edi)
    je      minmax_min_move
  minmax_min_try_1:
    inc     %edx
    cmpb    $0, 1(%edi)
    je      minmax_min_move
  minmax_min_try_2:
    inc     %edx
    cmpb    $0, 2(%edi)
    je      minmax_min_move
  minmax_min_try_3:
    inc     %edx
    cmpb    $0, 3(%edi)
    je      minmax_min_move
  minmax_min_try_4:
    inc     %edx
    cmpb    $0, 4(%edi)
    je      minmax_min_move
  minmax_min_try_5:
    inc     %edx
    cmpb    $0, 5(%edi)
    je      minmax_min_move
  minmax_min_try_6:
    inc     %edx
    cmpb    $0, 6(%edi)
    je      minmax_min_move
  minmax_min_try_7:
    inc     %edx
    cmpb    $0, 7(%edi)
    je      minmax_min_move
  minmax_min_try_8:
    inc     %edx
    cmpb    $0, 8(%edi)
    jne     minmax_min_loadv_done

.p2align 4
  minmax_min_move:
    movb    $o_piece, (%edi,%edx)
    mov     %edx, LOCAL_I_OFFSET(%ebp)
    push    ARG_BETA_OFFSET( %ebp )
    push    ARG_ALPHA_OFFSET( %ebp )
    call    minmax_max
    mov     LOCAL_I_OFFSET(%ebp), %edx
    movb    $0, (%edi,%edx)
    cmp     $lose_score, %eax
    je      minmax_min_depth_done             # can't do better than losing score when minimizing
    cmp     LOCAL_VALUE_OFFSET(%ebp), %eax    # compare score with value
    jge     minmax_min_next
    cmp     ARG_ALPHA_OFFSET(%ebp), %eax      # compare value with alpha
    jle     minmax_min_depth_done             # alpha pruning
    mov     %eax, LOCAL_VALUE_OFFSET(%ebp)    # update value with score
    lea     ARG_BETA_OFFSET(%ebp), %ebx
    cmp     (%ebx), %eax                      # compare value with beta
    jge     minmax_min_next
    mov     %eax, (%ebx)                      # update beta
  minmax_min_next:
    jmp     *NEXTMIN(,%edx,4)

.p2align 4
  minmax_min_loadv_done:
    mov     LOCAL_VALUE_OFFSET(%ebp), %eax    # load value then return

  minmax_min_depth_done:
    dec     %ecx                              # restore depth to the current level
    leave
    ret     $8

.p2align 4
proc0:
    movb    %al, %bl
    andb    1(%edi), %al
    andb    2(%edi), %al
    jnz     proc0_yes

    movb    %bl, %al
    andb    3(%edi), %al
    andb    6(%edi), %al
    jnz     proc0_yes

    movb    %bl, %al
    andb    4(%edi), %al
    andb    8(%edi), %al

  proc0_yes:
    ret

.p2align 4
proc1:
    movb    %al, %bl
    andb    0(%edi), %al
    andb    2(%edi), %al
    jnz     proc1_yes

    movb    %bl, %al
    andb    4(%edi), %al
    andb    7(%edi), %al

  proc1_yes:
    ret

.p2align 4
proc2:
    movb    %al, %bl
    andb    0(%edi), %al
    andb    1(%edi), %al
    jnz     proc2_yes

    movb    %bl, %al
    andb    5(%edi), %al
    andb    8(%edi), %al
    jnz     proc2_yes

    movb    %bl, %al
    andb    4(%edi), %al
    andb    6(%edi), %al

  proc2_yes:
    ret

.p2align 4
proc3:
    movb    %al, %bl
    andb    0(%edi), %al
    andb    6(%edi), %al
    jnz     proc3_yes

    movb    %bl, %al
    andb    4(%edi), %al
    andb    5(%edi), %al

  proc3_yes:
    ret

.p2align 4
proc4:
    movb    %al, %bl
    andb    0(%edi), %al
    andb    8(%edi), %al
    jnz     proc4_yes

    movb    %bl, %al
    andb    2(%edi), %al
    andb    6(%edi), %al
    jnz     proc4_yes

    movb    %bl, %al
    andb    1(%edi), %al
    andb    7(%edi), %al
    jnz     proc4_yes

    movb    %bl, %al
    andb    3(%edi), %al
    andb    5(%edi), %al

  proc4_yes:
    ret

.p2align 4
proc5:
    movb    %al, %bl
    andb    3(%edi), %al
    andb    4(%edi), %al
    jnz     proc5_yes

    movb    %bl, %al
    andb    2(%edi), %al
    andb    8(%edi), %al

  proc5_yes:
    ret

.p2align 4
proc6:
    movb    %al, %bl
    andb    4(%edi), %al
    andb    2(%edi), %al
    jnz     proc6_yes

    movb    %bl, %al
    andb    0(%edi), %al
    andb    3(%edi), %al
    jnz     proc6_yes

    movb    %bl, %al
    andb    7(%edi), %al
    andb    8(%edi), %al

  proc6_yes:
    ret

.p2align 4
proc7:
    movb    %al, %bl
    andb    1(%edi), %al
    andb    4(%edi), %al
    jnz     proc7_yes

    movb    %bl, %al
    andb    6(%edi), %al
    andb    8(%edi), %al

  proc7_yes:
    ret

.p2align 4
proc8:
    movb    %al, %bl
    andb    0(%edi), %al
    andb    4(%edi), %al
    jnz     proc8_yes

    movb    %bl, %al
    andb    2(%edi), %al
    andb    5(%edi), %al
    jnz     proc8_yes

    movb    %bl, %al
    andb    6(%edi), %al
    andb    7(%edi), %al

  proc8_yes:
    ret

/*
 * Function: print_uint32
 * Description: Prints a 32-bit unsigned integer from ECX to stdout.
 * Input: ECX contains the unsigned integer to print.
 * Clobbers: EAX, EBX, ECX, EDX, EDI, ESI
 */

.text
.globl print_uint32

print_uint32:
    /* Prologue to set up a new stack frame and save EBP */
    push    %ebp
    movl    %esp, %ebp

    /* Allocate 21 bytes on the stack for the string buffer.
     * (20 digits max for 2^64-1 + null terminator, or 1 for '0' case)
     */
    subl    $21, %esp

    /* Special case: if the input is 0, print a single '0' character. */
    cmpl    $0, %ecx
    jne     .nonzero_case

    mov     $4, %eax        /* sys_write syscall number */
    mov     $1, %ebx        /* file descriptor 1 (stdout) */
    mov     %esp, %ecx      /* buffer address */
    movb    $'0', (%ecx)    /* store '0' in the buffer */
    mov     $1, %edx        /* length is 1 */
    int     $0x80
    jmp     .done

.nonzero_case:
    movl    %ecx, %eax      /* rax = number */
    leal    20(%esp), %edi  /* rdi points to the end of the buffer */
    movb    $0, (%edi)      /* null-terminate the string */
    decl    %edi            /* move pointer to the last character position */

.convert_loop:
    xor     %edx, %edx      /* clear rdx for division */
    mov     $10, %ebx       /* divisor is 10 */
    div     %ebx            /* eax = eax / 10, edx = eax % 10 */
    addb    $'0', %dl       /* convert digit to ASCII character */
    movb    %dl, (%edi)     /* store the ASCII character in the buffer */
    dec     %edi            /* move to the next position */
    cmp     $0, %eax        /* check if eax is 0 */
    jne     .convert_loop   /* continue if not zero */

    inc     %edi            /* edi now points to the start of the string */

    mov     %ebp, %edx      /* ecx = initial esp (from ebp) */
    sub     %edi, %edx      /* ecx = length of the string */
    dec     %edx
    mov     %edi, %ecx      /* esi = address of the string to print */
    mov     $4, %eax        /* sys_write syscall number */
    mov     $1, %ebx        /* file descriptor 1 (stdout) */
    int     $0x80

.done:
    mov     %ebp, %esp      /* Restore the stack pointer */
    pop     %ebp            /* Restore EBP */
    ret

.text
.globl atou32
atou32:                                       # string in edi into a number in rax
    xor     %eax, %eax
    xor     %ebx, %ebx
    movl    $10, %esi
    xor     %edx, %edx
    movl    $'0', %ecx
  _atou32_next:    
    movb    (%edi), %bl
    cmp     $'0', %bl
    jl      _atou32_done
    cmp     $'9', %bl
    jg      _atou32_done
    mul     %esi
    sub     %cl, %bl
    add     %ebx, %eax
    inc     %edi
    jmp     _atou32_next
  _atou32_done:
    ret
