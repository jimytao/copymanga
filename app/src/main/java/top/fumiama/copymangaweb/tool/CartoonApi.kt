package top.fumiama.copymangaweb.tool

import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.fumiama.copymangaweb.data.CartoonApiResponse
import top.fumiama.copymangaweb.data.CartoonBrief
import top.fumiama.copymangaweb.data.CartoonDetailResult
import top.fumiama.copymangaweb.data.CartoonListResult
import top.fumiama.copymangaweb.data.EpisodeListResult
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

object CartoonApi {
    private val bases = listOf("https://api.manga-copy.com", "https://api.manga2025.com")
    private val gson = Gson()
    private const val TAG = "CartoonApi"

    private fun get(path: String): String? {
        for (base in bases) {
            try {
                val conn = URL("$base$path").openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                conn.setRequestProperty("User-Agent", "Dart/3.3 (dart:io)")
                conn.setRequestProperty("platform", "3")
                conn.setRequestProperty("version", "3.0.0")
                conn.setRequestProperty("Accept", "application/json")
                if (conn.responseCode == 200) {
                    val text = conn.inputStream.bufferedReader().readText()
                    conn.disconnect()
                    Log.d(TAG, "GET $base$path OK")
                    return text
                }
                Log.d(TAG, "GET $base$path HTTP ${conn.responseCode}")
                conn.disconnect()
            } catch (e: Exception) {
                Log.d(TAG, "GET $base$path FAIL: ${e.message}")
            }
        }
        return null
    }

    suspend fun getCartoons(offset: Int = 0, limit: Int = 24): CartoonListResult? = withContext(Dispatchers.IO) {
        val json = get("/api/v3/cartoons?limit=$limit&offset=$offset&ordering=-popular") ?: return@withContext null
        Log.d(TAG, "getCartoons raw: ${json.take(500)}")
        runCatching {
            val type = object : TypeToken<CartoonApiResponse<CartoonListResult>>() {}.type
            val resp: CartoonApiResponse<CartoonListResult> = gson.fromJson(json, type)
            Log.d(TAG, "getCartoons parsed: code=${resp.code} results=${resp.results}")
            if (resp.code == 200) resp.results else null
        }.onFailure { Log.e(TAG, "getCartoons parse error", it) }.getOrNull()
    }

    suspend fun searchCartoons(keyword: String, offset: Int = 0): CartoonListResult? = withContext(Dispatchers.IO) {
        val q = URLEncoder.encode(keyword, "UTF-8")
        val json = get("/api/v3/search/cartoons?q=$q&limit=24&offset=$offset") ?: return@withContext null
        runCatching {
            val type = object : TypeToken<CartoonApiResponse<CartoonListResult>>() {}.type
            val resp: CartoonApiResponse<CartoonListResult> = gson.fromJson(json, type)
            if (resp.code == 200) resp.results else null
        }.getOrNull()
    }

    suspend fun getDetail(pathWord: String): CartoonDetailResult? = withContext(Dispatchers.IO) {
        val json = get("/api/v3/cartoon/$pathWord") ?: return@withContext null
        runCatching {
            val type = object : TypeToken<CartoonApiResponse<CartoonDetailResult>>() {}.type
            val resp: CartoonApiResponse<CartoonDetailResult> = gson.fromJson(json, type)
            if (resp.code == 200) resp.results else null
        }.getOrNull()
    }

    suspend fun getEpisodes(pathWord: String, offset: Int = 0, limit: Int = 100): EpisodeListResult? = withContext(Dispatchers.IO) {
        val json = get("/api/v3/cartoon/$pathWord/chapters?limit=$limit&offset=$offset&ordering=-datetime_updated") ?: return@withContext null
        runCatching {
            val type = object : TypeToken<CartoonApiResponse<EpisodeListResult>>() {}.type
            val resp: CartoonApiResponse<EpisodeListResult> = gson.fromJson(json, type)
            if (resp.code == 200) resp.results else null
        }.getOrNull()
    }
}
