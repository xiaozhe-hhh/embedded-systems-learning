# Linux 中断与异常

- 学习状态：已学习，正在补全源码笔记
- 源码版本：Linux v6.17.7
- 架构示例：AArch64（arm64）；通用 IRQ 层与架构入口要分开理解
- 核心问题：CPU 异常入口、外设 IRQ 和 Linux 驱动 handler 是怎样衔接的？

## 阅读顺序

1. `Documentation/core-api/genericirq.rst`：先读 Linux 通用 IRQ 概念和 API。
2. `include/linux/interrupt.h`：看 `irq_handler_t`、`irqreturn_t`、`request_threaded_irq()`。
3. `kernel/irq/manage.c`：读 `request_threaded_irq()` 与 `__setup_irq()`，理解注册动作。
4. `kernel/irq/handle.c`：读 `__handle_irq_event_percpu()`，理解 handler 调用及 `IRQ_WAKE_THREAD`。
5. `arch/arm64/kernel/entry.S` 与 `arch/arm64/kernel/entry-common.c`：看异常向量如何分流到同步异常、IRQ、SError 等处理函数。
6. 查具体设备树 interrupt binding、IRQ domain 和 irqchip 驱动，理解硬件中断号如何映射为 Linux IRQ。

## 术语区分

- **CPU 异常（exception）**：CPU 发生同步或异步事件时进入异常级别/向量入口。同步异常包括系统调用、未定义指令、指令/数据 abort 等；异步异常包含 IRQ、FIQ、SError 等（术语细节由架构定义）。
- **硬件中断**：外设或中断控制器向 CPU 发出的异步通知。
- **Linux IRQ**：Linux IRQ 子系统管理的逻辑中断号/描述符，不一定等于设备树中的硬件中断 specifier 或控制器 hwirq。
- **异常向量入口**：架构特定的低层入口，保存上下文并转入 C 处理逻辑；不是驱动注册的回调本身。

## AArch64 源码路径

在 `arch/arm64/kernel/entry-common.c` 中：

- `el1h_64_sync_handler()` 根据 `ESR_ELx_EC(esr)` 分发 EL1 同步异常。
- `el1h_64_irq_handler()` 调用 `el1_interrupt(..., handle_arch_irq)`，接入架构配置的 IRQ 分发入口。
- 用户态同步异常有单独的 EL0 handler；数据/指令 abort 会走相应 abort/page-fault 处理路径。

这只是 arm64 的实现示例。x86、RISC-V、ARM32 等架构入口和寄存器规则不同；Linux 通用 IRQ API 在其上提供更统一的驱动接口。

## 源码摘录：注册线程化中断

Linux v6.17.7，`linux/kernel/irq/manage.c`，`request_threaded_irq()` 的核心行为：

```c
if (!handler) {
        if (!thread_fn)
                return -EINVAL;
        handler = irq_default_primary_handler;
}
/* 创建 irqaction 并填入 handler/thread_fn/flags */
retval = __setup_irq(irq, desc, action);
```

解释：驱动把 primary handler 和可选线程函数交给通用 IRQ 层注册。实际函数还检查 IRQ 是否可请求、共享中断是否有 `dev_id`、电源管理和线程创建等条件。

通用层事件分发位于 `kernel/irq/handle.c`。当 primary handler 返回 `IRQ_WAKE_THREAD` 且注册了 `thread_fn` 时，内核唤醒对应 IRQ 线程。primary handler 应快速确认中断来源、处理必要的硬件应答并决定是否唤醒线程。

## 硬中断与线程化处理

- 硬中断 handler 运行约束严格：不能睡眠，应尽快完成必须的寄存器处理。
- `request_threaded_irq(irq, handler, thread_fn, ...)` 可把较重、允许睡眠的工作移到 IRQ 线程；`IRQF_ONESHOT` 常用于线程运行期间保持中断线屏蔽，具体要结合触发类型和控制器语义。
- `request_irq()` 是无独立线程函数的常用形式。
- handler 共享 IRQ 时需使用 `IRQF_SHARED` 并提供稳定唯一的 `dev_id`；返回 `IRQ_NONE` 表示非本设备中断，`IRQ_HANDLED` 表示已处理。
- 软中断/tasklet/workqueue 也是延后工作机制，但执行上下文、可睡眠性和适用场景不同；workqueue 在进程上下文可睡眠，softirq/tasklet 不可睡眠。新驱动通常优先考虑 threaded IRQ 或 workqueue 等适合的机制。

## 异常处理边界

CPU 异常的向量和错误信息由架构定义，内核进一步分发到缺页、未定义指令、调试、系统调用等处理。不要将“异常”等同于“驱动 IRQ handler”。系统调用在许多架构上通过同步异常入口实现，但其语义是受控内核服务请求。

## 易错点

- DTS `interrupts` 单元通常先由父 interrupt-controller binding 解释为 hwirq/flags，再经 IRQ domain 映射为 Linux IRQ。
- `request_threaded_irq()` 的 handler 不应做可能睡眠的操作。
- 硬 IRQ 与线程函数的数据共享仍需同步；唤醒线程本身不自动保护设备状态。
- `disable_irq()`、`synchronize_irq()` 和释放资源的顺序影响正在运行的 handler 生命周期。

## 自测

1. CPU exception、硬件 IRQ、Linux IRQ 三者是什么关系？
2. AArch64 的 EL1 同步异常与 IRQ 分别从哪个 handler 分流？
3. `IRQ_WAKE_THREAD` 如何触发线程函数？
4. 线程化中断的 primary handler 适合做什么？
5. 设备树中断号为什么不一定等于 Linux IRQ number？

## 我的复盘

- 日期：待填写
- 我能画出的 arm64→generic IRQ→driver 路径：待填写
- 我学过的中断/异常区别：待填写
- 下次源码入口：`linux/arch/arm64/kernel/entry-common.c`、`linux/kernel/irq/manage.c`
