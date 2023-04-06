#ifndef UTIL_H
#define UTIL_H

#define BASE_LED (*((volatile int*)(0x100000)))
#define UART_DATA (*((volatile int*)(0x200000)))
#define UART_BUSY (*((volatile int*)(0x200004)))

void print(int n);
int strcmp(const char* x, const char* y);
char getc(void);
void putc(char c);
void puts(const char* s);
int gets(char* const buffer, int len);
void setLED(int value);

#endif
