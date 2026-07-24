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
