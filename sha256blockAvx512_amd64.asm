
// 16x Parallel implementation of SHA256 for AVX512

//
// Minio Cloud Storage, (C) 2017 Minio, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
// This code is based on the Intel Multi-Buffer Crypto for IPSec library
// and more specifically the following implementation:
// https://github.com/intel/intel-ipsec-mb/blob/master/avx512/sha256_x16_avx512.asm
//
// For Golang it has been converted into Plan 9 assembly with the help of
// github.com/minio/asm2plan9s to assemble the AVX512 instructions
//

// Copyright (c) 2017, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
//     * Redistributions of source code must retain the above copyright notice,
//       this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of Intel Corporation nor the names of its contributors
//       may be used to endorse or promote products derived from this software
//       without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#define SHA256_DIGEST_ROW_SIZE 64

// arg1
#define STATE rdi
#define STATE_P9 DI
// arg2
#define INP_SIZE rsi
#define INP_SIZE_P9 SI

#define IDX rcx
#define TBL rdx
#define TBL_P9 DX

#define INPUT rax
#define INPUT_P9 AX

#define inp0	r9
#define SCRATCH_P9 R12
#define SCRATCH  r12
#define maskp    r13
#define MASKP_P9 R13
#define mask     r14
#define MASK_P9  R14

#define A       zmm0
#define B       zmm1
#define C       zmm2
#define D       zmm3
#define E       zmm4
#define F       zmm5
#define G       zmm6
#define H       zmm7
#define T1      zmm8
#define TMP0    zmm9
#define TMP1    zmm10
#define TMP2    zmm11
#define TMP3    zmm12
#define TMP4    zmm13
#define TMP5    zmm14
#define TMP6    zmm15

#define W0      zmm16
#define W1      zmm17
#define W2      zmm18
#define W3      zmm19
#define W4      zmm20
#define W5      zmm21
#define W6      zmm22
#define W7      zmm23
#define W8      zmm24
#define W9      zmm25
#define W10     zmm26
#define W11     zmm27
#define W12     zmm28
#define W13     zmm29
#define W14     zmm30
#define W15     zmm31


