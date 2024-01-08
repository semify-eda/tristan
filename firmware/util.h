#ifndef UTIL_H
#define UTIL_H

#define BASE_LED (*((volatile int*)(0x0F000000)))
#define UART_DATA (*((volatile int*)(0x0A000000)))
#define UART_BUSY (*((volatile int*)(0x0A000004)))

void print(unsigned int n);
int strcmp(const char* x, const char* y);
void  *memset(void *b, int c, int len);
char getc(void);
void putc(char c);
void puts(const char* s);
int gets(char* const buffer, int len);
void setLED(int value);
unsigned int xorshift32(unsigned int x);

#endif
