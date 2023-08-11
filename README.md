## 目录

* [部署](#部署)
    * [规划](#规划)
    * [初始化](#初始化)
    * [部署方式](#部署方式)
    * [安装](#安装)
    * [存储池](#存储池)  
    * [监控](#监控)
    * [移除](#移除)
    
* [命令](#命令)
    * [OSD](#OSD)
    * [POOL](#POOL)
    * [RBD](#RBD)
    * [MGR](#MGR)
    * [CRUSH](#CRUSH)
    * [RULE](#RULE)
    * [PG](#PG)
    
## 部署

Ceph目前最新版本18（R版），此次部署的是（N版）

[版本清单](https://docs.ceph.com/en/latest/releases/)

### 规划

| 主机名                                  | 操作系统     | IP           | 角色                   |
|----------------------------------------|------------|--------------|------------------------|
| dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 | centos 7.9 | 10.104.2.23  | ceph-deploy、mon、osd  |
| dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 | centos 7.9 | 10.104.2.24  | mon、osd               |
| dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 | centos 7.9 | 10.104.2.25  | mon、osd               |

### 初始化

**1、关闭防火墙 & selinux**

```bash
systemctl stop firewalld
systemctl disable firewalld

sed -i 's/enforcing/disabled/' /etc/selinux/config
setenforce 0
```

**2、关闭 swap**

```bash
# 临时
swapoff -a 

# 永久，重启生效
sed -ri 's/.*swap.*/#&/' /etc/fstab 
```

**3、修改 hosts 解析**

```bash
cat >> /etc/hosts << EOF
10.104.2.23 dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
10.104.2.24 dx-lt-yd-zhejiang-jinhua-5-10-104-2-24
10.104.2.25 dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
EOF
```

**4、设置文件描述符**

```bash
ulimit -SHn 65535
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
EOF
```

**5、时间同步**

```bash
yum install ntpdate -y
ntpdate time.windows.com
```

**6、ssh 免交互认证**

配置 ceph-deploy 可以访问其他主机即可

```bash
ssh-keygen -t rsa
```

** 上面操作所有节点都要进行初始化 ** 

### 部署方式

14（N）版本及之前：
* yum：常规的部署方式
* ceph-deploy：ceph提供的简易部署工具，可以非常方便部署ceph集群
* ceph-ansible：官方基于ansible写的自动化部署工具

14（N）版本之后：
* cephadm：使用容器部署和管理Ceph集群，需要先部署Docker或者Podman和Python3
* rook：在Kubernetes中部署和管理Ceph集群

### 安装

**1、配置阿里云 yum 仓库（所有机器）**

```bash
wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -ivh epel-release-latest-7.noarch.rpm

cat > /etc/yum.repos.d/ceph.repo << EOF
[Ceph]
name=Ceph packages for $basearch
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/\$basearch
gpgcheck=0
[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch
gpgcheck=0
[ceph-source]
name=Ceph source packages
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/SRPMS
gpgcheck=0
EOF

yum -y install ceph-common
```

**2、安装 ceph-deploy 工具**

```bash
yum install python2-pip -y
yum -y install ceph-deploy
```

**3、生成安装目录**

创建一个my-cluster目录，所有命令在此目录下进行。

```bash
mkdir -p /ceph-cluster && cd /ceph-cluster
```

设置环境变量，创建集群。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# node1=dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# node2=dx-lt-yd-zhejiang-jinhua-5-10-104-2-24
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# node3=dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# ceph-deploy new $node1 $node2 $node3
[ceph_deploy.conf][DEBUG ] found configuration file at: /root/.cephdeploy.conf
[ceph_deploy.cli][INFO  ] Invoked (2.0.1): /bin/ceph-deploy new dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
[ceph_deploy.cli][INFO  ] ceph-deploy options:
[ceph_deploy.cli][INFO  ]  username                      : None
[ceph_deploy.cli][INFO  ]  func                          : <function new at 0x7f1de8b25398>
[ceph_deploy.cli][INFO  ]  verbose                       : False
[ceph_deploy.cli][INFO  ]  overwrite_conf                : False
[ceph_deploy.cli][INFO  ]  quiet                         : False
[ceph_deploy.cli][INFO  ]  cd_conf                       : <ceph_deploy.conf.cephdeploy.Conf instance at 0x7f1de8b43c68>
[ceph_deploy.cli][INFO  ]  cluster                       : ceph
[ceph_deploy.cli][INFO  ]  ssh_copykey                   : True
[ceph_deploy.cli][INFO  ]  mon                           : ['dx-lt-yd-zhejiang-jinhua-5-10-104-2-23', 'dx-lt-yd-zhejiang-jinhua-5-10-104-2-24', 'dx-lt-yd-zhejiang-jinhua-5-10-104-2-25']
[ceph_deploy.cli][INFO  ]  public_network                : None
[ceph_deploy.cli][INFO  ]  ceph_conf                     : None
[ceph_deploy.cli][INFO  ]  cluster_network               : None
[ceph_deploy.cli][INFO  ]  default_release               : False
[ceph_deploy.cli][INFO  ]  fsid                          : None
[ceph_deploy.new][DEBUG ] Creating new cluster named ceph
```

**4、执行安装**

安装 Ceph 包到指定节点： 注：–no-adjust-repos 参数是直接使用本地源，不使用官方默认源。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster] ceph-deploy install --no-adjust-repos $node1 $node2 $node3
[ceph_deploy.conf][DEBUG ] found configuration file at: /root/.cephdeploy.conf
[ceph_deploy.cli][INFO  ] Invoked (2.0.1): /bin/ceph-deploy install --no-adjust-repos dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
[ceph_deploy.cli][INFO  ] ceph-deploy options:
[ceph_deploy.cli][INFO  ]  verbose                       : False
[ceph_deploy.cli][INFO  ]  testing                       : None
[ceph_deploy.cli][INFO  ]  cd_conf                       : <ceph_deploy.conf.cephdeploy.Conf instance at 0x7fe7a6dffbd8>
[ceph_deploy.cli][INFO  ]  cluster                       : ceph
[ceph_deploy.cli][INFO  ]  dev_commit                    : None
[ceph_deploy.cli][INFO  ]  install_mds                   : False
[ceph_deploy.cli][INFO  ]  stable                        : None
[ceph_deploy.cli][INFO  ]  default_release               : False
[ceph_deploy.cli][INFO  ]  username                      : None
[ceph_deploy.cli][INFO  ]  adjust_repos                  : False
[ceph_deploy.cli][INFO  ]  func                          : <function install at 0x7fe7a744ab18>
[ceph_deploy.cli][INFO  ]  install_mgr                   : False
[ceph_deploy.cli][INFO  ]  install_all                   : False
[ceph_deploy.cli][INFO  ]  repo                          : False
[ceph_deploy.cli][INFO  ]  host                          : ['dx-lt-yd-zhejiang-jinhua-5-10-104-2-23', 'dx-lt-yd-zhejiang-jinhua-5-10-104-2-24', 'dx-lt-yd-zhejiang-jinhua-5-10-104-2-25']
[ceph_deploy.cli][INFO  ]  install_rgw                   : False
[ceph_deploy.cli][INFO  ]  install_tests                 : False
[ceph_deploy.cli][INFO  ]  repo_url                      : None
[ceph_deploy.cli][INFO  ]  ceph_conf                     : None
[ceph_deploy.cli][INFO  ]  install_osd                   : False
[ceph_deploy.cli][INFO  ]  version_kind                  : stable
[ceph_deploy.cli][INFO  ]  install_common                : False
[ceph_deploy.cli][INFO  ]  overwrite_conf                : False
[ceph_deploy.cli][INFO  ]  quiet                         : False
[ceph_deploy.cli][INFO  ]  dev                           : master
[ceph_deploy.cli][INFO  ]  nogpgcheck                    : False
[ceph_deploy.cli][INFO  ]  local_mirror                  : None
[ceph_deploy.cli][INFO  ]  release                       : None
[ceph_deploy.cli][INFO  ]  install_mon                   : False
[ceph_deploy.cli][INFO  ]  gpg_url                       : None
[ceph_deploy.install][DEBUG ] Installing stable version mimic on cluster ceph hosts dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
[ceph_deploy.install][DEBUG ] Detecting platform for host dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ...
```

**5、部署 Monitor 服务**

初始化并部署 monitor，收集所有密钥：

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# ceph-deploy mon create-initial
[ceph_deploy.conf][DEBUG ] found configuration file at: /root/.cephdeploy.conf
[ceph_deploy.cli][INFO  ] Invoked (2.0.1): /bin/ceph-deploy mon create-initial
[ceph_deploy.cli][INFO  ] ceph-deploy options:
[ceph_deploy.cli][INFO  ]  username                      : None
[ceph_deploy.cli][INFO  ]  verbose                       : False
[ceph_deploy.cli][INFO  ]  overwrite_conf                : False
[ceph_deploy.cli][INFO  ]  subcommand                    : create-initial
[ceph_deploy.cli][INFO  ]  quiet                         : False
[ceph_deploy.cli][INFO  ]  cd_conf                       : <ceph_deploy.conf.cephdeploy.Conf instance at 0x7f58ba5874d0>
[ceph_deploy.cli][INFO  ]  cluster                       : ceph
[ceph_deploy.cli][INFO  ]  func                          : <function mon at 0x7f58ba562938>
[ceph_deploy.cli][INFO  ]  ceph_conf                     : None
[ceph_deploy.cli][INFO  ]  default_release               : False
[ceph_deploy.cli][INFO  ]  keyrings                      : None
[ceph_deploy.mon][DEBUG ] Deploying mon, cluster ceph hosts dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
[ceph_deploy.mon][DEBUG ] detecting platform for host dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ...
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] connected to host: dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] detect platform information from remote host
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] detect machine type
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] find the location of an executable
[ceph_deploy.mon][INFO  ] distro info: CentOS Linux 7.9.2009 Core
```

使用 ceph-deploy 命令将配置文件和 admin key 复制到管理节点和 Ceph 节点，以便每次执行 ceph CLI 命令无需指定 monitor 地址和 ceph.client.admin.keyring。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# ceph-deploy admin $node1 $node2 $node3
[ceph_deploy.conf][DEBUG ] found configuration file at: /root/.cephdeploy.conf
[ceph_deploy.cli][INFO  ] Invoked (2.0.1): /bin/ceph-deploy admin dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
[ceph_deploy.cli][INFO  ] ceph-deploy options:
[ceph_deploy.cli][INFO  ]  username                      : None
[ceph_deploy.cli][INFO  ]  verbose                       : False
[ceph_deploy.cli][INFO  ]  overwrite_conf                : False
[ceph_deploy.cli][INFO  ]  quiet                         : False
[ceph_deploy.cli][INFO  ]  cd_conf                       : <ceph_deploy.conf.cephdeploy.Conf instance at 0x7fd92ffc7a28>
[ceph_deploy.cli][INFO  ]  cluster                       : ceph
[ceph_deploy.cli][INFO  ]  client                        : ['dx-lt-yd-zhejiang-jinhua-5-10-104-2-23', 'dx-lt-yd-zhejiang-jinhua-5-10-104-2-24', 'dx-lt-yd-zhejiang-jinhua-5-10-104-2-25']
[ceph_deploy.cli][INFO  ]  func                          : <function admin at 0x7fd930ae7758>
[ceph_deploy.cli][INFO  ]  ceph_conf                     : None
[ceph_deploy.cli][INFO  ]  default_release               : False
[ceph_deploy.admin][DEBUG ] Pushing admin keys and conf to dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] connected to host: dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] detect platform information from remote host
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] detect machine type
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] write cluster configuration to /etc/ceph/{cluster}.conf
[ceph_deploy.admin][DEBUG ] Pushing admin keys and conf to dx-lt-yd-zhejiang-jinhua-5-10-104-2-24
```

**6、添加 OSD**

部署 OSD 服务并添加硬盘，分别在每个节点添加一块硬盘作为 OSD 服务。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# ceph-deploy osd create --data /dev/sdh dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[ceph_deploy.conf][DEBUG ] found configuration file at: /root/.cephdeploy.conf
[ceph_deploy.cli][INFO  ] Invoked (2.0.1): /bin/ceph-deploy osd create --data /dev/sdh dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[ceph_deploy.cli][INFO  ] ceph-deploy options:
[ceph_deploy.cli][INFO  ]  verbose                       : False
[ceph_deploy.cli][INFO  ]  bluestore                     : None
[ceph_deploy.cli][INFO  ]  cd_conf                       : <ceph_deploy.conf.cephdeploy.Conf instance at 0x7f7304bf8a70>
[ceph_deploy.cli][INFO  ]  cluster                       : ceph
[ceph_deploy.cli][INFO  ]  fs_type                       : xfs
[ceph_deploy.cli][INFO  ]  block_wal                     : None
[ceph_deploy.cli][INFO  ]  default_release               : False
[ceph_deploy.cli][INFO  ]  username                      : None
[ceph_deploy.cli][INFO  ]  journal                       : None
[ceph_deploy.cli][INFO  ]  subcommand                    : create
[ceph_deploy.cli][INFO  ]  host                          : dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[ceph_deploy.cli][INFO  ]  filestore                     : None
[ceph_deploy.cli][INFO  ]  func                          : <function osd at 0x7f7304bbade8>
[ceph_deploy.cli][INFO  ]  ceph_conf                     : None
[ceph_deploy.cli][INFO  ]  zap_disk                      : False
[ceph_deploy.cli][INFO  ]  data                          : /dev/sdh
[ceph_deploy.cli][INFO  ]  block_db                      : None
[ceph_deploy.cli][INFO  ]  dmcrypt                       : False
[ceph_deploy.cli][INFO  ]  overwrite_conf                : False
[ceph_deploy.cli][INFO  ]  dmcrypt_key_dir               : /etc/ceph/dmcrypt-keys
[ceph_deploy.cli][INFO  ]  quiet                         : False
[ceph_deploy.cli][INFO  ]  debug                         : False
[ceph_deploy.osd][DEBUG ] Creating OSD on cluster ceph with data device /dev/sdh
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] connected to host: dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] detect platform information from remote host
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] detect machine type
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] find the location of an executable
[ceph_deploy.osd][INFO  ] Distro info: CentOS Linux 7.9.2009 Core
[ceph_deploy.osd][DEBUG ] Deploying osd to dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] write cluster configuration to /etc/ceph/{cluster}.conf
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] osd keyring does not exist yet, creating one
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] create a keyring file
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] find the location of an executable
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][INFO  ] Running command: /usr/sbin/ceph-volume --cluster ceph lvm create --bluestore --data /dev/sdh
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph-authtool --gen-print-key
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph --cluster ceph --name client.bootstrap-osd --keyring /var/lib/ceph/bootstrap-osd/ceph.keyring -i - osd new a17311b8-ee17-41ab-9242-ed0ef43418a6
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /sbin/vgcreate --force --yes ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883 /dev/sdh
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stdout: Wiping xfs signature on /dev/sdh.
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stdout: Physical volume "/dev/sdh" successfully created.
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stdout: Volume group "ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883" successfully created
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /sbin/lvcreate --yes -l 953861 -n osd-block-a17311b8-ee17-41ab-9242-ed0ef43418a6 ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stdout: Logical volume "osd-block-a17311b8-ee17-41ab-9242-ed0ef43418a6" created.
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph-authtool --gen-print-key
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/mount -t tmpfs tmpfs /var/lib/ceph/osd/ceph-2
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -h ceph:ceph /dev/ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883/osd-block-a17311b8-ee17-41ab-9242-ed0ef43418a6
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -R ceph:ceph /dev/dm-1
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ln -s /dev/ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883/osd-block-a17311b8-ee17-41ab-9242-ed0ef43418a6 /var/lib/ceph/osd/ceph-2/block
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph --cluster ceph --name client.bootstrap-osd --keyring /var/lib/ceph/bootstrap-osd/ceph.keyring mon getmap -o /var/lib/ceph/osd/ceph-2/activate.monmap
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stderr: 2023-08-08 14:28:05.570 7f57fabd0700 -1 auth: unable to find a keyring on /etc/ceph/ceph.client.bootstrap-osd.keyring,/etc/ceph/ceph.keyring,/etc/ceph/keyring,/etc/ceph/keyring.bin,: (2) No such file or directory
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] 2023-08-08 14:28:05.570 7f57fabd0700 -1 AuthRegistry(0x7f57f4066318) no keyring found at /etc/ceph/ceph.client.bootstrap-osd.keyring,/etc/ceph/ceph.keyring,/etc/ceph/keyring,/etc/ceph/keyring.bin,, disabling cephx
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stderr: got monmap epoch 1
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph-authtool /var/lib/ceph/osd/ceph-2/keyring --create-keyring --name osd.2 --add-key AQBz4NFk62FVHhAA1TVsMepg54fwLrP2tn06sA==
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stdout: creating /var/lib/ceph/osd/ceph-2/keyring
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] added entity osd.2 auth(key=AQBz4NFk62FVHhAA1TVsMepg54fwLrP2tn06sA==)
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -R ceph:ceph /var/lib/ceph/osd/ceph-2/keyring
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -R ceph:ceph /var/lib/ceph/osd/ceph-2/
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph-osd --cluster ceph --osd-objectstore bluestore --mkfs -i 2 --monmap /var/lib/ceph/osd/ceph-2/activate.monmap --keyfile - --osd-data /var/lib/ceph/osd/ceph-2/ --osd-uuid a17311b8-ee17-41ab-9242-ed0ef43418a6 --setuser ceph --setgroup ceph
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stderr: 2023-08-08 14:28:06.078 7f87265f3a80 -1 bluestore(/var/lib/ceph/osd/ceph-2/) _read_fsid unparsable uuid
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] --> ceph-volume lvm prepare successful for: /dev/sdh
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -R ceph:ceph /var/lib/ceph/osd/ceph-2
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ceph-bluestore-tool --cluster=ceph prime-osd-dir --dev /dev/ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883/osd-block-a17311b8-ee17-41ab-9242-ed0ef43418a6 --path /var/lib/ceph/osd/ceph-2 --no-mon-config
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/ln -snf /dev/ceph-29bcb30f-c0d3-4743-b4a5-be9d160fa883/osd-block-a17311b8-ee17-41ab-9242-ed0ef43418a6 /var/lib/ceph/osd/ceph-2/block
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -h ceph:ceph /var/lib/ceph/osd/ceph-2/block
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -R ceph:ceph /dev/dm-1
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/chown -R ceph:ceph /var/lib/ceph/osd/ceph-2
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/systemctl enable ceph-volume@lvm-2-a17311b8-ee17-41ab-9242-ed0ef43418a6
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stderr: Created symlink from /etc/systemd/system/multi-user.target.wants/ceph-volume@lvm-2-a17311b8-ee17-41ab-9242-ed0ef43418a6.service to /usr/lib/systemd/system/ceph-volume@.service.
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/systemctl enable --runtime ceph-osd@2
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN]  stderr: Created symlink from /run/systemd/system/ceph-osd.target.wants/ceph-osd@2.service to /usr/lib/systemd/system/ceph-osd@.service.
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] Running command: /bin/systemctl start ceph-osd@2
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] --> ceph-volume lvm activate successful for osd ID: 2
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][WARNIN] --> ceph-volume lvm create successful for: /dev/sdh
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][INFO  ] checking OSD status...
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][DEBUG ] find the location of an executable
[dx-lt-yd-zhejiang-jinhua-5-10-104-2-23][INFO  ] Running command: /bin/ceph --cluster=ceph osd stat --format=json
[ceph_deploy.osd][DEBUG ] Host dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 is now ready for osd use.
```

**7、部署 MGR 服务**

```bash
ceph-deploy mgr create $node1 $node2 $node3
```

注：MGR 是 Ceph L 版本新增加的组件，主要作用是分担和扩展 monitor 的部分功能，减轻 monitor 的负担，
建议每台 monitor 节点都部署一个 mgr，以实现相同级别的高可用。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# ceph -s
  cluster:
    id:     16b28327-7eca-494b-93fe-4218a156107a
    health: HEALTH_WARN
            mons are allowing insecure global_id reclaim

  services:
    mon: 3 daemons, quorum dx-lt-yd-zhejiang-jinhua-5-10-104-2-23,dx-lt-yd-zhejiang-jinhua-5-10-104-2-24,dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 (age 20m)
    mgr: dx-lt-yd-zhejiang-jinhua-5-10-104-2-23(active, since 6s), standbys: dx-lt-yd-zhejiang-jinhua-5-10-104-2-25, dx-lt-yd-zhejiang-jinhua-5-10-104-2-24
    osd: 3 osds: 3 up (since 2m), 3 in (since 2m)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 11 TiB / 11 TiB avail
    pgs:
```

