#!/bin/bash

# 检查 SELinux 状态
echo "==== 检查 SELinux 状态 ===="
sleep 2
SELINUX_STATUS=$(sestatus | awk '/SELinux status/ {print $3}')
if [ "$SELINUX_STATUS" != "disabled" ]; then
    if grep -q "^SELINUX=enforcing" /etc/selinux/config || grep -q "^SELINUX=permissive" /etc/selinux/config; then
        echo "==== 更改 SELinux 状态为 disabled ===="
        sleep 2
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' "/etc/selinux/config"
        echo "==== SELinux 状态已更改为 disabled，请重启系统 ===="
        reboot
    fi
fi

# 检查是否已使用阿里云源
if grep -q "mirrors.aliyun.com" /etc/yum.repos.d/CentOS-Base.repo; then
    echo "==== 已配置阿里云YUM源，跳过更换步骤 ===="
else
    echo "==== 更换yum源为阿里云源并更新系统 ===="
    sleep 2
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    
    if grep -q "mirrors.aliyun.com" /etc/yum.repos.d/CentOS-Base.repo; then
        echo "==== 阿里云YUM源更换成功 ===="
        sleep 2
    else
        echo "==== 阿里云YUM源更换失败，请检查网络或手动更换 ===="
        read -n 1 -s -r -p "按任意键退出..."
        exit 1
    fi
    yum clean all
    yum makecache fast
fi

yum update -y
echo "==== 系统更新完成 ===="
sleep 1

echo "==== 开始创建组与用户 ===="
sleep 2

# 创建必要的组，若组已存在则忽略错误
groupadd -g 501 oinstall 2>/dev/null
groupadd -g 502 dba 2>/dev/null
groupadd -g 503 oper 2>/dev/null
echo "==== 创建组完成 ===="
sleep 1

# 创建 Oracle 用户（注意：此处密码自动设置为 oracle）
echo "==== 创建 oracle 用户 ===="
sleep 1
if ! id oracle &>/dev/null; then
    useradd -u 502 -g oinstall -G dba,oper oracle
    echo "==== 自动设置 oracle 用户密码为 oracle ===="
    echo "oracle" | passwd --stdin oracle
    cp /etc/skel/.bashrc /home/oracle/ -y
    cp /etc/skel/.bash_profile /home/oracle/ -y
fi
echo "==== 创建组与用户完成 ===="
sleep 1

echo "==== 开始配置系统 ===="
sleep 2
cat >> /etc/sysctl.conf <<EOF

# Oracle Installation parameters
kernel.shmmni = 4096
kernel.shmmax = 4398046511104
kernel.shmall = 1073741824
kernel.sem = 250 32000 100 128
fs.aio-max-nr = 1048576
fs.file-max = 6815744
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048586
EOF

echo "==== 加载内核参数 ===="
sleep 2
sysctl -p

echo "==== 配置用户资源限制 ===="
sleep 2
cat >> /etc/security/limits.conf <<EOF

# Oracle 用户资源限制
oracle   soft   nproc    131072
oracle   hard   nproc    131072
oracle   soft   nofile   131072
oracle   hard   nofile   131072
oracle   soft   core     unlimited
oracle   hard   core     unlimited
oracle   soft   memlock  50000000
oracle   hard   memlock  50000000
EOF

echo "==== 创建目录结构 ===="
sleep 2
mkdir -p /ora01/app
chown oracle:oinstall /ora01/app
chmod 775 /ora01/app

mkdir -p /ora01/app/oracle
chown oracle:oinstall /ora01/app/oracle
chmod 775 /ora01/app/oracle

mkdir -p /ora01/app/oracle/product/11.2.0/db_1
chown -R oracle:oinstall /ora01/app/oracle

echo "==== 系统配置完成 ===="
sleep 2

echo "==== 安装Oracle依赖包 ===="
sleep 2
yum -y install elfutils-libelf-devel binutils compat compat-libstdc gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel libXi libXtst make sysstat unixODBC unixODBC-devel

echo "==== 检查依赖包安装情况 ===="
sleep 2
dependencies=(binutils elfutils-libelf elfutils-libelf-devel gcc gcc-c++ glibc glibc-common glibc-devel glibc-headers ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel make sysstat unixODBC unixODBC-devel)
missing=0
for pkg in "${dependencies[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        echo "==== $(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}(%{ARCH})\n' "$pkg") ===="
    else
        echo "==== 依赖包 $pkg 未安装！ ===="
        missing=1
    fi
done

if [ "$missing" -eq 1 ]; then
    echo "==== 部分依赖包未安装，请检查YUM源或手动安装后重试 ===="
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi

echo "==== 检查环境配置 ===="
sleep 2
sysctl -a | grep -E 'kernel.shmmni|kernel.shmmax|kernel.shmall|kernel.sem|fs.aio-max-nr|fs.file-max|net.ipv4.ip_local_port_range|net.core.rmem_default|net.core.rmem_max|net.core.wmem_default|net.core.wmem_max'

grep -E 'oracle.*nproc|oracle.*nofile|oracle.*core|oracle.*memlock' /etc/security/limits.conf

echo "==== 设定、检查 ORACLE 环境变量和目录结构 ===="
sleep 2

echo "==== 设定 ORACLE 环境变量 ===="
sleep 1
export ORACLE_BASE=/ora01/app/oracle
export ORACLE_HOME=/ora01/app/oracle/product/11.2.0/db_1
export ORACLE_SID=orcl
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib


echo "==== 自动解压 Oracle 安装软件 请确保软件已上传至/root 目录 ===="
sleep 3

echo "==== 自动解压 Oracle 安装软件 ===="
sleep 2
if [ -d "/ora01/app/oracle" ]; then
    cd /ora01/app/oracle
    if [ -f /root/linux.x64_11gR2_database_1of2.zip ] && [ -f /root/linux.x64_11gR2_database_2of2.zip ]; then
        echo "==== 开始解压 Oracle 安装包 ===="
        sleep 2
        if [ ! -d "/ora01/app/oracle/database" ]; then
            unzip /root/linux.x64_11gR2_database_1of2.zip -d /ora01/app/oracle && unzip /root/linux.x64_11gR2_database_2of2.zip -d /ora01/app/oracle
        else
            echo "==== Oracle 安装包已解压，跳过解压步骤 ===="
        fi
        echo "==== Oracle 安装包解压完成 ===="
    else
        echo "==== 未找到 Oracle 安装包，请检查文件是否存在 ===="
        read -n 1 -s -r -p "按任意键退出..."
        exit 1
    fi
else
    echo "==== 目录 /ora01/app/oracle 不存在，请检查 ===="
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi
echo "==== Oracle 脚本运行完毕 ===="
echo "==== 请移步物理机登录oracle用户执行安装脚本 ===="
echo "==== 运行安装脚本前请执行命令export DISPLAY=:0.0 ===="
echo "==== /ora01/app/oracle/database/runInstaller ===="
read -n 1 -s -r -p "按任意键退出..."

exit 0