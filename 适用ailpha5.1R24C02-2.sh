#!/bin/bash

# 检查是否为Das-os系统
if grep -q "Das-os" /etc/os-release; then
    # 检查IO调度器
    SCHEDULER_FILE="/sys/block/sda/queue/scheduler"
    if grep -q "\[cfq\]" "$SCHEDULER_FILE"; then
        echo "IO调度器成功修改为单队列deadline。"
        echo "deadline" > "$SCHEDULER_FILE"
    else
        echo "IO调度器未修改为单队列deadline。"
        exit 1
    fi
fi

# 检查LUANBIRD-AILPHA_ZQ-V5.1R24C02.tar.gz压缩包
TAR_FILE_PATH=$(ls | grep *AILPHA*)
if [[ -n "$TAR_FILE_PATH" ]]; then
    echo "找到压缩包: $TAR_FILE_PATH"
    read -p "是否需要解压该压缩包? (y/n): " EXTRACT_CONFIRM
    if [[ "$EXTRACT_CONFIRM" == "y" ]]; then
        sudo tar -zxvf "$TAR_FILE_PATH"
        echo "压缩包已解压。"
    else
        echo "未解压压缩包。"
    fi
else
    echo "未找到AILPHA安装压缩包。"
    exit 1
fi

# 文件路径
FILE_PATH="/etc/ansible/cluster_init/hosts.yml"
INSTALL_JSON_PATH="/etc/ansible/cluster_init/conf/install.json"

# 检查文件路径是否存在
if [[ ! -f "$FILE_PATH" || ! -f "$INSTALL_JSON_PATH" ]]; then
    echo "文件路径不正确，操作已取消。"
    exit 1
else
    echo "文件路径正确。"
fi

# 提示用户是否需要修改
read -p "是否需要修改hosts.yml文件? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "操作已取消。"
    exit 0
fi

# 获取本机的IP地址
echo "正在获取本机IP地址..."
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "本机IP地址是: $LOCAL_IP"

# 提示用户输入master的凭据

echo "请输入目标服务器ssh端口信息，默认为22:"
read ANSIBLE_SSH_PORT
echo "请输入有权限执行安装的服务器账号，当前登录账号用户名:"
read ANSIBLE_SSH_USER
echo "请输入有权限执行安装的服务器密码，当前登录账号密码"
read -s ANSIBLE_SSH_PASS

# 更新hosts.yml文件
sudo sed -i "5s/10.50.2.41/$LOCAL_IP/" "$FILE_PATH"
sudo sed -i "8s/10.50.2.41/$LOCAL_IP/" "$FILE_PATH"
sudo sed -i "/master:/,/node:/ s/ansible_ssh_pass:.*/ansible_ssh_pass: $ANSIBLE_SSH_PASS/" "$FILE_PATH"
sudo sed -i "/master:/,/node:/ s/ansible_ssh_port:.*/ansible_ssh_port: $ANSIBLE_SSH_PORT/" "$FILE_PATH"
sudo sed -i "/master:/,/node:/ s/ansible_ssh_user:.*/ansible_ssh_user: $ANSIBLE_SSH_USER/" "$FILE_PATH"

echo "hosts.yml已成功更新。"

# 提示用户是否需要修改install.json文件
read -p "是否需要修改install.json文件? (选择y进行修改): " MODIFY_INSTALL_JSON
if [[ "$MODIFY_INSTALL_JSON" == "y" ]]; then
    sudo sed -i "s/\"ip\": \".*\"/\"ip\": \"$LOCAL_IP\"/" "$INSTALL_JSON_PATH"
    sudo sed -i "s/\"Model\": \".*\"/\"Model\": \"hgdb\"/" "$INSTALL_JSON_PATH"
    echo "install.json已成功更新。"

    # 查找名为AILPHA的压缩包并修改install.json
    TAR_FILE=$(ls | grep *AILPHA*)
    if [[ -n "$TAR_FILE" ]]; then
        VERSION=$(echo "$TAR_FILE" | sed -n 's/.*AILPHA_.*-\(V[0-9.]*R[0-9.]*C[0-9.]*\)\.tar\.gz/\1/p')
        sudo sed -i "s/\"Version\": \".*\"/\"Version\": \"$VERSION\"/" "$INSTALL_JSON_PATH"
        sudo sed -i "s/\"Type\": \".*\"/\"Type\": \"DEFAULT\"/" "$INSTALL_JSON_PATH"
        echo "配置文件已修改完成，下面执行安装前预清理操作。"
    else
        echo "未找到AILPHA相关的压缩包。"
    fi
fi



# 执行清理和安装脚本
cd /etc/ansible/tools
sudo sh pre_clean.sh

echo "安装前预清理完成。"

# 询问是否进行安装
read -p "是否现在进行安装? (y/n): " INSTALL_CONFIRM
if [[ "$INSTALL_CONFIRM" == "y" ]]; then
    cd /etc/ansible
    sudo sh start.sh | sudo tee ./install.log -a
    echo "安装完成。"
else
    echo "安装已取消。"
    exit 0
fi

