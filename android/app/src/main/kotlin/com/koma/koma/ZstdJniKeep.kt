package com.koma.koma

import com.squareup.zstd.ZstdCompressor
import com.squareup.zstd.ZstdDecompressor

/**
 * Compile-time anchors so R8 cannot strip Square zstd JNI types.
 *
 * `libzstd-kmp.so` looks them up by name from [JniZstdKt.createJniZstd].
 * A missing class becomes a pending `ClassNotFoundException` across JNI,
 * which ART treats as fatal (`No pending exception expected`) and aborts
 * the process — [UncaughtExceptionInterceptor] never sees it.
 */
object ZstdJniKeep {
    @JvmField
    val compressor: Class<out ZstdCompressor> = ZstdCompressor::class.java

    @JvmField
    val decompressor: Class<out ZstdDecompressor> = ZstdDecompressor::class.java

    fun pin() {
        check(compressor.name == "com.squareup.zstd.ZstdCompressor")
        check(decompressor.name == "com.squareup.zstd.ZstdDecompressor")
    }
}
