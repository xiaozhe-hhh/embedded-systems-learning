# 设备树 01：为什么需要设备树

## 源码阅读导航（Linux v6.17.7）

本课目标是建立“DT 描述硬件，内核解析并按约定创建设备”的整体模型。按以下顺序阅读，每次只带着一个问题去看源码：

1. **先读内核文档的概念**：打开 [usage-model.rst](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/usage-model.rst?h=v6.17.7)，先读开头的 Data Model、2.1 High Level View，以及 2.3 Runtime configuration、2.4 Device population。重点回答 DT 为什么是数据、Linux 用它做哪些事。
2. **看一份实际板级 DTS**：从 [rk3566-anbernic-rg353ps.dts](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/arch/arm64/boot/dts/rockchip/rk3566-anbernic-rg353ps.dts?h=v6.17.7) 开始。先看根节点 `compatible`、`model` 和 `#address-cells`，再找 `&uart`、`&i2c` 等引用；继续追踪它 include 的 `.dtsi`，观察 SoC 节点、地址、中断与状态如何补全。这里选它作为阅读样例，不代表你的目标板就是 Rockchip。
3. **追踪扁平 DTB 如何进入内核**：在 [fdt.c](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/of/fdt.c?h=v6.17.7) 阅读 `early_init_dt_verify()`、`early_init_dt_scan_nodes()`、`unflatten_device_tree()`。先用编辑器查符号，不要从文件第一行逐行读。
4. **看架构启动代码在哪里调用它**：在 [setup.c](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/arch/arm64/kernel/setup.c?h=v6.17.7) 搜索 `early_init_dt_scan` 和 `unflatten_device_tree`，把调用点放回 arm64 启动顺序中理解。
5. **最后看设备如何从节点变成内核设备**：阅读 [platform.c](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/of/platform.c?h=v6.17.7) 的 `of_platform_populate()` 和 `of_platform_default_populate_init()`；之后再学习 `compatible` 与驱动匹配。

### 关键源码摘录：DTB 到运行时节点

摘自 Linux v6.17.7 `drivers/of/fdt.c` 的 `unflatten_device_tree()`，保留核心调用：

```c
void __init unflatten_device_tree(void)
{
	void *fdt = initial_boot_params;

	/* ... */
	__unflatten_device_tree(fdt, NULL, &of_root,
				early_init_dt_alloc_memory_arch, false);
	/* ... */
}
```

阅读要点：

- `initial_boot_params` 指向启动时传入的扁平设备树（FDT/DTB）数据。
- `__unflatten_device_tree()` 将扁平二进制树转换为内核可遍历的 `struct device_node` 树；`of_root` 是运行时树的根节点。
- 这一步是“解析成内核节点”，本身还不等于每个节点都已绑定驱动。
- 可以在 VS Code 中打开 `linux/drivers/of/fdt.c`，搜索 `unflatten_device_tree`，再用 F12 跳到 `__unflatten_device_tree` 的定义。

### 关键源码摘录：从设备树节点创建 platform device

摘自 Linux v6.17.7 `drivers/of/platform.c` 的 `of_platform_populate()`，只保留遍历和创建部分：

```c
for_each_child_of_node_scoped(root, child) {
	rc = of_platform_bus_create(child, matches, lookup, parent, true);
	if (rc)
		break;
}
```

阅读要点：这里展示设备树节点到 platform device 创建流程的入口。继续在同一文件追踪 `of_platform_bus_create()`，观察它怎样检查节点、递归总线并调用设备创建函数。之后驱动匹配是另一段流程，不要把“创建设备”和“驱动成功 probe”混为一件事。

### VS Code 源码阅读方法

- 打开工作区根目录后，从左侧 `linux/` 展开源码；笔记里的 `linux/...` 就是相对工作区根目录的路径。
- 用 `Ctrl+Shift+F` 搜函数名/属性名；在 C 代码中用 F12 跳到定义，Shift+F12 查看引用，Alt+← 返回。
- 读函数先看注释、参数、返回值和调用者，再读关键分支；先画出“谁调用谁”，遇到陌生 helper 就追一层即可，暂不深挖所有底层实现。
- 对 DTS，先看 `#include`/`/include/` 和节点层级；用 Ctrl+F 搜 `compatible`、`reg`、`interrupts`、`status`，然后追到对应 `.dtsi` 与 binding 文档。
- 笔记中的源码摘录只保留讲解所需的短片段；以工作区源码为准，复制时保留源文件路径和版本，避免片段修改后与源码脱节。

## 学习目标

理解设备树要描述什么、为什么 Linux 需要它，以及它怎样交给内核。

## 设备树解决的问题

Linux 内核需要知道当前板子有哪些硬件，以及这些硬件的资源和连接方式。例如：

- 某个 UART 控制器的寄存器地址范围和中断号
- 哪个 I2C 控制器连接了哪些设备
- GPIO 控制器、时钟、复位和引脚复用关系
- 内存范围、CPU 等基础硬件信息

这些板级信息如果全部写死在内核源码里，每种板子都要维护一套专属代码，内核会难以复用。设备树把大部分板级硬件描述从内核代码中分离出来，作为数据交给内核。

设备树描述的是硬件布局和资源，不是外设驱动本身。驱动仍由内核代码实现；内核根据设备树中的描述识别并创建设备，再让匹配的驱动负责操作它。

## 启动流程中的位置

一个简化的启动过程如下：

1. Boot ROM 和 Bootloader 完成早期启动工作。
2. Bootloader 将 Linux 内核镜像和设备树二进制文件（DTB）放入内存。
3. Bootloader 把 DTB 的位置等启动信息交给内核。
4. 内核解析设备树，获得内存、CPU、控制器和板级设备等信息。
5. 内核中的总线/设备模型创建设备，并尝试与驱动匹配。

常见文件格式：

- **DTS**：人编写的设备树源文件。
- **DTSI**：可被其他设备树包含的公共片段。
- **DTB**：编译后的二进制设备树，启动时由 Bootloader/内核使用。
- **DTC**：设备树编译器，常用于 DTS 与 DTB 之间的编译/反编译。

## 简化示意

```text
板级硬件信息（DTS/DTSI）
          │ DTC 编译
          ▼
         DTB ──Bootloader 传给内核──▶ Linux 内核解析
                                           │
                                           ▼
                               创建设备并匹配已有驱动
```

## 关键边界

- 设备树是对硬件的描述，不是驱动程序。
- 设备树本身不会“启动”硬件；驱动根据设备树提供的信息去配置和控制硬件。
- 设备树通常描述静态板级信息。运行时动态变化的设备也可能由其他机制发现，例如 USB 设备枚举。
- 具体属性的含义由设备树绑定（binding）和对应子系统/驱动约定，不能只凭属性名字猜测。

## 自测题

先尝试用自己的话回答，之后再对照：

1. 如果设备树描述了一个 UART，真正读写 UART 寄存器的是谁？
2. DTS、DTB 分别是什么，通常哪一个交给内核运行？
3. 设备树通常在启动流程的哪个阶段交给内核？
4. 为什么把板级硬件信息从内核代码中分离出来有帮助？

## 复盘记录

- 我的理解：待填写
- 不确定的问题：待填写
- 练习/实验：待填写
