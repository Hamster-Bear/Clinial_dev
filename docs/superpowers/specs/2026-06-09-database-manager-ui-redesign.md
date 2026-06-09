# 数据空间管理 UI/UX 重设计方案

## 1. 背景与问题

### 当前布局

`database_manager.R` 使用 `tabBox` 三页签布局：

```
┌─────────────────────────────────────────────────────────────────┐
│  数据空间管理                                                      │
│  "在这里整理数据空间、目录、数据集与结构总览"                             │
├─────────────────────────────────────────────────────────────────┤
│  [当前数据空间: xxx] [当前目录: xxx] [当前数据集: xxx] [权限: xxx]        │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                        │
│  │空间与目录  │ │上传与导入  │ │结构总览    │  ← tabBox 三页签          │
│  ├──────────┴─┴──────────┴─┴──────────┤                        │
│  │                                     │                        │
│  │  (当前页签内容)                       │                        │
│  │                                     │                        │
│  └─────────────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

### 用户工作流分析

实际使用场景中，用户的典型操作流程是：

```
选择数据空间 → 浏览目录结构 → 在目标目录上传数据 → 确认结构正确
      ↑                                                    |
      └────────────── 可能切换到另一个目录继续操作 ────────────┘
```

这个流程的核心问题是：**三个功能页面作为页签切换打断了连续工作流**。

具体痛点：
1. 在"空间与目录"选好目录后，需要切换到"上传与导入"才能上传数据
2. 上传完成后需要切换到"结构总览"才能确认结果
3. 每次切换页签都会丢失当前的操作上下文感
4. "结构总览"被隐藏在独立页签中，无法在管理操作时随时参考

## 2. 重设计方案：左侧导航树 + 右侧操作面板

### 设计理念

将"文件资源管理器"的交互模式引入数据空间管理：
- **左侧**：始终可见的导航树，展示完整的空间-目录-数据集层级结构
- **右侧**：与当前选中节点相关的操作面板

### 新布局示意

```
┌─────────────────────────────────────────────────────────────────────┐
│  数据空间管理                                                         │
│  "在这里浏览数据空间结构，管理目录与数据集"                                 │
├─────────────────────────────────────────────────────────────────────┤
│  [当前数据空间: xxx] [当前目录: xxx] [当前数据集: xxx] [权限: xxx]           │
├──────────────────────┬──────────────────────────────────────────────┤
│                      │                                              │
│  数据空间导航          │  操作面板                                     │
│  (width = 3)         │  (width = 9)                                │
│                      │                                              │
│  ┌────────────────┐  │  ┌────────────────────────────────────────┐  │
│  │ 选择数据空间 ▼   │  │  快速统计                                │  │
│  ├────────────────┤  │  ┌──────┐┌──────┐┌──────┐┌──────────┐   │  │
│  │ ▼ 空间A         │  │  │空间数 ││目录数 ││数据集数││累计数据行数│   │  │
│  │   📁 根目录      │  │  └──────┘└──────┘└──────┘└──────────┘   │  │
│  │     📊 数据集1   │  ├────────────────────────────────────────┤  │
│  │     📊 数据集2   │  │                                        │  │
│  │   📂 目录B       │  │  资源管理                               │  │
│  │     📊 数据集3   │  │  ┌──────────────────────────────────┐  │  │
│  │ ▶ 空间B         │  │  │ 新建目录名称: [________] [创建目录] │  │  │
│  │ ▶ 空间C         │  │  │ [删除当前目录] [删除当前数据集]      │  │  │
│  ├────────────────┤  │  └──────────────────────────────────┘  │  │
│  │ [+ 新建数据空间] │  ├────────────────────────────────────────┤  │  │
│  │ [🗑 删除数据空间] │  │                                        │  │  │
│  └────────────────┘  │  上传与导入                               │  │
│                      │  ┌──────────────────────────────────┐   │  │
│                      │  │ 单文件上传: [选择文件] [上传并保存]   │   │  │
│                      │  │ 批量上传:   [选择文件] [批量保存]    │   │  │
│                      │  │ CSV编码: [UTF-8 ▼]                │   │  │
│                      │  └──────────────────────────────────┘   │  │
│                      │                                        │  │
│                      └────────────────────────────────────────┘  │
└──────────────────────┴──────────────────────────────────────────────┘
```

### 2.1 左侧导航树设计

**组件结构：**

```r
div(class = "db-nav-panel",
  # 1. 数据空间选择器
  selectInput(ns("workspace_select"), "选择数据空间", choices = ...),

  # 2. 层级树（HTML <details>/<summary>）
  div(class = "db-nav-tree",
    tags$details(open = "open",
      tags$summary(icon("database"), " 空间A [目录:3 | 数据集:6]"),
      tags$ul(
        tags$li(
          tags$details(open = "open",
            tags$summary(icon("folder"), " 根目录 [2]"),
            tags$ul(
              tags$li(tags$a(class = "db-nav-item", "data-type" = "dataset", "data-id" = "ds_1",
                icon("table"), " adsl (300x15)")),
              tags$li(tags$a(class = "db-nav-item", "data-type" = "dataset", "data-id" = "ds_2",
                icon("table"), " adae (1200x20)"))
            )
          )
        ),
        tags$li(
          tags$details(
            tags$summary(icon("folder-open"), " 安全性数据 [3]"),
            tags$ul(...)
          )
        )
      )
    )
  ),

  # 3. 快捷操作按钮
  div(class = "db-nav-actions",
    actionButton(ns("create_workspace"), "新建空间", class = "btn-primary btn-sm"),
    actionButton(ns("delete_workspace"), "删除空间", class = "btn-danger btn-sm")
  )
)
```

**交互行为：**

| 操作 | 行为 |
|------|------|
| 点击空间节点 | 右侧面板切换到该空间上下文 |
| 点击目录节点 | 右侧面板切换到该目录上下文，高亮该节点 |
| 点击数据集节点 | 右侧面板切换到该数据集上下文，高亮该节点 |
| 切换 `selectInput` | 同步展开树中对应空间节点 |

**选中态高亮：**

```css
.db-nav-item.active {
  background: #e8f0fe;
  border-left: 3px solid #4285f4;
  font-weight: 600;
}
```

### 2.2 右侧操作面板设计

操作面板分为三个区块，从上到下依次排列：

**区块 A：快速统计卡（始终可见）**

复用现有 `app_stat_card` 组件，展示：
- 数据空间数
- 文件夹数
- 数据集数
- 累计数据行数

**区块 B：资源管理（根据选中节点动态变化）**

| 选中类型 | 显示内容 |
|---------|---------|
| 空间节点 | 新建目录表单 + 删除空间按钮 |
| 目录节点 | 新建目录表单 + 删除目录按钮 |
| 数据集节点 | 数据集信息 + 删除数据集按钮 + 显示名称覆盖 |

**区块 C：上传与导入（始终可见）**

- 单文件上传区
- 批量上传区
- 服务器目录导入区（管理员可见）

### 2.3 与现有组件的关系

| 现有组件 | 新位置 | 是否修改 |
|---------|--------|---------|
| `db_context_summary` | 顶部保留 | 不变 |
| `db_overview_cards` | 右侧操作面板顶部 | 不变 |
| `db_structure_tree` | 左侧导航树（改造） | 重写为可交互导航树 |
| `tabBox` 三页签 | 移除 | 删除 |
| 级联 `selectInput` | 左侧导航面板 | workspace_select 保留，folder/dataset 改为树节点点击 |

## 3. 实现要点

### 3.1 UI 层改造

**移除：**
- `tabBox(id = "db_workspace_tabs", ...)` 及其三个 `tabPanel`

**新增：**
- 左侧 `column(width = 3, ...)` 导航面板
- 右侧 `column(width = 9, ...)` 操作面板
- `uiOutput(ns("nav_tree"))` 用于渲染可交互导航树
- `uiOutput(ns("action_panel"))` 用于渲染动态操作面板

### 3.2 Server 层改造

**新增 reactive values：**

```r
nav_context <- reactiveValues(
  node_type = "workspace",  # "workspace" | "folder" | "dataset"
  node_id = ""
)
```

**新增 observeEvent：**

```r
observeEvent(input$nav_click, {
  # 解析点击事件，更新 nav_context
  # input$nav_click 由 JS 事件传递：{type: "folder", id: "fd_xxx"}
})
```

**改造 db_structure_tree → nav_tree：**

- 树节点添加 `onclick` 事件，通过 `Shiny.setInputValue` 传递点击信息
- 添加 `.active` 高亮样式
- 保留现有树渲染逻辑，增加交互层

**改造操作面板渲染：**

- 将原"空间与目录"tab 内容拆分为动态操作面板
- 根据 `nav_context$node_type` 渲染不同操作表单

### 3.3 保留的 Server 逻辑

以下逻辑保持不变，仅调整触发源：
- `observeEvent(input$create_workspace, ...)`
- `observeEvent(input$delete_workspace, ...)`
- `observeEvent(input$create_folder, ...)`
- `observeEvent(input$delete_folder, ...)`
- `observeEvent(input$save_dataset, ...)`
- `observeEvent(input$save_batch_datasets, ...)`
- `observeEvent(input$import_workspace_path, ...)`
- `refresh_workspace_choices()`
- `refresh_folder_choices()`
- `refresh_dataset_choices()`

## 4. 测试影响

| 测试文件 | 影响 |
|---------|------|
| `test_database_manager_layout_guard.R` | 需更新：移除 tabBox/tabPanel 断言，新增导航树断言 |

## 5. 文档更新

| 文档 | 更新内容 |
|------|---------|
| `PROJECT_GUIDE.md` | 更新数据库管理模块的 UI 描述 |
| `CODE_STYLE.md` | 无需更新 |

## 6. 实施步骤

1. **重构 UI 布局**：移除 tabBox，改为左右分栏布局
2. **改造导航树**：将 db_structure_tree 改造为可交互导航树
3. **改造操作面板**：将原 tab 内容整合到右侧面板
4. **新增点击交互**：JS 事件 + observeEvent 处理节点选中
5. **更新测试**：调整 layout guard 断言
6. **验证全链路**：空间创建/删除、目录创建/删除、数据集上传/删除、结构总览

## 7. 已修复的 Bug

### 结构总览报错 'length = 6' in coercion to 'logical(1)'

**根因：** `database_manager.R` 第 736 行定义的 `safe_get()` 函数对向量使用了标量逻辑运算符 `||`。

```r
# 问题代码
safe_get <- function(x, default = "") if(is.na(x) || is.null(x)) default else x
# 第 751 行调用
ds_folder <- ds_current[safe_get(ds_current$folder_id) == fd_id, , drop = FALSE]
```

`ds_current$folder_id` 是一个长度为 N 的向量，`is.na()` 返回长度为 N 的逻辑向量，`||` 要求标量逻辑值，R 报错 "length = N in coercion to logical(1)"。当工作区有 6 个数据集时，N=6，触发报错。

**修复：** 移除 `safe_get()`，改用向量化比较：

```r
ds_folder <- ds_current[!is.na(ds_current$folder_id) & ds_current$folder_id == fd_id, , drop = FALSE]
```

`&` 是向量化逻辑与，逐元素比较，不会触发标量强制转换错误。

### 重复的 workspace_select 监听

**根因：** `database_manager.R` 中存在两个 `observeEvent(input$workspace_select, ...)`，分别在第 634 行和第 832 行。

```r
# 第 634 行 — 完整版（带 req + 保留当前 folder/dataset 选择）
observeEvent(input$workspace_select, {
  req(has_database_access())
  selected_workspace <- input$workspace_select %||% ""
  selected_folder <- refresh_folder_choices(selected_workspace, isolate(input$folder_select %||% root_folder_token))
  refresh_dataset_choices(selected_workspace, selected_folder, isolate(input$dataset_select %||% ""))
}, ignoreInit = TRUE)

# 第 832 行 — 简化版（无 req，重置 folder 到根目录，ignoreNULL = FALSE）
observeEvent(input$workspace_select, {
  workspace_id <- input$workspace_select
  refresh_folder_choices(workspace_id)
  refresh_dataset_choices(workspace_id, root_folder_token)
}, ignoreNULL = FALSE)
```

**问题：**
- 两个监听重复触发 `refresh_folder_choices` 和 `refresh_dataset_choices`，造成双次数据库查询
- 行为不一致：第 634 行保留当前 folder 选择，第 832 行重置到根目录
- 第 832 行缺少 `req(has_database_access())` 检查，未登录时也会触发

**修复：** 删除第 832 行的重复监听，保留第 634 行的完整版。
