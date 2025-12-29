# compute the first 192 digits of e
# replicates this C code:
#    #define DIGITS_TO_FIND 200 /*9009*/
#    int main() {
#      int N = DIGITS_TO_FIND;
#      int x = 0;
#      int a[ DIGITS_TO_FIND ];
#      int n;
#
#      for (n = N - 1; n > 0; --n)
#          a[n] = 1;
#
#      a[1] = 2, a[0] = 0;
#      while (N > 9) {
#          n = N--;
#          while (--n) {
#              a[n] = x % n;
#              x = 10 * a[n-1] + x/n;
#          }
#          printf("%d", x);
#      }
#  
#      printf( "\ndone\n" );
#      return 0;
#    }
#
# array is in  edi
# N is in      ebx
# x is in      eax
# n is in      esi
# 10 is in     ecx

.equ array_size, 200

.data
.p2align 4
.comm _array, array_size
.p2align 4
.comm buffer 21
.p2align 4
done_string: .asciz "\ndone\n"

.global _start
.text
_start:
    lea     [_array], %edi                    # for (n = N - 1; n > 0; --n); a[n] = 1;
    mov     $0x01010101, %eax                 # initialize 4 array entries at a time
    mov     $array_size / 4, %ecx
    cld
    rep     stosl

    lea     [_array], %edi                    # for (n = N - 1; n > 0; --n); a[n] = 1;
    movb     $0, (%edi)                       # a[0] = 0;
    movb     $2, 1(%edi)                      # a[1] = 2;

    mov     $10, %ecx
    mov     $array_size, %ebx                 # N = DIGITS_TO_FIND;
    xor     %eax, %eax                        # x = 0;

  _outer:
    cmp     $9, %ebx                          # while (N > 9)
    je      _loop_done
    dec     %ebx                              # N--
    mov     %ebx, %esi                        # n = N
    xor     %edx, %edx                        # prepare for division

  _inner:
    div     %esi                              # x / n. quotient is in rax, remainder in rdx
    mov     %eax, %ebp                        # save the quotient for later
    movb    %dl, (%edi,%esi)                  # a[n] = x % n;
    movzbl  -1(%edi,%esi,1), %eax             # load a[n-1]
    mul     %ecx                              # x = 10 * a[n-1]. rdx will be 0 after this
    add     %ebp, %eax                        # x += x/n
#    xor     %edx, %edx
    dec     %esi                              # n--
    jne     _inner                            # while (--n)

  _print_digit:
    push    %ecx
    mov     %eax, %ecx
    push    %eax
    push    %ebx
    push    %edi
    call    print_uint32
    pop     %edi
    pop     %ebx
    pop     %eax
    pop     %ecx
    jmp     _outer

  _loop_done:
    mov     $4, %eax                         # write
    mov     $1, %ebx
    lea     done_string, %ecx
    mov     $6, %edx
    int     $0x80

    mov     $1, %eax                         # exit
    xor     %ebx, %ebx
    int     $0x80

/*
 * Function: print_uint32
 * Description: Prints a 32-bit unsigned integer from ECX to stdout.
 * Input: ECX contains the unsigned integer to print.
 * Clobbers: EAX, EBX, ECX, EDX, EDI, ESI
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
