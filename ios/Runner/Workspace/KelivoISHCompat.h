//
//  KelivoISHCompat.h
//  Runner
//
//  Include immediately before any iSH headers. Apple's <assert.h> only
//  aliases `static_assert` in C++, so Objective-C sees `static assert(...)`
//  and fails to parse emu/arch/arm64/cpu.h. iSH itself builds as gnu11
//  with Homebrew LLVM, whose assert.h provides the C11 alias.
//

#ifndef KelivoISHCompat_h
#define KelivoISHCompat_h

#ifdef assert
#undef assert
#endif
#ifndef static_assert
#define static_assert _Static_assert
#endif

#endif /* KelivoISHCompat_h */
