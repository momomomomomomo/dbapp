#!/bin/bash

# 日志文件路径
LOG_FILE="Download.log"

# 记录日志函数
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S"): $1" | tee -a $LOG_FILE
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


# 定义欢迎信息
message="欢迎使用AILPHA一键化安装脚本from付江瑞&赵佳  北京技术交付团队"

# 计算信息的长度
message_length=${#message}

# 计算框的宽度，这里为信息长度加上4个额外的空格
box_width=$((message_length + 4))

# 打印顶部边框
printf "+%0.s-" $(seq 1 $box_width)
printf "+\n"

# 打印带有欢迎信息的行
printf "|  %s  |\n" "$message"

# 打印底部边框
printf "+%0.s-" $(seq 1 $box_width)
printf "+\n"
    
# 检查服务器配置
function check_server_config() {
    log "欢迎使用AILPHA一键化安装脚本from北京技术交付团队&付江瑞+赵佳"
    log "即将检测服务器配置，是否检测？(y/n)"
    read answer
    if [ "$answer" = "y" ]; then
        log "### 检查服务器配置并回显 ###"
        # 检查硬件配置
        cpu_info=$(lscpu | grep "CPU(s):")
        mem_info=$(free -h | grep "Mem:")
        disk_info=$(df -h | grep "/dev")
        os_info=$(cat /etc/redhat-release)
        kernel_info=$(uname -r)

        if [ -n "$cpu_info" ] && [ -n "$mem_info" ] && [ -n "$disk_info" ] && [ -n "$os_info" ] && [ -n "$kernel_info" ]; then
            log "CPU信息：$cpu_info"
            log "内存信息：$mem_info"
            log "磁盘信息：$disk_info"
            log "操作系统版本：$os_info"
            log "内核版本：$kernel_info"
            log "服务器配置检测成功。"
        else
            log "服务器配置检测失败。"
        fi
    else
        log "跳过服务器配置检测。"
    fi
}

# 检测网关连通性
function check_gateway() {
    local gateway=$1
    if ping -c 3 -W 1 $gateway &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 验证IP地址格式
function validate_ip() {
    local ip=$1
    local pattern='^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$'
    if [[ $ip =~ $pattern ]]; then
        return 0
    else
        return 1
    fi
}

# 更改为静态地址
function set_static_ip() {
    log "目前要更改为静态IP，是否更改？(y/n)"
    read answer
    if [ "$answer" = "y" ]; then
        log "请先确认配置ip不属于172.19.0.0/16，否则请重新规划ip地址"
        # 获取可用网络接口
        interfaces=$(ip link show | grep -E '^[0-9]+:' | grep -v 'lo:' | awk -F': ' '{print $2}')
        if [ -z "$interfaces" ]; then
            log "未找到可用的网络接口，跳过静态IP设置。"
            return
        fi
        log "可用的网络接口有："
        i=1
        for interface in $interfaces; do
            current_ip=$(ip addr show $interface | grep -w inet | awk '{print $2}' | cut -d/ -f1)
            if [ -n "$current_ip" ]; then
                log "$i. $interface (当前IP: $current_ip)"
            else
                log "$i. $interface (无IP地址)"
            fi
            ((i++))
        done

        while true; do
            log "请输入要配置的网络接口对应的序号（输入 'q' 退出）："
            read interface_num
            if [ "$interface_num" = "q" ]; then
                log "用户选择退出静态IP设置。"
                return
            fi
            if ! [[ "$interface_num" =~ ^[0-9]+$ ]]; then
                log "输入无效，请输入有效的序号。"
                continue
            fi
            selected_index=$((interface_num - 1))
            selected_interfaces=($interfaces)
            if [ $selected_index -lt 0 ] || [ $selected_index -ge ${#selected_interfaces[@]} ]; then
                log "输入的序号超出范围，请重新输入。"
            else
                interface=${selected_interfaces[$selected_index]}
                break
            fi
        done

        local static_ip
        while true; do
            # 清理输入缓冲区
            while read -t 0; do :; done < /dev/stdin
            log "请输入静态IP地址（输入 'q' 退出）："
            read static_ip
            if [ "$static_ip" = "q" ]; then
                log "用户选择退出静态IP设置。"
                return
            fi
            if validate_ip "$static_ip"; then
                break
            else
                log "输入的IP地址格式不正确，请重新输入。"
            fi
        done

        local netmask="255.255.255.0"
        while true; do
            log "当前默认子网掩码为 255.255.255.0，输入 'i' 修改，输入 'r' 确认走下一步，输入 'q' 退出："
            read input
            if [ "$input" = "q" ]; then
                log "用户选择退出静态IP设置。"
                return
            elif [ "$input" = "i" ]; then
                while true; do
                    log "请输入子网掩码（仅允许输入 255.255.255.0，输入 'q' 退出）："
                    read netmask
                    if [ "$netmask" = "q" ]; then
                        log "用户选择退出静态IP设置。"
                        return
                    fi
                    if [ "$netmask" = "255.255.255.0" ]; then
                        break
                    else
                        log "输入的子网掩码不正确，请输入 255.255.255.0。"
                    fi
                done
                break
            elif [ "$input" = "r" ]; then
                break
            else
                log "输入无效，请输入 'i'、'r' 或 'q'。"
            fi
        done
        netmask="24"  # 转换为前缀长度

        local gateway
        while true; do
            # 清理输入缓冲区
            while read -t 0; do :; done < /dev/stdin
            log "请输入网关（输入 'q' 退出）："
            read gateway
            if [ "$gateway" = "q" ]; then
                log "用户选择退出静态IP设置。"
                return
            fi
            if validate_ip "$gateway"; then
                if check_gateway "$gateway"; then
                    log "网关 $gateway 连通性检测通过。"
                    break
                else
                    log "网关 $gateway 连通性检测失败。是否忽略此错误继续？(y/n)"
                    read ignore
                    if [ "$ignore" = "y" ]; then
                        break
                    fi
                fi
            else
                log "输入的网关格式不正确，请重新输入。"
            fi
        done

        local dns
        while true; do
            # 清理输入缓冲区
            while read -t 0; do :; done < /dev/stdin
            log "请输入DNS服务器（输入 'r' 跳过，输入 'q' 退出）："
            read dns
            if [ "$dns" = "q" ]; then
                log "用户选择退出静态IP设置。"
                return
            elif [ "$dns" = "r" ]; then
                log "跳过DNS服务器配置。"
                break
            elif validate_ip "$dns"; then
                break
            else
                log "输入的DNS服务器格式不正确，请重新输入。"
            fi
        done

        # 询问是否保存静态IP配置
        if confirm_action "是否保存静态IP配置？"; then
            mac=$(cat /sys/class/net/$interface/address | tr -d :)
            uuid=$(printf '%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\n' $((0x${mac:0:8})))

            # 创建网络配置文件
            sudo tee /etc/sysconfig/network-scripts/ifcfg-$interface > /dev/null << EOF
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
IPADDR=$static_ip
PREFIX=$netmask
GATEWAY=$gateway
$([ "$dns" != "r" ] && echo "DNS1=$dns")
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$interface
UUID=$uuid
DEVICE=$interface
HWADDR=$(cat /sys/class/net/$interface/address)
ONBOOT=yes
EOF
            log "静态IP配置已保存。"
        else
            log "静态IP配置未保存。"
            return
        fi

        log "静态IP设置完成，但未重启网络服务，请手动重启网络服务使配置生效。"
    else
        log "跳过静态IP设置。"
    fi
}

# 修改root密码
function change_root_password() {
    if confirm_action "是否修改root密码？"; then
        log "请输入新的root密码："
        if passwd; then
            log "root密码修改成功。"
        else
            log "root密码修改失败。"
        fi
    else
        log "用户选择不修改root密码。"
    fi
}

# 添加非root用户并进行相关操作
function add_non_root_user() {
    local new_non_root_user=""
    if confirm_action "是否添加非root用户？"; then
        log "请输入非root用户名："
        read non_root_user
        if sudo useradd $non_root_user; then
            log "非root用户 $non_root_user 创建成功。"
            log "请输入非root用户密码："
            if sudo passwd $non_root_user; then
                log "非root用户 $non_root_user 密码设置成功。"
                # 添加sudo免密权限
                if confirm_action "是否为 $non_root_user 用户添加sudo免密权限？"; then
                    sudo_file="/etc/sudoers.d/sudoers"
                    if [ $(sudo cat $sudo_file | grep "$non_root_user ALL=(ALL) NOPASSWD: ALL" | wc -l) -eq 0 ]; then
                        echo "$non_root_user ALL=(ALL) NOPASSWD: ALL" | sudo tee -a $sudo_file > /dev/null
                        log "已为 $non_root_user 用户添加sudo免密权限。"
                    else
                        log "$non_root_user 用户的sudo免密权限已存在。"
                    fi
                    # 确认sudo免密权限添加成功
                    sudo cat $sudo_file
                    if sudo cat $sudo_file | grep -q "$non_root_user ALL=(ALL) NOPASSWD: ALL"; then
                        log "$non_root_user 用户的sudo免密权限添加成功。"
                    else
                        log "$non_root_user 用户的sudo免密权限添加失败。"
                    fi
                else
                    log "用户选择不为 $non_root_user 用户添加sudo免密权限。"
                fi
            else
                log "非root用户 $non_root_user 密码设置失败。"
            fi
            new_non_root_user=$non_root_user
        else
            log "非root用户 $non_root_user 创建失败。"
        fi
    else
        log "用户选择不添加非root用户。"
    fi

    # 检查是否为Das-os系统
    if grep -q "Das-os" /etc/os-release; then
        log "检测到Das-os系统。"
        # 修改IO调度器为单队列deadline
        log "修改IO调度器为单队列deadline。"
        sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ scsi_mod.use_blk_mq=0 dm_mod.use_blk_mq=0 elevator=deadline"/' /etc/default/grub
        grub2-mkconfig -o /boot/efi/EFI/openEuler/grub.cfg
        grub2-mkconfig -o /boot/grub2/grub.cfg
        # 询问是否重启系统
        if confirm_action "需要重启系统以应用更改，是否现在重启？"; then
            reboot
        else
            log "系统重启已取消。"
        fi
    else
        log "非Das-os系统，继续执行重启网络服务的代码段。"
        # 直接执行重启网络服务的代码段
        if confirm_action "是否要重启网络服务以应用静态 IP 配置？"; then
            while true; do
                log "请选择重启方式（1：network.service   2:NetworkManager）："
                read restart_option
                case $restart_option in
                    1)
                        sudo systemctl stop NetworkManager
                        if sudo systemctl restart network.service; then
                            log "network.service 重启成功。"
                        else
                            log "network.service 重启失败。"
                        fi
                        break
                        ;;
                    2)
                        if sudo systemctl restart NetworkManager; then
                            log "NetworkManager 重启成功。"
                        else
                            log "NetworkManager 重启失败。"
                        fi
                        break
                        ;;
                    *)
                        log "输入无效，请输入 1 或 2。"
                        ;;
                esac
            done
        else
            if [ -n "$new_non_root_user" ]; then
                if confirm_action "是否切换到新创建的非 ROOT 用户 $new_non_root_user？"; then
                    su - $new_non_root_user
                fi
            fi
        fi
    fi
}

# 修改系统时间
function set_system_time() {
    log "是否修改系统时间？(y/n)"
    read answer
    if [ "$answer" = "y" ]; then
        local retry=true
        while $retry; do
            log "请输入时间（格式：YYYY-MM-DD HH:MM:SS，输入 'q' 退出）："
            read new_time
            if [ "$new_time" = "q" ]; then
                log "用户选择退出系统时间修改。"
                return
            fi
            if sudo date -s "$new_time" && sudo hwclock -w; then
                log "系统时间修改完成。"
                retry=false
            else
                log "系统时间修改失败。"
                if confirm_action "系统时间修改失败，是否再次尝试修改？"; then
                    continue
                else
                    retry=false
                fi
            fi
        done
    else
        log "跳过系统时间修改。"
    fi
}

# 主流程
check_server_config
set_static_ip
change_root_password
set_system_time
add_non_root_user

log "除安装步骤外的其他操作完成。请运行第二个脚本进行安装步骤。"

