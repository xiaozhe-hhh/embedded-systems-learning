# 嵌入式 Linux

## 阶段建议

当前进度：设备树正在学习中。字符设备、并发与竞争、平台总线、中断与异常已学习，正在按 Linux v6.17.7 源码补全笔记；总线基础也已学过，后续结合平台设备和设备树复习。

## 已学主题：源码笔记整理中

| 主题 | 笔记 | 主要源码入口 |
|---|---|---|
| 字符设备 | [字符设备：从设备号到 file_operations](character-device.md) | `fs/char_dev.c`、`include/linux/cdev.h`、`include/linux/fs.h` |
| 并发与竞争 | [Linux 并发与竞争](concurrency-and-races.md) | `Documentation/locking/`、`include/linux/spinlock.h`、`kernel/locking/` |
| 平台总线 | [Linux 平台总线](platform-bus.md) | `drivers/base/platform.c`、`drivers/of/platform.c` |
| 中断与异常 | [Linux 中断与异常](interrupts-and-exceptions.md) | `kernel/irq/`、`arch/arm64/kernel/entry-common.c` |
| 设备树 | [设备树 01：为什么需要设备树](device-tree-01-overview.md) | `Documentation/devicetree/`、`drivers/of/`、平台 DTS |

各主题的学习记录区仍待作者复盘填写，笔记整理不表示已经完成复习。

1. **主机 Linux**：文件系统、进程/线程、权限、管道、shell、常用工具。
2. **C 与构建**：GCC、Make、静态/动态链接、GDB、交叉编译。
3. **系统启动**：Boot ROM、Bootloader（常见为 U-Boot）、内核、设备树、根文件系统。
4. **内核与驱动**：模块、字符设备、设备模型、中断、同步、GPIO/I2C/SPI 等子系统。
5. **发行版构建**：先了解 Buildroot，再根据需求学习 Yocto。
6. **板级实践**：串口启动日志、网络、存储、升级、性能和故障定位。

## 每个主题的记录模板

- 学习目标：
- 主机/目标板与工具链：
- 核心概念：
- 命令或代码：
- 实验结果：
- 问题与排查：
- 后续问题：

实验前确认目标板型号、启动介质和串口参数；涉及刷写时先确认镜像与分区，避免覆盖重要数据。
