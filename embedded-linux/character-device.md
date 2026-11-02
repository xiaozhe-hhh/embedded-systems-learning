# Linux 字符设备：从设备号到 `file_operations`

- 学习状态：已学习，正在补全源码笔记
- 源码版本：Linux v6.17.7
- 核心问题：`open("/dev/xxx")` 怎样找到驱动提供的文件操作？

## 阅读顺序

1. `Documentation/admin-guide/devices.txt`：理解设备号传统约定；现代动态设备号不要求固定分配。
2. `include/linux/fs.h`：阅读 `struct file_operations`，对应用户态文件操作接口。
3. `include/linux/cdev.h`：阅读 `struct cdev` 及 `cdev_init()`、`cdev_add()` 声明。
4. `fs/char_dev.c`：先读 `alloc_chrdev_region()`、`cdev_add()`，再追 `chrdev_open()`。
5. 找一个具体驱动，看 `open/read/write/unlocked_ioctl` 如何操作驱动私有状态。

## 关键概念

- `dev_t` 编码主设备号和次设备号；主设备号用于分派到一类驱动，次设备号通常区分实例/通道。
- `alloc_chrdev_region()` 动态申请设备号范围；`register_chrdev_region()` 注册指定范围。
- `struct cdev` 把设备号范围和 `file_operations` 关联。`cdev_add()` 后设备立即可被打开，因此驱动应先初始化状态再发布 cdev。
- `/dev` 节点是用户态访问入口，由 devtmpfs/udev 或手动创建设备节点呈现；它不是设备驱动本身，也不是 `cdev`。
- `struct file_operations` 提供文件接口实现。常见 `.owner = THIS_MODULE` 用于模块引用计数保护。

## 核心调用关系

```text
用户 open()
  → VFS 查找字符设备 inode（inode->i_rdev 保存设备号）
  → def_chr_fops / chrdev_open()
  → 按 dev_t 在 cdev_map 中查到 struct cdev
  → 将 filp->f_op 替换为 cdev->ops
  → 调用驱动的 file_operations.open（若提供）
  → 后续 read/write/ioctl 等分派到驱动回调
```

## 源码摘录：字符设备 open 的关键步骤

Linux v6.17.7，`linux/fs/char_dev.c`，`chrdev_open()` 中的核心逻辑（删去引用计数与错误处理细节）：

```c
kobj = kobj_lookup(cdev_map, inode->i_rdev, &idx);
new = container_of(kobj, struct cdev, kobj);
/* ... */
replace_fops(filp, fops);
if (filp->f_op->open)
        ret = filp->f_op->open(inode, filp);
```

解释：内核依据 inode 的设备号查 `cdev_map`，找到 `cdev`，再将当前 `struct file` 的操作表换成驱动操作表，最后调用驱动 `.open`。实际函数还要用 `cdev_lock`、kobject/module 引用和错误路径处理并发卸载等生命周期问题。

## 驱动注册/清理次序

典型流程：

1. 初始化私有对象和锁、缓冲区、等待队列等；
2. `alloc_chrdev_region()` 申请设备号；
3. `cdev_init()` 绑定操作表；
4. `cdev_add()` 发布字符设备；
5. 创建 class/device 以便设备节点管理；
6. 退出时先阻止新访问、撤销 device/cdev，再释放设备号及资源。

实际项目可用 `cdev_device_add()`/`cdev_device_del()` 将 cdev 和 struct device 生命周期协调起来。清理顺序必须保证已有 file 引用不会访问已释放的私有数据。

## 容易混淆

- 设备号注册不等于创建 `/dev` 文件。
- `cdev_add()` 后设备已可访问，不能把它放在对象初始化之前。
- `.read` 的 `count` 是请求长度，实际可读长度可能更短；用户缓冲区不能直接解引用，要用 `copy_to_user()`/`copy_from_user()`。
- `copy_to_user()`/`copy_from_user()` 可能睡眠，不可在硬中断或持有自旋锁时调用。
- `file->private_data` 常用于保存设备实例指针；`.open` 和 `.release` 需建立/释放相应引用或状态。

## 自测

1. `dev_t` 的主次设备号分别承担什么用途？
2. `/dev/foo`、`struct cdev` 和驱动模块的区别是什么？
3. `chrdev_open()` 如何把 VFS 文件操作转交给驱动？
4. 为什么添加 cdev 之前必须完成状态初始化？
5. 哪些用户内存拷贝函数不能在持自旋锁时调用？

## 我的复盘

- 日期：待填写
- 我能画出的调用链：待填写
- 尚不清楚的点：待填写
- 下次源码入口：`linux/fs/char_dev.c` 中 `chrdev_open()`、`cdev_add()`
