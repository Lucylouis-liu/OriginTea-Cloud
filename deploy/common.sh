#!/bin/bash

# common.sh - 通用辅助函数
# 用于处理Windows Git Bash环境下的路径转换

# 将Git Bash路径转换为Docker可用的Windows路径格式
# 输入: /e/05chayuan/OriginTea-Cloud
# 输出: E:/05chayuan/OriginTea-Cloud
convert_path_for_docker() {
    local path="$1"
    
    # 检测是否在Windows环境（Git Bash/MSYS）
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
        # Windows环境，转换路径格式
        # 方法1: 使用cygpath（如果可用，最可靠）
        if command -v cygpath &> /dev/null; then
            cygpath -w "$path" | sed 's|\\|/|g'
        # 方法2: 手动转换 /e/path -> E:/path
        elif [[ "$path" =~ ^/([a-z])/(.*) ]]; then
            local drive_letter=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
            local path_part="${BASH_REMATCH[2]}"
            echo "${drive_letter}:/${path_part}"
        else
            # 如果路径格式不符合预期，返回原路径
            echo "$path"
        fi
    else
        # Linux/Mac环境，直接返回原路径
        echo "$path"
    fi
}

# 检测是否在Windows环境
is_windows() {
    [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]
}

