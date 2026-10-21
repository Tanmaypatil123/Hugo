package dev.hugo.hub

import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Message
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.HttpAuthHandler
import android.webkit.RenderProcessGoneDetail
import android.webkit.SafeBrowsingResponse
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import org.brotli.dec.BrotliInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.GZIPInputStream

/**
 * Wraps webview_flutter's WebViewClient to fix Hugging Face Spaces built with
 * newer Gradio versions.
 *
 * Those Spaces serve their static files (`/_app/...`) only Brotli-compressed
 * and answer 404 when the request doesn't advertise `br`. Older Android
 * System WebView builds don't, so the Space never starts. For those files we
 * download them ourselves with `Accept-Encoding: br`, decompress, and hand the
 * plain bytes to the WebView. Every other request, and every other callback,
 * goes to the original client unchanged.
 *
 * No cookies or Hugging Face token are attached to these requests.
 */
class SpaceAssetClient(private val inner: WebViewClient) : WebViewClient() {

    override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
        if (isSpaceAsset(request)) {
            try {
                fetch(request)?.let { return it }
            } catch (_: Exception) {
                // Fall through and let the WebView try on its own.
            }
        }
        return inner.shouldInterceptRequest(view, request)
    }

    private fun isSpaceAsset(request: WebResourceRequest): Boolean {
        val url = request.url
        return request.method == "GET" &&
            url.scheme == "https" &&
            (url.host?.endsWith(".hf.space") == true) &&
            (url.path?.contains("/_app/") == true)
    }

    private fun fetch(request: WebResourceRequest): WebResourceResponse? {
        val conn = URL(request.url.toString()).openConnection() as HttpURLConnection
        conn.connectTimeout = 20_000
        conn.readTimeout = 30_000
        conn.instanceFollowRedirects = true
        for ((name, value) in request.requestHeaders) {
            if (!name.equals("Accept-Encoding", ignoreCase = true) && !name.equals("Cookie", ignoreCase = true)) {
                conn.setRequestProperty(name, value)
            }
        }
        // Setting this ourselves turns off HttpURLConnection's automatic gzip
        // handling, so both encodings are decoded below.
        conn.setRequestProperty("Accept-Encoding", "br, gzip")

        val code = conn.responseCode
        if (code !in 200..299) {
            conn.disconnect()
            return null
        }
        val raw: InputStream = conn.inputStream
        val body: InputStream = when (conn.contentEncoding?.lowercase()) {
            "br" -> BrotliInputStream(raw)
            "gzip" -> GZIPInputStream(raw)
            else -> raw
        }
        val contentType = conn.contentType ?: "application/octet-stream"
        val mime = contentType.substringBefore(';').trim()
        val charset = Regex("charset=([^;]+)", RegexOption.IGNORE_CASE)
            .find(contentType)?.groupValues?.get(1)?.trim() ?: if (mime.startsWith("text/") || mime.endsWith("javascript")) "utf-8" else null
        val headers = conn.headerFields
            .filterKeys { it != null && !it.equals("Content-Encoding", true) && !it.equals("Content-Length", true) && !it.equals("Transfer-Encoding", true) }
            .mapKeys { it.key!! }
            .mapValues { it.value.joinToString(", ") }
        val reason = conn.responseMessage?.takeIf { it.isNotBlank() } ?: "OK"
        return WebResourceResponse(mime, charset, code, reason, headers, body)
    }

    // Everything below forwards to webview_flutter's client unchanged.

    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
        inner.shouldOverrideUrlLoading(view, request)

    @Deprecated("Deprecated in Android")
    override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean =
        @Suppress("DEPRECATION") inner.shouldOverrideUrlLoading(view, url)

    override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) = inner.onPageStarted(view, url, favicon)
    override fun onPageFinished(view: WebView, url: String?) = inner.onPageFinished(view, url)
    override fun onLoadResource(view: WebView, url: String?) = inner.onLoadResource(view, url)
    override fun onPageCommitVisible(view: WebView, url: String?) = inner.onPageCommitVisible(view, url)

    override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) =
        inner.onReceivedError(view, request, error)

    @Deprecated("Deprecated in Android")
    override fun onReceivedError(view: WebView, errorCode: Int, description: String?, failingUrl: String?) =
        @Suppress("DEPRECATION") inner.onReceivedError(view, errorCode, description, failingUrl)

    override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, errorResponse: WebResourceResponse) =
        inner.onReceivedHttpError(view, request, errorResponse)

    override fun onFormResubmission(view: WebView, dontResend: Message?, resend: Message?) =
        inner.onFormResubmission(view, dontResend, resend)

    override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) =
        inner.doUpdateVisitedHistory(view, url, isReload)

    override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError?) =
        inner.onReceivedSslError(view, handler, error)

    override fun onReceivedClientCertRequest(view: WebView, request: ClientCertRequest?) =
        inner.onReceivedClientCertRequest(view, request)

    override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String?, realm: String?) =
        inner.onReceivedHttpAuthRequest(view, handler, host, realm)

    override fun shouldOverrideKeyEvent(view: WebView, event: KeyEvent?): Boolean = inner.shouldOverrideKeyEvent(view, event)
    override fun onUnhandledKeyEvent(view: WebView, event: KeyEvent?) = inner.onUnhandledKeyEvent(view, event)
    override fun onScaleChanged(view: WebView, oldScale: Float, newScale: Float) = inner.onScaleChanged(view, oldScale, newScale)

    override fun onReceivedLoginRequest(view: WebView, realm: String?, account: String?, args: String?) =
        inner.onReceivedLoginRequest(view, realm, account, args)

    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail?): Boolean =
        inner.onRenderProcessGone(view, detail)

    override fun onSafeBrowsingHit(view: WebView, request: WebResourceRequest, threatType: Int, callback: SafeBrowsingResponse) =
        inner.onSafeBrowsingHit(view, request, threatType, callback)
}
