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
; y is N
; x is n

    .cr      6502
    .tf      e.hex, AP1, 8
    .or      $1000

echo         .eq     $ffef          ; sends the character in a to the console
prbyte       .eq     $ffdc          ; sends the value in a to the console in hex
exitapp      .eq     $ff1f          ; ends the app / returns to the Apple 1 monitor

array        .eq     $2000          ; starting at offset 8192.
array_digits .eq     200            ; each digit is just a byte

; The Apple 1 reserves locations 0x0024 through 0x002b in the 0 page for the monitor.

var_curarray     .eq $30            ; 2 bytes
var_bigN         .eq $32            ; 1 byte
var_n            .eq $33            ; 1 byte
var_x            .eq $34            ; 2 bytes
var_tmp          .eq $36            ; 1 byte
var_tmp2         .eq $37            ; 1 byte
var_opA          .eq $38            ; 2 bytes
var_opB          .eq $3a            ; 2 bytes
var_divRem       .eq $3c            ; 2 bytes
var_tmpWord      .eq $3e            ; 2 bytes
var_printString  .eq $40            ; 2 bytes
var_arrayOffset  .eq $42            ; 2 bytes

    jmp      start

intString     .az    '32768'

start
    lda      #$0a                   ; every apple 1 app should go to the next line on the console
    jsr      echo

    ; x = 0
    lda      #0
    sta      var_x
    sta      var_x+1
    
    ; for (n = N - 1; n > 0; --n)
    ;     a[n] = 1;
    lda      #array
    sta      var_curarray
    lda      /array
    sta      var_curarray+1
    ldy      #0
    ldx      #0

_initialize_next:
    lda      #1
    sta      (var_curarray),y
    inc      var_curarray
    inx
    cpx      #array_digits
    bne      _initialize_next

    ; a[1] = 2, a[0] = 0;
    lda      #array
    sta      var_curarray
    lda      /array
    sta      var_curarray+1
    lda      #0
    sta      (var_curarray),y
    inc      var_curarray
    lda      #2
    sta      (var_curarray),y

    lda      #array_digits          ; N = digits
    sta      var_bigN

    lda      /array                                             ; array is on a 256-byte page boundry and will never wrap
    sta      var_curarray+1

_outer:
    lda      #9                     ; while (N > 9)
    cmp      var_bigN
    beq      _all_done
    dec      var_bigN               ; N = N - 1
    lda      var_bigN               ; n = N
    sta      var_n

    lda      #array                 ; make var_currarry & array[ n ]
    sta      var_curarray
    clc
    lda      var_n                  ; add n to var_curarray. this won't wrap a page boundry since n < 256
    adc      var_curarray
    sta      var_curarray
                  
_inner
    jsr      div_mod_x_by_n         ; remainder in A and division result in X
    ldy      #0                     ; print_uint and div_mod_x_by_n can trash y, so reset it to 0
    sta      (var_curarray),y
    dec      var_curarray           ; --n for curarray
    lda      (var_curarray),y       ; a[ n - 1 ]
    jsr      mul_a_by_10            ; x = A * 10 ... this is a two-byte quantity
    txa
    clc
    adc      var_x
    sta      var_x
    lda      var_x+1
    adc      #0
    sta      var_x+1
    dec      var_n                  ; actual --n
    bne      _inner

_print_digit:
    lda      var_x
    sta      var_opA
    lda      var_x+1
    sta      var_opA+1
    jsr      print_uint
    jmp      _outer

_all_done:
    lda      #36                    ; print a $ to indicate the app is done. useful for measuring runtime.
    jsr      echo
    jmp      exitapp

; multiply value in register A by 10
; stores 2-byte result in var_x
mul_a_by_10:
    sta      var_tmp
    lda      #0
    sta      var_x
    sta      var_x+1
    lda      #10
    sta      var_tmp2
_mul_10_next:
    lda      var_x
    clc
    adc      var_tmp
    sta      var_x
    lda      var_x+1
    adc      #0
    sta      var_x+1
    dec      var_tmp2
    bne      _mul_10_next
    rts

; divide unsigned 2-byte number in var_x by unsigned 1-byte value n.
; store remainder in register a and quotient in register x. 
div_mod_x_by_n:
    lda      var_x
    sta      var_opB
    lda      var_x+1
    sta      var_opB+1
    lda      var_n
    sta      var_opA
    lda      #0
    sta      var_opA+1
    jsr      uidiv
    ldx      var_opB
    lda      var_divRem
    rts

; divide unsigned 2-byte number in opB by unsigned 2-byte number in opA.
; result is in opB. remainder is in var_divREM. 
uidiv:
    lda      #0               ; Initialize var_divREM to 0
    sta      var_divREM
    sta      var_divREM+1
    ldx      #16              ; There are 16 bits in var_opB
_uidiv_l1:
    asl      var_opB          ; Shift hi bit of var_opB into var_divREM
    rol      var_opB+1        ; (vacating the lo bit, which will be used for the quotient)
    rol      var_divREM
    rol      var_divREM+1
    lda      var_divREM
    sec                       ; Trial subtraction
    sbc      var_opA
    tay
    lda      var_divREM+1
    sbc      var_opA+1
    bcc      _uidiv_l2        ; Did subtraction succeed?
    sta      var_divREM+1     ; If yes, save it
    sty      var_divREM
    inc      var_opB          ; and record a 1 in the quotient
_uidiv_l2:
    dex
    bne      _uidiv_l1
    rts

; print the null-terminated string in var_printString to the console
prstr:
    ldy      #0
_prstr_next:
    lda      (var_printString), y
    beq      _prstr_done
    jsr      echo
    iny
    jmp      _prstr_next
_prstr_done:
    rts

print_uint:
    lda      var_opA
    sta      var_tmpWord
    lda      var_opA+1
    sta      var_tmpWord+1
    lda      #intString
    clc
    adc      #5
    sta      var_arrayOffset
    lda      /intString
    sta      var_arrayOffset+1
    bcc      _print_no_carry
    inc      var_arrayOffset+1
_print_no_carry:
_print_uint_again:
    lda      var_tmpWord
    sta      var_opB
    lda      var_tmpWord+1
    sta      var_opB+1
    lda      #10
    sta      var_opA
    lda      #0
    sta      var_opA+1
    jsr      uidiv
    lda      var_arrayOffset
    bne      _print_no_hidec
    dec      var_arrayOffset+1
_print_no_hidec:
    dec      var_arrayOffset
    lda      var_divRem
    clc
    adc      #48
    ldy      #0
    sta      (var_arrayOffset), y
    lda      var_opB+1
    sta      var_tmpWord+1
    lda      var_opB
    sta      var_tmpWord
    bne      _print_uint_again
    cmp      var_opB+1
    bne      _print_uint_again
    lda      var_arrayOffset
    sta      var_printString
    lda      var_arrayOffset+1
    sta      var_printString+1
    jsr      prstr
    rts

