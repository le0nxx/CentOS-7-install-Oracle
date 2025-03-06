#!/bin/bash

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


echo "==== 开始创建组与用户 ===="
sleep 2

# 创建必要的组，若组已存在则忽略错误
groupadd oinstall
groupadd dba
echo "==== 创建组完成 ===="
sleep 1

# 创建 Oracle 用户（注意：此处密码自动设置为 oracle）
echo "==== 创建 oracle 用户 ===="
sleep 1
if ! id oracle &>/dev/null; then
    useradd -g oinstall -G dba oracle
    echo "==== 自动设置 oracle 用户密码为 oracle ===="
    echo "oracle" | passwd --stdin oracle
    cp /etc/skel/.bashrc /home/oracle/
    cp /etc/skel/.bash_profile /home/oracle/
fi
echo "==== 创建组与用户完成 ===="
sleep 1

echo "==== 开始配置系统 ===="
sleep 2
cat >> /etc/sysctl.conf <<EOF

# Oracle Installation parameters
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
kernel.panic_on_oops = 1
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
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft stack 10240
EOF

echo "==== 创建目录结构 ===="
sleep 2

mkdir -p /app/oracle/product/19.3.000/db_home
mkdir -p /app/oraInventory
chown -R oracle:oinstall /app/oracle
chown -R oracle:oinstall /app/oraInventory
chmod -R 775 /app/oracle
chmod -R 775 /app/oraInventory


echo "==== 系统配置完成 ===="
sleep 2

echo "==== 安装Oracle依赖包 ===="
echo "==== compat-libstdc++是必须依赖包，但yum可能无法安装，需手动安装"
sleep 4
yum install -y compat-libstdc+ binutils.x86_64 compat-libcap1.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.x86_64 glibc-devel.x86_64 ksh.x86_64 libaio.x86_64 libaio-devel.x86_64 libstdc++.x86_64 libstdc++-devel.x86_64 libXi.x86_64 libXtst.x86_64 make.x86_64 sysstat.x86_64 glibc.i686

echo "==== 检查依赖包安装情况 ===="
sleep 2
dependencies=(compat-libstdc+ binutils.x86_64 compat-libcap1.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.x86_64 glibc-devel.x86_64 ksh.x86_64 libaio.x86_64 libaio-devel.x86_64 libstdc++.x86_64 libstdc++-devel.x86_64 libXi.x86_64 libXtst.x86_64 make.x86_64 sysstat.x86_64 glibc.i686)
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
    read -n 1 -s -r -p "按任意键继续(y)或退出(其他任意键)..." key
    if [[ "$key" != "y" ]]; then
        exit 1
    fi
fi

echo "==== 检查环境配置 ===="
sleep 2
sysctl -a | grep -E 'kernel.shmmni|kernel.shmmax|kernel.shmall|kernel.sem|fs.aio-max-nr|fs.file-max|net.ipv4.ip_local_port_range|net.core.rmem_default|net.core.rmem_max|net.core.wmem_default|net.core.wmem_max'

grep -E 'oracle.*nproc|oracle.*nofile|oracle.*core|oracle.*memlock' /etc/security/limits.conf


echo "==== 设定、检查 ORACLE 环境变量和目录结构 ===="
sleep 2


echo "==== 设定 ORACLE 环境变量 ===="
sleep 1

vim /home/oracle/.bash_profile <<EOF
export JAVA_HOME=/usr/local/jdk1.8.0_381
ORACLE_SID=orcl
export ORACLE_SID  
ORACLE_UNQNAME=orcl
export ORACLE_UNQNAME
ORACLE_BASE=/app/oracle/
export ORACLE_BASE
ORACLE_HOME=$ORACLE_BASE/product/19.3.000/db_home
export ORACLE_HOME
NLS_DATE_FORMAT="YYYY:MM:DDHH24:MI:SS"
export NLS_DATE_FORMAT
export NLS_LANG=american_america.ZHS16GBK
export TNS_ADMIN=$ORACLE_HOME/network/admin
export ORA_NLS11=$ORACLE_HOME/nls/data
PATH=.:${JAVA_HOME}/bin:${PATH}:$HOME/bin:$ORACLE_HOME/bin:$ORA_CRS_HOME/bin
PATH=${PATH}:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin
export PATH
LD_LIBRARY_PATH=$ORACLE_HOME/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$ORACLE_HOME/oracm/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH
CLASSPATH=$ORACLE_HOME/JRE
CLASSPATH=${CLASSPATH}:$ORACLE_HOME/jlib
CLASSPATH=${CLASSPATH}:$ORACLE_HOME/rdbms/jlib
CLASSPATH=${CLASSPATH}:$ORACLE_HOME/network/jlib
export CLASSPATH
THREADS_FLAG=native
export THREADS_FLAG
export TEMP=/tmp
export TMPDIR=/tmp
umask 022
EOF


echo "==== 自动解压 JDK Oracle 安装软件 请确保软件已上传至/root 目录 ===="
sleep 3

echo "==== 自动解压JDK安装包 ===="

if [ -f /root/jdk-8u381-linux-x64.tar.gz ]; then
    echo "==== 开始解压JDK安装包 ===="
    sleep 2
    if [ ! -d "/usr/local/jdk1.8.0_381" ]; then
        tar -zxvf /root/jdk-8u381-linux-x64.tar.gz -C /usr/local/
    else
        echo "==== JDK安装包已解压，跳过解压步骤 ===="
    fi
    echo "==== JDK安装包解压完成 ===="
else
    echo "==== 未找到JDK安装包，是否继续(y/n)? ===="
    read -n 1 -s -r -p "请选择 (y/n): " key
    if [[ "$key" == "y" ]]; then
        echo "==== 继续执行 ===="
    else
        echo "==== 退出 ===="
        exit 1
    fi
fi


echo "==== 自动解压 Oracle 安装软件 ===="
sleep 2
if [ -d "/app/oracle/product/19.3.000/db_home" ]; then
    if [ -f /root/LINUX.X64_193000_db_home.zip ] then
        echo "==== 开始解压 Oracle 安装包 ===="
        sleep 2
        if [ ! -d "/app/oracle/product/19.3.000/db_home/database" ]; then
            unzip /root/LINUX.X64_193000_db_home.zip -d /app/oracle/product/19.3.000/db_home
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
    echo "==== 目录 /app/oracle/product/19.3.000/db_home 不存在，请检查 ===="
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi
echo "==== Oracle 脚本运行完毕 ===="
echo "==== 请使用图形化界面登录oracle用户执行安装脚本 ===="
echo "==== 运行安装脚本前请执行命令export DISPLAY=:0.0 ===="
echo "==== $ORACLE_HOME/runInstaller ===="
read -n 1 -s -r -p "按任意键退出..."

exit 0