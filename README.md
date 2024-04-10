## 目录

* [部署](#部署)
    * [规划](#规划)
    * [初始化](#初始化)
    * [部署方式](#部署方式)
    * [安装](#安装)
    * [存储池](#存储池)
    * [监控](#监控)
    * [SSD](#SSD)

* [卸载](#卸载)
    * [移除OSD](#移除OSD)
    * [清理OSD缓存](#清理OSD缓存)
    * [清理HOST缓存](#清理HOST缓存)

* [命令](#命令)
    * [OSD](#osd)
    * [POOL](#pool)
    * [RBD](#rbd)
    * [MGR](#mgr)
    * [CRUSH](#crush)
    * [RULE](#rule)
    * [PG](#pg)
    * [IOSTAT](#iostat)

* [管理](#管理)
    * [Recovery](#Recovery)
    * [获取配置](#获取配置)
    * [日志级别](#日志级别)
    * [停机维护](#停机维护)

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

注：MGR 是 Ceph L 版本新增加的组件，主要作用是分担和扩展 monitor 的部分功能，减轻 monitor 的负担， 建议每台 monitor 节点都部署一个 mgr，以实现相同级别的高可用。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ceph-cluster]# ceph -s
  cluster:
    id:     16b28327-7eca-494b-93fe-4218a156107a
    health: HEALTH_WARN
            mons are allowing insecure global_id reclaim
......
```

解决 `mon is allowing insecure global_id reclaim` 有些许延迟。

```bash
ceph config set mon auth_allow_insecure_global_id_reclaim false
```

最后查看 Ceph 版本：

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
echo "123456" > password.txt 
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

### SSD

可以使用 NVMe 高性能 SSD 做元数据的存储，

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# mkfs.xfs -f /dev/nvme0n1
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mktable gpt
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.wal1 1M 50G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.wal2 50G 100G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.wal3 100G 150G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.wal4 150G 200G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.wal5 200G 250G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.wal6 250G 300G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.db1 300G 500G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.db2 500G 700G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.db3 700G 900G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.db4 900G 1100G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.db5 1100G 1300G
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 mkpart osd.db6 1300G 1500G

[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# parted -s /dev/nvme0n1 print
Model: NVMe Device (nvme)
Disk /dev/nvme0n1: 2000GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name      Flags
 1      1049kB  50.0GB  50.0GB               osd.wal1
 2      50.0GB  100GB   50.0GB               osd.wal2
 3      100GB   150GB   50.0GB               osd.wal3
 4      150GB   200GB   50.0GB               osd.wal4
 5      200GB   250GB   50.0GB               osd.wal5
 6      250GB   300GB   50.0GB               osd.wal6
 7      300GB   500GB   200GB                osd.db1
 8      500GB   700GB   200GB                osd.db2
 9      700GB   900GB   200GB                osd.db3
10      900GB   1100GB  200GB                osd.db4
11      1100GB  1300GB  200GB                osd.db5
12      1300GB  1500GB  200GB                osd.db6
```

部署 osd 指定 db 和 wal 的存储地址。

```bash
$ ceph-volume lvm create --bluestore --data  /dev/sdd --block.db  /dev/nvme0n1p9 --block.wal /dev/nvme0n1p3
```

查看 osd 的信息。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]#  ceph-volume lvm list /dev/sdc
====== osd.9 =======

  [block]       /dev/ceph-992f2429-562f-47da-8001-1398c9d3925b/osd-block-d8aec7ef-611e-491f-957c-335ae16623eb

      block device              /dev/ceph-992f2429-562f-47da-8001-1398c9d3925b/osd-block-d8aec7ef-611e-491f-957c-335ae16623eb
      block uuid                qHobxU-XUNs-hAXU-JxEM-5pOF-dorm-YWfxbr
      cephx lockbox secret
      cluster fsid              8490f6a8-d99d-43bd-85fb-43abc81bd261
      cluster name              ceph
      crush device class        None
      db device                 /dev/nvme0n1p8
      db uuid                   235844c6-4c1e-4ab1-a7c0-c73f44f6c9a5
      encrypted                 0
      osd fsid                  d8aec7ef-611e-491f-957c-335ae16623eb
      osd id                    9
      osdspec affinity
      type                      block
      vdo                       0
      wal device                /dev/nvme0n1p2
      wal uuid                  3570dafa-f0c6-4595-98bc-44dd1375780f
      devices                   /dev/sdc

  [db]          /dev/nvme0n1p8

      PARTUUID                  235844c6-4c1e-4ab1-a7c0-c73f44f6c9a5
```

## 卸载

### 移除OSD

为了防止两次数据迁移，需要先调整 osd 的 crush weight。

```bash
# ceph osd crush reweight osd.1 3
# ceph osd crush reweight osd.1 2
# ceph osd crush reweight osd.1 0
```

停止 osd 节点服务。

```bash
# 命令确认停止osd不会影响数据可用性。
$ ceph osd ok-to-stop osd.1

$ systemctl stop ceph-osd@1
```

将节点状态标记为 out，开始迁移数据。

```bash
$ ceph osd down osd.1
$ ceph osd out osd.1
```

迁移完数据之后进行下列操作，确认删除 osd 不会影响数据可用性。

```bash
$ ceph osd safe-to-destroy osd.1
```

将 osd 从 CRUSH map 中移除。

```bash
$ ceph osd crush remove osd.1
```

删除鉴权秘钥(不删除编号会占住）。

```bash
$ ceph auth rm osd.1
```

最后从 OSDMap 中移除 osd，主要清理状态信息，包括通信地址在内的元数据等。

```bash
$ ceph osd rm osd.1
```

### 清理OSD缓存

执行 `ceph-volume lvm list` 命令查到其中的 osd 编号并没有在集群中，osd.1 是残留的信息。

```bash
$ ceph-volume lvm list
```

查看 lvm 分区信息。

```bash
$ lsblk -l
```

使用 `dmsetup remove` 进行清理。

```bash
$ dmsetup ls

$ dmsetup remove  ceph--56b5a16e--a01d4b97731b-osd--block--a0a15a95
```

再次执行 `ceph-volume lvm list` 时，残留信息被清理。

### 清理HOST缓存

通过命令 `ceph osd tree` 查看，可以查看有的主机已经没有 osd 节点，可以进行清理

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-1-159 ~]# ceph osd tree
254   hdd   3.63869         osd.254                                      up  1.00000 1.00000
-64               0     host dx-lt-yd-zhejiang-jinhua-5-10-104-1-21
-21        43.66425     host dx-lt-yd-zhejiang-jinhua-5-10-104-1-37
 52   hdd   3.63869         osd.52                                       up  1.00000 1.00000
```

执行清理

```bash
ceph osd crush remove host dx-lt-yd-zhejiang-jinhua-5-10-104-1-21
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

本地执行 osd 创建命令。

```bash
$ /usr/sbin/ceph-volume --cluster ceph lvm create --bluestore --data /dev/sdc
```

查看 osd 状态。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-1-159 ~]# ceph osd stat
156 osds: 154 up (since 2d), 154 in (since 8w); epoch: e132810
```

查看所有 osd 分布。

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

查看所有 osd 磁盘使用状态。

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

查看所有 osd 映射信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-1-159 ~]# ceph osd dump
```

查看具体 osd 的 block 信息。

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

停止和启动 osd 服务。

```bash
$ systemctl stop ceph-osd@2
$ systemctl start ceph-osd@2
```

查看 osd 核心配置。

```
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 ~]# ceph config show osd.44
NAME                          VALUE                                                                                                                                 SOURCE   OVERRIDES   IGNORES
auth_client_required          cephx                                                                                                                                 file
auth_cluster_required         cephx                                                                                                                                 file
auth_service_required         cephx                                                                                                                                 file
daemonize                     false                                                                                                                                 override
keyring                       $osd_data/keyring                                                                                                                     default
leveldb_log                                                                                                                                                         default
mon_host                      10.103.3.134,10.103.3.137,10.103.3.139                                                                                                file
mon_initial_members           dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134, dx-lt-yd-hebei-shijiazhuang-10-10-103-3-137, dx-lt-yd-hebei-shijiazhuang-10-10-103-3-139 file
osd_max_backfills             3                                                                                                                                     override (mon[3])
osd_recovery_max_active       9                                                                                                                                     override (mon[9])
osd_recovery_max_single_start 1                                                                                                                                     mon
osd_recovery_sleep            0.500000                                                                                                                              mon
rbd_default_features          1                                                                                                                                     mon      default[61]
rbd_default_format            2                                                                                                                                     mon
setgroup                      ceph                                                                                                                                  cmdline
setuser                       ceph
```

查看 osd commit 和 apply 延迟信息。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-90 ~]# ceph osd perf
osd commit_latency(ms) apply_latency(ms)
  0                109               109
  6                  0                 0
  3                  1                 1
 17                  1                 1
 16                  0                 0
  5                  0                 0
  4                  0                 0
```

查看 osd 状态信息。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 ~]# ceph osd status
+-----+---------------------------------------------+-------+-------+--------+---------+--------+---------+-----------+
|  id |                     host                    |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+-----+---------------------------------------------+-------+-------+--------+---------+--------+---------+-----------+
|  0  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 3760G | 3690G |    7   |  6055k  |    1   |   179k  | exists,up |
|  1  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 3791G | 3660G |   25   |  4291k  |    3   |   426k  | exists,up |
|  2  |  dx-lt-yd-hebei-shijiazhuang-10-10-103-3-44 | 1302G |  485G |   63   |  45.6M  |    0   |     0   | exists,up |
|  3  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 4267G | 3184G |   15   |  7214k  |    8   |   345k  | exists,up |
|  4  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 2715G | 4735G |    6   |  2773k  |    5   |   609k  | exists,up |
|  5  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 3290G | 4161G |   15   |  4640k  |    7   |   580k  | exists,up |
|  6  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 3947G | 3504G |   14   |  6533k  |   18   |  2003k  | exists,up |
|  7  |  dx-lt-yd-hebei-shijiazhuang-10-10-103-3-41 | 1368G |  419G |   20   |  25.8M  |    0   |     0   | exists,up |
|  8  | dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 | 3614G | 3836G |   12   |  5960k  |    7   |   804k  | exists,up |
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

获取 pool 的相关参数和进行参数修改。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd pool get nomad size
size: 2
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd pool get nomad pg_num
pg_num: 64
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-23 ~]# ceph osd pool set nomad pg_num 512
```

获取 pool 的所有参数。

```
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-10-92 ~]# ceph osd pool get nomad all
size: 2
min_size: 1
pg_num: 512
pgp_num: 512
crush_rule: replicated_rule
hashpspool: true
nodelete: false
nopgchange: false
nosizechange: false
write_fadvise_dontneed: false
noscrub: true
nodeep-scrub: true
use_gmt_hitset: 1
fast_read: 0
pg_autoscale_mode: warn
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

查看挂载信息。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-3-139 ceph]# rbd showmapped
id pool  namespace image                                        snap device
0  nomad           csi-vol-1c563042-de7c-11ed-9750-6c92bf9d36fc -    /dev/rbd0
1  nomad           test-image                                   -    /dev/rbd1
2  nomad           csi-vol-88daec7d-7195-11ee-bb87-246e96073af4 -    /dev/rbd2
3  nomad           csi-vol-e78c5c60-84d2-11ed-9fe3-0894ef7dd406 -    /dev/rbd3
```

取消挂载。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-3-139 ceph]# rbd unmap -o force /dev/rbd2

[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-3-139 ceph]# cat /sys/kernel/debug/ceph/380a1e72-da89-4041-8478-76383f5f6378.client636459/osdc
REQUESTS 0 homeless 0
LINGER REQUESTS
18446462598732840962	osd10	1.ac5aac28	1.c28	[10,51]/10	[10,51]/10	e445078	rbd_header.92dc4d5698745	0x20	14	WC/0
BACKOFFS
```

查看 rbd 所在的节点机器

```
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-4-17 ~]# rbd status nomad/csi-vol-9afdfd47-94b5-11ee-be28-e8611f394983
Watchers:
	watcher=10.104.5.13:0/4205102659 client.274090 cookie=18446462598732840971
```

### MGR

获取 mgr 服务相关信息。

```bash
$ ceph mgr dump
```

### CRUSH

打印当前 crush 相关配置。

```bash
$ ceph osd crush dump
```

### RULE

创建：

```bash
$ ceph osd crush rule create-replicated rule-hdd default host hdd
```

设置：

```rule
$ ceph osd pool set nomad crush_rule rule-hdd
```

修改：

```bash
$ ceph osd getcrushmap -o compiled-crushmap
8
$ crushtool -d compiled-crushmap -o decompiled-crushmap
$ vim decompiled-crushmap
$ crushtool -c decompiled-crushmap -o new-crushmap
$ ceph osd setcrushmap -i new-crushmap
```

### PG

获取所有 pg 的基本状态信息，可以用来查看 scrub 时间。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph pg ls
PG    OBJECTS DEGRADED MISPLACED UNFOUND BYTES     OMAP_BYTES* OMAP_KEYS* LOG  STATE        SINCE VERSION     REPORTED    UP         ACTING     SCRUB_STAMP                DEEP_SCRUB_STAMP
1.0      1165        0         0       0 515784704           0          0 3091 active+clean   20h 1703'148431 1703:292944   [8,15]p8   [8,15]p8 2023-08-14 17:14:44.751649 2023-08-09 11:33:21.874603
1.1      1231        0         0       0 459677696           0          0 3058 active+clean   29h 1703'148800 1703:318795    [3,0]p3    [3,0]p3 2023-08-14 08:38:22.575081 2023-08-09 11:33:21.874603
1.2      1147        0         0       0 500555776           0          0 3015 active+clean   29h 1703'203541 1703:388279   [8,16]p8   [8,16]p8 2023-08-14 09:02:27.178658 2023-08-09 11:33:21.874603
1.3      1225        0         0       0 558604288           0          0 3066 active+clean   27h 1703'147294 1703:332381    [4,1]p4    [4,1]p4 2023-08-14 11:10:06.946977 2023-08-13 08:39:59.122150
1.4      1256        0         0       0 619810816           0          0 3045 active+clean   25h 1703'197198 1703:411128    [3,8]p3    [3,8]p3 2023-08-14 12:23:55.370157 2023-08-10 19:00:04.712304
1.5      1183        0         0       0 516734976           0          0 3026 active+clean    3h 1703'150475 1703:352785 [15,10]p15 [15,10]p15 2023-08-15 10:49:32.150982 2023-08-09 11:33:21.874603
1.6      1158        0         0       0 516968448           0          0 3072 active+clean   33h 1703'155869 1703:351394   [6,14]p6   [6,14]p6 2023-08-14 05:06:41.818069 2023-08-10 14:58:40.268083
1.7      1154        0         0       0 494632960           0          0 3010 active+clean   31h 1703'142384 1703:341985  [14,6]p14  [14,6]p14 2023-08-14 06:44:28.852279 2023-08-13 01:25:37.973756
1.8      1228        0         0       0 541659136           0          0 3017 active+clean   24h 1703'206843 1703:389781    [5,4]p5    [5,4]p5 2023-08-14 14:01:58.874771 2023-08-11 22:37:30.565692
1.9      1188        0         0       0 501682176           0          0 3014 active+clean    7h 1703'175567 1703:361147    [1,3]p1    [1,3]p1 2023-08-15 07:09:57.125092 2023-08-09 11:33:21.874603
```

查看 pg 的基本状态和分布情况，输出更详细的信息。其中 Omap 统计信息依赖深度扫描时收集，数据只能作为参考，下同。

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

查看特殊状态 pg 的详情。

```bash
[root@dx-lt-yd-hebei-shijiazhuang-10-10-103-3-134 ~]# ceph pg dump_stuck
PG_STAT STATE                                           UP          UP_PRIMARY ACTING      ACTING_PRIMARY
1.e87                     active+remapped+backfill_wait    [23,113]         23    [23,116]             23
1.e7c                       active+remapped+backfilling    [113,87]        113     [17,89]             17
1.e76                     active+remapped+backfill_wait     [21,82]         21    [21,107]             21
1.e70                     active+remapped+backfill_wait    [33,109]         33     [33,25]             33
1.e61                       active+remapped+backfilling    [30,108]         30     [30,57]             30
1.e60                     active+remapped+backfill_wait      [62,9]         62      [9,26]              9
1.e2c                     active+remapped+backfill_wait    [116,66]        116    [116,10]            116
1.e21                     active+remapped+backfill_wait     [64,11]         64    [11,103]             11
1.dff                       active+remapped+backfilling    [111,27]        111     [27,17]             27
1.dc3                       active+remapped+backfilling     [73,32]         73     [32,94]             32
1.daa                       active+remapped+backfilling     [88,82]         88     [88,58]             88
1.d1d                     active+remapped+backfill_wait    [111,58]        111     [26,76]             26
```

获取指定 osd 上做为 primary pg 的基本状态信息。

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

获取指定 osd 上 all pg 的基本状态信息，数据指标和上面一致。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph pg ls-by-osd osd.5
PG    OBJECTS DEGRADED MISPLACED UNFOUND BYTES     OMAP_BYTES* OMAP_KEYS* LOG  STATE        SINCE VERSION     REPORTED    UP        ACTING    SCRUB_STAMP                DEEP_SCRUB_STAMP
1.8      1228        0         0       0 541659136           0          0 3086 active+clean   24h 1703'207512 1703:391129   [5,4]p5   [5,4]p5 2023-08-14 14:01:58.874771 2023-08-11 22:37:30.565692
1.10     1192        0         0       0 471662592           0          0 3052 active+clean    8h 1703'138027 1703:289376   [5,6]p5   [5,6]p5 2023-08-15 06:07:13.350737 2023-08-09 11:33:21.874603
1.18     1229        0         0       0 511541248           0          0 3064 active+clean   26h 1703'219513 1703:439831  [5,16]p5  [5,16]p5 2023-08-14 12:01:21.151893 2023-08-14 12:01:21.151893
1.70     1237        0         0       0 586428416           0          0 3043 active+clean   24h 1703'188548 1703:353307   [2,5]p2   [2,5]p2 2023-08-14 14:23:26.260207 2023-08-11 17:28:31.199338
1.97     1170        0         0       0 572575744           0          0 3090 active+clean   22h 1703'168454 1703:379925  [5,12]p5  [5,12]p5 2023-08-14 15:53:23.611347 2023-08-09 11:33:21.874603
1.9c     1168        0         0       0 532922368           0          0 3060 active+clean   24h 1703'174105 1703:407977  [5,13]p5  [5,13]p5 2023-08-14 13:47:38.192312 2023-08-11 22:56:26.655758
1.b8     1164        0         0       0 545398784           0          0 3081 active+clean    2h 1703'161378 1703:366626 [15,5]p15 [15,5]p15 2023-08-15 11:29:00.295327 2023-08-15 11:29:00.295327
1.c8     1149        0         0       0 523264000           0          0 3092 active+clean   28h 1703'196036 1703:375087   [9,5]p9   [9,5]p9 2023-08-14 10:27:15.350574 2023-08-10 22:14:20.771845
1.c9     1183        0         0       0 507604992           0          0 3100 active+clean    8h 1703'142302 1703:301476  [5,10]p5  [5,10]p5 2023-08-15 05:37:37.965928 2023-08-09 11:33:21.874603
1.d9     1200        0         0       0 536494080           0          0 3009 active+clean   26h 1703'127113 1703:262978  [5,15]p5  [5,15]p5 2023-08-14 12:13:10.846808 2023-08-10 20:24:38.161190
1.dc     1177        0         0       0 497799168           0          0 3013 active+clean    3h 1703'163892 1703:391947 [13,5]p13 [13,5]p13 2023-08-15 10:55:36.024320 2023-08-09 11:33:21.874603
1.df     1177        0         0       0 480268288           0          0 3040 active+clean   23h 1703'133319 1703:336717  [5,10]p5  [5,10]p5 2023-08-14 15:02:17.859279 2023-08-09 11:33:21.874603
1.e3     1173        0         0       0 461873152           0          0 3074 active+clean   28h 1703'161053 1703:400210  [5,16]p5  [5,16]p5 2023-08-14 10:06:55.247139 2023-08-11 21:36:33.34121
```

获取当前集群 pg 状态。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph pg stat
128 pgs: 67 active+undersized+degraded, 61 active+clean; 35 GiB data, 106 GiB used, 2.1 TiB / 2.2 TiB avail; 4642/27156 objects degraded (17.094%)
```

如果 pg 出现不一致，可以尝试执行命令对 pg 进行修复。

```bash
ceph pg repair 1.1f8
```

更多命令：

```bash
ceph pg dump
ceph pg dump all
ceph pg dump summary
ceph pg dump pgs
ceph pg dump pools
ceph pg ls
```

### IOSTAT

查看集群 IOPS、读写带宽信息。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-1-159 ~]# ceph iostat
+--------------------------------------------+--------------------------------------------+--------------------------------------------+--------------------------------------------+--------------------------------------------+--------------------------------------------+
|                                       Read |                                      Write |                                      Total |                                  Read IOPS |                                 Write IOPS |                                 Total IOPS |
+--------------------------------------------+--------------------------------------------+--------------------------------------------+--------------------------------------------+--------------------------------------------+--------------------------------------------+
|                                  149 MiB/s |                                  381 MiB/s |                                  530 MiB/s |                                       1915 |                                       1455 |                                       3370 |
|                                  149 MiB/s |                                  381 MiB/s |                                  530 MiB/s |                                       1915 |                                       1455 |                                       3370 |
|                                  149 MiB/s |                                  382 MiB/s |                                  531 MiB/s |                                       1917 |                                       1457 |                                       3375 |
|                                  149 MiB/s |                                  382 MiB/s |                                  531 MiB/s |                                       1917 |                                       1457 |                                       3375 |
|                                  233 MiB/s |                                  525 MiB/s |                                  759 MiB/s |                                       3007 |                                       2157 |                                       5164 |
|                                  233 MiB/s |                                  525 MiB/s |                                  759 MiB/s |                                       3007 |                                       2157 |                                       5164 |
```

## 管理

### Recovery

首先，通过命令查看 osd 影响 recovery 速度的关键配置项。

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-1-159 ~]# ceph daemon osd.13 config show | egrep "osd_max_backfills|osd_recovery_max_active|osd_recovery_sleep|osd_recovery_op_priority|osd_recovery_max_single_start"
    "osd_max_backfills": "1",
    "osd_recovery_max_active": "1",
    "osd_recovery_max_single_start": "1",
    "osd_recovery_op_priority": "3",
    "osd_recovery_sleep": "0.500000",
    "osd_recovery_sleep_hdd": "0.100000",
    "osd_recovery_sleep_hybrid": "0.025000",
    "osd_recovery_sleep_ssd": "0.000000",
```

核心影响恢复速度的参数：

* osd_max_backfills：由于一个 osd 承载了多个 pg,所以一个 osd 中的 pg 很大可能需要做 recovery。 这个参数就是设置每个 osd 最多能让 osd_max_backfills 个 pg 进行同时做
  backfill。

* osd_recovery_op_priority：osd 修复操作的优先级，可小于该值；这个值越小，recovery 优先级越高。 高优先级会导致集群的性能降级直到 recovery 结束。

* osd_recovery_max_active：一个 osd 上可以承载多个 pg，可能好几个 pg 都需要 recovery， 这个值限定该 osd 最多同时有多少 pg 做 recovery。

* osd_recovery_max_single_start： 未知

* osd_recovery_sleep：每个 recovery 操作之间的间隔时间，单位是 ms。

修改配置提高 recovery 速度，同时注意观察集群延迟情况。

```bash
$ ceph tell "osd.*" injectargs --osd_max_backfills=15
$ ceph tell "osd.*" injectargs --osd_recovery_max_active=15
$ ceph tell "osd.*" injectargs --osd_recovery_max_single_start=10
$ ceph tell "osd.*" injectargs --osd_recovery_sleep=0.3
```

### 获取配置

获取 osd 全部配置信息。

```bash
$ ceph daemon osd.0 config show
```

获取 mon 全部配置信息。

```bash
$ ceph daemon mon.dx-lt-yd-zhejiang-jinhua-5-10-104-1-159 config show
```

### 日志级别

查看当前日志级别。

```bash
$ ceph tell osd.0 config get debug_osd
15/20
```

设置日志级别。

```bash
$ ceph tell osd.0 config set debug_osd 30/30
Set debug_osd to 30/30

$ ceph tell osd.0 config get debug_osd
30/30
```

所有 osd 服务都生效

```bash
$ ceph tell osd.* config set debug_osd 30/30
Set debug_osd to 30/30
```

### 停机维护

服务器节点需求重启，不迁移 osd 数据。

全局设置 noout，禁止数据平衡迁移。

```bash
$ ceph osd set noout
```

停止节点上的 osd 服务。

```bash
$ systemctl stop ceph-osd@{}
```

接下来进行服务器重启，然后恢复服务

```bash
$ ceph osd unset noout

$ systemctl start ceph-osd@{}
```

## 相关链接

[pg-states](https://docs.ceph.com/en/latest/dev/placement-group/#user-visible-pg-states)

[peering](https://docs.ceph.com/en/latest/dev/peering/)

[speed up osd recovery](https://www.suse.com/support/kb/doc/?id=000019693)
