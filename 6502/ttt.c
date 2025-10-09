/*
   Tic-Tac-Toe proof you can't win for the Apple 1.
   This version is for CC65. https://cc65.github.io/
   Uses Hex Dump app hd to generate an Apple 1 .hex file: https://github.com/davidly/hd
   Build on Windows like this:

        rem none defaults to a machine with RAM from 0 to $8000, perfect for the emulator and replica
        cc65 -T -Oi -Or -t none ttt.c
        ca65 ttt.s
        ld65 -o ttt -t none ttt.o none.lib
        hd -w:0x1000 ttt >ttt.hex

   To run in the ntvao Apple 1 emulator: https://github.com/davidly/ntvao

        rem ntvao -p -c /s:1022727 ttt.hex
        ntvao -p -c ttt.hex

   To run on the RetroTechLife Apple 1 Replica use ss (send serial): https://github.com/davidly/ss

        ss /p:7 /s:ttt.hex /r:1000
*/

#include <stdio.h>
#include <stdint.h>

#define true 1
#define false 0

/* Function Pointers are the fastest implementation for almost every compiler, but not for cc65 */
#define UseFunPointers 1
#define UseWinner2 2
#define UseLookForWinner 3
#define WinMethod UseWinner2

#define USE_SPRINTF false    /* this makes the app 2x as big, making transfers to the Apple 1 slow */
#define ABPrune true         /* alpha beta pruning */
#define WinLosePrune true    /* stop early on win/lose */
#define ScoreWin 6
#define ScoreTie 5
#define ScoreLose  4
#define ScoreMax 9
#define ScoreMin 2
#define DefaultIterations 1

#define PieceX 1
#define PieceO 2
#define PieceBlank 0

typedef uint8_t ttype;  /* 8-bit and 16-bit cpus do best with char aside from register in locals */
uint16_t g_Moves = 0;
uint8_t g_board[ 9 ];

#if WinMethod == UseFunPointers

uint8_t pos0func()
{
    register uint8_t x = g_board[0];
    
    if ( ( x == g_board[1] && x == g_board[2] ) ||
         ( x == g_board[3] && x == g_board[6] ) ||
         ( x == g_board[4] && x == g_board[8] ) )
        return x;
    return PieceBlank;
}

