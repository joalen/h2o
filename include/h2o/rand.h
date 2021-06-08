/*
 * Copyright (c) 2016 David Carlier
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
#ifndef h2o__rand_h
#define h2o__rand_h

#include <stdlib.h>
#include <unistd.h>

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__)
#define h2o_srand()
#define h2o_rand() arc4random()
#else
#define h2o_srand() srand(time(NULL) ^ getpid())
#define h2o_rand() rand()
#endif

/*
 * size of a UUID string representation + NUL byte
 */
#define H2O_UUID_STR_RFC4122_LEN 37

/**
 * generates and sets a UUIDv4 to buf, which must have an enough size, H2O_UUID_STR_RFC4122_LEN.
 */
void h2o_generate_uuidv4(char *buf);

#endif
