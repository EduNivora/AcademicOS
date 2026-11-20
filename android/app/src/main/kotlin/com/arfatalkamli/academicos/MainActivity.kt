package com.arfatalkamli.academicos

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val OAUTH_CHANNEL = "com.arfatalkamli.academicos/oauth_browser"
        private const val EXTERNAL_LINKS_CHANNEL = "com.arfatalkamli.academicos/external_links"
        private const val DEEP_LINK_SCHEME = "edunivora"
        private const val DEEP_LINK_HOST = "auth"
        private const val DEEP_LINK_PATH_PREFIX = "/callback"
    }

    private var oauthChannel: MethodChannel? = null
    private var pendingInitialDeepLink: String? = null
    private var awaitingCustomTabReturn: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractAuthDeepLink(intent)?.let { uri ->
            pendingInitialDeepLink = uri
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        oauthChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OAUTH_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchCustomTab" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("INVALID_URL", "OAuth URL must not be empty.", null)
                            return@setMethodCallHandler
                        }
                        val uri = Uri.parse(url)
                        if (uri.scheme?.lowercase() != "https") {
                            result.error("INSECURE_URL", "OAuth URL must use https.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            awaitingCustomTabReturn = true
                            val customTabsIntent = CustomTabsIntent.Builder()
                                .setShowTitle(true)
                                .setUrlBarHidingEnabled(false)
                                .build()
                            customTabsIntent.launchUrl(this, uri)
                            result.success(true)
                        } catch (_: ActivityNotFoundException) {
                            try {
                                val fallbackIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                                    addCategory(Intent.CATEGORY_BROWSABLE)
                                }
                                startActivity(fallbackIntent)
                                result.success(true)
                            } catch (fallbackError: Exception) {
                                awaitingCustomTabReturn = false
                                result.error(
                                    "NO_BROWSER",
                                    "No browser available to complete Google sign-in.",
                                    fallbackError.message
                                )
                            }
                        } catch (error: Exception) {
                            awaitingCustomTabReturn = false
                            result.error(
                                "CUSTOM_TAB_ERROR",
                                "Unable to open Chrome Custom Tabs.",
                                error.message
                            )
                        }
                    }

                    "consumeInitialDeepLink" -> {
                        val link = pendingInitialDeepLink
                        pendingInitialDeepLink = null
                        result.success(link)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXTERNAL_LINKS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val rawUrl = call.argument<String>("url")?.trim()
                    if (rawUrl.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val uri = try {
                        Uri.parse(rawUrl)
                    } catch (_: Exception) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val scheme = uri.scheme?.lowercase()
                    val intent = when (scheme) {
                        "https" -> {
                            if (uri.host.isNullOrBlank()) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            Intent(Intent.ACTION_VIEW, uri).apply {
                                addCategory(Intent.CATEGORY_BROWSABLE)
                            }
                        }

                        "mailto" -> {
                            if (uri.schemeSpecificPart.isNullOrBlank()) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            Intent(Intent.ACTION_VIEW, uri)
                        }

                        else -> {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                    }

                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val deepLink = extractAuthDeepLink(intent) ?: return
        awaitingCustomTabReturn = false
        val channel = oauthChannel
        if (channel != null) {
            channel.invokeMethod("onDeepLink", deepLink)
        } else {
            pendingInitialDeepLink = deepLink
        }
    }

    override fun onResume() {
        super.onResume()
        if (awaitingCustomTabReturn) {
            awaitingCustomTabReturn = false
            oauthChannel?.invokeMethod("onCustomTabClosed", null)
        }
    }

    private fun extractAuthDeepLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val data = intent.data ?: return null
        val scheme = data.scheme?.lowercase() ?: return null
        val host = data.host?.lowercase() ?: return null
        val path = data.path ?: ""
        if (scheme == DEEP_LINK_SCHEME &&
            host == DEEP_LINK_HOST &&
            path.startsWith(DEEP_LINK_PATH_PREFIX)
        ) {
            return data.toString()
        }
        return null
    }
}
