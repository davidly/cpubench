! the BYTE magazine sieve benchmark in sparc assembly
!
!    #define SIZE 8190
!
!    char flags[SIZE+1];
!
!    int main()
!            {
!            int i,k;
!            int prime,count,iter;
!
!            for (iter = 1; iter <= 10; iter++) {    /* do program 10 times */
!                    count = 0;                      /* initialize prime counter */
!                    for (i = 0; i <= SIZE; i++)     /* set all flags TRUE */
!                            flags[i] = TRUE;
!                    for (i = 0; i <= SIZE; i++) {
!                            if (flags[i]) {         /* found a prime */
!                                    prime = i + i + 3;      /* twice index + 3 */
!                                    for (k = i + prime; k <= SIZE; k += prime)
!                                            flags[k] = FALSE;       /* kill all multiples */
!                                    count++;                /* primes found */
!                                    }
!                            }
!                    }
!            printf("%d primes.\n",count);           /*primes found in 10th pass */
!            return 0;
!            }
!
! k l0
! flags l1
! size l2
! prime l3
! count l4
! i l5
! iter l6

.equ size, 8190
.equ sizefull, (size+2)

.section ".text"
    .align 8
.done_string:
    .asciz "%u primes.\n"
.align 8
.flags:
    .zero size + 1

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

    mov 1, %l6

  nextiter:    
    sethi %hi(0x01010101), %o0
    or %o0, %lo(0x01010101), %o0
    sethi %hi(.flags), %l1
    add %l1, %lo(.flags), %l1
    sethi %hi(sizefull), %o1
    add %o1, %lo(sizefull), %o1

  finit:
    subcc %o1, 4, %o1
    bg finit 
    st %o0, [%l1 + %o1 ]       ! delay slot

    sethi %hi(size), %l2
    add %l2, %lo(size), %l2
    clr %l4
    clr %l5

  outer:
    ldub [%l1 + %l5], %o0      ! if ( flags[i] )
    cmp %o0, 0
    be,a outer
    add %l5, 1, %l5            ! i++;  delay slot

    cmp %l5, %l2               ! i <= SIZE
    bg alldone
    add %l5, 3, %l3            ! prime = i + 3; delay slot
    add %l5, %l3, %l3          ! prime += i
    mov %l5, %l0               ! k = i

  inner:
    add %l0, %l3, %l0          ! k += prime
    cmp %l0, %l2               ! k <= SIZE
    ble,a inner
    stb %g0, [%l1 + %l0]       ! flags[k] = FALSE; delay slot
    
  inccount:
    inc %l4                    ! count++
    ba outer
    inc %l5                    ! i++; delay slot

  alldone:
    cmp %l6, 10
    bl nextiter
    inc %l6                    ! delay slot
    
    sethi %hi(.done_string), %o0
    add %o0, %lo(.done_string), %o0       
    mov %l4, %o1
    call printf, 0
    mov 0, %i0                 ! delay slot
    jmp   %i7+8
    restore
.cfi_endproc

.section        .note.GNU-stack,"",@progbits
