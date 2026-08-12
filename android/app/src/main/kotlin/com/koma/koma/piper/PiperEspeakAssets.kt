package com.koma.koma.piper

import android.content.Context
import java.io.File
import java.io.FileOutputStream

/**
 * Copies bundled [espeak-ng-data] from assets to files dir on first use.
 */
object PiperEspeakAssets {
    private const val ASSET_ROOT = "piper/espeak-ng-data"
    private const val MARKER = "phondata"

    fun ensureExtracted(context: Context): String {
        val dest = File(context.filesDir, "piper/espeak-ng-data")
        val marker = File(dest, MARKER)
        if (marker.exists()) {
            return dest.absolutePath
        }
        dest.mkdirs()
        copyAssetTree(context, ASSET_ROOT, dest)
        return dest.absolutePath
    }

    private fun copyAssetTree(context: Context, assetPath: String, destDir: File) {
        val children = context.assets.list(assetPath)
        if (children == null || children.isEmpty()) {
            copyAssetFile(context, assetPath, destDir)
            return
        }
        destDir.mkdirs()
        for (child in children) {
            val childAsset = "$assetPath/$child"
            val childDest = File(destDir, child)
            val sub = context.assets.list(childAsset)
            if (sub.isNullOrEmpty()) {
                copyAssetFile(context, childAsset, childDest)
            } else {
                copyAssetTree(context, childAsset, childDest)
            }
        }
    }

    private fun copyAssetFile(context: Context, assetPath: String, dest: File) {
        dest.parentFile?.mkdirs()
        context.assets.open(assetPath).use { input ->
            FileOutputStream(dest).use { output ->
                input.copyTo(output)
            }
        }
    }
}
