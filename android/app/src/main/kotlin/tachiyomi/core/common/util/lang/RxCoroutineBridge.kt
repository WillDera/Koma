package tachiyomi.core.common.util.lang

import kotlinx.coroutines.suspendCancellableCoroutine
import rx.Observable
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

suspend fun <T> Observable<T>.awaitSingle(): T = suspendCancellableCoroutine { cont ->
    val subscription = subscribe(
        { value -> cont.resume(value) },
        { error -> cont.resumeWithException(error) },
    )
    cont.invokeOnCancellation { subscription.unsubscribe() }
}
