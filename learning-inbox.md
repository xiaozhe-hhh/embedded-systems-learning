# 学习问题收件箱

这里按提问时间记录对话中的知识问题。原始问答先集中保存在本文件，定期整理后再分配到对应知识笔记；已归档记录仍保留，便于回看学习轨迹。

## 已归档（2026-11-03）

### 2026-11-02 19:24（Asia/Shanghai）— 二分查找的中点防溢出写法

**问题**：代码里为什么把中点写成 `left + (right - left) / 2`，而不写 `(left + right) / 2`？

**回答摘要**：当 `left`、`right` 是较大的正整数时，`left + right` 可能先超过整数类型上限，即使最终中点本身可表示也会出错。对满足 `0 <= left <= right` 的数组下标，先算区间差再加回 `left`，数学结果仍是向下取整的中点，同时避免两个大下标直接相加。若处理任意有符号整数范围，`right - left` 本身也可能溢出；C++20 可考虑 `<numeric>` 中的 `std::midpoint`。

**归档状态**：已归档（2026-11-03），目标：[《代码随想录》二分查找](code-thought-record/二分查找.md)
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

**归档状态**：已归档（2026-11-03），目标：[《代码随想录》二分查找](code-thought-record/二分查找.md)
**建议归档主题**：优先归档到《代码随想录》笔记 `code-thought-record/二分查找.md` 的 LeetCode 704 条目；通用数据结构笔记可链接该专题。

### 2026-11-02 23:44（Asia/Shanghai）— LeetCode 27 移除元素的数组搬移边界

**问题**：在《代码随想录》LeetCode 27 暴力解法中，第二层循环原写法从 `j = i + 1` 开始并执行 `nums[j - 1] = nums[j]`。如果保持外层代码不变，改成从 `j = i` 开始并执行 `nums[j] = nums[j + 1]`，循环条件仍写 `j < size`，是否正确？

**结论**：不正确。原数组逻辑长度为 `size` 时，有效下标是 `0` 到 `size - 1`。当 `j == size - 1` 时，右侧表达式会读取 `nums[size]`，越过 vector 的有效元素范围，属于未定义行为。即使 vector 的 capacity 更大，`nums[size]` 仍不是有效元素下标。

若改成从当前位置向左覆盖，循环上界也必须相应收紧：

```cpp
for (int j = i; j < size - 1; ++j) {
    nums[j] = nums[j + 1];
}
```

完整上下文示例：

```cpp
int removeElement(vector<int>& nums, int val) {
    int size = static_cast<int>(nums.size());

    for (int i = 0; i < size; ++i) {
        if (nums[i] == val) {
            for (int j = i; j < size - 1; ++j) {
                nums[j] = nums[j + 1];
            }
            --i;     // 当前 i 位置被右侧元素覆盖，下一轮要重新检查
            --size;  // 逻辑长度减一；末尾旧值不再属于有效结果
        }
    }
    return size;
}
```

这与原写法 `for (j = i + 1; j < size; ++j) nums[j - 1] = nums[j];` 等价：两者都是把后续元素整体左移一位。每次删除后 `i--` 配合外层 `for` 的 `i++`，使同一下标重新检查；`size--` 缩短有效区间。该暴力做法最坏时间复杂度为 `O(n^2)`，额外空间复杂度为 `O(1)`。

**示例**：`nums = [0,1,2,2,3,0,4,2]`、`val = 2`。在 `i = 2` 删除一个 `2` 时，后续有效元素左移，`size` 从 8 减到 7；下标 2 需要重新检查，因为那里又被下一个元素覆盖。

**归档状态**：已归档（2026-11-03），目标：[《代码随想录》数组](code-thought-record/数组.md)
**建议归档主题**：《代码随想录》数组 / LeetCode 27 移除元素，建议归入 `code-thought-record/数组.md`。

### 2026-11-02 23:51（Asia/Shanghai）— LeetCode 27 快慢指针写法

**问题**：在《代码随想录》的双指针版本中，`if (val != nums[fastIndex]) nums[slowIndex++] = nums[fastIndex];` 是不是表示“当前值不等于要删除的值时，把当前下标的后一个元素赋成当前元素”？

**代码**：

```cpp
int removeElement(vector<int>& nums, int val) {
    int slowIndex = 0;
    for (int fastIndex = 0; fastIndex < nums.size(); ++fastIndex) {
        if (val != nums[fastIndex]) {
            nums[slowIndex++] = nums[fastIndex];
        }
    }
    return slowIndex;
}
```

**解释**：不是“当前下标的后一个元素”。`fastIndex` 是读指针，逐个检查原数组元素；`slowIndex` 是写指针，指向下一个保留元素应该写入的位置。发现 `nums[fastIndex] != val` 时，把当前保留值写到 `nums[slowIndex]`，然后 `slowIndex` 加一。发现要删除的值时跳过它，`slowIndex` 不变。

`nums[slowIndex++] = nums[fastIndex];` 可理解为下面两步：

```cpp
nums[slowIndex] = nums[fastIndex];
++slowIndex;
```

例如 `nums = [0,1,2,2,3,0,4,2]`、`val = 2`：

| `fastIndex` | 读到的值 | 操作 | `slowIndex` 变化 |
|---:|---:|---|---:|
| 0 | 0 | 写到 `nums[0]` | 0 → 1 |
| 1 | 1 | 写到 `nums[1]` | 1 → 2 |
| 2 | 2 | 跳过 | 保持 2 |
| 3 | 2 | 跳过 | 保持 2 |
| 4 | 3 | 写到 `nums[2]` | 2 → 3 |
| 5 | 0 | 写到 `nums[3]` | 3 → 4 |
| 6 | 4 | 写到 `nums[4]` | 4 → 5 |
| 7 | 2 | 跳过 | 保持 5 |

循环结束后返回 `5`；有效结果是前 5 个元素 `[0,1,3,0,4]`。`slowIndex` 表示新长度，数组尾部的旧值不属于结果，不要求清除。该快慢指针解法时间复杂度 `O(n)`、额外空间复杂度 `O(1)`，保持其余元素的相对顺序。

**归档状态**：已归档（2026-11-03），目标：[《代码随想录》数组](code-thought-record/数组.md)
**建议归档主题**：《代码随想录》数组 / LeetCode 27 移除元素，归入 `code-thought-record/数组.md`；与前面暴力搬移写法对照。
