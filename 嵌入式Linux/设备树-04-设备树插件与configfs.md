# 设备树 04：设备树插件与 configfs

## 学习状态

今天学习设备树插件（Device Tree Overlay, DTO）的用途、基本语法、编译和使用流程，并开始学习 configfs 虚拟文件系统。已学习到用户空间通过 `mkdir` 请求创建 item，以及内核侧由 `make_item` 回调创建对象；configfs 子系统注册、属性读写、`drop_item`/`release` 等实现细节仍在继续学习。

## 一、什么是设备树插件

设备树插件通常指 Device Tree Overlay：在系统运行时对内核的 live device tree 应用一组增量修改。它可以向已有总线节点添加设备、修改目标节点属性或增加/移除节点。应用后内核的 OF changeset/notifier 和设备模型可能触发设备创建、驱动匹配，移除 overlay 时也可能注销关联设备。

它不是 Linux 驱动模块，也不是可以任意修改所有硬件状态的通用热插拔机制。overlay 只修改设备树描述；驱动、总线和相关子系统还必须支持对应设备的创建、重配置和移除。特别是运行中切换 pinmux 时，要先考虑正在使用引脚的驱动、资源冲突及安全的停用/恢复顺序。

### 课程提到的应用场景

- 驱动开发时临时添加/修改硬件节点，便于调试。
- 硬件模块在启动时无法预先确定，运行时才需要加入设备描述。
- 在经过驱动/子系统配合和资源管理的前提下，动态调整某些硬件描述（例如 pinctrl 状态）。

这些是适用方向，不意味着任何节点或引脚都能在运行中安全切换。

## 二、插件语法与目标节点

一个 overlay 源文件常用 `.dtso` 扩展名，以 `/plugin/;` 标识插件。可以用 base tree 中导出的标签定位，也可以用绝对路径定位：

```dts
/dts-v1/;
/plugin/;

/* 按 base tree 中导出的标签定位 */
&ocp {
	new_device {
		compatible = "vendor,new-device";
		status = "okay";
	};
};
```

等价的 fragment 写法示意：

```dts
/dts-v1/;
/plugin/;

/ {
	fragment@0 {
		target = <&ocp>;
		__overlay__ {
			new_device {
				compatible = "vendor,new-device";
				status = "okay";
			};
		};
	};
};
```

`target = <&ocp>` 依赖 base DTB 中 `ocp` 标签对应的 phandle/symbol；路径形式可写成 `target-path = "/ocp"`，或由 `&{/ocp}` 语法表达。标签方式更不依赖具体层级路径，但要求 base DT 导出相应 symbol。

## 三、编译插件与 fixup

常见编译命令：

```sh
# base DTS：导出标签符号，供 overlay 按标签定位
dtc -@ -I dts -O dtb -o base.dtb base.dts

# overlay DTS：生成供运行时解析的 .dtbo
dtc -@ -I dts -O dtb -o new-device.dtbo new-device.dtso
```

`-@` 会生成解析标签引用所需的符号/修正信息。插件中引用 base DT 的外部标签会通过 `__fixups__` 描述；插件内部 phandle 引用的调整信息通过 `__local_fixups__` 描述。Linux resolver 在应用前修正这些引用，因此 `.dtbo` 不能只当成普通、独立的 DTB 看待。

实际项目应使用内核/厂商提供的 dtc 版本、include 路径和构建规则；单独编译成功只说明语法和引用处理通过，不等于 binding、硬件地址或电气配置正确。

## 四、插件如何生效：实现主线

Linux v6.17.7 文档 `Documentation/devicetree/overlay-notes.rst` 描述的内核 API 主线为：

```text
.dtbo/FDT blob
  → resolver 修正外部/本地 phandle
  → of_overlay_fdt_apply()
  → overlay changeset 应用到 live tree
  → OF changeset 通知与设备模型处理
  → 可能创建设备、匹配驱动并 probe
```

撤销时调用 `of_overlay_remove(cookie)`；被其他 overlay 叠加的 overlay 不能先行移除。overlay 节点/属性的指针在 overlay 移除后可能失效，内核代码不能在其生命周期之外继续保存和使用这些指针。

设备节点增加后，设备是否真的出现还受节点状态、父总线枚举规则、对应总线/驱动支持和资源依赖影响。修改 live tree 也不等同于保证现有驱动自动完成任意属性的热重配置。

## 五、configfs 与设备树插件

configfs 是基于内存的配置文件系统，面向用户空间创建和管理内核对象：用户通过 `mkdir` 创建 item、读写属性配置对象，通过 `rmdir` 请求删除；内核中的 configfs client/subsystem 定义对象类型及其属性和生命周期回调。它与 sysfs 的侧重点不同：sysfs 通常展示内核已创建对象，configfs 则允许用户空间主动创建配置对象；二者可以同时存在，configfs 不取代 sysfs。

