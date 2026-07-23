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
    enqueue(
        object : Callback {
            override fun onResponse(call: Call, response: Response) {
                subscriber.onNext(response)
                subscriber.onCompleted()
            }

            override fun onFailure(call: Call, e: IOException) {
                subscriber.onError(e)
            }
        },
    )
}

fun Call.asObservableSuccess(): Observable<Response> = asObservable().map { response ->
    if (!response.isSuccessful) throw HttpException(response)
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

class HttpException(val response: Response) : Exception("HTTP ${response.code} ${response.message}")
