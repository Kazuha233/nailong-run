# -*- coding: utf-8 -*-
"""
奶龙快跑 - 桌面版启动器
pywebview + WebView2 加载游戏页面，PyInstaller 打包为单文件 exe
"""
import os
import sys
import webview


def resource_path(rel: str) -> str:
    """PyInstaller 打包后资源在 _MEIPASS 临时目录；源码运行时为脚本目录"""
    base = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, rel)


def main():
    index = resource_path("index.html")
    webview.create_window(
        "奶龙快跑 🦖",
        index,
        width=920,
        height=560,
        min_size=(640, 360),
        resizable=True,
        background_color="#101018",
    )
    webview.start()


if __name__ == "__main__":
    main()
