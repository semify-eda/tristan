#include "util.h"

void  *memset(void *b, int c, int len)
{
  unsigned char *p = b;
  while(len > 0)
    {
      *p = c;
      p++;
      len--;
    }
  return(b);
}

void print(int n)
{
    // If number is smaller than 0, put a - sign
    // and change number to positive
    if (n < 0) {
        putc('-');
        n = -n;
    }
 
    // Remove the last digit and recur
    if (n/10)
        print(n/10);
 
    // Print the last digit
    putc(n%10 + ((int)'0'));
}

int strcmp(const char* x, const char* y)
{
    while (*x)
    {
        if (*x != *y)
        {
            break;
        }
        
        x++;
        y++;
    }
    
    return *(const unsigned char*)x - *(const unsigned char*)y;
}

int gets(char* const buffer, int len)
{
    char c;
    int cnt = 0;

    do
    {
        c = getc();
        buffer[cnt++] = c;
        
        // Input completed
        if (c == '\n')
        {
            buffer[--cnt] = '\0';
            return 0;
        }
    // Iterate until buffer full
    } while (cnt < len - 1);

    buffer[--cnt] = '\0';
    return -1;
}

char getc(void)
{
    int data;
    do
    {
        data = UART_DATA;
    } while (data == -1);

    return (char)data;
}

void puts(const char* s)
{
    while (*s != '\0')
    {
        putc(*(s++));
    }
}

void putc(char c)
{
    while (UART_BUSY);
    UART_DATA = c;
}

void setLED(int value)
{
    BASE_LED = value;
}

unsigned xorshift32(unsigned int x) {
    x |= x == 0;   // if x == 0, set x = 1 instead
    x ^= (x & 0x0007ffff) << 13;
    x ^= x >> 17;
    x ^= (x & 0x07ffffff) << 5;
    return x & 0xffffffff;
}
