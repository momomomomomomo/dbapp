#!/bin/bash

# 日志文件路径
LOG_FILE="Download.log"

# 记录日志函数
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S"): $1" | sudo tee -a $LOG_FILE
}

# 确认操作函数
confirm_action() {
    local prompt="$1"
    while true; do
        read -p "$prompt (y/n): " answer
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) log "请输入 'y' 或 'n'。" ;;
        esac
    done
}

# 获取当前宿主机的真实 IP
get_host_ip() {
    local ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    echo "$ip"
}

# 获取当前登录用户的密码（注：这种方式不安全，仅为示例）
get_user_password() {
    read -s -p "请输入当前登录用户的密码: " password
    echo "$password"
}

# 安装步骤
function install_packages() {
    log "是否进行安装步骤？(y/n)"
    read answer
    if [ "$answer" = "y" ]; then
        # 以AiLPHA为关键字检索压缩包
        package_files=($(ls | grep 'AiLPHA'))
        if [ ${#package_files[@]} -eq 0 ]; then
            log "未找到以AiLPHA为关键字的压缩包，跳过安装步骤。"
            return
        fi

        if [ ${#package_files[@]} -gt 1 ]; then
            log "找到多个安装文件，请选择要安装的文件："
            for i in "${!package_files[@]}"; do
                echo "$((i + 1)): ${package_files[$i]}"
            done
            log "请输入编号进行安装，注：大数据安装文件为common"
            while true; do
                read -p "请输入编号: " choice
                if [[ $choice =~ ^[0-9]+$ ]] && [ $choice -ge 1 ] && [ $choice -le ${#package_files[@]} ]; then
                    package=${package_files[$((choice - 1))]}
                    break
                else
                    log "输入无效，请输入有效的编号。"
                fi
            done
        else
            package=${package_files[0]}
        fi

        log "选择的压缩包: $package"
        # 解压安装包
        if sudo tar -zPpxvf "$package"; then
            log "压缩包 $package 解压成功。"
            cd init

            # 获取当前宿主机的真实 IP
            host_ip=$(get_host_ip)
            if [ -z "$host_ip" ]; then
                log "无法获取当前宿主机的真实 IP，跳过后续步骤。"
                return
            fi
            log "当前宿主机的真实 IP 是: $host_ip"

            # 修改install.json文件前的确认
            if confirm_action "是否要修改 install.json 文件，将 hosts 内的 ip 改成当前宿主机真实 IP，Model 修改为 single？"; then
                install_json_path="conf/install.json"
                if [ -f "$install_json_path" ]; then
                    # 修改 hosts 字段的 IP
                    sudo sed -i -E "/\"hosts\": \[/{N; s/\"[0-9.]+\"/\"$host_ip\"/}" "$install_json_path"
                    # 修改 product 下的 Model
                    sudo sed -i "s/\"Model\": \"[^\"]*\"/\"Model\": \"single\"/" "$install_json_path"
                    log "install.json 文件修改成功。"
                else
                    log "未找到 $install_json_path 文件，跳过修改步骤。"
                fi
            else
                log "用户选择不修改 install.json 文件。"
            fi

            # 修改passwd.txt文件前的确认
            if confirm_action "是否要修改 passwd.txt 文件，将其内容设置为当前登录用户的密码？"; then
                # 获取当前登录用户的密码
                user_password=$(get_user_password)
                passwd_txt_path="conf/passwd.txt"
                if [ -f "$passwd_txt_path" ]; then
                    echo "$user_password" | sudo tee "$passwd_txt_path" > /dev/null
                    log "passwd.txt 文件修改成功。"
                else
                    log "未找到 $passwd_txt_path 文件，跳过修改步骤。"
                fi
            else
                log "用户选择不修改 passwd.txt 文件。"
            fi

            # 检查并进入 /home/init 目录执行安装
            target_dir="/home/init"
            real_path=$(readlink -f "$target_dir")
            if [ -d "$real_path" ]; then
                cd "$real_path" || {
                    log "无法进入 $target_dir 目录，跳过安装步骤。"
                    return
                }
                log "开始执行安装脚本，使用 IP: $host_ip"
                # 执行安装命令并将输出追加到日志文件，同时显示在终端
                install_log="./intall.log"
                sudo sh main.sh "$host_ip" | tee -a "$install_log"
                if [ $? -eq 0 ]; then
                    log "安装步骤完成。"
                else
                    log "安装步骤执行失败。"
                fi
            else
                log "$target_dir 目录不存在，跳过安装步骤。"
            fi
        else
            log "压缩包 $package 解压失败。"
        fi
    else
        log "跳过安装步骤。"
    fi
}

# 主流程
install_packages

log "安装步骤完成。"
