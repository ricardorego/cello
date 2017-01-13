#
#
#            Nim's Runtime Library
#        (c) Copyright 2017 Nim Authors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module implements a series of low level methods for bit manipulation.
## By default, this module use compiler intrinsics to improve performance
## on supported compilers: ``GCC``, ``LLVM_GCC``, ``CLANG``, ``VCC``, ``ICC``.
##
## The module will fallback to pure nim procs incase the backend is not supported.
## You can also use the flag `noIntrinsicsBitOpts` to disable compiler intrinsics.
##
## This module is also compatible with other backends: ``Javascript``, ``Nimscript``
## as well as the ``compiletime VM``.


const useBuiltins = not defined(noIntrinsicsBitOpts)
const useGCC_builtins = (defined(gcc) or defined(llvm_gcc) or defined(clang)) and useBuiltins
const useICC_builtins = defined(icc) and useBuiltins
const useVCC_builtins = defined(vcc) and useBuiltins

# #### Pure Nim version ####

proc firstSetBit_nim(x: uint32): cint {.inline, nosideeffect.} =
    ## Returns the 1-based index of the least significant set bit of x, or if x is zero, returns zero.
    # https://graphics.stanford.edu/%7Eseander/bithacks.html#ZerosOnRightMultLookup
    const lookup: array[32, uint8] = [0'u8, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15,
        25, 17, 4, 8, 31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9]
    var v = x.uint32
    var k = not v + 1 # get two's complement # cast[uint32](-cast[int32](v))
    result = 1.cint + lookup[uint32((v and k) * 0x077CB531'u32) shr 27].cint

proc firstSetBit_nim(x: uint64): cint {.inline, nosideeffect.} =
    ## Returns the 1-based index of the least significant set bit of x, or if x is zero, returns zero.
    # https://graphics.stanford.edu/%7Eseander/bithacks.html#ZerosOnRightMultLookup
    var v = uint64(x)
    var k = uint32(v and 0xFFFFFFFF'u32)
    if k == 0:
        k = uint32(v shr 32'u32) and 0xFFFFFFFF'u32
        result = 32
    result += firstSetBit_nim(k)

proc fastlog2_nim(x: uint32): int {.inline, nosideeffect.} =
    ## Quickly find the log base 2 of a 32-bit or less integer.
    # https://graphics.stanford.edu/%7Eseander/bithacks.html#IntegerLogDeBruijn
    # https://stackoverflow.com/questions/11376288/fast-computing-of-log2-for-64-bit-integers
    const lookup: array[32, uint8] = [0'u8, 9, 1, 10, 13, 21, 2, 29, 11, 14, 16, 18,
        22, 25, 3, 30, 8, 12, 20, 28, 15, 17, 24, 7, 19, 27, 23, 6, 26, 5, 4, 31]
    var v = x.uint32
    v = v or v shr 1 # first round down to one less than a power of 2
    v = v or v shr 2
    v = v or v shr 4
    v = v or v shr 8
    v = v or v shr 16
    result = lookup[uint32(v * 0x07C4ACDD'u32) shr 27].int

proc fastlog2_nim(x: uint64): int {.inline, nosideeffect.} =
    ## Quickly find the log base 2 of a 64-bit integer.
    # https://graphics.stanford.edu/%7Eseander/bithacks.html#IntegerLogDeBruijn
    # https://stackoverflow.com/questions/11376288/fast-computing-of-log2-for-64-bit-integers
    const lookup: array[64, uint8] = [0'u8, 58, 1, 59, 47, 53, 2, 60, 39, 48, 27, 54,
        33, 42, 3, 61, 51, 37, 40, 49, 18, 28, 20, 55, 30, 34, 11, 43, 14, 22, 4, 62,
        57, 46, 52, 38, 26, 32, 41, 50, 36, 17, 19, 29, 10, 13, 21, 56, 45, 25, 31,
        35, 16, 9, 12, 44, 24, 15, 8, 23, 7, 6, 5, 63]
    var v = x.uint64
    v = v or v shr 1 # first round down to one less than a power of 2
    v = v or v shr 2
    v = v or v shr 4
    v = v or v shr 8
    v = v or v shr 16
    v = v or v shr 32
    result = lookup[(v * 0x03F6EAF2CD271461'u64) shr 58].int


proc countSetBits_nim(n: uint32): cint {.inline, noSideEffect.} =
  ## Counts the set bits in integer. (also called Hamming weight.)
  # generic formula is from: https://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetParallel

  var v = uint32(n)
  v = v - ((v shr 1) and 0x55555555)
  v = (v and 0x33333333) + ((v shr 2) and 0x33333333)
  result = (((v + (v shr 4) and 0xF0F0F0F) * 0x1010101) shr 24).cint

proc countSetBits_nim(n: uint64): cint {.inline, noSideEffect.} =
  ## Counts the set bits in integer. (also called Hamming weight.)
  # generic formula is from: https://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetParallel
  var v = uint64(n)
  v = v - ((v shr 1'u64) and 0x5555555555555555'u64)
  v = (v and 0x3333333333333333'u64) + ((v shr 2'u64) and 0x3333333333333333'u64)
  v = (v + (v shr 4'u64) and 0x0F0F0F0F0F0F0F0F'u64)
  result = ((v * 0x0101010101010101'u64) shr 56'u64).cint


template parity_impl[T](value: T): cint =
    # formula id from: https://graphics.stanford.edu/%7Eseander/bithacks.html#ParityParallel
    var v = value
    when sizeof(T) == 8:
        v = v xor (v shr 32)
    when sizeof(T) >= 4:
        v = v xor (v shr 16)
    when sizeof(T) >= 2:
        v = v xor (v shr 8)
    v = v xor (v shr 4)
    v = v and 0xf
    ((0x6996'u shr v) and 1).cint


when useGCC_builtins:
    # Returns the number of set 1-bits in value.
    proc builtin_popcount(x: cuint): cint {.importc: "__builtin_popcount", cdecl.}
    proc builtin_popcountll(x: culonglong): cint {.importc: "__builtin_popcountll", cdecl.}

    # Returns the bit parity in value
    proc builtin_parity(x: cuint): cint {.importc: "__builtin_parity", cdecl.}
    proc builtin_parityll(x: culonglong): cint {.importc: "__builtin_parityll", cdecl.}

    # Returns one plus the index of the least significant 1-bit of x, or if x is zero, returns zero.
    proc builtin_ffs(x: cint): cint {.importc: "__builtin_ffs", cdecl.}
    proc builtin_ffsll(x: clonglong): cint {.importc: "__builtin_ffsll", cdecl.}

    # Returns the number of leading 0-bits in x, starting at the most significant bit position. If x is 0, the result is undefined.
    proc builtin_clz(x: cuint): cint {.importc: "__builtin_clz", cdecl.}
    proc builtin_clzll(x: culonglong): cint {.importc: "__builtin_clzll", cdecl.}

    # Returns the number of trailing 0-bits in x, starting at the least significant bit position. If x is 0, the result is undefined.
    proc builtin_ctz(x: cuint): cint {.importc: "__builtin_ctz", cdecl.}
    proc builtin_ctzll(x: culonglong): cint {.importc: "__builtin_ctzll", cdecl.}

elif useVCC_builtins:
    # Counts the number of one bits (population count) in a 16-, 32-, or 64-byte unsigned integer.
    proc builtin_popcnt16(a2: uint16): uint16 {.importc: "__popcnt16" header: "<intrin.h>", nosideeffect.}
    proc builtin_popcnt32(a2: uint32): uint32 {.importc: "__popcnt" header: "<intrin.h>", nosideeffect.}
    proc builtin_popcnt64(a2: uint64): uint64 {.importc: "__popcnt64" header: "<intrin.h>", nosideeffect.}

    # Search the mask data from most significant bit (MSB) to least significant bit (LSB) for a set bit (1).
    proc bitScanReverse(index: ptr culong, mask: culong): cuchar {.importc: "_BitScanReverse", header: "<intrin.h>", nosideeffect.}
    proc bitScanReverse64(index: ptr culong, mask: uint64): cuchar {.importc: "_BitScanReverse64", header: "<intrin.h>", nosideeffect.}

    # Search the mask data from least significant bit (LSB) to the most significant bit (MSB) for a set bit (1).
    proc bitScanForward(index: ptr culong, mask: culong): cuchar {.importc: "_bitScanForward", header: "<intrin.h>", nosideeffect.}
    proc bitScanForward64(index: ptr culong, mask: uint64): cuchar {.importc: "_bitScanForward64", header: "<intrin.h>", nosideeffect.}

    template vcc_scan_impl(fnc: untyped; v: untyped): cint =
        var index: culong
        discard fnc(index.addr, v)
        index.cint

elif useICC_builtins:

    # Intel compiler intrinsics: http://fulla.fnal.gov/intel/compiler_c/main_cls/intref_cls/common/intref_allia_misc.htm
    # see also: https://software.intel.com/en-us/node/523362
    # Returns the number of trailing 0-bits in x, starting at the least significant bit position. If x is 0, the result is undefined.
    proc bitScanForward(p: ptr uint32, b: uint32): cuchar {.importc: "_BitScanForward", header: "<immintrin.h>", nosideeffect.}
    proc bitScanForward64(p: ptr uint32, b: uint64): cuchar {.importc: "_BitScanForward64", header: "<immintrin.h>", nosideeffect.}

    # Returns the number of leading 0-bits in x, starting at the most significant bit position. If x is 0, the result is undefined.
    proc BitScanReverse(p: ptr uint32, b: uint32): cuchar {.importc: "_BitScanReverse", header: "<immintrin.h>", nosideeffect.}
    proc BitScanReverse64(p: ptr uint32, b: uint64): cuchar {.importc: "_BitScanReverse64", header: "<immintrin.h>", nosideeffect.}

    template icc_scan_impl(fnc: untyped; v: untyped): cint =
        var index: uint32
        discard fnc(index.addr, v)
        index.cint

{.push rangeChecks: off}
proc countSetBits*(x: SomeInteger): cint {.inline, nosideeffect.} =
    ## Counts the set bits in integer. (also called Hamming weight.)
    when nimvm:
        when sizeof(x) <= 4: result = countSetBits_nim(x.uint32)
        else:                result = countSetBits_nim(x.uint64)
    else:
        when useGCC_builtins:
            when sizeof(x) <= 4: result = builtin_popcount(x.cuint)
            else:                result = builtin_popcountll(x.culonglong)
        elif useVCC_builtins:
            when sizeof(x) <= 2: result = builtin_popcnt16(x.uint16).cint
            elif sizeof(x) <= 4: result = builtin_popcnt32(x.uint32).cint
            else:                result = builtin_popcnt64(x.uint64).cint
        else:
            when sizeof(x) <= 4: result = countSetBits_nim(x.uint32)
            else:                result = countSetBits_nim(x.uint64)

proc parityBits*(x: SomeInteger): cint {.inline, nosideeffect.} =
    ## Calculate the bit parity in integer. If number of 1-bit
    ## is odd parity is 1, otherwise 0.    when nimvm:
    when nimvm:
        when sizeof(x) <= 4: result = parity_impl(x.uint32)
        else:                result = parity_impl(x.uint64)
    else:
        when useGCC_builtins:
            when sizeof(x) <= 4: result = builtin_parity(x.uint32)
            else:                result = builtin_parityll(x.uint64)
        else:
            when sizeof(x) <= 4: result = parity_impl(x.uint32)
            else:                result = parity_impl(x.uint64)

proc firstSetBit*(x: SomeInteger): cint {.inline, nosideeffect.} =
    ## Returns the 1-based index of the least significant set bit of x, or if x is zero, returns zero.
    when nimvm:
        when sizeof(x) <= 4: result = firstSetBit_nim(x.uint32)
        else:                result = firstSetBit_nim(x.uint64)
    else:
        when useGCC_builtins:
            when sizeof(x) <= 4: result = builtin_ffs(x.cint)
            else:                result = builtin_ffsll(x.clonglong)
        elif useVCC_builtins:
            when sizeof(x) <= 4:
                result = 1.cint + vcc_scan_impl(bitScanForward, x.culong)
            else:
                result = 1.cint + vcc_scan_impl(bitScanForward64, x.uint64)
        elif useICC_builtins:
            when sizeof(x) <= 4:
                result = 1.cint + icc_scan_impl(bitScanForward, x.uint32)
            else:
                result = 1.cint + icc_scan_impl(bitScanForward64, x.uint64)
        else:
            when sizeof(x) <= 4: result = firstSetBit_nim(x.uint32)
            else:                result = firstSetBit_nim(x.uint64)

proc fastlog2*(x: SomeInteger): int {.inline, nosideeffect.} =
    ## Quickly find the log base 2 of a 32-bit or less integer.
    when nimvm:
        when sizeof(x) <= 4: result = fastlog2_nim(x.uint32)
        else:                result = fastlog2_nim(x.uint64)
    else:
        when useGCC_builtins:
            when sizeof(x) <= 4: result = 31 - builtin_clz(x.uint32).int
            else:                result = 63 - builtin_clzll(x.uint64).int
        elif useVCC_builtins:
            when sizeof(x) <= 4:
                result = 31 - vcc_scan_impl(bitScanReverse, x.culong).int
            else:
                result = 63 - vcc_scan_impl(bitScanReverse64, x.uint64).int
        elif useICC_builtins:
            when sizeof(x) <= 4:
                result = 31 - icc_scan_impl(bitScanReverse, x.uint32).int
            else:
                result = 63 - icc_scan_impl(bitScanReverse64, x.uint64).int
        else:
            when sizeof(x) <= 4: result = fastlog2_nim(x.uint32)
            else:                result = fastlog2_nim(x.uint64)

proc leadingZeroBits*(x: SomeInteger): cint {.inline, nosideeffect.} =
    ## Returns the number of leading zero bits in integer.
    when nimvm:
            when sizeof(x) <= 4: result = sizeof(x)*8 - 1 - fastlog2_nim(x.uint32).cint
            else:                result = sizeof(x)*8 - 1 - fastlog2_nim(x.uint64).cint
    else:
        when useGCC_builtins:
            when sizeof(x) <= 4: result = builtin_clz(x.uint32) - (32 - sizeof(x)*8)
            else:                result = builtin_clzll(x.uint64)
        else:
            when sizeof(x) <= 4: result = sizeof(x)*8 - 1 - fastlog2_nim(x.uint32).cint
            else:                result = sizeof(x)*8 - 1 - fastlog2_nim(x.uint64).cint

proc trailingZeroBits*(x: SomeInteger): cint {.inline, nosideeffect.} =
    ## Returns the number of trailing zeros in integer.
    when nimvm:
        result = firstSetBit(x) - 1
    else:
        when useGCC_builtins:
            when sizeof(x) <= 4: result = builtin_ctz(x.uint32)
            else:                result = builtin_ctzll(x.uint64)
        else:
            result = firstSetBit(x) - 1




proc rotateLeftBits*(value: uint8;
                     amount: range[1..7]): uint8 {.inline, noSideEffect.} =
    ## Left-rotate bits in a 8-bits value.
    result = (value shl amount) or (value shr (8 - amount))

proc rotateLeftBits*(value: uint16;
                     amount: range[1..15]): uint16 {.inline, noSideEffect.} =
    ## Left-rotate bits in a 16-bits value.
    result = (value shl amount) or (value shr (16 - amount))

proc rotateLeftBits*(value: uint32;
                     amount: range[1..31]): uint32 {.inline, noSideEffect.} =
    ## Left-rotate bits in a 32-bits value.
    result = (value shl amount) or (value shr (32 - amount))

proc rotateLeftBits*(value: uint64;
                     amount: range[1..63]): uint64 {.inline, noSideEffect.} =
    ## Left-rotate bits in a 64-bits value.
    result = (value shl amount) or (value shr (64 - amount))


proc rotateRightBits*(value: uint8;
                      amount: range[1..7]): uint8 {.inline, noSideEffect.} =
    ## Right-rotate bits in a 8-bits value.
    result = (value shr amount) or (value shl (8 - amount))

proc rotateRightBits*(value: uint16;
                      amount: range[1..15]): uint16 {.inline, noSideEffect.} =
    ## Right-rotate bits in a 16-bits value.
    result = (value shr amount) or (value shl (16 - amount))

proc rotateRightBits*(value: uint32;
                      amount: range[1..31]): uint32 {.inline, noSideEffect.} =
    ## Right-rotate bits in a 32-bits value.
    result = (value shr amount) or (value shl (32 - amount))

proc rotateRightBits*(value: uint64;
                      amount: range[1..63]): uint64 {.inline, noSideEffect.} =
    ## Right-rotate bits in a 64-bits value.
    result = (value shr amount) or (value shl (64 - amount))
{.pop.}
