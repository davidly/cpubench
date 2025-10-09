; build on Windows for AMD64 like this:
;   ml64 /nologo /Fl%1.lst /Zd /Zf /Zi %1.asm /link /OPT:REF /nologo /PDB:%1.pdb ^
;     /subsystem:console /defaultlib:kernel32.lib ^
;     /defaultlib:user32.lib ^
;     /defaultlib:libucrt.lib ^
;     /defaultlib:libcmt.lib ^
;     /entry:mainCRTStartup
;
; The BYTE magazine classic sieve from 1981:
;   #define SIZE 8190
;
;   char flags[SIZE+1];
;
;   int main()
;           {
;           int i,k;
;           int prime,count,iter;
;
;           for (iter = 1; iter <= 10; iter++) {    /* do program 10 times */
;                   count = 0;                      /* initialize prime counter */
;                   for (i = 0; i <= SIZE; i++)     /* set all flags TRUE */
;                           flags[i] = TRUE;
;                   for (i = 0; i <= SIZE; i++) {
;                           if (flags[i]) {         /* found a prime */
;                                   prime = i + i + 3;      /* twice index + 3 */
;                                   for (k = i + prime; k <= SIZE; k += prime)
;                                           flags[k] = FALSE;       /* kill all multiples */
;                                   count++;                /* primes found */
;                                   }
;                           }
;                   }
;           printf("%d primes.\n",count);           /*primes found in 10th pass */
;           return 0;
;           }
;
; amd64 calling convention on windows:
;   arguments:   rcx, rdx, r8, r9
;   return:      rax
;   volatile:    rax, rcx, rdx, r8, r9, r10, r11
;   nonvolatile: rbx, rbp, rdi, rsi, rsp, r12, r13, r14, r15
;
; k         r10
; flags     r11
; size      r12
; prime     r13
; stdout    r14
; count     rdx
; i         r15
; iter      r9

extern puts: PROC
extern GetStdHandle: PROC
extern WriteFile: PROC

flags_size      equ 8190
size_full       equ 8192

data_sieve SEGMENT ALIGN( 4096 ) 'DATA'
    flags             db flags_size dup(?)
  align 64
    buffer            db 21 dup (0)         ; Buffer to store the ASCII string (max 20 digits for 64-bit + 1 for null terminator)
  align 64
    done_string       db ' primes.',13,10,0
data_sieve ENDS

code_sieve SEGMENT ALIGN( 4096 ) 'CODE'

main PROC ; linking with the C runtime, so main will be invoked
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32 + 8 * 4

    mov     rcx, -11                        ; STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     r14, rax

    mov     r9, 10                          ; iter <= 10

  _next_iteration:
    lea     r11, [flags]                    ; for (i = 0; i <= SIZE; i++)
    mov     rcx, 0101010101010101h          ; initialize 8 array entries at a time
    mov     rbx, size_full - 8

  _initialize_next:
    mov     qword ptr [r11 + rbx], rcx      ; flags[i] = TRUE
    sub     rbx, 8
    jge     _initialize_next

    mov     r15, -1                         ; i = -1
    xor     rdx, rdx                        ; count = 0

  _outer:
    inc     r15
    cmp     byte ptr [r11 + r15], 0
    je      _outer                          ; if flags[i]

    cmp     r15, flags_size
    jg      _all_done

    mov     r13, r15                        ; prime = i
    add     r13, 3                          ; prime += 3
    add     r13, r15                        ; prime += i
    mov     r10, r13                        ; k = prime
    add     r10, r15                        ; k += i
    cmp     r10, flags_size
    jg      _inc_count

  _inner:
    mov     byte ptr [r11 + r10], 0         ; flags[ k ] = false
    add     r10, r13                        ; k += prime
    cmp     r10, flags_size                 ; k <= SIZE
    jle     _inner

  _inc_count:
    inc     rdx
    jmp     _outer

  _all_done:
    dec     r9
    jnz     _next_iteration

    mov     rcx, rdx
    call    print_uint64
    lea     rcx, done_string
    call    puts

    xor     rax, rax
    leave
    ret
main ENDP

; print_uint64(rcx: unsigned 64-bit integer)
; Prints an unsigned 64-bit integer to the standard output.
; Preserves registers that are not part of the standard volatile set.
print_uint64 PROC
    ; Standard Windows x64 ABI prologue: Allocate stack space for parameters and save non-volatile registers.
    sub rsp, 88             ; Allocate stack space (shadow space + local variables)
    mov [rsp+80], rbx       ; Save non-volatile registers
    mov [rsp+72], rbp
    mov [rsp+64], rsi
    mov [rsp+56], rdi

    mov rbx, rcx            ; Copy the integer from rcx into rbx for processing

    ; Handle the special case of the number 0
    cmp rbx, 0
    jne _not_zero
    mov byte ptr [rsp+10], '0'  ; Place '0' in the buffer
    mov rdi, rsp
    inc rdi                     ; Move past the digit
    jmp _print_string

  _not_zero:
    mov rdi, rsp            ; Use the stack as a temporary buffer
    add rdi, 19             ; Point to the last byte of the buffer for reverse insertion
    mov byte ptr [rdi], 0   ; Null-terminate the string
    mov r8, 10              ; r8 holds the divisor (10)

  _division_loop:
    xor rdx, rdx            ; Clear rdx for 64-bit division
    mov rax, rbx            ; Move dividend into rax
    div r8                  ; Divide rax by r8. Quotient in rax, remainder in rdx.
    mov rbx, rax            ; Move quotient back to rbx
    add rdx, 48             ; Convert remainder (digit 0-9) to ASCII
    dec rdi                 ; Move backward in the buffer
    mov byte ptr [rdi], dl  ; Store the ASCII digit
    cmp rax, 0
    jne _division_loop      ; Continue if the quotient is not zero

  _print_string:
    ; Use the Windows API WriteFile to output the string to stdout
    ; Arguments for WriteFile:
    ; rcx: hFile (handle to stdout)
    ; rdx: lpBuffer (pointer to the string)
    ; r8: nNumberOfBytesToWrite
    ; r9: lpNumberOfBytesWritten (pointer to a variable to hold the count)
    ; stack+32: lpOverlapped (NULL)

    ; Set up the arguments for WriteFile
    mov rcx, r14            ; hFile (handle from GetStdHandle)
    mov rdx, rdi            ; lpBuffer (pointer to our string)
    sub rsp, 32             ; Shadow space for WriteFile

    ; Calculate the string length
    xor rax, rax
    mov rsi, rdi
  _find_length:
    cmp byte ptr [rsi], 0
    je _length_found
    inc rax
    inc rsi
    jmp _find_length

  _length_found:
    mov r8, rax             ; nNumberOfBytesToWrite
    xor r9, r9              ; not interested in the result
    mov qword ptr [rsp+32], 0 ; lpOverlapped (NULL)

    call WriteFile          ; Call the API function

    add rsp, 32             ; Restore shadow space for WriteFile
    
    ; Restore non-volatile registers and exit
    mov rbx, [rsp+80]       ; Restore saved registers
    mov rbp, [rsp+72]
    mov rsi, [rsp+64]
    mov rdi, [rsp+56]
    add rsp, 88
    ret
print_uint64 ENDP

code_sieve ENDS
END

