# Elfos-pstwo

This is a loadable driver for Elf/OS 4 that implements video output using a TMS9918 type video display processor along with a PS/2 type keyboard for input. The hardware it was developed for are the 1802/Mini 9918 video card and PS/2 adapter:

https://github.com/dmadole/1802-Mini-9918-Video  
https://github.com/dmadole/Elf-PS2-Adapter  

However, there is nothing in this driver that is particular to the 1802/Mini or to this particular 9918 implementation.

At this time, the driver output supports the ASCII printable character set plus carriage return, line feed, and backspace.

Build 2 adds support for group port selection, support for unloading the driver, and some general cleanup and improvement. The default configuration in Build 2 is for expander port 1, expander group 1, and 9918 ports 6 and 7, but this can be changed by re-assembling.