解决 `mon is allowing insecure global_id reclaim` 有些许延迟。

```bash
ceph config set mon auth_allow_insecure_global_id_reclaim false
```

查看 Ceph 版本：

```
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph -v
ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
```

### 存储池

创建一个存储池，指定 pg 数量 64，副本数 3。

```
ceph osd pool create nomad 64 3
ceph osd pool ls
```

指定存储池作为 RBD 使用。
```
ceph osd pool application enable nomad rbd
```

创建 image，如下：

```
rbd create nomad/ceph-volume --size 2T --image-format 2 --image-feature  layering
```

初始化并挂载在本地。

```
rbd map nomad/ceph-volume
sudo mkfs.xfs /dev/rbd0 -f

mkdir -p /mnt/rbd0
mount /dev/rbd0 /mnt/rbd0
```

### 监控

**1、Dashboard**

从 L 版本开始，Ceph 提供了原生的 Dashboard 功能，通过 Dashboard 对 Ceph 集群状态查看和基本管理。

所有节点都需要安装：

```bash
yum install ceph-mgr-dashboard -y
```

接下来只需要在主节点执行，启用。

```bash
ceph mgr module enable dashboard  --force
```

修改默认配置：

```bash
ceph config set mgr mgr/dashboard/server_addr 0.0.0.0
ceph config set mgr mgr/dashboard/server_port 7000 
ceph config set mgr mgr/dashboard/ssl false
```

