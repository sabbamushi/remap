#import <ctype.h>
#import <stdint.h>
#import <stdio.h>

int main(void) {
  uint64_t icanon = 0x00000100;
  uint64_t echo = 0x00000008;

  printf("%llu\n", icanon);
  printf("%llu\n", echo);
  uint64_t flag = 0;
  flag |= icanon | echo;

  printf("%llu\n", flag);
  return 0;
}
