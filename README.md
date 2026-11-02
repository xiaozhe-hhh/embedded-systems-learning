# 嵌入式学习笔记

这是一个持续更新的个人学习与复盘项目，记录嵌入式 Linux、MCU 和 RTOS 的学习过程，包含通用基础知识、源码阅读路线、关键代码摘录、自测题和复盘记录。

作者目前是研二学生，研究方向为天线设计，计划转向嵌入式软件就业。本项目用于系统学习和整理个人理解，不是官方教材；内容可能有疏漏，欢迎通过 Issue 指出并讨论。

## 项目导航

- [学习进度与路线](embedded-linux/README.md)
- [通用基础知识](shared-notes/README.md)
- [每日学习计划（30 个学习日）](study-plan/README.md)
- [每日学习日志](daily-log/README.md)
- [嵌入式 Linux](embedded-linux/README.md)
- [MCU + RTOS](mcu-rtos/README.md)
- [资料索引](resources/README.md)
- [设备树中文参考译稿](zh-linux/usage-model.rst)

## 学习进度

进度区分“已学习”和“笔记已整理”：目前已学习过中断、总线、字符设备、并发与竞争、平台总线，以及中断与异常；本仓库正在补全这些内容的源码阅读笔记。通用基础目录中的材料是复习与补充资料，不代表作者对每项内容均已掌握。设备树正在学习中。

## Linux 源码

本仓库不提交完整 Linux 源码。Linux v6.17.7 约 1.7 GiB，源码及其压缩包属于第三方项目内容，直接纳入会使本学习仓库过大。可运行 [`scripts/fetch-linux-source.sh`](scripts/fetch-linux-source.sh) 从 kernel.org 下载并校验后解压。笔记默认源码位置为工作区下的 `linux/`。

Linux 源码采用 GPL-2.0-only，版权及许可属于 Linux 内核项目和各贡献者。仓库中的少量源码摘录用于学习并注明版本、路径和符号；原文许可仍适用。详见[许可证说明](LICENSE.md)。

## 推荐学习方式

先读概念和官方文档，再看小型例子，最后沿着关键函数调用链阅读源码。每篇源码笔记提供建议阅读顺序、符号入口、短代码摘录和自测题；请把自己的复盘写在“我的复盘”区域。详见[源码阅读方法](shared-notes/source-reading-guide.md)。

树莓派等资源有限设备可用 Geany、Mousepad 或命令行工具阅读；不需要为阅读笔记编译整个内核。VS Code 设置已排除 Linux 源码的递归文件监视。

## 目录结构

```text
.
├── embedded-linux/   # Linux 学习路线与源码笔记
├── mcu-rtos/         # MCU + RTOS 学习路线
├── shared-notes/     # C、数据结构、计算机组成、OS、工具等基础
├── study-plan/       # 30 个学习日的学习计划
├── daily-log/        # 每日总结与复盘日志
├── resources/        # 资料索引
├── zh-linux/         # 内核文档中文参考译稿
└── scripts/          # 获取指定版本 Linux 源码
```

## 许可证与贡献

作者原创学习笔记采用 CC BY-SA 4.0，便于分享和改编并保留署名与相同方式共享。第三方文档、源码及代码摘录仍以各自声明的许可证为准。欢迎提出问题、纠错或提交改进建议；请勿提交个人隐私、令牌或整份第三方源码。
