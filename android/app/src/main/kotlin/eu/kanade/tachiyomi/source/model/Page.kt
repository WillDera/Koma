package eu.kanade.tachiyomi.source.model

open class Page(
    val index: Int,
    val url: String = "",
    var imageUrl: String? = null,
    var uri: String? = null,
) {

    val number: Int get() = index + 1

    var status: State = State.Queue
    var progress: Int = 0

    sealed interface State {
        data object Queue : State
        data object LoadPage : State
        data object DownloadImage : State
        data object Ready : State
        data class Error(val error: Throwable) : State
    }
}