#define TRANSPOSE16(_r0, _r1, _r2, _r3, _r4, _r5, _r6, _r7, _r8, _r9, _r10, _r11, _r12, _r13, _r14, _r15, _t0, _t1) \
    \
    \ // input   r0  = {a15 a14 a13 a12   a11 a10  a9  a8    a7  a6  a5  a4    a3  a2  a1  a0}
    \ //         r1  = {b15 b14 b13 b12   b11 b10  b9  b8    b7  b6  b5  b4    b3  b2  b1  b0}
    \ //         r2  = {c15 c14 c13 c12   c11 c10  c9  c8    c7  c6  c5  c4    c3  c2  c1  c0}
    \ //         r3  = {d15 d14 d13 d12   d11 d10  d9  d8    d7  d6  d5  d4    d3  d2  d1  d0}
    \ //         r4  = {e15 e14 e13 e12   e11 e10  e9  e8    e7  e6  e5  e4    e3  e2  e1  e0}
    \ //         r5  = {f15 f14 f13 f12   f11 f10  f9  f8    f7  f6  f5  f4    f3  f2  f1  f0}
    \ //         r6  = {g15 g14 g13 g12   g11 g10  g9  g8    g7  g6  g5  g4    g3  g2  g1  g0}
    \ //         r7  = {h15 h14 h13 h12   h11 h10  h9  h8    h7  h6  h5  h4    h3  h2  h1  h0}
    \ //         r8  = {i15 i14 i13 i12   i11 i10  i9  i8    i7  i6  i5  i4    i3  i2  i1  i0}
    \ //         r9  = {j15 j14 j13 j12   j11 j10  j9  j8    j7  j6  j5  j4    j3  j2  j1  j0}
    \ //         r10 = {k15 k14 k13 k12   k11 k10  k9  k8    k7  k6  k5  k4    k3  k2  k1  k0}
    \ //         r11 = {l15 l14 l13 l12   l11 l10  l9  l8    l7  l6  l5  l4    l3  l2  l1  l0}
    \ //         r12 = {m15 m14 m13 m12   m11 m10  m9  m8    m7  m6  m5  m4    m3  m2  m1  m0}
    \ //         r13 = {n15 n14 n13 n12   n11 n10  n9  n8    n7  n6  n5  n4    n3  n2  n1  n0}
    \ //         r14 = {o15 o14 o13 o12   o11 o10  o9  o8    o7  o6  o5  o4    o3  o2  o1  o0}
    \ //         r15 = {p15 p14 p13 p12   p11 p10  p9  p8    p7  p6  p5  p4    p3  p2  p1  p0}
    \
    \ // output  r0  = { p0  o0  n0  m0    l0  k0  j0  i0    h0  g0  f0  e0    d0  c0  b0  a0}
    \ //         r1  = { p1  o1  n1  m1    l1  k1  j1  i1    h1  g1  f1  e1    d1  c1  b1  a1}
    \ //         r2  = { p2  o2  n2  m2    l2  k2  j2  i2    h2  g2  f2  e2    d2  c2  b2  a2}
    \ //         r3  = { p3  o3  n3  m3    l3  k3  j3  i3    h3  g3  f3  e3    d3  c3  b3  a3}
    \ //         r4  = { p4  o4  n4  m4    l4  k4  j4  i4    h4  g4  f4  e4    d4  c4  b4  a4}
    \ //         r5  = { p5  o5  n5  m5    l5  k5  j5  i5    h5  g5  f5  e5    d5  c5  b5  a5}
    \ //         r6  = { p6  o6  n6  m6    l6  k6  j6  i6    h6  g6  f6  e6    d6  c6  b6  a6}
    \ //         r7  = { p7  o7  n7  m7    l7  k7  j7  i7    h7  g7  f7  e7    d7  c7  b7  a7}
    \ //         r8  = { p8  o8  n8  m8    l8  k8  j8  i8    h8  g8  f8  e8    d8  c8  b8  a8}
    \ //         r9  = { p9  o9  n9  m9    l9  k9  j9  i9    h9  g9  f9  e9    d9  c9  b9  a9}
    \ //         r10 = {p10 o10 n10 m10   l10 k10 j10 i10   h10 g10 f10 e10   d10 c10 b10 a10}
    \ //         r11 = {p11 o11 n11 m11   l11 k11 j11 i11   h11 g11 f11 e11   d11 c11 b11 a11}
    \ //         r12 = {p12 o12 n12 m12   l12 k12 j12 i12   h12 g12 f12 e12   d12 c12 b12 a12}
    \ //         r13 = {p13 o13 n13 m13   l13 k13 j13 i13   h13 g13 f13 e13   d13 c13 b13 a13}
    \ //         r14 = {p14 o14 n14 m14   l14 k14 j14 i14   h14 g14 f14 e14   d14 c14 b14 a14}
    \ //         r15 = {p15 o15 n15 m15   l15 k15 j15 i15   h15 g15 f15 e15   d15 c15 b15 a15}
    \
    \ // process top half
    vshufps _t0, _r0, _r1, 0x44      \ // t0 = {b13 b12 a13 a12   b9  b8  a9  a8   b5 b4 a5 a4   b1 b0 a1 a0}
    vshufps _r0, _r0, _r1, 0xEE      \ // r0 = {b15 b14 a15 a14   b11 b10 a11 a10  b7 b6 a7 a6   b3 b2 a3 a2}
    vshufps _t1, _r2, _r3, 0x44      \ // t1 = {d13 d12 c13 c12   d9  d8  c9  c8   d5 d4 c5 c4   d1 d0 c1 c0}
    vshufps _r2, _r2, _r3, 0xEE      \ // r2 = {d15 d14 c15 c14   d11 d10 c11 c10  d7 d6 c7 c6   d3 d2 c3 c2}
                                     \
    vshufps	_r3, _t0, _t1, 0xDD      \ // r3 = {d13 c13 b13 a13   d9  c9  b9  a9   d5 c5 b5 a5   d1 c1 b1 a1}
    vshufps	_r1, _r0, _r2, 0x88      \ // r1 = {d14 c14 b14 a14   d10 c10 b10 a10  d6 c6 b6 a6   d2 c2 b2 a2}
    vshufps	_r0, _r0, _r2, 0xDD      \ // r0 = {d15 c15 b15 a15   d11 c11 b11 a11  d7 c7 b7 a7   d3 c3 b3 a3}
    vshufps	_t0, _t0, _t1, 0x88      \ // t0 = {d12 c12 b12 a12   d8  c8  b8  a8   d4 c4 b4 a4   d0 c0 b0 a0}
                                     \
    \ // use r2 in place of t0
    vshufps _r2, _r4, _r5, 0x44      \ // r2 = {f13 f12 e13 e12   f9  f8  e9  e8   f5 f4 e5 e4   f1 f0 e1 e0}
    vshufps _r4, _r4, _r5, 0xEE      \ // r4 = {f15 f14 e15 e14   f11 f10 e11 e10  f7 f6 e7 e6   f3 f2 e3 e2}
    vshufps _t1, _r6, _r7, 0x44      \ // t1 = {h13 h12 g13 g12   h9  h8  g9  g8   h5 h4 g5 g4   h1 h0 g1 g0}
    vshufps _r6, _r6, _r7, 0xEE      \ // r6 = {h15 h14 g15 g14   h11 h10 g11 g10  h7 h6 g7 g6   h3 h2 g3 g2}
                                     \
    vshufps _r7, _r2, _t1, 0xDD      \ // r7 = {h13 g13 f13 e13   h9  g9  f9  e9   h5 g5 f5 e5   h1 g1 f1 e1}
    vshufps _r5, _r4, _r6, 0x88      \ // r5 = {h14 g14 f14 e14   h10 g10 f10 e10  h6 g6 f6 e6   h2 g2 f2 e2}
    vshufps _r4, _r4, _r6, 0xDD      \ // r4 = {h15 g15 f15 e15   h11 g11 f11 e11  h7 g7 f7 e7   h3 g3 f3 e3}
    vshufps _r2, _r2, _t1, 0x88      \ // r2 = {h12 g12 f12 e12   h8  g8  f8  e8   h4 g4 f4 e4   h0 g0 f0 e0}
                                     \
    \ // use r6 in place of t0
    vshufps _r6, _r8, _r9,    0x44   \ // r6  = {j13 j12 i13 i12   j9  j8  i9  i8   j5 j4 i5 i4   j1 j0 i1 i0}
    vshufps _r8, _r8, _r9,    0xEE   \ // r8  = {j15 j14 i15 i14   j11 j10 i11 i10  j7 j6 i7 i6   j3 j2 i3 i2}
    vshufps _t1, _r10, _r11,  0x44   \ // t1  = {l13 l12 k13 k12   l9  l8  k9  k8   l5 l4 k5 k4   l1 l0 k1 k0}
    vshufps _r10, _r10, _r11, 0xEE   \ // r10 = {l15 l14 k15 k14   l11 l10 k11 k10  l7 l6 k7 k6   l3 l2 k3 k2}
                                     \
    vshufps _r11, _r6, _t1, 0xDD     \ // r11 = {l13 k13 j13 113   l9  k9  j9  i9   l5 k5 j5 i5   l1 k1 j1 i1}
    vshufps _r9, _r8, _r10, 0x88     \ // r9  = {l14 k14 j14 114   l10 k10 j10 i10  l6 k6 j6 i6   l2 k2 j2 i2}
    vshufps _r8, _r8, _r10, 0xDD     \ // r8  = {l15 k15 j15 115   l11 k11 j11 i11  l7 k7 j7 i7   l3 k3 j3 i3}
    vshufps _r6, _r6, _t1,  0x88     \ // r6  = {l12 k12 j12 112   l8  k8  j8  i8   l4 k4 j4 i4   l0 k0 j0 i0}
                                     \
    \ // use r10 in place of t0
    vshufps _r10, _r12, _r13, 0x44   \ // r10 = {n13 n12 m13 m12   n9  n8  m9  m8   n5 n4 m5 m4   n1 n0 a1 m0}
    vshufps _r12, _r12, _r13, 0xEE   \ // r12 = {n15 n14 m15 m14   n11 n10 m11 m10  n7 n6 m7 m6   n3 n2 a3 m2}
    vshufps _t1, _r14, _r15,  0x44   \ // t1  = {p13 p12 013 012   p9  p8  09  08   p5 p4 05 04   p1 p0 01 00}
    vshufps _r14, _r14, _r15, 0xEE   \ // r14 = {p15 p14 015 014   p11 p10 011 010  p7 p6 07 06   p3 p2 03 02}
                                     \
    vshufps _r15, _r10, _t1,  0xDD   \ // r15 = {p13 013 n13 m13   p9  09  n9  m9   p5 05 n5 m5   p1 01 n1 m1}
    vshufps _r13, _r12, _r14, 0x88   \ // r13 = {p14 014 n14 m14   p10 010 n10 m10  p6 06 n6 m6   p2 02 n2 m2}
    vshufps _r12, _r12, _r14, 0xDD   \ // r12 = {p15 015 n15 m15   p11 011 n11 m11  p7 07 n7 m7   p3 03 n3 m3}
    vshufps _r10, _r10, _t1,  0x88   \ // r10 = {p12 012 n12 m12   p8  08  n8  m8   p4 04 n4 m4   p0 00 n0 m0}
                                     \
    \ // At this point, the registers that contain interesting data are:
    \ // t0, r3, r1, r0, r2, r7, r5, r4, r6, r11, r9, r8, r10, r15, r13, r12
    \ // Can use t1 and r14 as scratch registers
    LEAQ PSHUFFLE_TRANSPOSE16_MASK1<>(SB), BX \
    LEAQ PSHUFFLE_TRANSPOSE16_MASK2<>(SB), R8 \
                                     \
    vmovdqu32 _r14, [rbx]            \
    vpermi2q  _r14, _t0, _r2         \ // r14 = {h8  g8  f8  e8   d8  c8  b8  a8   h0 g0 f0 e0	 d0 c0 b0 a0}
    vmovdqu32 _t1,  [r8]             \
    vpermi2q  _t1,  _t0, _r2         \ // t1  = {h12 g12 f12 e12  d12 c12 b12 a12  h4 g4 f4 e4	 d4 c4 b4 a4}
                                     \
    vmovdqu32 _r2, [rbx]             \
    vpermi2q  _r2, _r3, _r7          \ // r2  = {h9  g9  f9  e9   d9  c9  b9  a9   h1 g1 f1 e1	 d1 c1 b1 a1}
    vmovdqu32 _t0, [r8]              \
    vpermi2q  _t0, _r3, _r7          \ // t0  = {h13 g13 f13 e13  d13 c13 b13 a13  h5 g5 f5 e5	 d5 c5 b5 a5}
                                     \
    vmovdqu32 _r3, [rbx]             \
    vpermi2q  _r3, _r1, _r5          \ // r3  = {h10 g10 f10 e10  d10 c10 b10 a10  h2 g2 f2 e2	 d2 c2 b2 a2}
    vmovdqu32 _r7, [r8]              \
    vpermi2q  _r7, _r1, _r5          \ // r7  = {h14 g14 f14 e14  d14 c14 b14 a14  h6 g6 f6 e6	 d6 c6 b6 a6}
                                     \
    vmovdqu32 _r1, [rbx]             \
    vpermi2q  _r1, _r0, _r4          \ // r1  = {h11 g11 f11 e11  d11 c11 b11 a11  h3 g3 f3 e3	 d3 c3 b3 a3}
    vmovdqu32 _r5, [r8]              \
    vpermi2q  _r5, _r0, _r4          \ // r5  = {h15 g15 f15 e15  d15 c15 b15 a15  h7 g7 f7 e7	 d7 c7 b7 a7}
                                     \
    vmovdqu32 _r0, [rbx]             \
    vpermi2q  _r0, _r6, _r10         \ // r0  = {p8  o8  n8  m8   l8  k8  j8  i8   p0 o0 n0 m0	 l0 k0 j0 i0}
    vmovdqu32 _r4, [r8]              \
    vpermi2q  _r4, _r6, _r10         \ // r4  = {p12 o12 n12 m12  l12 k12 j12 i12  p4 o4 n4 m4	 l4 k4 j4 i4}
                                     \
    vmovdqu32 _r6, [rbx]             \
    vpermi2q  _r6, _r11, _r15        \ // r6  = {p9  o9  n9  m9   l9  k9  j9  i9   p1 o1 n1 m1	 l1 k1 j1 i1}
    vmovdqu32 _r10, [r8]             \
    vpermi2q  _r10, _r11, _r15       \ // r10 = {p13 o13 n13 m13  l13 k13 j13 i13  p5 o5 n5 m5	 l5 k5 j5 i5}
                                     \
    vmovdqu32 _r11, [rbx]            \
    vpermi2q  _r11, _r9, _r13        \ // r11 = {p10 o10 n10 m10  l10 k10 j10 i10  p2 o2 n2 m2	 l2 k2 j2 i2}
    vmovdqu32 _r15, [r8]             \
    vpermi2q  _r15, _r9, _r13        \ // r15 = {p14 o14 n14 m14  l14 k14 j14 i14  p6 o6 n6 m6	 l6 k6 j6 i6}
                                     \
    vmovdqu32 _r9, [rbx]             \
    vpermi2q  _r9, _r8, _r12         \ // r9  = {p11 o11 n11 m11  l11 k11 j11 i11  p3 o3 n3 m3	 l3 k3 j3 i3}
    vmovdqu32 _r13, [r8]             \
    vpermi2q  _r13, _r8, _r12        \ // r13 = {p15 o15 n15 m15  l15 k15 j15 i15  p7 o7 n7 m7	 l7 k7 j7 i7}
                                     \
    \ // At this point r8 and r12 can be used as scratch registers
    vshuff64x2 _r8, _r14, _r0, 0xEE  \ // r8  = {p8  o8  n8  m8   l8  k8  j8  i8   h8 g8 f8 e8   d8 c8 b8 a8}
    vshuff64x2 _r0, _r14, _r0, 0x44  \ // r0  = {p0  o0  n0  m0   l0  k0  j0  i0   h0 g0 f0 e0   d0 c0 b0 a0}
                                     \
    vshuff64x2 _r12, _t1, _r4, 0xEE  \ // r12 = {p12 o12 n12 m12  l12 k12 j12 i12  h12 g12 f12 e12  d12 c12 b12 a12}
    vshuff64x2 _r4, _t1, _r4, 0x44   \ // r4  = {p4  o4  n4  m4   l4  k4  j4  i4   h4 g4 f4 e4   d4 c4 b4 a4}
                                     \
    vshuff64x2 _r14, _r7, _r15, 0xEE \ // r14 = {p14 o14 n14 m14  l14 k14 j14 i14  h14 g14 f14 e14  d14 c14 b14 a14}
    vshuff64x2 _t1, _r7, _r15, 0x44  \ // t1  = {p6  o6  n6  m6   l6  k6  j6  i6   h6 g6 f6 e6   d6 c6 b6 a6}
                                     \
    vshuff64x2 _r15, _r5, _r13, 0xEE \ // r15 = {p15 o15 n15 m15  l15 k15 j15 i15  h15 g15 f15 e15  d15 c15 b15 a15}
    vshuff64x2 _r7, _r5, _r13, 0x44  \ // r7  = {p7  o7  n7  m7   l7  k7  j7  i7   h7 g7 f7 e7   d7 c7 b7 a7}
                                     \
    vshuff64x2 _r13, _t0, _r10, 0xEE \ // r13 = {p13 o13 n13 m13  l13 k13 j13 i13  h13 g13 f13 e13  d13 c13 b13 a13}
    vshuff64x2 _r5, _t0, _r10, 0x44  \ // r5  = {p5  o5  n5  m5   l5  k5  j5  i5   h5 g5 f5 e5   d5 c5 b5 a5}
                                     \
    vshuff64x2 _r10, _r3, _r11, 0xEE \ // r10 = {p10 o10 n10 m10  l10 k10 j10 i10  h10 g10 f10 e10  d10 c10 b10 a10}
    vshuff64x2 _t0, _r3, _r11, 0x44  \ // t0  = {p2  o2  n2  m2   l2  k2  j2  i2   h2 g2 f2 e2   d2 c2 b2 a2}
                                     \
    vshuff64x2 _r11, _r1, _r9, 0xEE  \ // r11 = {p11 o11 n11 m11  l11 k11 j11 i11  h11 g11 f11 e11  d11 c11 b11 a11}
    vshuff64x2 _r3, _r1, _r9, 0x44   \ // r3  = {p3  o3  n3  m3   l3  k3  j3  i3   h3 g3 f3 e3   d3 c3 b3 a3}
                                     \
    vshuff64x2 _r9, _r2, _r6, 0xEE   \ // r9  = {p9  o9  n9  m9   l9  k9  j9  i9   h9 g9 f9 e9   d9 c9 b9 a9}
    vshuff64x2 _r1, _r2, _r6, 0x44   \ // r1  = {p1  o1  n1  m1   l1  k1  j1  i1   h1 g1 f1 e1   d1 c1 b1 a1}
                                     \
    vmovdqu32 _r2, _t0               \ // r2  = {p2  o2  n2  m2   l2  k2  j2  i2   h2 g2 f2 e2   d2 c2 b2 a2}
    vmovdqu32 _r6, _t1               \ // r6  = {p6  o6  n6  m6   l6  k6  j6  i6   h6 g6 f6 e6   d6 c6 b6 a6}