课程大纲中的 configfs 实践包括：注册 configfs 子系统、实现 group 容器、创建 item、注册 attribute、实现多级目录，并完善 `drop_item`/`release` 等生命周期函数。后续需要结合 configfs API 和课程代码逐项学习。

### 用户空间 `mkdir` 如何变成内核 `make_item`

configfs 中的 item 通常在文件系统里表现为一个目录；它下面的 attribute 才表现为普通文件或二进制文件。因此“创建 item 文件”更准确地说，是用户对相应父目录执行 `mkdir item_name`，请求 configfs 创建一个 item 目录。

基本调用关系：

```text
用户空间 mkdir("/sys/kernel/config/<subsystem>/<group>/test")
  → VFS/configfs 的 mkdir 处理
  → 读取父 group 的 config_item_type
  → 调用 configfs_group_operations.make_item(group, "test")
  → subsystem 自己分配并初始化嵌入 config_item 的对象
  → 返回 config_item，configfs 将它挂入目录树
  → 按该 item 的 config_item_type 创建属性文件
```

课件中说 `make_item` 需要我们自己定义，指 subsystem/client 需要实现这个回调函数，并把函数指针放入 `configfs_group_operations`。用户执行 `mkdir` 时，configfs core 负责调用它。当前 Linux v6.17.7 的结构定义为：

```c
struct configfs_group_operations {
	struct config_item *(*make_item)(struct config_group *group,
					 const char *name);
	struct config_group *(*make_group)(struct config_group *group,
					   const char *name);
	void (*drop_item)(struct config_group *group,
			  struct config_item *item);
	/* 还有 disconnect_notify/is_visible 等可选回调 */
};
```

最小化示意：

```c
struct demo_item {
	struct config_item item; /* 嵌入 configfs 通用对象 */
	/* subsystem 自己的状态字段 */
};

static struct config_item *demo_make_item(struct config_group *group,
					  const char *name)
{
	struct demo_item *obj;

	obj = kzalloc(sizeof(*obj), GFP_KERNEL);
	if (!obj)
		return ERR_PTR(-ENOMEM);

	config_item_init_type_name(&obj->item, name, &demo_item_type);
	return &obj->item;
}

static struct configfs_group_operations demo_group_ops = {
	.make_item = demo_make_item,
};
```

这是说明调用关系的片段，不是完整可加载模块：实际实现还要定义 `demo_item_type`、属性、引用计数释放回调，并在出错及删除路径正确释放资源。Linux v6.17.7 的 `configfs_mkdir()` 在父 group 提供 `make_item` 时调用该回调；回调返回 `ERR_PTR()` 可报告错误，NULL 在当前实现中按 `-ENOMEM` 处理。

#### 这和 C++ 虚函数是什么关系？

**设计思想相似，但不是 C++ 虚函数本身。** 相似点是调用者面向一组约定的操作，具体 subsystem 提供实现，运行时根据对象的 operations 指针间接分派；这体现了接口/多态式设计。

区别在于：C++ 虚函数由语言和编译器提供继承、虚函数表及对象布局机制；这里是 C 语言的普通结构体中保存函数指针。configfs core 执行的本质类似：

```c
group->cg_item.ci_type->ct_group_ops->make_item(group, name);
```

所以可以用“类似虚函数的回调/接口机制”帮助理解，但不要说它就是 C++ `virtual`，也没有 C++ 类继承。

`make_item` 一般负责创建和初始化配置对象，不是直接在用户空间创建/写属性文件。属性文件由 item 的 `config_item_type` 中 `ct_attrs` / `ct_bin_attrs` 描述，`show()` / `store()` 或 binary attribute 回调负责数据交互；销毁时还要配合 `drop_item()` 与 item type 的 `release()` 管理生命周期。

### 删除对象、释放内存、属性和多级 group

