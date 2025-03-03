该脚本用于自动配置并安装 Oracle 11g 数据库环境。它主要负责：  
This script is intended to automate the configuration and installation of the Oracle 11g database environment. It mainly performs the following tasks:

- **检查 SELinux 状态 / Check SELinux Status:**  
  检查系统的 SELinux 状态并将其设置为 disabled。  
  Checks the SELinux status and disables it (which will require a system reboot).

- **配置阿里云 YUM 源 / Configure Aliyun YUM Repository:**  
  检查是否已经配置阿里云 YUM 源，如果没有，则更换并更新系统。  
  Checks if the Aliyun YUM repository is configured; if not, it replaces the repository and updates the system.

- **创建组与用户 / Create Groups and User:**  
  创建必要的系统组 (oinstall, dba, oper) 并添加 Oracle 用户，同时设置初始密码。  
  Creates essential system groups (oinstall, dba, oper) and adds the Oracle user with the default password.

- **调整系统配置 / Update System Configuration:**  
  配置内核参数、用户资源限制等，以满足 Oracle 数据库的需求。  
  Sets up kernel parameters and user resource limits required by the Oracle database.

- **安装依赖包 / Install Dependencies:**  
  自动安装 Oracle 所需的依赖包，并验证安装情况。  
  Automatically installs the dependencies required by Oracle and verifies their installation.

- **设置 Oracle 环境变量和目录 / Setup Oracle Environment and Directories:**  
  定义 ORACLE_BASE、ORACLE_HOME 与 ORACLE_SID，创建并调整目录权限。  
  Defines ORACLE_BASE, ORACLE_HOME, and ORACLE_SID; creates and adjusts directory permissions.

- **自动解压安装软件 / Automatic Extraction of Installation Packages:**  
  自动检测与解压 Oracle 安装软件包，需要的软件包应放置于 `/root` 目录。  
  Automatically detects and extracts the Oracle installation packages which should be placed in the `/root` directory.



## 使用方法 / Usage

1. **解压脚本与授权 / Download and Set Permissions:**  
   - 将压缩包文件放入 `/root` 目录，确保当前终端用户为 **root** 用户。  
     Place the compressed file in the `/root` directory and ensure the current user is **root**.
   - 执行以下命令进行下载和授权：  
     Execute the following commands:
     
   ```bash
   curl -O https://raw.githubusercontent.com/le0nxx/Oracle11g_install/refs/heads/main/oracle_install.sh
   chmod +x oracle_install.sh
   . oracle_install.sh
   ```

2. **安装 Oracle 数据库 / Install Oracle Database:**  
   - 脚本配置完环境后，切换至 **oracle** 用户进行图形化安装。  
     Once the environment is set up, switch to the **oracle** user for GUI installation.
   - 执行以下命令启动安装程序：  
     Run the following commands to launch the installer:
     
   ```bash
   su - oracle
   cd /ora1/app/database
   chmod +x runInstaller
   ./runInstaller
   ```