//  CH(A, B, C) = (A&B) ^ (~A&C)
// MAJ(E, F, G) = (E&F) ^ (E&G) ^ (F&G)
// SIGMA0 = ROR_2  ^ ROR_13 ^ ROR_22
// SIGMA1 = ROR_6  ^ ROR_11 ^ ROR_25
// sigma0 = ROR_7  ^ ROR_18 ^ SHR_3
// sigma1 = ROR_17 ^ ROR_19 ^ SHR_10

// Main processing loop per round
#define PROCESS_LOOP(_WT, _ROUND, _A, _B, _C, _D, _E, _F, _G, _H)  \
    \ // T1 = H + SIGMA1(E) + CH(E, F, G) + Kt + Wt
    \ // T2 = SIGMA0(A) + MAJ(A, B, C)
    \ // H=G, G=F, F=E, E=D+T1, D=C, C=B, B=A, A=T1+T2
    \
    \ // H becomes T2, then add T1 for A
    \ // D becomes D + T1 for E
    \
    vpaddd      T1, _H, TMP3           \ // T1 = H + Kt
    vmovdqu32   TMP0, _E               \
    vprord      TMP1, _E, 6            \ // ROR_6(E)
    vprord      TMP2, _E, 11           \ // ROR_11(E)
    vprord      TMP3, _E, 25           \ // ROR_25(E)
    vpternlogd  TMP0, _F, _G, 0xCA     \ // TMP0 = CH(E,F,G)
    vpaddd      T1, T1, _WT            \ // T1 = T1 + Wt
    vpternlogd  TMP1, TMP2, TMP3, 0x96 \ // TMP1 = SIGMA1(E)
    vpaddd      T1, T1, TMP0           \ // T1 = T1 + CH(E,F,G)
    vpaddd      T1, T1, TMP1           \ // T1 = T1 + SIGMA1(E)
    vpaddd      _D, _D, T1             \ // D = D + T1
                                       \
    vprord      _H, _A, 2              \ // ROR_2(A)
    vprord      TMP2, _A, 13           \ // ROR_13(A)
    vprord      TMP3, _A, 22           \ // ROR_22(A)
    vmovdqu32   TMP0, _A               \
    vpternlogd  TMP0, _B, _C, 0xE8     \ // TMP0 = MAJ(A,B,C)
    vpternlogd  _H, TMP2, TMP3, 0x96   \ // H(T2) = SIGMA0(A)
    vpaddd      _H, _H, TMP0           \ // H(T2) = SIGMA0(A) + MAJ(A,B,C)
    vpaddd      _H, _H, T1             \ // H(A) = H(T2) + T1
                                       \
    vmovdqu32   TMP3, [TBL + ((_ROUND+1)*64)] \ // Next Kt