- **`drop_item(group, item)`**：用户对 item/group 执行 `rmdir` 时的父 group 回调。configfs 已从文件系统层级解除 item 的连接；若实现了该回调，subsystem 负责对创建时持有的 item 引用执行 `config_item_put()`，并处理 subsystem 自己持有的关联。它返回 `void`，不能拒绝删除。
- **`release(item)`**：注册在 item 的 `configfs_item_operations` 中。当该 item 的引用计数最终降到 0 时调用，常用于通过 `container_of()` 找回外层对象并释放内存。`drop_item` 负责删除/放弃引用，`release` 负责对象最终释放；二者不是同一个回调。
- 如果没有额外删除工作，父 group 可以不提供 `drop_item`，configfs 会替它 `config_item_put()`。但动态分配的 item 通常仍需提供 `release` 来释放外层对象。
- **引用计数**：`config_item_get()` 为调用者取得一个引用，`config_item_put()` 归还一个引用。计数表示仍有多少持有者要求对象保持有效，不表示对象被访问或操作的次数；不是每次读写属性后都调用 `put()`。
- 当最后一个引用被归还、计数归零时，configfs 通过 item type 的 `ct_item_ops->release()` 执行最终释放。动态分配的外层对象通常在该回调里用 `container_of()` 找回并释放。
- `rmdir()` 负责从 configfs 的目录层级中移除对象；目录移除与内存立即释放不是一回事。若仍有其他引用，对象会继续存活，直到这些引用都归还。
- **属性**：用 `struct configfs_attribute` 描述名字、权限和 `show`/`store` 回调，并放进 `config_item_type.ct_attrs` 的 NULL 结尾数组。二进制内容使用 `configfs_bin_attribute` 并放进 `ct_bin_attrs`。group 自己也可以有属性；item 和 group 的 type 各自决定目录中可见的属性。
- **多级目录**：某个 group 的 `configfs_group_operations.make_group()` 创建子 `config_group`，通过 `config_group_init_type_name()` 初始化；子 group 可绑定自己的 group operations，再提供下一层 `make_group()` 或 `make_item()`。因此目录层级由 group 类型/回调逐层定义。

课件中的关系可以概括为：

```text
configfs_subsystem
  └─ config_group
      ├─ make_item()  → config_item 目录
      └─ make_group() → 子 config_group 目录
           ├─ ct_attrs / ct_bin_attrs → 文件属性
           └─ 子 group operations → 更深层目录
```

实现和调试时重点追踪对象所有权：谁分配，谁初始化 `config_item`，`rmdir` 时谁 `put`，最后由哪个 `release` 回调释放容器。Linux v6.17.7 的 `samples/configfs/configfs_sample.c` 展示 child item、attribute、release、`make_item` 和 `make_group` 示例；其中示例注释说明没有额外删除工作时可以省略 `drop_item`。

### 设备树插件驱动移植流程（课程记录）

课程给出的目标板流程：

1. 挂载 configfs 虚拟文件系统，并确认目标板提供课程需要的 overlay 配置入口。
2. 在内核配置界面检查/配置相关选项；`menuconfig` 中可按 `/` 搜索配置符号，再回到菜单核实依赖关系和最终状态。
3. 获取课程/厂商提供的设备树插件驱动源码，按目标 BSP 的构建规则选择编译为 `.ko` 模块或编入内核。
4. 安装/加载驱动后，按该 BSP 的 configfs 接口创建 overlay item、写入 `.dtbo` 并观察状态；验证 live tree、设备注册、驱动 probe 和移除结果。

这里的模块/内建选择针对课程提供的内核驱动或 configfs client；`.dtbo` 本身是设备树 blob，不是 `.ko`。上游 v6.17.7 是否有某个 configfs overlay 接口不能仅凭通用 configfs 或 `CONFIG_OF_OVERLAY` 推断，需检查开发板 BSP 是否提供对应驱动及其 Kconfig/Makefile。配置符号名称同样以目标 BSP 源码为准，不把课件菜单项直接当成上游配置项。

## 参考资料路径

在工作区的 Linux v6.17.7 源码中：

- 课件提到的 `configfs_sample.c`：[`linux-6.17.7/samples/configfs/configfs_sample.c`](../linux-6.17.7/samples/configfs/configfs_sample.c)。可重点看 `simple_children_make_item()`、`simple_child_release()`、attribute 定义，以及 `group_children_make_group()`。
- 课件写作 `configfs.txt` 的说明文档，在此版本已使用 reStructuredText 后缀：[`linux-6.17.7/Documentation/filesystems/configfs.rst`](../linux-6.17.7/Documentation/filesystems/configfs.rst)。当前源码树里没有找到字面文件名 `configfs.txt`。
- configfs core 实现：`linux-6.17.7/fs/configfs/`；头文件/结构体声明：`linux-6.17.7/include/linux/configfs.h`。
- OF overlay 实现和文档：`linux-6.17.7/drivers/of/overlay.c`、`resolver.c`、`Documentation/devicetree/overlay-notes.rst`。课程 RK3568 的 `device-tree/overlays` configfs 控制器若不同于这些文件，应另在厂商 BSP 中定位。

