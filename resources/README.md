# 资料索引

学习时优先查阅芯片厂商手册、Linux 内核文档、设备树 binding 和 RTOS 官方文档。记录资料版本，避免把旧版行为直接套用到新版本。

## Linux 内核

- 本仓库阅读版本：Linux v6.17.7。
- 官方 kernel.org 源码归档：<https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.17.7.tar.xz>。
- 获取脚本：[scripts/fetch-linux-source.sh](../scripts/fetch-linux-source.sh)。
- 设备树文档入口：`Documentation/devicetree/`。
- 锁文档入口：`Documentation/locking/`。
- 通用 IRQ 文档入口：`Documentation/core-api/genericirq.rst`。

## 推荐查阅顺序

1. 芯片 Reference Manual / Technical Reference Manual：寄存器、时钟、中断控制器、总线和复位。
2. 芯片/板卡数据手册：电气限制、引脚和外设能力。
3. Linux `Documentation/` 与 `Documentation/devicetree/bindings/`。
4. 对应内核版本的驱动源码和设备树示例。
5. FreeRTOS 或所选 RTOS 官方文档及目标 MCU SDK。

新增资料时写明标题、来源链接、适用芯片/内核/RTOS 版本以及访问日期。不要把无许可说明的第三方书籍或整份源码复制进仓库。