uint8_t pos1func()
{
    register uint8_t x = g_board[1];
    
    if ( ( x == g_board[0] && x == g_board[2] ) ||
         ( x == g_board[4] && x == g_board[7] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos2func()
{
    register uint8_t x = g_board[2];
    
    if ( ( x == g_board[0] && x == g_board[1] ) ||
         ( x == g_board[5] && x == g_board[8] ) ||
         ( x == g_board[4] && x == g_board[6] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos3func()
{
    register uint8_t x = g_board[3];
    
    if ( ( x == g_board[4] && x == g_board[5] ) ||
         ( x == g_board[0] && x == g_board[6] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos4func()
{
    register uint8_t x = g_board[4];
    
    if ( ( x == g_board[0] && x == g_board[8] ) ||
         ( x == g_board[2] && x == g_board[6] ) ||
         ( x == g_board[1] && x == g_board[7] ) ||
         ( x == g_board[3] && x == g_board[5] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos5func()
{
    register uint8_t x = g_board[5];
    
    if ( ( x == g_board[3] && x == g_board[4] ) ||
         ( x == g_board[2] && x == g_board[8] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos6func()
{
    register uint8_t x = g_board[6];
    
    if ( ( x == g_board[7] && x == g_board[8] ) ||
         ( x == g_board[0] && x == g_board[3] ) ||
         ( x == g_board[4] && x == g_board[2] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos7func()
{
    register uint8_t x = g_board[7];
    
    if ( ( x == g_board[6] && x == g_board[8] ) ||
         ( x == g_board[1] && x == g_board[4] ) )
        return x;
    return PieceBlank;
} 

uint8_t pos8func()
{
    register uint8_t x = g_board[8];
    
    if ( ( x == g_board[6] && x == g_board[7] ) ||
         ( x == g_board[2] && x == g_board[5] ) ||
         ( x == g_board[0] && x == g_board[4] ) )
        return x;
    return PieceBlank;
} 

typedef uint8_t pfunc_t();

pfunc_t * winner_functions[9] =
{
    pos0func,
    pos1func,
    pos2func,
    pos3func,
    pos4func,
    pos5func,
    pos6func,
    pos7func,
    pos8func,
};

#endif

#if WinMethod == UseWinner2

ttype winner2( move ) ttype move;
{
    register ttype x; 

    switch( move ) /* msc v3 from 1985 generates a jump table! */
    {
        case 0:
        {
            x = g_board[ 0 ];
            if ( ( x == g_board[1] && x == g_board[2] ) ||
                 ( x == g_board[3] && x == g_board[6] ) ||
                 ( x == g_board[4] && x == g_board[8] ) )
               return x;
            break;
        }
        case 1:
        {
            x = g_board[ 1 ];
            if ( ( x == g_board[0] && x == g_board[2] ) ||
                 ( x == g_board[4] && x == g_board[7] ) )
                return x;
            break;
        }
        case 2:
        {
            x = g_board[ 2 ];
            if ( ( x == g_board[0] && x == g_board[1] ) ||
                 ( x == g_board[5] && x == g_board[8] ) ||
                 ( x == g_board[4] && x == g_board[6] ) )
                return x;
            break;
        }
        case 3:
        {
            x = g_board[ 3 ];
            if ( ( x == g_board[4] && x == g_board[5] ) ||
                 ( x == g_board[0] && x == g_board[6] ) )
                return x;
            break;
        }
        case 4:
        {
            x = g_board[ 4 ];
            if ( ( x == g_board[0] && x == g_board[8] ) ||
                 ( x == g_board[2] && x == g_board[6] ) ||
                 ( x == g_board[1] && x == g_board[7] ) ||
                 ( x == g_board[3] && x == g_board[5] ) )
                return x;
            break;
        }
        case 5:
        {
            x = g_board[ 5 ];
            if ( ( x == g_board[3] && x == g_board[4] ) ||
                 ( x == g_board[2] && x == g_board[8] ) )
                return x;
            break;
        }
        case 6:
        {
            x = g_board[ 6 ];
            if ( ( x == g_board[7] && x == g_board[8] ) ||
                 ( x == g_board[0] && x == g_board[3] ) ||
                 ( x == g_board[4] && x == g_board[2] ) )
                return x;
            break;
        }
        case 7:
        {
            x = g_board[ 7 ];
            if ( ( x == g_board[6] && x == g_board[8] ) ||
                 ( x == g_board[1] && x == g_board[4] ) )
                return x;
            break;
        }
        case 8:
        {
            x = g_board[ 8 ];
            if ( ( x == g_board[6] && x == g_board[7] ) ||
                 ( x == g_board[2] && x == g_board[5] ) ||
                 ( x == g_board[0] && x == g_board[4] ) )
                return x;
            break;
         }
    }

    return PieceBlank;
} /*winner2*/

#endif

#if WinMethod == UseLookForWinner

uint8_t LookForWinner()
{
    register uint8_t p = g_board[0];
    if ( PieceBlank != p )
    {
        if ( ( p == g_board[1] && p == g_board[2] ) ||
             ( p == g_board[3] && p == g_board[6] ) ||
             ( p == g_board[4] && p == g_board[8] ) )
            return p;
    }

    p = g_board[3];
    if ( PieceBlank != p && p == g_board[4] && p == g_board[5] )
        return p;

    p = g_board[6];
    if ( PieceBlank != p && p == g_board[7] && p == g_board[8] )
        return p;

    p = g_board[1];
    if ( PieceBlank != p && p == g_board[4] && p == g_board[7] )
        return p;

    p = g_board[2];
    if ( PieceBlank != p )
    {
        if ( ( p == g_board[5] && p == g_board[8] ) ||
             ( p == g_board[4] && p == g_board[6] ) )
            return p;
    }

    return PieceBlank;
} /*LookForWinner*/

#endif

#if WinMethod == UseLookForWinner
int MinMax( alpha, beta, depth ) uint8_t alpha; uint8_t beta; uint8_t depth;
#else
int MinMax( alpha, beta, depth, move ) uint8_t alpha; uint8_t beta; uint8_t depth; uint8_t move;
#endif
{
    uint8_t pieceMove, score;
    uint8_t value, p;

    g_Moves++;

    if ( depth >= 4 )
    {
#if WinMethod == UseFunPointers
        p = ( * winner_functions[ move ] )();
#endif
#if WinMethod == UseWinner2
        p = winner2( move );
#endif
#if WinMethod == UseLookForWinner
        p = LookForWinner();
#endif

        if ( PieceBlank != p )
        {
            if ( PieceX == p )
                return ScoreWin;

            return ScoreLose;
        }

        if ( 8 == depth )
            return ScoreTie;
    }

    if ( depth & 1 ) 
    {
        value = ScoreMin;
        pieceMove = PieceX;
    }
    else
    {
        value = ScoreMax;
        pieceMove = PieceO;
    }

    for ( p = 0; p < 9; ++p )
    {
        if ( PieceBlank == g_board[ p ] )
        {
            g_board[p] = pieceMove;
#if WinMethod == UseLookForWinner
            score = MinMax( alpha, beta, depth + 1 );
#else
            score = MinMax( alpha, beta, depth + 1, p );
#endif
            g_board[p] = PieceBlank;

            if ( depth & 1 ) 
            {
#if WinLosePrune   /* #if statements must be in column 0 for MS C 1.0 */
                if ( ScoreWin == score )
                    return ScoreWin;
#endif

                if ( score > value )
                {
                    value = score;

#if ABPrune
                    if ( value >= beta )
                        return value;
                    if ( value > alpha )
                        alpha = value;
#endif
                }
            }
            else
            {
#if WinLosePrune
                if ( ScoreLose == score )
                    return ScoreLose;
#endif

                if ( score < value )
                {
                    value = score;

#if ABPrune
                    if ( value <= alpha )
                        return value;
                    if ( value < beta )
                        beta = value;
#endif
                }
            }
        }
    }

    return value;
}  /*MinMax*/

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

int FindSolution( position ) uint8_t position;
{
    g_board[ position ] = PieceX;
#if WinMethod == UseLookForWinner
    MinMax( ScoreMin, ScoreMax, 0 );
#else
    MinMax( ScoreMin, ScoreMax, 0, position );
#endif
    g_board[ position ] = PieceBlank;

    return 0;
} /*FindSolution*/

int main()
{
#if USE_SPRINTF
    static char ac[40];
#endif
    uint8_t i;

    for ( i = 0; i < 9; ++i )
        g_board[ i ] = PieceBlank;

    for ( i = 0; i < DefaultIterations; i++ )
    {
        g_Moves = 0;
        FindSolution( 0 );
        FindSolution( 1 );
        FindSolution( 4 );
    }

#if USE_SPRINTF
    sprintf( ac, " moves %d", g_Moves );
    show_string( ac );
    sprintf( ac, ", iterations %d", DefaultIterations );
    show_string( ac );
#else
    show_string( " moves " );
    show_int( g_Moves );
    show_string( ", " );
    show_int( DefaultIterations );
#endif

    show_string( ", " );
    show_string( ( WinMethod == UseFunPointers ) ? "function pointers" :
                 ( WinMethod == UseWinner2 ) ? "winner2" :
                 ( WinMethod == UseLookForWinner ) ? "look for winner" :
                 "invalid method" );
    show_char( '$' ); // signal to elapsed time measurement app that execution is complete

    /* The C runtime doesn't know how to exit or even return to the entry proc
       on an Apple 1, so exit with bye() */

    bye();

    return 0;
} /*main*/

