package com.koma.koma.piper

object PiperNative {
    init {
        // ONNX Runtime must load before koma_piper (dynamic link dependency).
        System.loadLibrary("onnxruntime")
        System.loadLibrary("koma_piper")
    }

    fun version(): String = nativeVersion()

    fun create(modelPath: String, configPath: String, espeakPath: String): Long =
        nativeCreate(modelPath, configPath, espeakPath)

    fun free(handle: Long) {
        if (handle != 0L) nativeFree(handle)
    }

    fun synthesize(
        handle: Long,
        text: String,
        lengthScale: Float,
        noiseScale: Float,
        noiseWScale: Float,
        speakerId: Int,
    ): ByteArray? = nativeSynthesize(
        handle,
        text,
        lengthScale,
        noiseScale,
        noiseWScale,
        speakerId,
    )

    private external fun nativeVersion(): String
    private external fun nativeCreate(
        modelPath: String,
        configPath: String,
        espeakPath: String,
    ): Long

    private external fun nativeFree(handle: Long)

    private external fun nativeSynthesize(
        handle: Long,
        text: String,
        lengthScale: Float,
        noiseScale: Float,
        noiseWScale: Float,
        speakerId: Int,
    ): ByteArray?
}
