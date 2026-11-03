# Linux 并发与竞争

- 学习状态：已学习，正在补全源码笔记
- 源码版本：Linux v6.17.7
- 核心问题：多个执行上下文访问共享状态时，怎样保持不变量？

## 阅读顺序

1. `Documentation/locking/locktypes.rst`：先学习锁类型和上下文约束。
2. `Documentation/locking/lockdep-design.rst`：了解锁依赖检查和死锁风险。
3. `include/linux/mutex.h` 与 `include/linux/spinlock.h`：查看 API 和注释。
4. `kernel/locking/mutex.c`、`kernel/locking/spinlock.c`：仅追关键路径，不从头通读。
5. 查看驱动中的共享状态保护，逐个标出进程、工作队列、定时器和 IRQ 上下文。

## 基本模型

竞态条件是执行结果取决于非预期交错。先定义共享状态的不变量，再列出所有访问者和上下文，最后选同步手段。加锁要保护完整状态转移，而不是机械地包住单条赋值。

| 原语 | 典型用途 | 约束/注意 |
|---|---|---|
| mutex | 可睡眠的进程上下文临界区 | 不可在硬中断上下文获取；持锁时可睡眠，但要控制临界区 |
| spinlock | 很短、不能睡眠的共享状态保护 | 持锁期间不能睡眠；本地 IRQ 也访问时需选正确的 irq-save 变体 |
| atomic_t/原子 API | 简单计数或状态原子更新 | 原子操作不自动保护多个字段组成的不变量；内存序需按 API 约定 |
| completions/wait queues | 等待事件或条件变化 | 条件检查、状态更新和唤醒顺序必须正确 |
| RCU | 读多写少且可延迟回收的数据结构 | 需要遵守读侧临界区和 grace period 生命周期规则 |

## 上下文约束

- 进程上下文可睡眠；硬中断上下文不能睡眠。
- tasklet/softirq 等软中断上下文不能像普通进程一样睡眠。
- 同一数据同时被进程和硬中断访问时，仅仅在进程上下文使用普通 `spin_lock()` 可能导致本地中断打断并死锁；应根据访问上下文使用 `spin_lock_irqsave()` 等正确变体。
- 自旋锁临界区内不能执行 `copy_to_user()`、`mutex_lock()`、`schedule()` 等可能睡眠操作。

## 源码阅读提示

`include/linux/spinlock.h` 提供自旋锁 API；配置和架构会影响实现形式。`Documentation/locking/locktypes.rst` 是语义入口。阅读时重点看调用约束、持锁上下文和配对释放，不要把某一架构的宏展开当作通用实现。

Linux 中很多设施通过锁保护不变量。示例中应先找锁字段，再搜索 `spin_lock*`/`mutex_lock`，逐个检查所有读写路径是否使用同一保护规则。

## 死锁与常见错误

- 两把锁不同顺序获取导致 ABBA；统一锁顺序或缩小嵌套范围。
- 持锁调用回调，回调又取同一把锁或等待当前持锁者。
- 释放锁后继续访问对象，造成 use-after-free；需要引用计数/RCU/生命周期协议。
- 原子变量解决单变量更新，却没保护与其相关联的其他状态。
- `volatile` 只涉及编译器访问语义，不提供互斥、原子性或跨 CPU 同步。

## 自测

1. 进程上下文与硬中断上下文为什么不能使用相同锁策略？
2. 何时用 mutex 而非 spinlock？
3. 单个原子计数为什么可能无法保护复合状态？
4. `spin_lock_irqsave()` 中保存的是什么状态，为什么要恢复？
5. ABBA 死锁如何发生？

## 我的复盘

- 日期：待填写
- 选择锁前我会检查：待填写
- 我能举出的竞态/死锁例子：待填写
- 下次源码入口：`Documentation/locking/locktypes.rst`
