# 每日学习计划

本计划按“学习日”顺序推进，不绑定日历日期，方便配合研究生课程和项目安排。建议每天安排约 60–90 分钟；忙碌时完成当日最小产出即可。实际完成情况记在 [每日学习日志](../daily-log/README.md)，不要把计划直接当作完成记录。

## 每日学习节奏

1. **回忆（5–10 分钟）**：不看笔记，写下昨天主题的 3 个关键点。
2. **学习（25–40 分钟）**：按当天入口阅读笔记、文档或源码，只追一条主线。
3. **动手（15–25 分钟）**：画流程、读 DTS/代码、写小例子或做概念对比。
4. **复盘（10–15 分钟）**：回答自测题，用自己的话写总结和疑问。

每日最小产出：一段自己的总结、至少一个自测答案、一个待解决问题或“暂无”。

## 30 个学习日

| 学习日 | 主题与任务 | 当日可检查的产出 |
|---:|---|---|
| 01 | 设备树整体模型：重读[设备树 01](../embedded-linux/device-tree-01-overview.md)，回答 DTS/DTB、驱动职责和启动交接问题。 | 用自己的话解释“设备树描述什么、驱动做什么”；完成 4 道自测。 |
| 02 | DTS 语法与树模型：读一个 DTS 的根节点、子节点、属性、`/include/` 和标签引用。 | 手绘一棵树，标出节点、属性和 phandle 引用。 |
| 03 | `compatible`、设备树 binding 与驱动匹配：对照 `Documentation/devicetree/bindings/` 的一个 schema 和驱动 match table。 | 解释兼容字符串的顺序，并指出 schema 约束了什么。 |
| 04 | 地址与 `reg`：理解 `#address-cells`、`#size-cells` 如何解释子节点 `reg`。 | 选一个真实节点，手算其地址和长度单元。 |
| 05 | 总线地址转换：阅读 `ranges` 和父子 bus 地址空间关系；回顾已学总线知识。 | 画出一个子总线地址转换示意，说明不能把 `reg` 直接当虚拟地址。 |
| 06 | 设备树中断描述：读 `interrupt-parent`、`interrupts` 和对应控制器 binding。 | 区分中断 specifier、hwirq 与 Linux IRQ。 |
| 07 | GPIO、pinctrl、clock、reset、regulator：从一个外设节点追到供给资源节点。 | 画出该设备依赖的资源关系图。 |
| 08 | DTS 到 DTB：查 `dtc`、DTS Makefile/Kbuild 规则和预处理/include 流程。 | 写出 DTS/DTSI/DTB/overlay 的关系及编译入口。 |
| 09 | Bootloader 到内核：从 arm64 启动代码查 FDT 指针接收和 `early_init_dt_scan()`。 | 画出“DTB 交接—早期扫描”的简化调用图。 |
| 10 | 扁平树转运行时树：阅读 `drivers/of/fdt.c` 的 `unflatten_device_tree()` 和 `__unflatten_device_tree()`。 | 解释 `initial_boot_params`、`of_root` 和 unflatten 的作用。 |
| 11 | OF 节点到 platform device：追 `of_platform_populate()`、`of_platform_bus_create()`。 | 区分创建设备、匹配驱动和 probe 成功。 |
| 12 | 设备资源与 probe：对照一个 platform driver，追 `probe()`、`devm_*`、IRQ/寄存器资源获取。 | 画出从 DTS 资源到驱动 API 的路径。 |
| 13 | 字符设备复习：阅读[字符设备笔记](../embedded-linux/character-device.md)和 `fs/char_dev.c`。 | 画出 `open()` 到驱动 `file_operations` 的调用链。 |
| 14 | 并发与竞争复习：阅读[并发笔记](../embedded-linux/concurrency-and-races.md)及 locking 文档。 | 为一个共享状态表列访问上下文，并说明锁选择。 |
| 15 | Linux IRQ API 复习：阅读[中断与异常笔记](../embedded-linux/interrupts-and-exceptions.md)、`request_threaded_irq()`。 | 解释 primary handler、thread_fn、`IRQ_WAKE_THREAD`。 |
| 16 | CPU 异常与 arm64 入口：读 `entry-common.c` 的同步异常与 IRQ 分流。 | 画出同步异常、IRQ 和驱动 handler 的边界。 |
| 17 | Linux 源码综合复盘：选一个 DT 外设，从 DTS 一直追到 probe。 | 完成一张“DTS→device→match→probe→resource”流程图。 |
| 18 | C 与内存复习：指针、生命周期、对齐、`const`/`volatile`；参考[C 语言笔记](../shared-notes/c-language.md)。 | 用例子说明数组/指针区别与 volatile 的限制。 |
| 19 | 编译、链接与交叉工具链：读[构建与调试笔记](../shared-notes/build-and-debug.md)。 | 用命令识别一个 ELF 的架构、符号和段。 |
| 20 | MMIO、缓存与 DMA：读[计算机组成笔记](../shared-notes/computer-organization.md)，结合目标 MCU/SoC 手册。 | 解释 CPU 地址、物理地址和 DMA 地址可能不同的原因。 |
| 21 | MCU 中断复习：回顾向量表、优先级、ISR 约束和中断/任务协作。 | 写出一个 ISR 中应做与不应做的工作清单。 |
| 22 | MCU 外设驱动分层：选 GPIO、UART 或定时器，区分寄存器层、驱动层和应用层。 | 画出一次收发/中断的模块关系图。 |
| 23 | RTOS 任务与调度：读所选 RTOS 官方文档，整理任务状态、优先级、抢占和阻塞。 | 用状态图解释任务为何从运行转为阻塞/就绪。 |
| 24 | 队列、信号量、互斥锁和事件：比较用途、所有权与 ISR 可用 API。 | 为“传数据、通知事件、保护资源”分别选择同步原语并说明理由。 |
| 25 | RTOS 并发与优先级反转：结合[数据结构](../shared-notes/data-structures.md)和[操作系统基础](../shared-notes/operating-systems.md)。 | 画出优先级反转时序，并说明继承/天花板协议的目标。 |
| 26 | 栈、堆与内存管理：检查任务栈、栈水位、静态/动态分配和失败路径。 | 制定一个任务栈和内存使用检查表。 |
| 27 | 通信协议复习：从[通信协议笔记](../shared-notes/protocols.md)选 UART/I2C/SPI/CAN/RS-485/TCP/UDP。 | 设计一个带长度、校验和超时处理的简单帧格式。 |
| 28 | 状态机与错误恢复：选一个小设备功能，列正常、超时、断线和重试状态。 | 画状态图并定义每个状态的输入与输出。 |
| 29 | 小型综合设计：规划一个 MCU + RTOS 采集/通信任务，或 Linux 设备树外设练习。 | 写模块图、任务/中断分工、接口和风险点。 |
| 30 | 阶段复盘与下轮计划：复查 30 天日志和自测错题。 | 更新学习状态表，列出 3 个已掌握点、3 个待补点和下一阶段目标。 |

## 自适应规则

- 某天自测答不稳，就先复习并在日志中标记“复习日”，后续序号顺延。
- Linux 源码部分统一基于 v6.17.7；MCU/RTOS 部分在开始前记录板卡、芯片、SDK 和 RTOS 版本。
- 每天只深入一条主线。遇到复杂调用链，记录入口和疑问，留到后续专项学习。
- 每周选一天做周复盘：整理错题、补笔记、调整后续任务，不要求追赶日历进度。

## 进度

- 当前：学习日 01 讲解已提供；自测和个人复盘待完成。
- 下一步：完成设备树整体模型的 4 道自测，再开始学习日 02。
