package top.fumiama.copymangaweb.activity.template

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import top.fumiama.copymangaweb.tool.ToolsBox
import java.lang.ref.WeakReference

// AppCompatActivity 已内置 LifecycleOwner，无需手动管理 LifecycleRegistry
open class ToolsBoxActivity : AppCompatActivity() {
    lateinit var toolsBox: ToolsBox

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        toolsBox = ToolsBox(WeakReference(this))
    }
}
