! compute the first 192 digits of e
! replicates this C code:
!    #define DIGITS_TO_FIND 200 /*9009*/
!    int main() {
!      int N = DIGITS_TO_FIND;
!      int x = 0;
!      int a[ DIGITS_TO_FIND ];
!      int n;
!
!      for (n = N - 1; n > 0; --n)
!          a[n] = 1;
!
!      a[1] = 2, a[0] = 0;
!      while (N > 9) {
!          n = N--;
!          while (--n) {
!              a[n] = x % n;
!              x = 10 * a[n-1] + x/n;
!          }
!          printf("%d", x);
!      }
!
!      printf( "\ndone\n" );
!      return 0;
!    }
!
! array is in %l2
! & a[n] is in %l1
! n is in %l5
! x is in %l4
! N is in %l3
   
.section    ".text"
    .align 8
.done_string:
    .asciz "\ndone\n"
.number_string:
    .asciz "%u"
.equ array_size, 200
    .align 8
.array:
    .zero 2*array_size    

    .section .text.startup,"ax",@progbits
    .align 4
    .global main
    .type main, #function
    .proc 04
main:
    .cfi_startproc
    save %sp, -96, %sp
    .cfi_window_save
    .cfi_register 15, 31
    .cfi_def_cfa_register 30

    sethi 64, %l0
    add %l0, 1, %l0
    mov array_size * 2, %l1
    sub %l1, 4, %l1
    sethi %hi(.array), %l2
    add %l2, %lo(.array), %l2
  .init_next:
    st %l0, [%l2 + %l1]
    subcc %l1, 4, %l1
    bne,a .init_next
    nop
    
    sth %g0, [%l2]
    mov 2, %l0
    sth %l0, [%l2 + 2]

    mov 10, %l6
    mov array_size, %l3
    clr %l4
    wr 0, %y

  outer:
    cmp %l3, 9             ! while ( N > 9 )
    beq loop_done
    sub %l3, 1, %l3        ! N = N - 1.  in the beq delay slot, always executed
    mov %l3, %l5           ! n = N
    mov %l2, %l1           ! move array pointer to %l1
    add %l1, %l5, %l1      ! add n to the pointer twice because each element is 2 bytes
    add %l1, %l5, %l1

  inner:
    udiv %l4, %l5, %o0     ! x / n
    umul %o0, %l5, %l0     ! begin to compute the remainder
    sub %l4, %l0, %l0      ! set %l0 to x % n, which is ( n - ( ( x / n ) * n ) )
    sth %l0, [%l1]         ! a[n] = x % n
    sub %l1, 2, %l1        ! move the current array pointer down one element
    lduh [%l1], %l0        ! load a[ n - 1 ] to %l0
    umul %l0, 10, %l0
    subcc %l5, 1, %l5      ! while ( --n )
    bne inner
    add %l0, %o0, %l4      ! x = 10 * a[ n - 1 ] + x / n. in the bne delay slot, always executed
 
  print_digit:
    call print_unsigned
    mov %l4, %o0          ! in the delay slot
    ba,a outer
    
  loop_done:
    sethi %hi(.done_string), %o0
    add %o0, %lo(.done_string), %o0 
    call puts, 0
    nop

    mov 0, %i0
    jmp %i7+8
    restore
.cfi_endproc

! print_unsigned: Prints a 32-bit unsigned integer to stdout.
! Argument:
!   %o0: The unsigned integer to print.
    .align 4
    .global print_unsigned
    .section ".text"
print_unsigned:
    save  %sp, -96, %sp     ! Create a new stack frame. 96 is a common frame size.
                            ! The local variables (including our buffer) will be in the
                            ! newly allocated space on the stack.

    ! Special case for input number 0
    cmp   %i0, 0
    be    .L_print_zero
    nop
    mov   %i0, %o3          ! Copy number to %o3 for loop processing.
    set   10, %o4           ! Divisor (10) for decimal conversion.
    add   %fp, -4, %o1      ! Set %o1 as a pointer to the buffer on the stack.
                            ! We will build the string from right to left, starting at the
                            ! end of a 10-digit buffer, plus null terminator.

.L_convert_loop:
    mov   %o3, %o5          ! Save the number to convert.
    udiv  %o5, %o4, %o3     ! Divide by 10. %o3 = %o5 / 10. (quotient)
    smul  %o3, %o4, %g1     ! Calculate quotient * 10 in %g1.
    sub   %o5, %g1, %o5     ! Calculate remainder in %o5: %o5 - %g1. (remainder)

    add   %o5, '0', %o5     ! Convert digit to ASCII character.
    stb   %o5, [%o1]        ! Store the ASCII character in the buffer.
    sub   %o1, 1, %o1       ! Move buffer pointer to the left.

    cmp   %o3, 0            ! Check if the quotient is zero.
    bne   .L_convert_loop   ! Loop if not.
    nop                     ! Delay slot.

    inc   %o1               ! Point to the start of the final string.
    sub   %fp, %o1, %o2     ! Calculate the length of the string.
    sub   %o2, 3, %o2  

    ba    .L_call_write
    nop

.L_print_zero:
    sethi %hi(.L_zero_str), %o1  ! Get high 22 bits of string address.
    or    %o1, %lo(.L_zero_str), %o1  ! Get low 10 bits.
    mov   1, %o2                 ! Length is 1 character.

.L_call_write:
    mov   4, %g1            ! write syscall
    mov   1, %o0            ! File descriptor 1 (stdout)
    ! %o1 already holds the buffer address
    ! %o2 already holds the length
    t    0x10               ! Trap to kernel for syscall.
    ret
    restore                 ! Restore registers and return.

.section ".data"
.L_zero_str:
    .ascii "0\n"            ! String for special case '0'.

.section        .note.GNU-stack,"",@progbits
