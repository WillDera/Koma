package com.koma.koma.piper

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PiperMethodChannel(private val context: Context) {

    private var voiceHandle: Long = 0L

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initEspeak" -> {
                Thread {
                    try {
                        PiperNative.version()
                        val path = PiperEspeakAssets.ensureExtracted(context)
                        result.success(path)
                    } catch (e: Throwable) {
                        Log.e("Piper", "initEspeak failed", e)
                        result.error("ESPEAK", e.message, null)
                    }
                }.start()
            }
            "loadVoice" -> {
                val modelPath = call.argument<String>("modelPath")
                    ?: return result.error("ARG", "missing modelPath", null)
                val configPath = call.argument<String>("configPath")
                    ?: return result.error("ARG", "missing configPath", null)
                val espeakPath = call.argument<String>("espeakPath")
                    ?: return result.error("ARG", "missing espeakPath", null)
                Thread {
                    try {
                        PiperNative.version()
                        if (voiceHandle != 0L) {
                            PiperNative.free(voiceHandle)
                            voiceHandle = 0L
                        }
                        val handle = PiperNative.create(modelPath, configPath, espeakPath)
                        if (handle == 0L) {
                            result.error("LOAD", "piper_create failed", null)
                            return@Thread
                        }
                        voiceHandle = handle
                        result.success(null)
                    } catch (e: Throwable) {
                        Log.e("Piper", "loadVoice failed", e)
                        result.error("LOAD", e.message, null)
                    }
                }.start()
            }
            "freeVoice" -> {
                Thread {
                    try {
                        if (voiceHandle != 0L) {
                            PiperNative.free(voiceHandle)
                            voiceHandle = 0L
                        }
                        result.success(null)
                    } catch (e: Throwable) {
                        result.error("FREE", e.message, null)
                    }
                }.start()
            }
            "synthesize" -> {
                val text = call.argument<String>("text")
                    ?: return result.error("ARG", "missing text", null)
                val lengthScale = call.argument<Double>("lengthScale")?.toFloat() ?: 1.0f
                val noiseScale = call.argument<Double>("noiseScale")?.toFloat() ?: 0.667f
                val noiseWScale = call.argument<Double>("noiseWScale")?.toFloat() ?: 0.8f
                val speakerId = call.argument<Int>("speakerId") ?: 0
                Thread {
                    try {
                        if (voiceHandle == 0L) {
                            result.error("NO_VOICE", "voice not loaded", null)
                            return@Thread
                        }
                        val audio = PiperNative.synthesize(
                            voiceHandle,
                            text,
                            lengthScale,
                            noiseScale,
                            noiseWScale,
                            speakerId,
                        )
                        if (audio == null) {
                            result.error("SYNTH", "synthesis failed", null)
                            return@Thread
                        }
                        result.success(audio)
                    } catch (e: Throwable) {
                        Log.e("Piper", "synthesize failed", e)
                        result.error("SYNTH", e.message, null)
                    }
                }.start()
            }
            "version" -> {
                    try {
                        PiperNative.version()
                        result.success(PiperNative.version())
                } catch (e: Throwable) {
                    result.error("VERSION", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
