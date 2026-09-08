package eu.kanade.tachiyomi.network

import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Response
import rx.Observable
import java.io.IOException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

fun Call.asObservable(): Observable<Response> = Observable.create { subscriber ->
    // Deliver callbacks safely: RxJava 1 treats Errors (e.g. NoClassDefFoundError
    // from extension code in .map) as fatal and rethrows them onto the OkHttp
    // dispatcher, which kills the whole app process.
    enqueue(
        object : Callback {
            override fun onResponse(call: Call, response: Response) {
                try {
                    if (!subscriber.isUnsubscribed) {
                        subscriber.onNext(response)
                    }
                    if (!subscriber.isUnsubscribed) {
                        subscriber.onCompleted()
                    }
                } catch (t: Throwable) {
                    if (!subscriber.isUnsubscribed) {
                        subscriber.onError(t.toNonFatal())
                    }
                }
            }

            override fun onFailure(call: Call, e: IOException) {
                if (!subscriber.isUnsubscribed) {
                    subscriber.onError(e)
                }
            }
        },
    )
}

fun Call.asObservableSuccess(): Observable<Response> = asObservable().map { response ->
    if (!response.isSuccessful) {
        response.close()
        throw HttpException(response.code)
    }
    response
}

suspend fun Call.await(): Response = suspendCancellableCoroutine { continuation ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) {
            continuation.resume(response)
        }

        override fun onFailure(call: Call, e: IOException) {
            continuation.resumeWithException(e)
        }
    })
    continuation.invokeOnCancellation { cancel() }
}

suspend fun Call.awaitSuccess(): Response {
    val response = await()
    if (!response.isSuccessful) {
        response.close()
        throw HttpException(response.code)
    }
    return response
}

class HttpException(val code: Int) : IllegalStateException("HTTP error $code")

/**
 * RxJava 1's [rx.exceptions.Exceptions.throwIfFatal] rethrows Errors onto the
 * calling thread. Wrap them so extension ClassNotFound / linkage failures
 * surface as Observable errors instead of process death.
 */
private fun Throwable.toNonFatal(): Throwable =
    if (this is Exception) this else Exception(this)
