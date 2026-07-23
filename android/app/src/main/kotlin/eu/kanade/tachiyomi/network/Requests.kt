package eu.kanade.tachiyomi.network

import kotlin.time.Duration
import okhttp3.CacheControl
import okhttp3.Headers
import okhttp3.HttpUrl
import okhttp3.Request
import okhttp3.RequestBody
import java.util.concurrent.TimeUnit

val DEFAULT_HEADERS: Headers
    get() = Headers.Builder()
        .add("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")
        .build()

val DEFAULT_CACHE_CONTROL: CacheControl
    get() = CacheControl.Builder().build()

fun CacheControl.Builder.maxStale(duration: Duration): CacheControl.Builder =
    maxStale(duration.inWholeSeconds.toInt(), TimeUnit.SECONDS)

fun GET(
    url: String,
    headers: Headers = DEFAULT_HEADERS,
    cache: CacheControl = DEFAULT_CACHE_CONTROL,
): Request = Request.Builder().url(url).headers(headers).cacheControl(cache).build()

fun GET(
    url: HttpUrl,
    headers: Headers = DEFAULT_HEADERS,
    cache: CacheControl = DEFAULT_CACHE_CONTROL,
): Request = Request.Builder().url(url).headers(headers).cacheControl(cache).build()

fun POST(
    url: String,
    headers: Headers = DEFAULT_HEADERS,
    body: RequestBody,
    cache: CacheControl = DEFAULT_CACHE_CONTROL,
): Request = Request.Builder().url(url).headers(headers).post(body).cacheControl(cache).build()

fun POST(
    url: HttpUrl,
    headers: Headers = DEFAULT_HEADERS,
    body: RequestBody,
    cache: CacheControl = DEFAULT_CACHE_CONTROL,
): Request = Request.Builder().url(url).headers(headers).post(body).cacheControl(cache).build()

fun PUT(
    url: String,
    headers: Headers = DEFAULT_HEADERS,
    body: RequestBody,
    cache: CacheControl = DEFAULT_CACHE_CONTROL,
): Request = Request.Builder().url(url).headers(headers).put(body).cacheControl(cache).build()

fun DELETE(
    url: String,
    headers: Headers = DEFAULT_HEADERS,
    cache: CacheControl = DEFAULT_CACHE_CONTROL,
): Request = Request.Builder().url(url).headers(headers).delete().cacheControl(cache).build()
