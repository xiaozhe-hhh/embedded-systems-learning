.. SPDX-License-Identifier: GPL-2.0

================
Linux 与设备树
================

Linux 对设备树数据的使用模型

:作者: Grant Likely <grant.likely@secretlab.ca>

本文介绍 Linux 如何使用设备树。关于设备树数据格式的概述，请参阅 devicetree.org 上的设备树使用指南 [1]_。

.. [1] https://www.devicetree.org/specifications/

“开放固件设备树”（Open Firmware Device Tree），简称设备树（Devicetree，DT），是一种用于描述硬件的数据结构和语言。更具体地说，它是一种操作系统可读取的硬件描述，因此操作系统无需将机器的具体信息硬编码在代码中。

从结构上看，DT 是一棵树，也可以说是一个带有命名节点的有向无环图。节点可以包含任意数量的命名属性，用来封装任意数据。此外，还可以在自然树形结构之外建立任意节点之间的链接。

从概念上说，一套通用的使用约定称为“绑定”（bindings），它定义了树中的数据应如何组织，以描述常见的硬件特性，包括数据总线、中断线、GPIO 连接和外围设备。

硬件描述应尽可能采用现有绑定，以便最大限度地复用已有支持代码。不过，由于属性名和节点名只是文本字符串，因此也很容易通过定义新的节点和属性来扩展现有绑定，或创建新绑定。但创建新绑定前务必先做好调研，了解已有方案。目前存在两种彼此不兼容的 I2C 总线绑定，原因就是有人创建新绑定前，没有先调查现有系统中 I2C 设备的枚举方式。

1. 历史
-------
设备树最初由 Open Firmware 创建，作为一种通信方式，用于将数据从 Open Firmware 传递给客户端程序（例如操作系统）。操作系统使用设备树在运行时发现硬件拓扑结构，从而支持大多数可用硬件，而无需硬编码设备信息（前提是所有设备都有对应的驱动程序）。

由于 Open Firmware 常用于 PowerPC 和 SPARC 平台，Linux 对这些架构的支持长期以来一直使用设备树。

