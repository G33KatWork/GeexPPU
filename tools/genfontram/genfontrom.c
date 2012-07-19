#include <stdio.h>
#include "font8x8.h"

static uint8_t stretch[16] = {
	0x00, 0x03, 0x0c, 0x0f,
	0x30, 0x33, 0x3c, 0x3f,
	0xc0, 0xc3, 0xcc, 0xcf,
	0xf0, 0xf3, 0xfc, 0xff
};

int main(int argc, char const *argv[])
{
	for (int i = 0; i < 768; ++i)
	{
		uint8_t byte = font8x8[i];

		uint8_t h = stretch[byte >> 4];
		uint8_t l = stretch[byte & 0x0f];

		printf("%02x\n", h);
		printf("%02x\n", l);
	}

	return 0;
}