创建一个 dashboard 登录用户名密码。

```bash
echo "123456" >password.txt 
ceph dashboard ac-user-create admin administrator -i password.txt 
```

查看访问方式：

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph mgr services
{
    "dashboard": "http://dx-lt-yd-zhejiang-jinhua-5-10-104-2-23:7000/",
}
```

后面如果修改配置，重启生效：

```bash
ceph mgr module disable dashboard
ceph mgr module enable dashboard
```

**2、Prometheus**

启用 MGR Prometheus 插件。

```bash
ceph mgr module enable prometheus
```

开启 RBD 相关指标。

```bash
ceph config set mgr mgr/prometheus/rbd_stats_pools nomad
```

测试 promtheus 指标接口。

```bash
curl 127.0.0.1:9283/metrics
```

查看访问方式：

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph mgr services
{
    "dashboard": "http://dx-lt-yd-zhejiang-jinhua-5-10-104-2-23:7000/",
    "prometheus": "http://dx-lt-yd-zhejiang-jinhua-5-10-104-2-23:9283/"
}
```


## 命令

基础命令，查看集群健康详情。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-2-12 ~]# ceph health detail
HEALTH_WARN 95 pgs not deep-scrubbed in time; 100 pgs not scrubbed in time
PG_NOT_DEEP_SCRUBBED 95 pgs not deep-scrubbed in time
    pg 1.fb9 not deep-scrubbed since 2023-07-11 12:37:44.526932
    pg 1.f19 not deep-scrubbed since 2023-07-20 23:57:06.398897
    pg 1.ec5 not deep-scrubbed since 2023-07-17 01:59:38.137176
    pg 1.eac not deep-scrubbed since 2023-07-02 06:58:50.516897
    pg 1.68f not deep-scrubbed since 2023-06-27 23:26:45.383738
    pg 1.603 not deep-scrubbed since 2023-06-17 14:56:39.413443
    pg 1.5c8 not deep-scrubbed since 2023-06-25 16:32:47.583276
    pg 1.5b1 not deep-scrubbed since 2023-07-01 12:58:55.506933
