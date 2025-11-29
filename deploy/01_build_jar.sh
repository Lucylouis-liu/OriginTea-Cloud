#!/bin/bash

# 01_build_jar.sh - 编译Java项目并复制JAR包到Docker目录
# 使用Docker容器环境编译项目，避免本地环境依赖
# 
# 用法:
#   ./01_build_jar.sh              # 编译所有服务
#   ./01_build_jar.sh gateway      # 只编译网关服务
#   ./01_build_jar.sh gateway auth # 只编译网关和认证服务
#   ./01_build_jar.sh all          # 编译所有服务（等同于不传参数）

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Windows Git Bash路径转换：Docker需要Windows格式路径
# 检测是否在Windows环境（Git Bash/MSYS）
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    # Windows环境，转换路径格式
    # 方法1: 使用pwd -W（Git Bash特有，最可靠）
    cd "$PROJECT_ROOT"
    if pwd -W &> /dev/null; then
        PROJECT_ROOT_DOCKER=$(pwd -W | sed 's|\\|/|g')
    # 方法2: 使用cygpath（如果可用）
    elif command -v cygpath &> /dev/null 2>&1; then
        PROJECT_ROOT_DOCKER=$(cygpath -w "$PROJECT_ROOT" | sed 's|\\|/|g')
    # 方法3: 手动转换 /e/path -> E:/path
    elif [[ "$PROJECT_ROOT" =~ ^/([a-z])/(.*) ]]; then
        DRIVE_LETTER=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
        PATH_PART="${BASH_REMATCH[2]}"
        PROJECT_ROOT_DOCKER="${DRIVE_LETTER}:/${PATH_PART}"
    else
        # 如果都不行，使用原路径
        PROJECT_ROOT_DOCKER="$PROJECT_ROOT"
    fi
    cd "$SCRIPT_DIR"
    echo -e "${YELLOW}检测到Windows环境，路径已转换: $PROJECT_ROOT_DOCKER${NC}"
else
    # Linux/Mac环境，直接使用
    PROJECT_ROOT_DOCKER="$PROJECT_ROOT"
fi

DOCKER_DIR="$PROJECT_ROOT/docker_dev"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始编译Java项目...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查项目根目录
if [ ! -f "$PROJECT_ROOT/pom.xml" ]; then
    echo -e "${RED}错误: 未找到项目根目录的pom.xml文件${NC}"
    exit 1
fi

# 定义需要编译的模块及其JAR包路径
# 格式: ["模块名"]="Maven模块路径:JAR输出路径"
declare -A JAR_MODULES=(
    ["gateway"]="ruoyi-gateway/target/ruoyi-gateway.jar:docker_dev/ruoyi/gateway/jar/"
    ["auth"]="ruoyi-auth/target/ruoyi-auth.jar:docker_dev/ruoyi/auth/jar/"
    ["system"]="ruoyi-modules/ruoyi-system/target/ruoyi-modules-system.jar:docker_dev/ruoyi/modules/system/jar/"
    ["gen"]="ruoyi-modules/ruoyi-gen/target/ruoyi-modules-gen.jar:docker_dev/ruoyi/modules/gen/jar/"
    ["job"]="ruoyi-modules/ruoyi-job/target/ruoyi-modules-job.jar:docker_dev/ruoyi/modules/job/jar/"
    ["file"]="ruoyi-modules/ruoyi-file/target/ruoyi-modules-file.jar:docker_dev/ruoyi/modules/file/jar/"
    ["monitor"]="ruoyi-visual/ruoyi-monitor/target/ruoyi-visual-monitor.jar:docker_dev/ruoyi/visual/monitor/jar/"
)

# 定义模块名到Maven模块路径的映射
declare -A MODULE_TO_MAVEN=(
    ["gateway"]="ruoyi-gateway"
    ["auth"]="ruoyi-auth"
    ["system"]="ruoyi-modules/ruoyi-system"
    ["gen"]="ruoyi-modules/ruoyi-gen"
    ["job"]="ruoyi-modules/ruoyi-job"
    ["file"]="ruoyi-modules/ruoyi-file"
    ["monitor"]="ruoyi-visual/ruoyi-monitor"
)

