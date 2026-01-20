; BYTE magazine benchmark
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
; should produce 0x076b = 1899

    .cr      6502
    .tf      sieve.hex, AP1, 8
    .or      $1000

echo         .eq     $ffef          ; sends the character in a to the console
prbyte       .eq     $ffdc          ; sends the value in a to the console in hex
exitapp      .eq     $ff1f          ; ends the app / returns to the Apple 1 monitor

addr_flags   .eq     $2000          ; 8192 bytes starting at offset 8192. You need at least 16k of RAM on your Apple I
len_flags    .eq     $2000          ; amount of RAM allocated and initialized to 1
size_flags   .eq     $1ffe          ; 8190 is size. sieve writes to 8191 entries. one extra byte allocated as a flags to terminate the loop
beyond_flags .eq     addr_flags+size_flags

; The Apple 1 reserves locations 0x0024 through 0x002b in the 0 page for the monitor.

var_zeroflags    .eq $30
var_k            .eq $32
var_prime        .eq $34
var_count        .eq $36
var_i            .eq $38
var_iter         .eq $3a  ; just a byte is used
var_curflags     .eq $3c

; location of starting address for memset
memset_ptr       .eq $40
memset_len       .eq $42

start:
    lda      #$0a                   ; every apple 1 app should go to the next line on the console
    jsr      echo

    lda      #10
    sta      var_iter

.next_iteration:
    lda      #addr_flags
    sta      memset_ptr
    lda      /addr_flags
    sta      memset_ptr+1
    lda      #len_flags
    sta      memset_len
    lda      /len_flags
    sta      memset_len+1
    lda      #1
    jsr      memset
    ldy      #0

    lda      #addr_flags
    sta      var_curflags
    lda      #0
    sta      var_count
    sta      var_count+1
    lda      /addr_flags
    sta      var_curflags+1

.outer:
    lda      (var_curflags), y
    bne      .found_one
    inc      var_curflags
    bne      .outer
    inc      var_curflags+1
    jmp      .outer

.found_one:
    ; set i and prime based on the curflags pointer
    sec
    lda      var_curflags
    sbc      #addr_flags
    sta      var_i
    sta      var_prime
    lda      var_curflags+1
    sbc      /addr_flags
    sta      var_i+1
    sta      var_prime+1

    ; if i > size, we're done
    lda      var_i+1
    cmp      /size_flags
    beq      .i_chk_eq
    bcc      .setup_outer
    jmp      .all_done

.i_chk_eq:
    lda      var_i
    cmp      #size_flags
    bcc      .setup_outer
    jmp      .all_done

.setup_outer:
    ; prime = prime + 3
    clc
    lda      var_i
    adc      #3
    sta      var_prime
    lda      var_i+1
    adc      #0
    sta      var_prime+1

    ; prime += i
    clc
    lda      var_i
    adc      var_prime
    sta      var_prime
    lda      var_i+1
    adc      var_prime+1
    sta      var_prime+1

    ; k = prime + i
    clc
    lda      var_i
    adc      var_prime
    sta      var_k
    lda      var_i+1
    adc      var_prime+1
    sta      var_k+1

    ; if k > size then don't execute the inner loop
    lda      var_k+1
    cmp      /size_flags
    beq      .k_chk_eq
    bcs      .inc_count
    jmp      .setup_inner

.k_chk_eq:
    lda      var_k
    cmp      #size_flags
    bcs      .inc_count

.setup_inner:
    clc
    lda      #addr_flags
    adc      var_k
    sta      var_zeroflags
    lda      /addr_flags
    adc      var_k+1
    sta      var_zeroflags+1

.inner:
    ; flags[ k ] = false
    lda      #0
    sta      (var_zeroflags), y

    ; k += prime
    clc
    lda      var_zeroflags
    adc      var_prime
    sta      var_zeroflags
    lda      var_zeroflags+1
    adc      var_prime+1
    sta      var_zeroflags+1

    ; k <= size (but do the check var_zeroflags <= ( var_flags + size_flags ) )
    ; already loaded above    lda      var_zeroflags+1
    cmp      /beyond_flags
    beq      .zero_chk_eq
    bcc      .inner
    jmp      .inc_count
.zero_chk_eq:
    lda      var_zeroflags
    cmp      #beyond_flags
    bcc      .inner

.inc_count:
    ; count += 1
    inc      var_count
    bne      .skip_hi_count_inc
    inc      var_count+1
.skip_hi_count_inc:
    inc      var_curflags
    bne      .skip_hi_curflags_inc
    inc      var_curflags+1
.skip_hi_curflags_inc:
    jmp      .outer

.all_done:
    dec      var_iter
    beq      .print_results
    jmp      .next_iteration

.print_results
    ; print the count of primes. 0x76b = 1899 expected
    lda      var_count+1
    jsr      prbyte
    lda      var_count
    jsr      prbyte

    lda      #36                    ; print a $ to indicate the app is done. useful for measuring runtime.
    jsr      echo
    jmp      exitapp

; Arguments:
;   A = byte to write
;   memset_ptr = the pointer where the setting starts
;   memset_len = the # of bytes to write
memset:
    tax
.memset_page_loop
    lda      memset_len+1
    beq      .memset_remainder
    ldy      #0
    txa
.memset_page_256:
    sta      (memset_ptr),y
    iny
    bne      .memset_page_256
    inc      memset_ptr+1
    dec      memset_len+1
    bne      .memset_page_loop
.memset_remainder
    ldy      #0
    txa
.memset_tail_loop:
    cpy      memset_len
    beq      .memset_done
    sta      (memset_ptr),y
    iny
    jmp      .memset_tail_loop
.memset_done:
    rts

