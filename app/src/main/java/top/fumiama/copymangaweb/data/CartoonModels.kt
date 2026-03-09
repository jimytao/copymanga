package top.fumiama.copymangaweb.data

data class CartoonApiResponse<T>(
    val code: Int,
    val message: String,
    val results: T?
)

data class CartoonListResult(
    val total: Int,
    val list: List<CartoonBrief>
)

data class CartoonBrief(
    val path_word: String,
    val name: String,
    val cover: String,
    val count: Int?,
    val years: String?,
    val datetime_updated: String?,
    val popular: Int?
)

data class CartoonDetailResult(
    val cartoon: CartoonDetail
)

data class CartoonDetail(
    val uuid: String,
    val path_word: String,
    val name: String,
    val cover: String,
    val brief: String?,
    val theme: List<String>?,
    val years: String?,
    val popular: Int?,
    val last_chapter: EpisodeRef?,
    val b_subtitle: Boolean?,
    val free_type: LabelValue?,
    val cartoon_type: LabelValue?
)

data class EpisodeListResult(
    val total: Int,
    val list: List<Episode>
)

data class Episode(
    val uuid: String,
    val name: String,
    val datetime_updated: String?
)

data class EpisodeRef(
    val uuid: String,
    val name: String
)

data class LabelValue(
    val value: Int,
    val display: String
)
