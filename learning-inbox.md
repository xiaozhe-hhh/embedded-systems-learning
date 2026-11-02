# 学习问题收件箱

这里按提问时间记录对话中的知识问题。原始问答先集中保存在本文件，定期整理后再分配到对应知识笔记；已归档记录仍保留，便于回看学习轨迹。

## 待归档

### 2026-11-02 19:24（Asia/Shanghai）— 二分查找的中点防溢出写法

**问题**：代码里为什么把中点写成 `left + (right - left) / 2`，而不写 `(left + right) / 2`？

**回答摘要**：当 `left`、`right` 是较大的正整数时，`left + right` 可能先超过整数类型上限，即使最终中点本身可表示也会出错。对满足 `0 <= left <= right` 的数组下标，先算区间差再加回 `left`，数学结果仍是向下取整的中点，同时避免两个大下标直接相加。若处理任意有符号整数范围，`right - left` 本身也可能溢出；C++20 可考虑 `<numeric>` 中的 `std::midpoint`。

**归档状态**：待归档
**建议归档主题**：优先归档到《代码随想录》笔记 `code-thought-record/二分查找.md` 的 LeetCode 704 条目；通用数据结构笔记可链接该专题。

### 2026-11-02 21:14（Asia/Shanghai）— 二分查找的两种区间写法

**问题/学习请求**：记录二分查找的两种边界写法：左闭右闭 `[left, right]`，以及左闭右开 `[left, right)`。

**补充时间**：2026-11-02 21:16（Asia/Shanghai）

**代码记录**：以下两个函数都假设 `nums` 按升序排列、`n >= 0`，找到时返回下标，未找到返回 `-1`。中点使用 `left + (right - left) / 2`，避免直接计算 `left + right`。

左闭右闭区间 `[left, right]`：

```cpp
int binary_search_closed(const int* nums, int n, int target) {
    int left = 0;
    int right = n - 1;

    while (left <= right) {
        int middle = left + (right - left) / 2;

        if (nums[middle] > target) {
            right = middle - 1;
        } else if (nums[middle] < target) {
            left = middle + 1;
        } else {
            return middle;
        }
    }
    return -1;
}
```

- 候选下标始终在 `[left, right]` 中，所以循环条件是 `left <= right`。
- 初始 `right = n - 1`；排除 `middle` 后用 `right = middle - 1` 或 `left = middle + 1`。
- `n == 0` 时 `right == -1`，循环不执行，返回 `-1`。

左闭右开区间 `[left, right)`：

```cpp
int binary_search_half_open(const int* nums, int n, int target) {
    int left = 0;
    int right = n;

    while (left < right) {
        int middle = left + (right - left) / 2;

        if (nums[middle] > target) {
            right = middle;
        } else if (nums[middle] < target) {
            left = middle + 1;
        } else {
            return middle;
        }
    }
    return -1;
}
```

- 候选下标始终在 `[left, right)` 中，`right` 是排除在区间外的边界，因此循环条件是 `left < right`。
- 初始 `right = n`；当中点值大于目标时，`middle` 及其右侧已排除，更新为 `right = middle`，不能减一。
- 当中点值小于目标时，更新为 `left = middle + 1`。循环结束时区间为空，未找到则返回 `-1`。
- `n == 0` 时 `left == right == 0`，循环不执行，返回 `-1`。

例如在升序数组 `[1, 2, 3, 4, 7, 9, 10]` 中查找 `2`，两种写法都会返回下标 `1`。两者时间复杂度均为 `O(log n)`，额外空间复杂度为 `O(1)`。

**归档状态**：待归档，尚未展开讲解
**建议归档主题**：优先归档到《代码随想录》笔记 `code-thought-record/二分查找.md` 的 LeetCode 704 条目；通用数据结构笔记可链接该专题。