```

### OSD

本地执行 OSD 创建命令。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# /usr/sbin/ceph-volume --cluster ceph lvm create --bluestore --data /dev/sdc
```

查看所有 OSD 分布。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph osd tree
ID CLASS WEIGHT   TYPE NAME                                       STATUS REWEIGHT PRI-AFF
-1       65.49600 root default
-7       21.83200     host dx-lt-yd-zhejiang-jinhua-5-10-104-2-23
 2   hdd  3.63899         osd.2                                       up  1.00000 1.00000
 3   hdd  3.63899         osd.3                                       up  1.00000 1.00000
 6   hdd  3.63899         osd.6                                       up  1.00000 1.00000
 9   hdd  3.63899         osd.9                                       up  1.00000 1.00000
12   hdd  3.63899         osd.12                                      up  1.00000 1.00000
15   hdd  3.63899         osd.15                                      up  1.00000 1.00000
-3       21.83200     host dx-lt-yd-zhejiang-jinhua-5-10-104-2-24
 0   hdd  3.63899         osd.0                                       up  1.00000 1.00000
 4   hdd  3.63899         osd.4                                       up  1.00000 1.00000
 7   hdd  3.63899         osd.7                                       up  1.00000 1.00000
10   hdd  3.63899         osd.10                                      up  1.00000 1.00000
13   hdd  3.63899         osd.13                                      up  1.00000 1.00000
16   hdd  3.63899         osd.16                                      up  1.00000 1.00000
-5       21.83200     host dx-lt-yd-zhejiang-jinhua-5-10-104-2-25
 1   hdd  3.63899         osd.1                                       up  1.00000 1.00000
 5   hdd  3.63899         osd.5                                       up  1.00000 1.00000
 8   hdd  3.63899         osd.8                                       up  1.00000 1.00000
