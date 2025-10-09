! compute the first 192 digits of e
! sparc v7 version (with no umul or udiv instructions)
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
! tmpdiv is in %l6
! n is in %l5
! x is in %l4
! N is in %l3
! array is in %l2
! & a[n] is in %l1
   
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
    mov %l4, %o0           ! prepare to compute x%n and x/n
    call .udiv             ! on return, o0 has the quotient and o1 has the remainder
    mov %l5, %o1           ! in the delay slot; argument o1 set prior to the call above

    sth %o1, [%l1]         ! a[n] = x % n
    sub %l1, 2, %l1        ! move the current array pointer down one element
    lduh [%l1], %o1        ! load a[ n - 1 ] to %o0
    add %o1, %o1, %o2      ! 10 * a[ n - 1 ] step 1 -- o1 has 2x
    sll %o1, 3, %o1        ! step 2 -- o0 has 8x
    add %o1, %o2, %o1      ! step 3 -- o0 has 10x

    subcc %l5, 1, %l5      ! while ( --n )
    bne inner
    add %o1, %o0, %l4      ! x = 10 * a[ n - 1 ] + x / n. in the bne delay slot, always executed
 
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

.umul10:
    add %o0, %o0, %o1
    add %o1, %o1, %o1
    add %o1, %o1, %o1
    add %o0, %o0, %o0
    retl !leaf-routine return
    add %o0, %o1, %o0       ! in the delay slot, executed prior to the retl

/*
    * taken from the Sparc v8 Architecture Manual.
    * Procedure to perform a 32 by 32 unsigned multiply.
    * Pass the multiplier in %o0,and the multiplic and in %o1.
    * The least significant 32 bits of the result will be returned in %o0,
    * and the most significant in %o1.
    *
    * This code indicates that overflow has occurred by leaving the Z condition
    * code clear. The following call sequence would be used if you wish to
    * deal with overflow:
    *
    * call .umul
    * nop !(or setup last parameter here)
    * bnz overflow_code 
*/
.global .umul
.umul:
    or %o0,%o1,%o4 ! logical or of multiplier and multiplicand
    mov %o0,%y ! multiplier to Y register
    andncc %o4,0xfff,%o5 ! mask out lower 12 bits
    be mul_shortway ! can do it the short way
    andcc %g0,%g0,%o4 ! zero the partial product and clear N and V conditions
 
    !longmultiply
 
    mulscc %o4,%o1,%o4 !firstiterationof33
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4
    mulscc %o4,%o1,%o4 ! 32nd iteration
    mulscc %o4,%g0,%o4 ! last iteration only shifts

    tst %o1
    bge 1f
    nop
    add %o4,%o0,%o4
  1:
    rd %y,%o0 !return least sig. bits of prod
    retl !leaf-routine return
    addcc %o4,%g0,%o1 ! delay slot; return high bits and set zerobit appropriately

  mul_shortway:
    mulscc %o4,%o1,%o4 !firstiterationof13
    mulscc %o4,%o1,%o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4
    mulscc %o4, %o1, %o4 ! 12th iteration
    mulscc %o4, %g0, %o4 ! last iteration only shifts
    
    rd %y, %o5
    sll %o4, 12, %o4 ! left shift partial product by 12 bits
    srl %o5, 20, %o5 ! right shift product by 20 bits
    or %o5, %o4, %o0 ! merge for true product

    ! The delay instruction (addcc) moves zero into %o1,
    ! sets the zero condition code, and clears the other conditions.
    ! This is the equivalent result to a long umultiply which doesn’t overflow.
    retl ! leaf-routine return
    addcc %g0, %g0, %o1

/*
 * Unsigned 32-bit integer division for SPARC V7 as a leaf procedure.
 * This routine assumes the divisor is non-zero.
 * Arguments:
 *  %o0: Dividend
 *  %o1: Divisor
 * Returns:
 *  %o0: Quotient
 *  %o1: Remainder
*/
        .global .udiv
.udiv:
    mov     %g0, %g1        ! %g1 = 0 (quotient)
    cmp     %o0, %o1        ! Compare remainder with divisor
    bl,a    divide_end      ! Branch if less (remainder < divisor)
    nop
    sub     %o0, %o1, %o0   

divide_loop:
    add     %g1, 1, %g1     
    cmp     %o0, %o1        ! Compare remainder with divisor
    bge,a   divide_loop
    sub     %o0, %o1, %o0   ! delay slot subtraction. only executed if the branch to loop is taken

divide_end:
    mov     %o0, %o1        ! move remainder to o1
    retl                    ! Return from a leaf function
    mov     %g1, %o0        ! delay slot. executed prior to retl. %o0 = quotient result

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
    mov   %i0, %l3          ! Copy number to %l3 for loop processing.
    add   %fp, -4, %l1      ! Set %o1 as a pointer to the buffer on the stack.
                            ! We will build the string from right to left, starting at the
                            ! end of a 10-digit buffer, plus null terminator.

.L_convert_loop:
    mov   %l3, %l5          ! Save the number to convert.
    mov   %l3, %o0
    call  .udiv             ! divide the input number by 10
    mov   10, %o1           ! in the delay slot. executed prior to the call above
    mov   %o0, %l3          ! quotient

    add   %o1, '0', %o1     ! Convert digit to ASCII character.
    stb   %o1, [%l1]        ! Store the ASCII character in the buffer.
    sub   %l1, 1, %l1       ! Move buffer pointer to the left.

    cmp   %l3, 0            ! Check if the quotient is zero.
    bne   .L_convert_loop   ! Loop if not.
    nop                     ! Delay slot.

    inc   %l1               ! Point to the start of the final string.
    sub   %fp, %l1, %l2     ! Calculate the length of the string.
    sub   %l2, 3, %l2  

    ba    .L_call_write
    nop

.L_print_zero:
    sethi %hi(.L_zero_str), %l1  ! Get high 22 bits of string address.
    or    %l1, %lo(.L_zero_str), %l1  ! Get low 10 bits.
    mov   1, %l2                 ! Length is 1 character.

.L_call_write:
    mov   4, %g1            ! write syscall
    mov   1, %o0            ! File descriptor 1 (stdout)
    mov   %l1, %o1
    mov   %l2, %o2
    t    0x10               ! Trap to kernel for syscall.
    ret
    restore                 ! Restore registers and return.

.section ".data"
.L_zero_str:
    .ascii "0\n"            ! String for special case '0'.    
 
.section        .note.GNU-stack,"",@progbits
