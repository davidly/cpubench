/*  sieve.c */

/* Eratosthenes Sieve Prime Number Program in C from Byte Jan 1983
   to compare the speed. */

#include <stdio.h>
#include <stdint.h>

#define TRUE 1
#define FALSE 0
#define SIZE 8190

char flags[SIZE+1];

void show_int( val ) uint16_t val;
{
    static uint8_t h, l;
    h = (uint8_t) ( val >> 8 );
    l = (uint8_t) val;

    __asm__( "lda     %v", h );
    __asm__( "jsr     $ffdc" );
    __asm__( "lda     %v", l );
    __asm__( "jsr     $ffdc" );
} /*show_int*/

void show_char( val ) char val;
{
    static uint8_t s_val;
    s_val = val;
    __asm__( "lda     %v", s_val );
    __asm__( "jsr     $ffef" );
} /*show_char*/

void show_string( str ) char * str;
{
    while ( *str )
    {
        show_char( *str );
        str++;
    }
} /*show_string*/

void bye()
{
    __asm__( "jsr     $ff1f" );
} /*bye*/

char acbuf[ 20 ];

void showi( val ) int val;
{
    int digits, x;
    digits = 0;

    if ( 0 == val )
    {
        show_char( '0' );
        return;
    }

    if ( val < 0 )
    {
        show_char( '-' );
        val = -val;
    }

    while ( val )
    {
        x = val % 10;
        acbuf[ digits++ ] = x + '0';
        val /= 10;
    }

    for ( x = digits - 1; x >= 0; x-- )
        show_char( acbuf[ x ] );
}

int main()
        {
        int i,k;
        int prime,count,iter;

        for (iter = 1; iter <= 10; iter++) {    /* do program 10 times */
                count = 0;                      /* initialize prime counter */
                for (i = 0; i <= SIZE; i++)     /* set all flags true */
                        flags[i] = TRUE;
                for (i = 0; i <= SIZE; i++) {
                        if (flags[i]) {         /* found a prime */
                                prime = i + i + 3;      /* twice index + 3 */
                                for (k = i + prime; k <= SIZE; k += prime)
                                        flags[k] = FALSE;       /* kill all multiples */
                                count++;                /* primes found */
                                }
                        }
                }
        showi( count );
        show_string(" primes.\r" );
        bye();
        return 0;
        }