11   hdd  3.63899         osd.11                                      up  1.00000 1.00000
14   hdd  3.63899         osd.14                                      up  1.00000 1.00000
17   hdd  3.63899         osd.17                                      up  1.00000 1.00000
```

查看所有 OSD 概览信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph osd df
ID CLASS WEIGHT  REWEIGHT SIZE    RAW USE DATA    OMAP    META     AVAIL   %USE VAR  PGS STATUS
 2   hdd 3.63899  1.00000 3.6 TiB  20 GiB  19 GiB 108 KiB 1024 MiB 3.6 TiB 0.54 0.90  50     up
 3   hdd 3.63899  1.00000 3.6 TiB  28 GiB  27 GiB  41 KiB 1024 MiB 3.6 TiB 0.76 1.26  72     up
 6   hdd 3.63899  1.00000 3.6 TiB  25 GiB  24 GiB 144 KiB 1024 MiB 3.6 TiB 0.66 1.09  63     up
 9   hdd 3.63899  1.00000 3.6 TiB  20 GiB  19 GiB  64 KiB 1024 MiB 3.6 TiB 0.53 0.87  49     up
12   hdd 3.63899  1.00000 3.6 TiB  22 GiB  21 GiB  44 KiB 1024 MiB 3.6 TiB 0.59 0.97  56     up
15   hdd 3.63899  1.00000 3.6 TiB  23 GiB  22 GiB  80 KiB 1024 MiB 3.6 TiB 0.61 1.01  58     up
 0   hdd 3.63899  1.00000 3.6 TiB  27 GiB  26 GiB 132 KiB 1024 MiB 3.6 TiB 0.72 1.19  69     up
 4   hdd 3.63899  1.00000 3.6 TiB  22 GiB  21 GiB  92 KiB 1024 MiB 3.6 TiB 0.59 0.98  55     up
 7   hdd 3.63899  1.00000 3.6 TiB  19 GiB  18 GiB  40 KiB 1024 MiB 3.6 TiB 0.52 0.86  48     up
10   hdd 3.63899  1.00000 3.6 TiB  23 GiB  22 GiB  68 KiB 1024 MiB 3.6 TiB 0.62 1.02  59     up
13   hdd 3.63899  1.00000 3.6 TiB  22 GiB  21 GiB  52 KiB 1024 MiB 3.6 TiB 0.58 0.96  54     up
16   hdd 3.63899  1.00000 3.6 TiB  21 GiB  20 GiB  88 KiB 1024 MiB 3.6 TiB 0.56 0.93  54     up
 1   hdd 3.63899  1.00000 3.6 TiB  23 GiB  22 GiB 108 KiB 1024 MiB 3.6 TiB 0.61 1.00  57     up
 5   hdd 3.63899  1.00000 3.6 TiB  20 GiB  19 GiB 313 KiB 1024 MiB 3.6 TiB 0.55 0.90  51     up
 8   hdd 3.63899  1.00000 3.6 TiB  27 GiB  26 GiB 108 KiB 1024 MiB 3.6 TiB 0.73 1.21  68     up
11   hdd 3.63899  1.00000 3.6 TiB  19 GiB  18 GiB  48 KiB 1024 MiB 3.6 TiB 0.52 0.86  48     up
14   hdd 3.63899  1.00000 3.6 TiB  24 GiB  23 GiB  84 KiB 1024 MiB 3.6 TiB 0.65 1.08  62     up
17   hdd 3.63899  1.00000 3.6 TiB  20 GiB  19 GiB  48 KiB 1024 MiB 3.6 TiB 0.54 0.88  51     up
                    TOTAL  65 TiB 406 GiB 388 GiB 1.6 MiB   18 GiB  65 TiB 0.61
MIN/MAX VAR: 0.86/1.26  STDDEV: 0.07
```