2005 年，PowerPC Linux 开始进行大规模清理并合并 32 位和 64 位支持。当时决定要求所有 PowerPC 平台都支持 DT，无论它们是否使用 Open Firmware。为此，人们创建了一种称为扁平设备树（Flattened Device Tree，FDT）的 DT 表示形式。它可以作为二进制数据块传递给内核，无需真正的 Open Firmware 实现。U-Boot、kexec 及其他引导加载程序也经过修改，既能传递设备树二进制文件（dtb），也能在启动时修改 dtb。PowerPC 引导封装程序（``arch/powerpc/boot/*``）也加入了 DT 支持，这样就能将 dtb 与内核映像封装在一起，从而支持使用现有的不支持 DT 的固件启动。

一段时间后，FDT 基础设施被泛化，以便所有架构都能使用。在本文撰写时，已有 6 个进入主线的架构（arm、microblaze、mips、powerpc、sparc 和 x86），以及 1 个尚未进入主线的架构（nios）具备一定程度的 DT 支持。

2. 数据模型
-----------
如果你还没有读过设备树使用指南 [1]_，现在就去读一下吧。我等你……

2.1 高层概述
------------
最重要的一点是，DT 只是一种描述硬件的数据结构。它没有什么神奇之处，也不会自动解决所有硬件配置问题。它所提供的是一种语言，用于将硬件配置与 Linux 内核（或其他操作系统）中的板级支持和设备驱动支持解耦。这样，板级支持和设备支持就可以由数据驱动：根据传入内核的数据做出设置决策，而不是针对每台机器进行硬编码。

理想情况下，由数据驱动的平台设置可以减少代码重复，并让单个内核映像更容易支持各种硬件。

Linux 使用 DT 数据主要有三个目的：

1) 平台识别，
2) 运行时配置，以及
3) 设备枚举。

2.2 平台识别
------------
首先，内核会使用 DT 中的数据识别具体的机器。在理想情况下，具体平台不应影响内核，因为设备树可以一致、可靠地完整描述所有平台细节。但硬件并不完美，因此内核必须在启动早期识别机器，以便有机会执行特定于机器的修正操作。

在大多数情况下，机器身份并不重要，内核会根据机器的核心 CPU 或 SoC 来选择设置代码。例如，在 ARM 上，arch/arm/kernel/setup.c 中的 setup_arch() 会调用 arch/arm/kernel/devtree.c 中的 setup_machine_fdt()。该函数会搜索 machine_desc 表，并选出与设备树数据最匹配的 machine_desc。它通过查看设备树根节点的 'compatible' 属性，并将其与 struct machine_desc 中的 dt_compat 列表进行比较来确定最佳匹配。struct machine_desc 定义在 arch/arm/include/asm/mach/arch.h 中。

'compatible' 属性包含一个经过排序的字符串列表：第一个字符串是机器的确切名称，后面可以跟随该机器兼容的其他板卡，并按兼容程度从高到低排列。例如，TI BeagleBoard 及其后继产品 BeagleBoard xM 的根节点 compatible 属性可能分别如下：

::

    compatible = "ti,omap3-beagleboard", "ti,omap3450", "ti,omap3";
    compatible = "ti,omap3-beagleboard-xm", "ti,omap3450", "ti,omap3";

其中，"ti,omap3-beagleboard-xm" 指明了确切型号，同时声明它兼容 OMAP 3450 SoC，也兼容 OMAP3 系列 SoC。可以看到，列表按照从最具体（确切板卡）到最宽泛（SoC 系列）的顺序排列。

细心的读者可能会指出，Beagle xM 也可以声明兼容原版 BeagleBoard。不过，不建议在板卡层面这样做，因为即使属于同一产品线，不同板卡之间通常也会有较大差异，很难准确界定一块板卡声称兼容另一块板卡究竟意味着什么。因此，在顶层描述中，最好谨慎处理，不要轻易声明一块板卡兼容另一块板卡。一个明显的例外是：一块板卡作为另一块板卡的载板，例如 CPU 模块安装在载板上。

关于 compatible 值还有一点需要注意：compatible 属性中使用的每个字符串，都必须有文档说明其含义。请在 Documentation/devicetree/bindings 中为 compatible 字符串添加文档。

仍以 ARM 为例，对于每个 machine_desc，内核都会检查其 dt_compat 列表中的条目是否出现在 compatible 属性中。如果有条目匹配，该 machine_desc 就是驱动此机器的候选项。搜索完整个 machine_desc 表后，setup_machine_fdt() 会根据每个 machine_desc 匹配到 compatible 属性中哪个条目，返回“最兼容”的 machine_desc。如果没有找到匹配项，则返回 NULL。

这一方案的依据是：在大多数情况下，如果多个板卡使用相同的 SoC 或同一系列 SoC，一个 machine_desc 就能支持它们。但总会有一些例外：特定板卡需要特殊设置代码，而这些代码对通用情况并无用处。可以在通用设置代码中显式检查有问题的板卡来处理这些特殊情况，但如果情况不止一两个，这种做法很快就会变得混乱且难以维护。

因此，compatible 列表允许通用 machine_desc 在其 dt_compat 列表中指定“兼容性较宽泛”的值，从而支持一组广泛的板卡。在上面的例子中，通用板级支持可以声明兼容 "ti,omap3" 或 "ti,omap3450"。如果发现原版 BeagleBoard 存在一个需要在启动早期执行特殊规避处理的缺陷，那么就可以添加一个新的 machine_desc 来实现该处理，并且只匹配 "ti,omap3-beagleboard"。

PowerPC 使用的方案略有不同：它会调用每个 machine_desc 的 .probe() 钩子，并采用第一个返回 TRUE 的项。不过，这种方法没有考虑 compatible 列表中各项的优先级，新架构支持应尽量避免采用这种方式。

2.3 运行时配置
---------------
在大多数情况下，DT 是固件向内核传递数据的唯一方式，因此它也会用于传递运行时和配置信息，例如内核参数字符串和 initrd 映像的位置。

这些数据大多位于 /chosen 节点中。启动 Linux 时，该节点可能如下所示：

::

    chosen {
        bootargs = "console=ttyS0,115200 loglevel=8";
        initrd-start = <0xc8000000>;
        initrd-end = <0xc8200000>;
    };

bootargs 属性包含内核参数，initrd-* 属性则定义 initrd 数据块的地址和大小。注意，initrd-end 是 initrd 映像之后的第一个地址，因此它与 struct resource 通常采用的语义不同。/chosen 节点还可以包含任意数量的其他属性，用于传递平台特定的配置信息。

在启动早期，架构设置代码会多次调用 of_scan_flat_dt()，并传入不同的辅助回调函数，以便在分页机制建立之前解析设备树数据。of_scan_flat_dt() 会扫描设备树，并使用这些辅助函数提取启动早期所需的信息。通常，early_init_dt_scan_chosen() 用于解析 chosen 节点（包括内核参数）；early_init_dt_scan_root() 用于初始化 DT 地址空间模型；early_init_dt_scan_memory() 则用于确定可用 RAM 的大小和位置。

在 ARM 上，setup_machine_fdt() 函数负责在选定支持该板卡的 machine_desc 后，对设备树进行启动早期扫描。

2.4 设备枚举
-------------
识别板卡并解析早期配置信息后，内核初始化就可以按常规方式继续进行。在初始化过程中的某个阶段，会调用 unflatten_device_tree()，将数据转换为更适合运行时使用的表示形式。此时也会调用特定于机器的设置钩子，例如 ARM 上 machine_desc 的 .init_early()、.init_irq() 和 .init_machine() 钩子。本节其余部分将以 ARM 实现为例，但所有使用 DT 的架构基本都会采用类似的方式。

从这些函数的名字大致可以看出，.init_early() 用于执行需要在启动早期进行的机器专属设置，而 .init_irq() 用于设置中断处理。使用 DT 不会实质性地改变这两个函数的行为。如果提供了 DT，这两个函数都可以调用 include/linux/of*.h 中的 DT 查询函数（of_*），获取平台的其他信息。

在 DT 语境下，最值得关注的钩子是 .init_machine()，它主要负责将平台数据填充到 Linux 设备模型中。过去，嵌入式平台通常会在板级支持 .c 文件中定义一组静态时钟结构、platform_devices 及其他数据，并在 .init_machine() 中一次性注册。使用 DT 后，就不必再为每个平台硬编码静态设备，而是可以解析 DT，动态获取设备列表并分配设备结构。

最简单的情况是，.init_machine() 只负责注册一组 platform_devices。platform_device 是 Linux 中的一个概念，用于表示无法通过硬件检测的内存映射或 I/O 映射设备，也用于表示“组合式”或“虚拟”设备（稍后会进一步介绍）。虽然 DT 中没有“平台设备”这一术语，但 platform_device 大致对应于设备树根节点上的设备节点，以及简单内存映射总线节点的子节点。

现在适合看一个例子。下面是 NVIDIA Tegra 板卡设备树的一部分：

::

  /{
    compatible = "nvidia,harmony", "nvidia,tegra20";
    #address-cells = <1>;
    #size-cells = <1>;
    interrupt-parent = <&intc>;

    chosen { };
    aliases { };

    memory {
        device_type = "memory";
        reg = <0x00000000 0x40000000>;
    };

    soc {
        compatible = "nvidia,tegra20-soc", "simple-bus";
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        intc: interrupt-controller@50041000 {
            compatible = "nvidia,tegra20-gic";
            interrupt-controller;
            #interrupt-cells = <1>;
            reg = <0x50041000 0x1000>, < 0x50040100 0x0100 >;
        };

        serial@70006300 {
            compatible = "nvidia,tegra20-uart";
            reg = <0x70006300 0x100>;
            interrupts = <122>;
        };

        i2s1: i2s@70002800 {
            compatible = "nvidia,tegra20-i2s";
            reg = <0x70002800 0x100>;
            interrupts = <77>;
            codec = <&wm8903>;
        };

        i2c@7000c000 {
            compatible = "nvidia,tegra20-i2c";
            #address-cells = <1>;
            #size-cells = <0>;
            reg = <0x7000c000 0x100>;
            interrupts = <70>;

            wm8903: codec@1a {
                compatible = "wlf,wm8903";
                reg = <0x1a>;
                interrupts = <347>;
            };
        };
    };

    sound {
        compatible = "nvidia,harmony-sound";
        i2s-controller = <&i2s1>;
        i2s-codec = <&wm8903>;
    };
  };

在 .init_machine() 阶段，Tegra 板级支持代码需要查看 DT，并决定为哪些节点创建 platform_devices。不过，从设备树结构本身并不容易看出每个节点代表什么类型的设备，甚至不容易判断某个节点是否代表设备。/chosen、/aliases 和 /memory 节点是信息节点，并不描述设备（尽管也可以认为内存是一种设备）。/soc 的子节点是内存映射设备，但 codec@1a 是 I2C 设备；sound 节点则不是设备，而是描述其他设备如何连接在一起以构成音频子系统。我知道每个设备是什么，是因为我熟悉这块板子的设计，但内核如何知道每个节点该如何处理呢？

关键在于，内核从设备树根节点开始，查找包含 'compatible' 属性的节点。首先，通常可以假设任何包含 'compatible' 属性的节点都代表某种设备；其次，可以假设设备树根节点上的节点要么直接连接到处理器总线，要么是无法用其他方式描述的杂项系统设备。对于每个这样的节点，Linux 都会分配并注册一个 platform_device，而它随后可能会绑定到一个 platform_driver。

为什么可以放心地将这些节点作为 platform_device 使用？这是因为 Linux 的设备模型中，几乎所有 bus_type 都假设其设备是某个总线控制器的子设备。例如，每个 i2c_client 都是某个 i2c_master 的子设备；每个 spi_device 都是 SPI 总线的子设备；USB、PCI、MDIO 等也类似。DT 中也采用相同的层级结构：I2C 设备节点只会出现在 I2C 总线节点之下，SPI、MDIO、USB 等也一样。唯一不要求特定类型父设备的设备是 platform_device（以及稍后会介绍的 amba_device），它们可以直接位于 Linux /sys/devices 树的根部。因此，如果 DT 节点位于设备树根部，那么将其注册为 platform_device 通常是最合适的做法。

Linux 板级支持代码会调用 of_platform_populate(NULL, NULL, NULL, NULL)，启动对设备树根节点下设备的发现。所有参数都是 NULL，是因为从设备树根节点开始时，不需要指定起始节点（第一个 NULL），不需要指定父 struct device（最后一个 NULL），也不使用匹配表（至少目前不需要）。如果板级支持只需要注册设备，那么 .init_machine() 除了调用 of_platform_populate() 外可以什么都不做。

在 Tegra 示例中，这会处理 /soc 和 /sound 节点。但 SoC 节点的子节点又该怎么办？它们不也应该注册为 platform device 吗？对于 Linux DT 支持，通常由父设备的驱动程序在其 .probe() 阶段注册子设备。因此，I2C 总线设备驱动会为每个子节点注册一个 i2c_client；SPI 总线驱动会注册其 spi_device 子设备；其他 bus_type 也类似。

按照这种模型，可以编写一个绑定到 SoC 节点的驱动程序，让它只负责为所有子节点注册 platform_devices。板级支持代码分配并注册一个 SoC 设备后，一个（理论上的）SoC 设备驱动就可以绑定到该设备，并在其 .probe() 钩子中为 /soc/interrupt-controller、/soc/serial、/soc/i2s 和 /soc/i2c 注册 platform_devices。听起来很简单，对吧？

实际上，将某些 platform_device 的子节点注册为更多 platform_device 是一种常见模式，设备树支持代码也利用这一点简化了上述例子。of_platform_populate() 的第二个参数是一个 of_device_id 表。任何匹配该表中条目的节点，其子节点也会被注册。在 Tegra 示例中，代码可以类似这样：

::

  static void __init harmony_init_machine(void)
  {
    /* ... */
    of_platform_populate(NULL, of_default_bus_match_table, NULL, NULL);
  }

Devicetree 规范将 "simple-bus" 定义为一种表示简单内存映射总线的属性，因此 of_platform_populate() 本可以直接假设所有带有 simple-bus compatible 值的节点都应遍历其子节点。不过，我们把匹配表作为参数传入，这样板级支持代码始终可以覆盖默认行为。

[需要补充关于如何添加 I2C、SPI 等子设备的讨论]

附录 A：AMBA 设备
-----------------

ARM PrimeCell 是连接到 ARM AMBA 总线的一类设备，具备一定的硬件检测和电源管理支持。在 Linux 中，使用 struct amba_device 和 amba_bus_type 表示 PrimeCell 设备。不过，问题在于 AMBA 总线上的设备并非全部都是 PrimeCell；在 Linux 中，amba_device 和 platform_device 实例通常会作为同一总线段上的同级设备存在。

使用 DT 时，这会给 of_platform_populate() 带来问题，因为它必须判断每个节点应注册为 platform_device 还是 amba_device。遗憾的是，这会让设备创建模型稍微复杂一些，但解决方案并不需要太多改动。如果某节点兼容 "arm,primecell"，那么 of_platform_populate() 就会将其注册为 amba_device，而不是 platform_device。