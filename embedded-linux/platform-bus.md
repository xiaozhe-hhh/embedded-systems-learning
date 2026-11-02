# Linux 平台总线

- 学习状态：已学习，正在补全源码笔记
- 源码版本：Linux v6.17.7
- 核心问题：不可自动枚举的 SoC 外设如何成为 Linux device，并与 driver 匹配？

## 阅读顺序

1. `include/linux/platform_device.h`：读 `struct platform_device`、`struct platform_driver` 和资源 API。
2. `drivers/base/platform.c`：读 `platform_bus_type`、注册包装函数和 `platform_match()`。
3. `drivers/of/platform.c`：读 `of_platform_populate()`、`of_platform_bus_create()`、设备创建路径。
4. `drivers/base/bus.c`、`drivers/base/dd.c`：按需要追通用 device/driver 匹配及 probe 调用。
5. 对照一个 DTS 节点和驱动的 `of_match_table`，观察资源从 DTS 到 probe 的路径。

## 三类对象

- `platform_device`：表示一个平台设备，包含通用 `struct device`、资源、平台数据和设备树节点等。
- `platform_driver`：平台驱动，包含通用 `struct device_driver`、`probe`/`remove` 等回调和可选 ID 表。
- `platform_bus_type`：提供匹配规则并加入 Linux 通用 driver model。

平台总线通常用于 SoC 内存映射外设或无法通过 PCI/USB 等总线枚举的设备。设备树常负责描述设备实例，但平台设备也可以由板级代码或其他固件枚举机制建立。

## 设备树到驱动匹配

```text
DTS 节点
  → of_platform_populate()/platform_device 创建
  → platform_device 注册到 platform_bus_type
  → platform_match() 检查 driver_override、OF compatible、ACPI、ID table、名称
  → 匹配成功后通用 driver core 调用驱动 probe()
  → 驱动读取资源并初始化硬件
```

## 源码摘录：匹配优先级

Linux v6.17.7，`linux/drivers/base/platform.c`，`platform_match()` 的核心顺序：

```c
if (of_driver_match_device(dev, drv))
        return 1;
if (acpi_driver_match_device(dev, drv))
        return 1;
if (pdrv->id_table)
        return platform_match_id(pdrv->id_table, pdev) != NULL;
return (strcmp(pdev->name, drv->name) == 0);
```

解释：OF/设备树匹配是平台驱动常见路径，但并非唯一方式。匹配成功只表示候选驱动绑定；probe 仍可能因资源或硬件初始化失败而返回错误。

`platform_driver_register()` 最终设置 `drv->driver.bus = &platform_bus_type` 并进入通用 `driver_register()`。后续设备、驱动任一方注册时，driver core 都会尝试匹配。

## 资源与生命周期

- `reg` 经总线地址转换后通常由资源转换逻辑成为 `IORESOURCE_MEM`；驱动用 `platform_get_resource()`、`devm_platform_ioremap_resource()` 获取并映射。
- `interrupts` 由 IRQ domain 翻译，驱动通常用 `platform_get_irq()`/`platform_get_irq_byname()` 获取 Linux IRQ。
- 时钟、复位、GPIO、regulator 等资源一般通过各自子系统的 consumer API 获取，不应自行解析所有 DT 属性。
- `devm_*` 资源在设备解绑时自动释放；非 devm 资源需在错误路径和 remove 中配对释放。

## 易错点

- compatible 匹配成功不等于 probe 成功。
- 设备树节点不直接调用驱动；它参与创建 device 和提供匹配/资源数据。
- `reg` 不是可以不经转换就直接 `ioremap` 的 CPU 虚拟地址。
- platform bus 不是“所有硬件的总线”；能自描述/枚举的 PCI、USB 等通常有各自总线模型。

## 自测

1. platform_device 与 platform_driver 分别描述什么？
2. `platform_match()` 中 OF 匹配之后还检查哪些方案？
3. 匹配成功后到 probe 之间还会发生什么？
4. 为什么驱动应使用子系统 consumer API 获取时钟、GPIO 等资源？
5. DTS 的 `reg` 怎样成为驱动可用的映射？

## 我的复盘

- 日期：待填写
- 我能解释的调用链：待填写
- 目标板上一个 platform device 示例：待填写
- 下次源码入口：`linux/drivers/base/platform.c` 的 `platform_match()`
