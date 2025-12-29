# build on linux: gcc $1.s -o $1.elf -static -nostdlib
#
# The BYTE magazine classic sieve from 1981:
#   #define SIZE 8190
#
#   char flags[SIZE+1];
#
#   int main()
#           {
#           int i,k;
#           int prime,count,iter;
#
#           for (iter = 1; iter <= 10; iter++) {    /* do program 10 times */
#                   count = 0;                      /* initialize prime counter */
#                   for (i = 0; i <= SIZE; i++)     /* set all flags TRUE */
#                           flags[i] = TRUE;
#                   for (i = 0; i <= SIZE; i++) {
#                           if (flags[i]) {         /* found a prime */
#                                   prime = i + i + 3;      /* twice index + 3 */
#                                   for (k = i + prime; k <= SIZE; k += prime)
#                                           flags[k] = FALSE;       /* kill all multiples */
#                                   count++;                /* primes found */
#                                   }
#                           }
#                   }
#           printf("%d primes.\n",count);           /*primes found in 10th pass */
#           return 0;
#           }
#
# k         ecx
# flags     esi
# prime     edi
# count     edx
# i         ebx

.equ flags_size, 8190
.equ size_full, 8192

.data
.globl _flags
.p2align 4
.comm _flags,flags_size+2         # multiple of 4 and includes 2 bonus bytes per algorithm and to stop inner loop
.p2align 4
_iterations: .long 0
.p2align 4
.comm buffer 21
.p2align 4
done_string: .asciz " primes\n"

.global _start
.text
_start:
    push    %ebp
    mov     %esp, %ebp

    movl    $10, (_iterations)                # iter <= 10

  _next_iteration:
    lea     [_flags], %edi                    # for (i = 0; i <= SIZE; i++)
    mov     $0x01010101, %eax                 # initialize 4 array entries at a time
    mov     $size_full / 4, %ecx
    cld
    rep     stosl

    lea     [_flags], %esi
    movl    $-1, %ebx                         # i = -1
    xor     %edx, %edx                        # count = 0

  _outer:
    inc     %ebx
    cmpb    $0, (%esi, %ebx)
    je      _outer                            # if flags[i]

    cmp     $flags_size, %ebx
    jg      _all_done

    mov     %ebx, %edi                        # prime = i
    add     $3, %edi                          # prime += 3
    add     %ebx, %edi                        # prime += i
    mov     %edi, %ecx                        # k = prime
    add     %ebx, %ecx                        # k += i
    cmp     $flags_size, %ecx
    jg      _inc_count

  _inner:
    movb    $0, (%esi, %ecx)                  # flags[ k ] = false
    add     %edi, %ecx                        # k += prime
    cmp     $flags_size, %ecx                 # k <= SIZE
    jle     _inner

  _inc_count:
    inc     %edx
    jmp     _outer

  _all_done:
    decl    _iterations
    jnz     _next_iteration

    mov     %edx, %ecx
    call    print_uint32

    movl    $4, %eax                         # write
    movl    $1, %ebx
    lea     done_string, %ecx
    movl    $8, %edx
    int     $0x80

    movl    $1, %eax                         # exit
    xor     %ebx, %ebx
    int     $0x80

/*
 * Function: print_uint32
 * Description: Prints a 32-bit unsigned integer from ECX to stdout.
 * Input: ECX contains the unsigned integer to print.
 * Clobbers: RAX, RCX, RDX, RDI, RSI, RBP, RSP, R11
 * The syscall instruction results in rax, rcx, and r11 getting trashed.
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
    movb    $'0', (%esi)    /* store '0' in the buffer */
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
