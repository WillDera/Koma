package eu.kanade.tachiyomi.network

import okhttp3.Call
import okhttp3.Response
import rx.Observable
import java.io.IOException

fun Call.asObservable(): Observable<Response> = Observable.create { subscriber ->
    enqueue(
        object : okhttp3.Callback {
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

class HttpException(val response: Response) : Exception("HTTP ${response.code} ${response.message}")
