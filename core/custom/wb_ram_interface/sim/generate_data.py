from sys import argv
import random

try:
    ram_width = int(argv[1])
except:
    ram_width = 32

try:
    ram_depth = int(argv[2])
except:
    ram_depth = 4096

ram_width = int(ram_width / 4)

hex = ['0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f']

for _ in range(0, ram_depth):
    output = ''
    for _ in range(0, ram_width):
        output = output + random.choice(hex)
    print(output)