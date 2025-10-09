; build on Windows for AMD64 like this:
;   ml64 /nologo /Fl%1.lst /Zd /Zf /Zi %1.asm /link /OPT:REF /nologo /PDB:%1.pdb ^
;     /subsystem:console /defaultlib:kernel32.lib ^
;     /defaultlib:user32.lib ^
;     /defaultlib:libucrt.lib ^
;     /defaultlib:libcmt.lib ^
;     /entry:mainCRTStartup
;
; compute the first 192 digits of e
; replicates this C code:
;    #define DIGITS_TO_FIND 200 /*9009*/
;    int main() {
;      int N = DIGITS_TO_FIND;
;      int x = 0;
;      int a[ DIGITS_TO_FIND ];
;      int n;
;
;      for (n = N - 1; n > 0; --n)
;          a[n] = 1;
;
;      a[1] = 2, a[0] = 0;
;      while (N > 9) {
;          n = N--;
;          while (--n) {
;              a[n] = x % n;
;              x = 10 * a[n-1] + x/n;
;          }
;          printf("%d", x);
;      }
;  
;      printf( "\ndone\n" );
;      return 0;
;    }
;
; amd64 calling convention on windows:
;   arguments:   rcx, rdx, r8, r9
;   return:      rax
;   volatile:    rax, rcx, rdx, r8, r9, r10, r11
;   nonvolatile: rbx, rbp, rdi, rsi, rsp, r12, r13, r14, r15
;
; array is in  r12
; N is in      r13
; x is in      rax
; n is in      r15
; 10 is in     rdi
; stdout is in r14

extern puts: PROC
extern GetStdHandle: PROC
extern WriteFile: PROC

array_size            equ 200

data_e SEGMENT ALIGN( 4096 ) 'DATA'
    array             db array_size dup(?)
  align 64
    buffer            db 21 dup (0)         ; Buffer to store the ASCII string (max 20 digits for 64-bit + 1 for null terminator)
  align 64
    done_string       db 13,10,'done',13,10,0
data_e ENDS

code_e SEGMENT ALIGN( 4096 ) 'CODE'

main PROC ; linking with the C runtime, so main will be invoked
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32 + 8 * 4

    mov     rcx, -11                        ; STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     r14, rax

    mov     rdi, 10
    lea     r12, [array]                    ; for (n = N - 1; n > 0; --n); a[n] = 1;
    mov     rcx, 0101010101010101h          ; initialize 8 array entries at a time
    mov     rbx, array_size - 8

  _initialize_next:
    mov     QWORD PTR [r12 + rbx], rcx
    sub     rbx, 8
    jge     _initialize_next

    mov     BYTE PTR [r12], 0               ; a[0] = 0;
    mov     BYTE PTR [r12 + 1], 2           ; a[1] = 2;

    mov     r13, array_size                 ; N = DIGITS_TO_FIND;
    xor     rax, rax                        ; x = 0;

  _outer:
    cmp     r13, 9                          ; while (N > 9)
    je      _loop_done
    dec     r13                             ; N--
    mov     r15, r13                        ; n = N
    xor     rdx, rdx                        ; prepare for division

  _inner:
    div     r15                             ; x / n. quotient is in rax, remainder in rdx
    mov     r9, rax                         ; save quotient in r9 for later
    mov     BYTE PTR [r12+r15], dl          ; a[n] = x % n;
    movzx   eax, BYTE PTR [r12+r15-1]       ; load a[n-1]
    mul     rdi                             ; x = 10 * a[n-1]. rdx will be 0 after this
    add     rax, r9                         ; x += x/n
    dec     r15                             ; n--
    jne     _inner                          ; while (--n)

  _print_digit:
    mov     rcx, rax
    call    print_uint64
    jmp     _outer

  _loop_done:
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

code_e ENDS
END