查看具体 OSD 的 BLOCK 信息。

```
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph-volume lvm list /dev/sdj

====== osd.8 =======

  [block]       /dev/ceph-4093f374-fc36-4768-ac98-c544d36be9b0/osd-block-ee85c7c9-1b37-4d69-bfa0-a12db586facf

      block device              /dev/ceph-4093f374-fc36-4768-ac98-c544d36be9b0/osd-block-ee85c7c9-1b37-4d69-bfa0-a12db586facf
      block uuid                9nwPUB-Z5rE-9TqH-vvEc-3x6M-D7ze-QeX3pC
      cephx lockbox secret
      cluster fsid              16b28327-7eca-494b-93fe-4218a156107a
      cluster name              ceph
      crush device class        None
      encrypted                 0
      osd fsid                  ee85c7c9-1b37-4d69-bfa0-a12db586facf
      osd id                    8
      osdspec affinity
      type                      block
      vdo                       0
      devices                   /dev/sdj
```

停止和启动 OSD 服务。 

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# systemctl stop ceph-osd@2
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# systemctl start ceph-osd@2
```


### POOL

查看集群所有的存储池。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph df
RAW STORAGE:
    CLASS     SIZE       AVAIL      USED        RAW USED     %RAW USED
    hdd       65 TiB     65 TiB     178 GiB      196 GiB          0.29
    TOTAL     65 TiB     65 TiB     178 GiB      196 GiB          0.29

POOLS:
    POOL      ID     PGS     STORED     OBJECTS     USED        %USED     MAX AVAIL
    nomad      1     512     71 GiB     560.91k     176 GiB      0.28        31 TiB
```

