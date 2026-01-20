/*
   Find e for the Apple 1.
   This version builds with Aztec CG65 v3.2c 10-2-89 on MS-DOS targeting 6502.
   That compiler expects an Apple II, so there are hacks here for the Apple 1.
   There are dependencies on start.a, which initializes for the Apple 1.
   Aztec C treats the char type as unsigned, and expands to 16 bits for any expression (slow!)
*/

#define LINT_ARGS
#include <stdint.h>

#include <stdio.h>

#define true 1
#define false 0

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

void showu( val ) unsigned int val;
{
    int digits, x;
    int d;
    digits = 0;

    while ( val )
    {
#if 1
        d = val / 10;
        x = val - ( d * 10 );
        acbuf[ digits++ ] = x + '0';
        val = d;
#else
        val % 10;
        acbuf[ digits++ ] = x + '0';
        val /= 10;
#endif
    }

    for ( x = digits - 1; x >= 0; x-- )
        show_char( acbuf[ x ] );
}

void showi( val ) int val;
{
    if ( val < 0 )
    {
        show_char( '-' );
        val = -val;
    }

    showu( val );
}

#define DIGITS_TO_FIND 200 /*9009;*/

char a[ DIGITS_TO_FIND ];

int main()
{
    int N, x, n;
    int d;

    N = DIGITS_TO_FIND;
    x = 0;

    for (n = N - 1; n > 0; --n)
        a[n] = 1;

    a[1] = 2, a[0] = 0;
    while (N > 9)
    {
        n = N--;
        while (--n)
        {
#if 1
            d = x / n;
            a[n] = x - ( d * n );
            x = 10 * a[n-1] + d;
#else
            a[n] = x % n;
            x = 10 * a[n-1] + x/n;
#endif
        }
        showu( x );
    }

    show_char( '\r' );

    /* The C runtime doesn't know how to exit or even return to the entry proc
       on an Apple 1, so exit with bye() */

    bye();

    return 0;
} /*main*/

