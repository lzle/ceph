## 目录

* [部署](#部署)
    * [规划](#规划)
    * [初始化](#初始化)
    * [部署方式](#部署方式)
    * [安装](#安装)
    * [监控](#监控)

    
    
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

使用 ceph-deploy 命令将配置文件和 admin key 复制到管理节点和 Ceph 节点，以便每次执行 ceph CLI 命令无需指定 monitor 地址和 ceph.client.admin.keyring

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

查看Ceph版本：

```
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph -v
ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
```

### 监控

**1、Dashboard**

从 L 版本开始，Ceph 提供了原生的 Dashboard 功能，通过 Dashboard 对 Ceph 集群状态查看和基本管理。

所有节点都需要安装

```bash
yum install ceph-mgr-dashboard -y
```

接下来只需要在主节点执行，启用

```bash
ceph mgr module enable dashboard  --force
```

修改默认配置

```bash
ceph config set mgr mgr/dashboard/server_addr 0.0.0.0
ceph config set mgr mgr/dashboard/server_port 7000 
ceph config set mgr mgr/dashboard/ssl false
```

创建一个 dashboard 登录用户名密码

```bash
echo "123456" >password.txt 
ceph dashboard ac-user-create admin administrator -i password.txt 
```

查看访问方式

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

启用 MGR Prometheus 插件

```bash
ceph mgr module enable prometheus

```

测试 promtheus 指标接口

```bash
curl 127.0.0.1:9283/metrics
```

查看访问方式

```bash
[root@dx-lt-yd-zhejiang-jinhua-5-10-104-2-24 ~]# ceph mgr services
{
    "dashboard": "http://dx-lt-yd-zhejiang-jinhua-5-10-104-2-23:7000/",
    "prometheus": "http://dx-lt-yd-zhejiang-jinhua-5-10-104-2-23:9283/"
}
```


## 相关链接

[awesome-resty](https://github.com/bungle/awesome-resty)

