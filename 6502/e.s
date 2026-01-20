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

    .cr      6502
    .tf      e.hex, AP1, 8
    .or      $200

echo         .eq     $ffef          ; sends the character in a to the console
prbyte       .eq     $ffdc          ; sends the value in a to the console in hex
exitapp      .eq     $ff1f          ; ends the app / returns to the Apple 1 monitor

; The Apple 1 reserves locations 0x0024 through 0x002b in the 0 page for the monitor.

var_bigN         .eq $10            ; 1 byte
var_n            .eq $11            ; 1 byte
var_x            .eq $12            ; 2 bytes
var_tmp          .eq $14            ; 2 bytes
var_opA          .eq $16            ; 2 bytes
var_opB          .eq $18            ; 2 bytes
var_divRem       .eq $1a            ; 2 bytes
var_printString  .eq $1c            ; 2 bytes
var_arrayOffset  .eq $1e            ; 2 bytes

array            .eq $38            ; starting at offset 0x38 through 0xff
array_digits     .eq 200            ; each digit is just a byte

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
    ldx      #array_digits-1

_initialize_next:
    lda      #1
    sta      array,x
    dex
    bne      _initialize_next

    ; a[1] = 2, a[0] = 0;
    lda      #0
    sta      array,x
    lda      #2
    sta      array+1,x

    lda      #array_digits          ; N = digits
    sta      var_bigN

_outer:
    lda      #9                     ; while (N > 9)
    cmp      var_bigN
    beq      _all_done
    dec      var_bigN               ; N = N - 1
    lda      var_bigN               ; n = N
    sta      var_n
    tay                             ; put n in Y

_inner
    jsr      div_mod_x_by_n         ; remainder in A and division result in X
    ldy      var_n                  ; y may have been trashed in div_mod; restore it
    sta      array,y
    lda      array-1,y              ; a[ n - 1 ]
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
    sta      var_x                  ; store input in x
    lda      #$00
    sta      var_x+1                ; clear result's high byte
    lda      var_x                  ; restore x into a
    asl      a                      ; a = 2x
    rol      var_x+1                ; carry into high byte
    asl      a                      ; a = 4x
    rol      var_x+1                ; carry into high byte
    clc                             ; clear carry for addition
    adc      var_x                  ; a = 4x + x = 5x
    sta      var_x                  ; store 5x low byte
    lda      var_x+1                ; load high byte
    adc      #0                     ; add carry from (4x + x)
    sta      var_x+1                ; store 5x high byte
    asl      var_x                  ; low byte (5x * 2) = 10x
    rol      var_x+1                ; final shift into high byte for 10x
    rts

; Input:  Dividend in two bytes at var_x
;         Divisor in one byte at var_n
; Output: Quotient in Register X
;         Remainder in Register A
div_mod_x_by_n:
    lda      var_x                  ; copy var_x so it isn't modified
    sta      var_tmp
    lda      var_x+1
    sta      var_tmp+1
    lda      #0                     ; initialize remainder (a) to 0
    ldx      #16                    ; loop for each of the 16 bits in the dividend

div_loop:
    asl      var_tmp                ; shift dividend low byte left
    rol      var_tmp+1              ; shift dividend high byte left, carry into remainder
    rol      a                      ; rotate dividend's high bit into remainder (a)
    cmp      var_n                  ; compare remainder (a) with divisor in var_n
    bcc      skip_sub               ; if remainder < divisor, skip subtraction
    sbc      var_n                  ; remainder = remainder - divisor
    inc      var_tmp                ; set the lowest bit of the quotient

skip_sub:
    dex                             ; decrement bit counter
    bne      div_loop               ; repeat for all 16 bits

    ldx      var_tmp                ; move quotient (low byte of result) to x
    rts                             ; return with remainder in a, quotient in x

; divide unsigned 2-byte number in opB by unsigned 2-byte number in opA.
; result is in opB. remainder is in var_divREM.
uidiv:
    lda      #0                     ; Initialize var_divREM to 0
    sta      var_divREM
    sta      var_divREM+1
    ldx      #16                    ; There are 16 bits in var_opB
_uidiv_l1:
    asl      var_opB                ; Shift hi bit of var_opB into var_divREM
    rol      var_opB+1              ; (vacating the lo bit, which will be used for the quotient)
    rol      var_divREM
    rol      var_divREM+1
    lda      var_divREM
    sec                             ; Trial subtraction
    sbc      var_opA
    tay
    lda      var_divREM+1
    sbc      var_opA+1
    bcc      _uidiv_l2              ; Did subtraction succeed?
    sta      var_divREM+1           ; If yes, save it
    sty      var_divREM
    inc      var_opB                ; and record a 1 in the quotient
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
    sta      var_tmp
    lda      var_opA+1
    sta      var_tmp+1
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
    lda      var_tmp
    sta      var_opB
    lda      var_tmp+1
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
    sta      var_tmp+1
    lda      var_opB
    sta      var_tmp
    bne      _print_uint_again
    cmp      var_opB+1
    bne      _print_uint_again
    lda      var_arrayOffset
    sta      var_printString
    lda      var_arrayOffset+1
    sta      var_printString+1
    jsr      prstr
    rts