// TODO: Aligned load above

// This is supposed to be SKL optimized assuming:
// vpternlog, vpaddd ports 5,8
// vprord ports 1,8
// However, vprord is only working on port 8
//
// Main processing loop per round
// Get the msg schedule word 16 from the current, now unneccessary word
#define PROCESS_LOOP_00_47


#define MSG_SCHED_ROUND_16_63(_WT, _WTp1, _WTp9, _WTp14) \
    vprord      TMP4, _WTp14, 17                         \ // ROR_17(Wt-2)
    vprord      TMP5, _WTp14, 19                         \ // ROR_19(Wt-2)
    vpsrld      TMP6, _WTp14, 10                         \ // SHR_10(Wt-2)
    vpternlogd  TMP4, TMP5, TMP6, 0x96                   \ // TMP4 = sigma1(Wt-2)
                                                         \
    vpaddd      _WT, _WT, TMP4	                         \ // Wt = Wt-16 + sigma1(Wt-2)
    vpaddd      _WT, _WT, _WTp9	                         \ // Wt = Wt-16 + sigma1(Wt-2) + Wt-7
                                                         \
    vprord      TMP4, _WTp1, 7                           \ // ROR_7(Wt-15)
    vprord      TMP5, _WTp1, 18                          \ // ROR_18(Wt-15)
    vpsrld      TMP6, _WTp1, 3                           \ // SHR_3(Wt-15)
    vpternlogd  TMP4, TMP5, TMP6, 0x96                   \ // TMP4 = sigma0(Wt-15)
                                                         \
    vpaddd      _WT, _WT, TMP4	                         \ // Wt = Wt-16 + sigma1(Wt-2) +
                                                         \ //      Wt-7 + sigma0(Wt-15) +


// Note this is reading in a block of data for one lane
// When all 16 are read, the data must be transposed to build msg schedule
#define MSG_SCHED_ROUND_00_15(_WT, OFFSET, LABEL)             \
    TESTQ $(1<<OFFSET), MASK_P9                               \
    JE    LABEL                                               \
    MOVQ  OFFSET*24(INPUT_P9), R9                             \
    vmovups _WT, [inp0+IDX]                                   \
LABEL:                                                        \

#define MASKED_LOAD(_WT, OFFSET, LABEL) \
    TESTQ $(1<<OFFSET), MASK_P9         \
    JE    LABEL                         \
    MOVQ  OFFSET*24(INPUT_P9), R9       \
    vmovups _WT,[inp0+IDX]              \
LABEL:                                  \