**版本边界**：Linux v6.17.7 上游源码包含通用 configfs 和 `CONFIG_OF_OVERLAY`/overlay 内核 API，但没有找到把通用 configfs 目录直接注册为设备树 overlay 控制接口的上游实现。因此课程中通过 configfs 用户空间动态加载 overlay 的操作，应结合所用开发板的 BSP/发行版实现核实，不能假设所有上游 Linux 系统都有相同接口。

## 源码与文档阅读顺序

1. `Documentation/devicetree/overlay-notes.rst`：先看 overlay 目标、标签/路径定位和 apply/remove 生命周期。
2. `Documentation/devicetree/dynamic-resolution-notes.rst`：理解 `__fixups__`、`__local_fixups__` 与 phandle 调整。
3. `drivers/of/resolver.c`：跟踪 overlay 引用修正。
4. `drivers/of/overlay.c`：从 `of_overlay_fdt_apply()`、changeset apply/remove 和 notifier 继续读。
5. `Documentation/filesystems/configfs.rst`：学习 item/group/attribute 和生命周期。
6. 课程所用 BSP 中的 configfs overlay 控制代码：确认挂载路径、dtbo 写入方式、内核配置和移除行为。

### 补充：configfs sample 的 Kbuild 入口

阅读 `samples/configfs/configfs_sample.c` 时，可以沿着配置入口追到目标文件：

```text
samples/Kconfig
  → 声明 SAMPLE_CONFIGFS 配置项（依赖 CONFIGFS_FS，且限制为模块）
samples/Makefile
  → obj-$(CONFIG_SAMPLE_CONFIGFS) += configfs/
samples/configfs/Makefile
  → obj-$(CONFIG_SAMPLE_CONFIGFS) += configfs_sample.o
```

Kbuild 根据配置值把 `obj-$(CONFIG_FOO)` 展开为 `obj-m`、`obj-y` 或不参与构建的目标列表。Kbuild 负责通用编译和链接规则，因此子目录 Makefile 通常只需声明目标，无需手写 `.c` 到 `.o` 的命令。这个 sample 的 Kconfig 依赖将其限制为模块，所以实际目标是 `configfs_sample.ko`。

源码定位：`linux-6.17.7/samples/Kconfig` 中 `SAMPLE_CONFIGFS`、`linux-6.17.7/samples/Makefile`、`linux-6.17.7/samples/configfs/Makefile`，以及 `linux-6.17.7/Documentation/kbuild/makefiles.rst` 的目标定义说明。

## 后续课程清单

- [ ] 搞清楚插件驱动如何移植到目标 BSP，并核对驱动与 binding。
- [ ] 实际应用/移除一个 `.dtbo`，观察 live tree、设备注册和驱动 probe/remove。
- [ ] 用实例验证 overlay 修改节点属性/状态的效果与限制。
- [x] 初步理解用户空间 `mkdir` 触发父 group 的 `make_item`，由内核 subsystem 创建 item 对象。
- [x] 学习 `drop_item`/`release`、attribute 注册、`make_group` 和多级目录的基本职责。
- [x] 记录课程提到的驱动移植/build 流程，并找到 `configfs` 参考文档和 sample 路径。
- [ ] 继续学习 configfs 对象模型：subsystem、group、item、attribute 及完整生命周期。
- [ ] 在目标板按课程步骤实际验证插件驱动配置、构建、加载、应用和移除。
- [ ] 查清楚目标板 BSP 的 configfs overlay 接口是否为上游实现、厂商扩展或自定义驱动。

## 复盘问题

1. overlay 与普通完整 DTS/DTB 的用途区别是什么？
2. 为什么 base DTB 和 overlay 编译时常需要 `-@`？`__fixups__` 与 `__local_fixups__` 分别解决什么问题？
3. overlay apply 后，为什么设备树节点出现不等同于驱动一定 probe 成功？
4. configfs 和 sysfs 的对象生命周期由谁发起/控制？
5. 目标板的 configfs overlay 接口来自内核上游还是 BSP 扩展，如何从源码确认？
6. configfs 的 item 目录由哪个操作请求创建？`make_item` 回调负责什么？它和 C++ 虚函数有哪些相似/不同？
7. `drop_item` 和 `release` 分别在哪个生命周期阶段运行，谁负责 `config_item_put()`？
8. `make_group()` 如何逐层创建多级目录？`ct_attrs` 和 `ct_bin_attrs` 分别描述什么？

## 本次复盘

- 当前完成：设备树插件用途、基础语法/编译方式、动态设备树修改的实现主线；configfs 学习到 `mkdir` → `make_item`、`make_group`、属性和删除/释放回调的基本职责。
- 尚待实操：插件驱动移植和目标板配置/构建/加载、动态修改实验，以及 configfs 对象生命周期代码的完整实现与验证。