获取 pool 的相关参数并进行修改。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd pool get nomad size
size: 2
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd pool get nomad pg_num
pg_num: 64
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd pool set nomad pg_num 512
```

### RBD

获取 image 相关信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# rbd ls nomad
ceph-volume
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# rbd -p nomad info ceph-volume
rbd image 'ceph-volume':
	size 2 TiB in 524288 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 1254ebed8401
	block_name_prefix: rbd_data.1254ebed8401
	format: 2
	features: layering
	op_features:
	flags:
	create_timestamp: Wed Aug  9 11:41:55 2023
	access_timestamp: Wed Aug  9 19:52:11 2023
	modify_timestamp: Wed Aug  9 20:44:17 2023
```

### MGR

获取 mgr 服务相关信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph mgr dump
```

### CRUSH

打印当前 crush 相关配置。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph osd crush dump
```

### RULE

创建：

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph osd crush rule create-replicated rule-hdd default host hdd
```

设置：

```rule
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph osd pool set nomad crush_rule rule-hdd
```

修改：

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd getcrushmap -o compiled-crushmap
8
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# crushtool -d compiled-crushmap -o decompiled-crushmap
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# vim decompiled-crushmap
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# crushtool -c decompiled-crushmap -o new-crushmap
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd setcrushmap -i new-crushmap
```

### PG