# 解析命令行参数
SELECTED_MODULES=()
if [ $# -eq 0 ]; then
    # 没有参数，编译所有模块
    SELECTED_MODULES=("${!JAR_MODULES[@]}")
    echo -e "${BLUE}未指定模块，将编译所有服务${NC}"
else
    # 有参数，只编译指定的模块
    for arg in "$@"; do
        if [ "$arg" == "all" ]; then
            SELECTED_MODULES=("${!JAR_MODULES[@]}")
            break
        elif [[ -n "${JAR_MODULES[$arg]}" ]]; then
            SELECTED_MODULES+=("$arg")
        else
            echo -e "${RED}错误: 未知的模块名 '$arg'${NC}"
            echo -e "${YELLOW}可用的模块: ${!JAR_MODULES[*]}${NC}"
            exit 1
        fi
    done
fi

if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
    echo -e "${RED}错误: 没有有效的模块需要编译${NC}"
    exit 1
fi

echo -e "${BLUE}将编译以下模块: ${SELECTED_MODULES[*]}${NC}"

# 创建临时容器名称
CONTAINER_NAME="ruoyi-build-$(date +%s)"

echo -e "${YELLOW}使用Docker容器编译项目...${NC}"

# 构建Maven编译命令
MAVEN_CMD="mvn clean package -Dmaven.test.skip=true"

# 如果只编译部分模块，使用 -pl 参数指定模块
if [ ${#SELECTED_MODULES[@]} -lt ${#JAR_MODULES[@]} ]; then
    # 构建 -pl 参数
    PL_ARGS=()
    for module in "${SELECTED_MODULES[@]}"; do
        PL_ARGS+=("${MODULE_TO_MAVEN[$module]}")
    done
    MAVEN_CMD="mvn clean package -Dmaven.test.skip=true -pl $(IFS=,; echo "${PL_ARGS[*]}") -am"
    echo -e "${BLUE}Maven命令: $MAVEN_CMD${NC}"
fi

# 使用Maven官方镜像进行编译
# 在Windows上使用转换后的路径，确保使用正确的格式
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    # Windows环境：确保路径格式正确
    # 移除可能的尾部斜杠
    PROJECT_ROOT_DOCKER=$(echo "$PROJECT_ROOT_DOCKER" | sed 's|/$||')
    echo -e "${YELLOW}使用Docker卷挂载路径: $PROJECT_ROOT_DOCKER${NC}"
    
    # 在Windows上，Docker Desktop需要Windows格式路径（E:/path格式）
    # 使用 sh -c 在容器内切换目录，避免 -w 参数在Windows上的问题
    docker run --rm \
        --name "$CONTAINER_NAME" \
        -v "${PROJECT_ROOT_DOCKER}:/workspace" \
        maven:3.9-eclipse-temurin-17 \
        sh -c "cd /workspace && $MAVEN_CMD"
else
    # Linux/Mac环境
    docker run --rm \
        --name "$CONTAINER_NAME" \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        maven:3.9-eclipse-temurin-17 \
        sh -c "$MAVEN_CMD"
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}错误: Maven编译失败${NC}"
    exit 1
fi

echo -e "${GREEN}编译完成，开始复制JAR包...${NC}"

# 复制JAR包到对应的Docker目录（只复制选中的模块）
for module in "${SELECTED_MODULES[@]}"; do
    IFS=':' read -r source_path target_path <<< "${JAR_MODULES[$module]}"
    source_file="$PROJECT_ROOT/$source_path"
    target_dir="$PROJECT_ROOT/$target_path"
    
    if [ ! -f "$source_file" ]; then
        echo -e "${RED}警告: 未找到JAR文件 $source_file${NC}"
        continue
    fi
    
    # 创建目标目录
    mkdir -p "$target_dir"
    
    # 复制JAR文件
    cp "$source_file" "$target_dir"
    
    # 获取JAR文件名
    jar_name=$(basename "$source_file")
    
    echo -e "${GREEN}✓ 已复制 $module: $jar_name${NC}"
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}所有JAR包已复制完成！${NC}"
echo -e "${GREEN}========================================${NC}"