TEXT ·sha256_x16_avx512(SB), 7, $0
    MOVQ  digests+0(FP), STATE_P9       //
    MOVQ  scratch+8(FP), SCRATCH_P9
    MOVQ  mask_len+24(FP), INP_SIZE_P9  // number of blocks to process
    MOVQ  mask+16(FP), MASKP_P9
    MOVQ (MASKP_P9), MASK_P9
    kmovq k1, mask
    LEAQ  inputs+40(FP), INPUT_P9

    // Initialize digests
    vmovdqu32 A, [STATE + 0*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 B, [STATE + 1*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 C, [STATE + 2*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 D, [STATE + 3*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 E, [STATE + 4*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 F, [STATE + 5*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 G, [STATE + 6*SHA256_DIGEST_ROW_SIZE]
    vmovdqu32 H, [STATE + 7*SHA256_DIGEST_ROW_SIZE]

    LEAQ TABLE<>(SB), TBL_P9

    // TODO: Fix comment
    // Do we need to transpose digests???
    // SHA1 does not, but SHA256 has been

    xor IDX, IDX

    // Read in first block of input data
    MASKED_LOAD( W0,  0, skipInput0)
    MASKED_LOAD( W1,  1, skipInput1)
    MASKED_LOAD( W2,  2, skipInput2)
    MASKED_LOAD( W3,  3, skipInput3)
    MASKED_LOAD( W4,  4, skipInput4)
    MASKED_LOAD( W5,  5, skipInput5)
    MASKED_LOAD( W6,  6, skipInput6)
    MASKED_LOAD( W7,  7, skipInput7)
    MASKED_LOAD( W8,  8, skipInput8)
    MASKED_LOAD( W9,  9, skipInput9)
    MASKED_LOAD(W10, 10, skipInput10)
    MASKED_LOAD(W11, 11, skipInput11)
    MASKED_LOAD(W12, 12, skipInput12)
    MASKED_LOAD(W13, 13, skipInput13)
    MASKED_LOAD(W14, 14, skipInput14)
    MASKED_LOAD(W15, 15, skipInput15)

lloop:
    LEAQ PSHUFFLE_BYTE_FLIP_MASK<>(SB), TBL_P9
    vmovdqu32 TMP2, [TBL]

    // First K
    LEAQ TABLE<>(SB), TBL_P9
    // TODO: load aligned
    vmovdqu32	TMP3, [TBL]

    // Save digests for later addition
    vmovdqu32 [SCRATCH + 64*0], A
    vmovdqu32 [SCRATCH + 64*1], B
    vmovdqu32 [SCRATCH + 64*2], C
    vmovdqu32 [SCRATCH + 64*3], D
    vmovdqu32 [SCRATCH + 64*4], E
    vmovdqu32 [SCRATCH + 64*5], F
    vmovdqu32 [SCRATCH + 64*6], G
    vmovdqu32 [SCRATCH + 64*7], H

    add IDX, 64

    // Transpose input data
    TRANSPOSE16(W0, W1, W2, W3, W4, W5, W6, W7, W8, W9, W10, W11, W12, W13, W14, W15, TMP0, TMP1)

    vpshufb W0, W0, TMP2
    vpshufb W1, W1, TMP2
    vpshufb W2, W2, TMP2
    vpshufb W3, W3, TMP2
    vpshufb W4, W4, TMP2
    vpshufb W5, W5, TMP2
    vpshufb W6, W6, TMP2
    vpshufb W7, W7, TMP2
    vpshufb W8, W8, TMP2
    vpshufb W9, W9, TMP2
    vpshufb W10, W10, TMP2
    vpshufb W11, W11, TMP2
    vpshufb W12, W12, TMP2
    vpshufb W13, W13, TMP2
    vpshufb W14, W14, TMP2
    vpshufb W15, W15, TMP2

    // MSG Schedule for W0-W15 is now complete in registers
    // Process first 48 rounds
    // Calculate next Wt+16 after processing is complete and Wt is unneeded

    PROCESS_LOOP( W0,  0, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_16_63( W0,  W1,  W9, W14)
    PROCESS_LOOP( W1,  1, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_16_63( W1,  W2, W10, W15)
    PROCESS_LOOP( W2,  2, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_16_63( W2,  W3, W11,  W0)
    PROCESS_LOOP( W3,  3, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_16_63( W3,  W4, W12,  W1)
    PROCESS_LOOP( W4,  4, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_16_63( W4,  W5, W13,  W2)
    PROCESS_LOOP( W5,  5, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_16_63( W5,  W6, W14,  W3)
    PROCESS_LOOP( W6,  6, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_16_63( W6,  W7, W15,  W4)
    PROCESS_LOOP( W7,  7, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_16_63( W7,  W8,  W0,  W5)
    PROCESS_LOOP( W8,  8, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_16_63( W8,  W9,  W1,  W6)
    PROCESS_LOOP( W9,  9, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_16_63( W9, W10,  W2,  W7)
    PROCESS_LOOP(W10, 10, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_16_63(W10, W11,  W3,  W8)
    PROCESS_LOOP(W11, 11, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_16_63(W11, W12,  W4,  W9)
    PROCESS_LOOP(W12, 12, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_16_63(W12, W13,  W5, W10)
    PROCESS_LOOP(W13, 13, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_16_63(W13, W14,  W6, W11)
    PROCESS_LOOP(W14, 14, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_16_63(W14, W15,  W7, W12)
    PROCESS_LOOP(W15, 15, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_16_63(W15,  W0,  W8, W13)
    PROCESS_LOOP( W0, 16, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_16_63( W0,  W1,  W9, W14)
    PROCESS_LOOP( W1, 17, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_16_63( W1,  W2, W10, W15)
    PROCESS_LOOP( W2, 18, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_16_63( W2,  W3, W11,  W0)
    PROCESS_LOOP( W3, 19, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_16_63( W3,  W4, W12,  W1)
    PROCESS_LOOP( W4, 20, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_16_63( W4,  W5, W13,  W2)
    PROCESS_LOOP( W5, 21, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_16_63( W5,  W6, W14,  W3)
    PROCESS_LOOP( W6, 22, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_16_63( W6,  W7, W15,  W4)
    PROCESS_LOOP( W7, 23, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_16_63( W7,  W8,  W0,  W5)
    PROCESS_LOOP( W8, 24, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_16_63( W8,  W9,  W1,  W6)
    PROCESS_LOOP( W9, 25, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_16_63( W9, W10,  W2,  W7)
    PROCESS_LOOP(W10, 26, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_16_63(W10, W11,  W3,  W8)
    PROCESS_LOOP(W11, 27, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_16_63(W11, W12,  W4,  W9)
    PROCESS_LOOP(W12, 28, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_16_63(W12, W13,  W5, W10)
    PROCESS_LOOP(W13, 29, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_16_63(W13, W14,  W6, W11)
    PROCESS_LOOP(W14, 30, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_16_63(W14, W15,  W7, W12)
    PROCESS_LOOP(W15, 31, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_16_63(W15,  W0,  W8, W13)
    PROCESS_LOOP( W0, 32, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_16_63( W0,  W1,  W9, W14)
    PROCESS_LOOP( W1, 33, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_16_63( W1,  W2, W10, W15)
    PROCESS_LOOP( W2, 34, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_16_63( W2,  W3, W11,  W0)
    PROCESS_LOOP( W3, 35, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_16_63( W3,  W4, W12,  W1)
    PROCESS_LOOP( W4, 36, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_16_63( W4,  W5, W13,  W2)
    PROCESS_LOOP( W5, 37, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_16_63( W5,  W6, W14,  W3)
    PROCESS_LOOP( W6, 38, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_16_63( W6,  W7, W15,  W4)
    PROCESS_LOOP( W7, 39, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_16_63( W7,  W8,  W0,  W5)
    PROCESS_LOOP( W8, 40, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_16_63( W8,  W9,  W1,  W6)
    PROCESS_LOOP( W9, 41, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_16_63( W9, W10,  W2,  W7)
    PROCESS_LOOP(W10, 42, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_16_63(W10, W11,  W3,  W8)
    PROCESS_LOOP(W11, 43, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_16_63(W11, W12,  W4,  W9)
    PROCESS_LOOP(W12, 44, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_16_63(W12, W13,  W5, W10)
    PROCESS_LOOP(W13, 45, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_16_63(W13, W14,  W6, W11)
    PROCESS_LOOP(W14, 46, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_16_63(W14, W15,  W7, W12)
    PROCESS_LOOP(W15, 47, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_16_63(W15,  W0,  W8, W13)

    // Check if this is the last block
    sub INP_SIZE, 1
    JE  lastLoop

    // Load next mask for inputs
    ADDQ $8, MASKP_P9
    MOVQ (MASKP_P9), MASK_P9

    // Process last 16 rounds
    // Read in next block msg data for use in first 16 words of msg sched

    PROCESS_LOOP( W0, 48, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_00_15( W0,  0, skipNext0)
    PROCESS_LOOP( W1, 49, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_00_15( W1,  1, skipNext1)
    PROCESS_LOOP( W2, 50, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_00_15( W2,  2, skipNext2)
    PROCESS_LOOP( W3, 51, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_00_15( W3,  3, skipNext3)
    PROCESS_LOOP( W4, 52, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_00_15( W4,  4, skipNext4)
    PROCESS_LOOP( W5, 53, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_00_15( W5,  5, skipNext5)
    PROCESS_LOOP( W6, 54, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_00_15( W6,  6, skipNext6)
    PROCESS_LOOP( W7, 55, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_00_15( W7,  7, skipNext7)
    PROCESS_LOOP( W8, 56, A, B, C, D, E, F, G, H)
    MSG_SCHED_ROUND_00_15( W8,  8, skipNext8)
    PROCESS_LOOP( W9, 57, H, A, B, C, D, E, F, G)
    MSG_SCHED_ROUND_00_15( W9,  9, skipNext9)
    PROCESS_LOOP(W10, 58, G, H, A, B, C, D, E, F)
    MSG_SCHED_ROUND_00_15(W10, 10, skipNext10)
    PROCESS_LOOP(W11, 59, F, G, H, A, B, C, D, E)
    MSG_SCHED_ROUND_00_15(W11, 11, skipNext11)
    PROCESS_LOOP(W12, 60, E, F, G, H, A, B, C, D)
    MSG_SCHED_ROUND_00_15(W12, 12, skipNext12)
    PROCESS_LOOP(W13, 61, D, E, F, G, H, A, B, C)
    MSG_SCHED_ROUND_00_15(W13, 13, skipNext13)
    PROCESS_LOOP(W14, 62, C, D, E, F, G, H, A, B)
    MSG_SCHED_ROUND_00_15(W14, 14, skipNext14)
    PROCESS_LOOP(W15, 63, B, C, D, E, F, G, H, A)
    MSG_SCHED_ROUND_00_15(W15, 15, skipNext15)

    // Add old digest
    vmovdqu32  TMP2, A
    vmovdqu32 A, [SCRATCH + 64*0]
    vpaddd A{k1}, A, TMP2
    vmovdqu32  TMP2, B
    vmovdqu32 B, [SCRATCH + 64*1]
    vpaddd B{k1}, B, TMP2
    vmovdqu32  TMP2, C
    vmovdqu32 C, [SCRATCH + 64*2]
    vpaddd C{k1}, C, TMP2
    vmovdqu32  TMP2, D
    vmovdqu32 D, [SCRATCH + 64*3]
    vpaddd D{k1}, D, TMP2
    vmovdqu32  TMP2, E
    vmovdqu32 E, [SCRATCH + 64*4]
    vpaddd E{k1}, E, TMP2
    vmovdqu32  TMP2, F
    vmovdqu32 F, [SCRATCH + 64*5]
    vpaddd F{k1}, F, TMP2
    vmovdqu32  TMP2, G
    vmovdqu32 G, [SCRATCH + 64*6]
    vpaddd G{k1}, G, TMP2
    vmovdqu32  TMP2, H
    vmovdqu32 H, [SCRATCH + 64*7]
    vpaddd H{k1}, H, TMP2

    kmovq k1, mask
    JMP lloop

lastLoop:
    // Process last 16 rounds
    PROCESS_LOOP( W0, 48, A, B, C, D, E, F, G, H)
    PROCESS_LOOP( W1, 49, H, A, B, C, D, E, F, G)
    PROCESS_LOOP( W2, 50, G, H, A, B, C, D, E, F)
    PROCESS_LOOP( W3, 51, F, G, H, A, B, C, D, E)
    PROCESS_LOOP( W4, 52, E, F, G, H, A, B, C, D)
    PROCESS_LOOP( W5, 53, D, E, F, G, H, A, B, C)
    PROCESS_LOOP( W6, 54, C, D, E, F, G, H, A, B)
    PROCESS_LOOP( W7, 55, B, C, D, E, F, G, H, A)
    PROCESS_LOOP( W8, 56, A, B, C, D, E, F, G, H)
    PROCESS_LOOP( W9, 57, H, A, B, C, D, E, F, G)
    PROCESS_LOOP(W10, 58, G, H, A, B, C, D, E, F)
    PROCESS_LOOP(W11, 59, F, G, H, A, B, C, D, E)
    PROCESS_LOOP(W12, 60, E, F, G, H, A, B, C, D)
    PROCESS_LOOP(W13, 61, D, E, F, G, H, A, B, C)
    PROCESS_LOOP(W14, 62, C, D, E, F, G, H, A, B)
    PROCESS_LOOP(W15, 63, B, C, D, E, F, G, H, A)

    // Add old digest
    vmovdqu32  TMP2, A
    vmovdqu32 A, [SCRATCH + 64*0]
    vpaddd A{k1}, A, TMP2
    vmovdqu32  TMP2, B
    vmovdqu32 B, [SCRATCH + 64*1]
    vpaddd B{k1}, B, TMP2
    vmovdqu32  TMP2, C
    vmovdqu32 C, [SCRATCH + 64*2]
    vpaddd C{k1}, C, TMP2
    vmovdqu32  TMP2, D
    vmovdqu32 D, [SCRATCH + 64*3]
    vpaddd D{k1}, D, TMP2
    vmovdqu32  TMP2, E
    vmovdqu32 E, [SCRATCH + 64*4]
    vpaddd E{k1}, E, TMP2
    vmovdqu32  TMP2, F
    vmovdqu32 F, [SCRATCH + 64*5]
    vpaddd F{k1}, F, TMP2
    vmovdqu32  TMP2, G
    vmovdqu32 G, [SCRATCH + 64*6]
    vpaddd G{k1}, G, TMP2
    vmovdqu32  TMP2, H
    vmovdqu32 H, [SCRATCH + 64*7]
    vpaddd H{k1}, H, TMP2

    // Write out digest
    // Do we need to untranspose digests???
    vmovdqu32 [STATE + 0*SHA256_DIGEST_ROW_SIZE], A
    vmovdqu32 [STATE + 1*SHA256_DIGEST_ROW_SIZE], B
    vmovdqu32 [STATE + 2*SHA256_DIGEST_ROW_SIZE], C
    vmovdqu32 [STATE + 3*SHA256_DIGEST_ROW_SIZE], D
    vmovdqu32 [STATE + 4*SHA256_DIGEST_ROW_SIZE], E
    vmovdqu32 [STATE + 5*SHA256_DIGEST_ROW_SIZE], F
    vmovdqu32 [STATE + 6*SHA256_DIGEST_ROW_SIZE], G
    vmovdqu32 [STATE + 7*SHA256_DIGEST_ROW_SIZE], H

    VZEROUPPER
    RET

//
// Tables
//

DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x000(SB)/8, $0x0405060700010203
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x008(SB)/8, $0x0c0d0e0f08090a0b
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x010(SB)/8, $0x0405060700010203
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x018(SB)/8, $0x0c0d0e0f08090a0b
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x020(SB)/8, $0x0405060700010203
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x028(SB)/8, $0x0c0d0e0f08090a0b
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x030(SB)/8, $0x0405060700010203
DATA PSHUFFLE_BYTE_FLIP_MASK<>+0x038(SB)/8, $0x0c0d0e0f08090a0b
GLOBL PSHUFFLE_BYTE_FLIP_MASK<>(SB), 8, $64

DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x000(SB)/8, $0x0000000000000000
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x008(SB)/8, $0x0000000000000001
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x010(SB)/8, $0x0000000000000008
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x018(SB)/8, $0x0000000000000009
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x020(SB)/8, $0x0000000000000004
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x028(SB)/8, $0x0000000000000005
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x030(SB)/8, $0x000000000000000C
DATA PSHUFFLE_TRANSPOSE16_MASK1<>+0x038(SB)/8, $0x000000000000000D
GLOBL PSHUFFLE_TRANSPOSE16_MASK1<>(SB), 8, $64

DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x000(SB)/8, $0x0000000000000002
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x008(SB)/8, $0x0000000000000003
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x010(SB)/8, $0x000000000000000A
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x018(SB)/8, $0x000000000000000B
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x020(SB)/8, $0x0000000000000006
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x028(SB)/8, $0x0000000000000007
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x030(SB)/8, $0x000000000000000E
DATA PSHUFFLE_TRANSPOSE16_MASK2<>+0x038(SB)/8, $0x000000000000000F
GLOBL PSHUFFLE_TRANSPOSE16_MASK2<>(SB), 8, $64

DATA TABLE<>+0x000(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x008(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x010(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x018(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x020(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x028(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x030(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x038(SB)/8, $0x428a2f98428a2f98
DATA TABLE<>+0x040(SB)/8, $0x7137449171374491
DATA TABLE<>+0x048(SB)/8, $0x7137449171374491
DATA TABLE<>+0x050(SB)/8, $0x7137449171374491
DATA TABLE<>+0x058(SB)/8, $0x7137449171374491
DATA TABLE<>+0x060(SB)/8, $0x7137449171374491
DATA TABLE<>+0x068(SB)/8, $0x7137449171374491
DATA TABLE<>+0x070(SB)/8, $0x7137449171374491
DATA TABLE<>+0x078(SB)/8, $0x7137449171374491
DATA TABLE<>+0x080(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x088(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x090(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x098(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x0a0(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x0a8(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x0b0(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x0b8(SB)/8, $0xb5c0fbcfb5c0fbcf
DATA TABLE<>+0x0c0(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0c8(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0d0(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0d8(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0e0(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0e8(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0f0(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x0f8(SB)/8, $0xe9b5dba5e9b5dba5
DATA TABLE<>+0x100(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x108(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x110(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x118(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x120(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x128(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x130(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x138(SB)/8, $0x3956c25b3956c25b
DATA TABLE<>+0x140(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x148(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x150(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x158(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x160(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x168(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x170(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x178(SB)/8, $0x59f111f159f111f1
DATA TABLE<>+0x180(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x188(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x190(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x198(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x1a0(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x1a8(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x1b0(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x1b8(SB)/8, $0x923f82a4923f82a4
DATA TABLE<>+0x1c0(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1c8(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1d0(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1d8(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1e0(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1e8(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1f0(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x1f8(SB)/8, $0xab1c5ed5ab1c5ed5
DATA TABLE<>+0x200(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x208(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x210(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x218(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x220(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x228(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x230(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x238(SB)/8, $0xd807aa98d807aa98
DATA TABLE<>+0x240(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x248(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x250(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x258(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x260(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x268(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x270(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x278(SB)/8, $0x12835b0112835b01
DATA TABLE<>+0x280(SB)/8, $0x243185be243185be
DATA TABLE<>+0x288(SB)/8, $0x243185be243185be
DATA TABLE<>+0x290(SB)/8, $0x243185be243185be
DATA TABLE<>+0x298(SB)/8, $0x243185be243185be
DATA TABLE<>+0x2a0(SB)/8, $0x243185be243185be
DATA TABLE<>+0x2a8(SB)/8, $0x243185be243185be
DATA TABLE<>+0x2b0(SB)/8, $0x243185be243185be
DATA TABLE<>+0x2b8(SB)/8, $0x243185be243185be
DATA TABLE<>+0x2c0(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2c8(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2d0(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2d8(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2e0(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2e8(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2f0(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x2f8(SB)/8, $0x550c7dc3550c7dc3
DATA TABLE<>+0x300(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x308(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x310(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x318(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x320(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x328(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x330(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x338(SB)/8, $0x72be5d7472be5d74
DATA TABLE<>+0x340(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x348(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x350(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x358(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x360(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x368(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x370(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x378(SB)/8, $0x80deb1fe80deb1fe
DATA TABLE<>+0x380(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x388(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x390(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x398(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x3a0(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x3a8(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x3b0(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x3b8(SB)/8, $0x9bdc06a79bdc06a7
DATA TABLE<>+0x3c0(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3c8(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3d0(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3d8(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3e0(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3e8(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3f0(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x3f8(SB)/8, $0xc19bf174c19bf174
DATA TABLE<>+0x400(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x408(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x410(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x418(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x420(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x428(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x430(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x438(SB)/8, $0xe49b69c1e49b69c1
DATA TABLE<>+0x440(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x448(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x450(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x458(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x460(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x468(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x470(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x478(SB)/8, $0xefbe4786efbe4786
DATA TABLE<>+0x480(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x488(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x490(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x498(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x4a0(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x4a8(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x4b0(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x4b8(SB)/8, $0x0fc19dc60fc19dc6
DATA TABLE<>+0x4c0(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4c8(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4d0(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4d8(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4e0(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4e8(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4f0(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x4f8(SB)/8, $0x240ca1cc240ca1cc
DATA TABLE<>+0x500(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x508(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x510(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x518(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x520(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x528(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x530(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x538(SB)/8, $0x2de92c6f2de92c6f
DATA TABLE<>+0x540(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x548(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x550(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x558(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x560(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x568(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x570(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x578(SB)/8, $0x4a7484aa4a7484aa
DATA TABLE<>+0x580(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x588(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x590(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x598(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x5a0(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x5a8(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x5b0(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x5b8(SB)/8, $0x5cb0a9dc5cb0a9dc
DATA TABLE<>+0x5c0(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5c8(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5d0(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5d8(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5e0(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5e8(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5f0(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x5f8(SB)/8, $0x76f988da76f988da
DATA TABLE<>+0x600(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x608(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x610(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x618(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x620(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x628(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x630(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x638(SB)/8, $0x983e5152983e5152
DATA TABLE<>+0x640(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x648(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x650(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x658(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x660(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x668(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x670(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x678(SB)/8, $0xa831c66da831c66d
DATA TABLE<>+0x680(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x688(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x690(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x698(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x6a0(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x6a8(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x6b0(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x6b8(SB)/8, $0xb00327c8b00327c8
DATA TABLE<>+0x6c0(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6c8(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6d0(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6d8(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6e0(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6e8(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6f0(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x6f8(SB)/8, $0xbf597fc7bf597fc7
DATA TABLE<>+0x700(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x708(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x710(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x718(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x720(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x728(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x730(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x738(SB)/8, $0xc6e00bf3c6e00bf3
DATA TABLE<>+0x740(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x748(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x750(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x758(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x760(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x768(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x770(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x778(SB)/8, $0xd5a79147d5a79147
DATA TABLE<>+0x780(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x788(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x790(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x798(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x7a0(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x7a8(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x7b0(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x7b8(SB)/8, $0x06ca635106ca6351
DATA TABLE<>+0x7c0(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7c8(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7d0(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7d8(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7e0(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7e8(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7f0(SB)/8, $0x1429296714292967
DATA TABLE<>+0x7f8(SB)/8, $0x1429296714292967
DATA TABLE<>+0x800(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x808(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x810(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x818(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x820(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x828(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x830(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x838(SB)/8, $0x27b70a8527b70a85
DATA TABLE<>+0x840(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x848(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x850(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x858(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x860(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x868(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x870(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x878(SB)/8, $0x2e1b21382e1b2138
DATA TABLE<>+0x880(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x888(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x890(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x898(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x8a0(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x8a8(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x8b0(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x8b8(SB)/8, $0x4d2c6dfc4d2c6dfc
DATA TABLE<>+0x8c0(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8c8(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8d0(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8d8(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8e0(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8e8(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8f0(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x8f8(SB)/8, $0x53380d1353380d13
DATA TABLE<>+0x900(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x908(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x910(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x918(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x920(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x928(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x930(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x938(SB)/8, $0x650a7354650a7354
DATA TABLE<>+0x940(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x948(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x950(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x958(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x960(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x968(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x970(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x978(SB)/8, $0x766a0abb766a0abb
DATA TABLE<>+0x980(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x988(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x990(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x998(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x9a0(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x9a8(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x9b0(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x9b8(SB)/8, $0x81c2c92e81c2c92e
DATA TABLE<>+0x9c0(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9c8(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9d0(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9d8(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9e0(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9e8(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9f0(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0x9f8(SB)/8, $0x92722c8592722c85
DATA TABLE<>+0xa00(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa08(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa10(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa18(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa20(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa28(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa30(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa38(SB)/8, $0xa2bfe8a1a2bfe8a1
DATA TABLE<>+0xa40(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa48(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa50(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa58(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa60(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa68(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa70(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa78(SB)/8, $0xa81a664ba81a664b
DATA TABLE<>+0xa80(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xa88(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xa90(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xa98(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xaa0(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xaa8(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xab0(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xab8(SB)/8, $0xc24b8b70c24b8b70
DATA TABLE<>+0xac0(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xac8(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xad0(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xad8(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xae0(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xae8(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xaf0(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xaf8(SB)/8, $0xc76c51a3c76c51a3
DATA TABLE<>+0xb00(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb08(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb10(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb18(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb20(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb28(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb30(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb38(SB)/8, $0xd192e819d192e819
DATA TABLE<>+0xb40(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb48(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb50(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb58(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb60(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb68(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb70(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb78(SB)/8, $0xd6990624d6990624
DATA TABLE<>+0xb80(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xb88(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xb90(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xb98(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xba0(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xba8(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xbb0(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xbb8(SB)/8, $0xf40e3585f40e3585
DATA TABLE<>+0xbc0(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbc8(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbd0(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbd8(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbe0(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbe8(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbf0(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xbf8(SB)/8, $0x106aa070106aa070
DATA TABLE<>+0xc00(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc08(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc10(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc18(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc20(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc28(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc30(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc38(SB)/8, $0x19a4c11619a4c116
DATA TABLE<>+0xc40(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc48(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc50(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc58(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc60(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc68(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc70(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc78(SB)/8, $0x1e376c081e376c08
DATA TABLE<>+0xc80(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xc88(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xc90(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xc98(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xca0(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xca8(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xcb0(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xcb8(SB)/8, $0x2748774c2748774c
DATA TABLE<>+0xcc0(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xcc8(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xcd0(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xcd8(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xce0(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xce8(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xcf0(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xcf8(SB)/8, $0x34b0bcb534b0bcb5
DATA TABLE<>+0xd00(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd08(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd10(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd18(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd20(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd28(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd30(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd38(SB)/8, $0x391c0cb3391c0cb3
DATA TABLE<>+0xd40(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd48(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd50(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd58(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd60(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd68(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd70(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd78(SB)/8, $0x4ed8aa4a4ed8aa4a
DATA TABLE<>+0xd80(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xd88(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xd90(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xd98(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xda0(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xda8(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xdb0(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xdb8(SB)/8, $0x5b9cca4f5b9cca4f
DATA TABLE<>+0xdc0(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xdc8(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xdd0(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xdd8(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xde0(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xde8(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xdf0(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xdf8(SB)/8, $0x682e6ff3682e6ff3
DATA TABLE<>+0xe00(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe08(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe10(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe18(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe20(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe28(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe30(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe38(SB)/8, $0x748f82ee748f82ee
DATA TABLE<>+0xe40(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe48(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe50(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe58(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe60(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe68(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe70(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe78(SB)/8, $0x78a5636f78a5636f
DATA TABLE<>+0xe80(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xe88(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xe90(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xe98(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xea0(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xea8(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xeb0(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xeb8(SB)/8, $0x84c8781484c87814
DATA TABLE<>+0xec0(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xec8(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xed0(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xed8(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xee0(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xee8(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xef0(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xef8(SB)/8, $0x8cc702088cc70208
DATA TABLE<>+0xf00(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf08(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf10(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf18(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf20(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf28(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf30(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf38(SB)/8, $0x90befffa90befffa
DATA TABLE<>+0xf40(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf48(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf50(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf58(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf60(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf68(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf70(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf78(SB)/8, $0xa4506ceba4506ceb
DATA TABLE<>+0xf80(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xf88(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xf90(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xf98(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xfa0(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xfa8(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xfb0(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xfb8(SB)/8, $0xbef9a3f7bef9a3f7
DATA TABLE<>+0xfc0(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xfc8(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xfd0(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xfd8(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xfe0(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xfe8(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xff0(SB)/8, $0xc67178f2c67178f2
DATA TABLE<>+0xff8(SB)/8, $0xc67178f2c67178f2
GLOBL TABLE<>(SB), 8, $4096