查看 pg 的状态和分布情况。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph pg dump
......
OSD_STAT USED    AVAIL   USED_RAW TOTAL   HB_PEERS                            PG_SUM PRIMARY_PG_SUM
17        19 GiB 3.6 TiB   20 GiB 3.6 TiB         [0,2,3,4,6,7,9,12,13,15,16]     51             23
16        20 GiB 3.6 TiB   21 GiB 3.6 TiB          [1,3,5,8,9,11,12,14,15,17]     54             22
15        22 GiB 3.6 TiB   23 GiB 3.6 TiB     [0,1,4,5,7,8,10,11,13,14,16,17]     58             32
14        23 GiB 3.6 TiB   24 GiB 3.6 TiB          [0,3,4,6,7,10,12,13,15,16]     62             21
13        21 GiB 3.6 TiB   22 GiB 3.6 TiB      [1,2,3,5,6,8,9,11,12,14,15,17]     54             31
12        21 GiB 3.6 TiB   22 GiB 3.6 TiB     [0,1,4,5,7,8,10,11,13,14,16,17]     56             30
11        18 GiB 3.6 TiB   19 GiB 3.6 TiB         [0,2,3,4,6,7,9,10,12,13,16]     48             24
10        22 GiB 3.6 TiB   23 GiB 3.6 TiB      [1,2,3,5,6,8,9,11,12,14,15,17]     59             35
3         27 GiB 3.6 TiB   28 GiB 3.6 TiB      [0,1,2,4,5,7,8,10,11,13,14,17]     72             39
2         19 GiB 3.6 TiB   20 GiB 3.6 TiB     [1,3,4,5,7,8,10,11,13,14,16,17]     50             24
1         22 GiB 3.6 TiB   23 GiB 3.6 TiB      [0,2,3,4,6,7,9,10,12,13,15,16]     57             29
0         26 GiB 3.6 TiB   27 GiB 3.6 TiB [1,2,3,4,5,6,8,9,10,11,12,14,15,17]     69             40
4         21 GiB 3.6 TiB   22 GiB 3.6 TiB         [1,2,3,5,6,8,9,11,14,15,17]     55             31
5         19 GiB 3.6 TiB   20 GiB 3.6 TiB      [0,2,3,4,6,7,9,10,12,13,15,16]     51             21
6         24 GiB 3.6 TiB   25 GiB 3.6 TiB   [0,1,3,4,5,7,8,10,11,13,14,16,17]     63             32
7         18 GiB 3.6 TiB   19 GiB 3.6 TiB            [1,2,3,5,6,8,9,11,14,17]     48             23
8         26 GiB 3.6 TiB   27 GiB 3.6 TiB      [0,2,3,4,6,7,9,10,12,13,15,16]     68             34
9         19 GiB 3.6 TiB   20 GiB 3.6 TiB       [0,1,4,5,8,10,11,13,14,16,17]     49             21
sum      388 GiB  65 TiB  406 GiB  65 TiB
```

获取当前 osd 上 primary pg 的基本信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph pg ls-by-primary osd.5
PG    OBJECTS DEGRADED MISPLACED UNFOUND BYTES     OMAP_BYTES* OMAP_KEYS* LOG  STATE        SINCE VERSION     REPORTED    UP       ACTING   SCRUB_STAMP                DEEP_SCRUB_STAMP
1.8      1189        0         0       0 378081280           0          0 3033 active+clean   71m 1701'117659 1701:213562  [5,4]p5  [5,4]p5 2023-08-11 22:37:30.565692 2023-08-11 22:37:30.565692
1.10     1158        0         0       0 329056256           0          0 3249 active+clean   67m 1701'105715 1701:226836  [5,6]p5  [5,6]p5 2023-08-11 22:40:56.596985 2023-08-09 11:33:21.874603
1.18     1195        0         0       0 368934912           0          0 3080 active+clean   68m 1701'111229 1701:226586 [5,16]p5 [5,16]p5 2023-08-11 22:39:46.167104 2023-08-09 11:33:21.874603
1.97     1137        0         0       0 434163712           0          0 3352 active+clean   52m 1701'100890 1701:247114 [5,12]p5 [5,12]p5 2023-08-11 22:56:13.836447 2023-08-09 11:33:21.874603
1.9c     1136        0         0       0 398704640           0          0 4385 active+clean   52m 1701'102417 1701:266931 [5,13]p5 [5,13]p5 2023-08-11 22:56:26.655758 2023-08-11 22:56:26.655758
1.c9     1144        0         0       0 344027136           0          0 4901 active+clean   52m  1701'99001 1701:216962 [5,10]p5 [5,10]p5 2023-08-11 22:56:26.962591 2023-08-09 11:33:21.874603
1.d9     1164        0         0       0 385499136           0          0 3384 active+clean   52m 1701'109884 1701:230833 [5,15]p5 [5,15]p5 2023-08-11 22:56:27.937661 2023-08-10 20:24:38.161190
1.df     1147        0         0       0 354439168           0          0 3257 active+clean   52m 1701'100467 1701:273232 [5,10]p5 [5,10]p5 2023-08-11 22:56:29.934775 2023-08-09 11:33:21.874603
1.e3     1146        0         0       0 352804864           0          0 3527 active+clean   51m 1701'115509 1701:311209 [5,16]p5 [5,16]p5 2023-08-11 22:56:34.927850 2023-08-11 21:36:33.341214
1.e8     1102        0         0       0 365084672           0          0 3048 active+clean   51m 1701'107744 1701:282304  [5,3]p5  [5,3]p5 2023-08-11 22:56:39.886345 2023-08-10 16:54:12.475772
1.f4     1177        0         0       0 343142400           0          0 3247 active+clean   51m  1701'99630 1701:269765 [5,10]p5 [5,10]p5 2023-08-11 22:56:42.882092 2023-08-09 11:33:21.874603
1.ff     1142        0         0       0 374489088           0          0 3720 active+clean   51m 1701'111168 1701:334898 [5,16]p5 [5,16]p5 2023-08-11 22:56:43.908609 2023-08-10 19:20:36.589840
1.119    1134        0         0       0 377098240           0          0 3450 active+clean   51m 1701'109950 1701:227026 [5,10]p5 [5,10]p5 2023-08-11 22:57:17.188768 2023-08-10 20:24:38.161190
1.144    1152        0         0       0 407887872           0          0 3045 active+clean   51m 1701'115413 1701:255511  [5,3]p5  [5,3]p5 2023-08-11 22:56:45.965646 2023-08-10 19:00:04.712304
1.14f    1140        0         0       0 372760576           0          0 3484 active+clean   51m 1701'103580 1701:268104  [5,0]p5  [5,0]p5 2023-08-11 22:57:08.216644 2023-08-09 11:33:21.874603
1.15f    1159        0         0       0 385597440           0          0 3384 active+clean   51m 1701'100594 1701:272070 [5,12]p5 [5,12]p5 2023-08-11 22:56:46.999844 2023-08-09 11:33:21.874603
1.17a    1138        0         0       0 384913408           0          0 3263 active+clean   51m  1701'96836 1701:227578  [5,6]p5  [5,6]p5 2023-08-11 22:57:13.190288 2023-08-09 11:33:21.874603
1.19f    1087        0         0       0 375009280           0          0 3376 active+clean   51m 1701'100586 1701:273153  [5,9]p5  [5,9]p5 2023-08-11 22:57:18.188223 2023-08-09 11:33:21.874603
1.1a4    1141        0         0       0 404832256           0          0 5535 active+clean   51m 1701'100090 1701:217159  [5,7]p5  [5,7]p5 2023-08-11 22:57:19.168426 2023-08-09 11:33:21.874603
1.1b2    1167        0         0       0 365268992           0          0 3353 active+clean   51m 1701'105670 1701:243116 [5,12]p5 [5,12]p5 2023-08-11 22:57:24.224763 2023-08-09 11:33:21.874603
1.1f8    1175        0         0       0 399880192           0          0 3657 active+clean   52m 1701'119453 1701:290254  [5,2]p5  [5,2]p5 2023-08-11 22:41:16.365644 2023-08-11 21:47:39.203228
```

获取当前 osd 上 all pg 的基本信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-25 ~]# ceph pg ls-by-osd osd.5
```

## 相关链接

[awesome-resty](https://github.com/bungle/awesome-resty)

