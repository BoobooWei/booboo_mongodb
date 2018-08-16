# MongoDB 副本集

> 2018-08-16 BoobooWei

[MongoDB 副本集的原理、搭建、应用](https://www.cnblogs.com/zhoujinyi/p/3554010.html)

## 概念

​      在了解了[这篇文章](http://www.cnblogs.com/zhoujinyi/p/3554196.html)之后，可以进行该篇文章的说明和测试。MongoDB 副本集（Replica Set）是有自动故障恢复功能的主从集群，有一个Primary节点和一个或多个Secondary节点组成。类似于MySQL的MMM架构。更多关于副本集的介绍请见[官网](http://docs.mongodb.org/manual/core/replication-introduction/)。也可以在google、baidu上查阅。

​      **副本集中数据同步过程**：**Primary节点写入数据，Secondary通过读取Primary的oplog得到复制信息，开始复制数据并且将复制信息写入到自己的oplog**。如果某个操作失败，则备份节点停止从当前数据源复制数据。如果某个备份节点由于某些原因挂掉了，当重新启动后，就会自动从oplog的最后一个操作开始同步，同步完成后，将信息写入自己的oplog，由于复制操作是先复制数据，复制完成后再写入oplog，有可能相同的操作会同步两份，不过MongoDB在设计之初就考虑到这个问题，将oplog的同一个操作执行多次，与执行一次的效果是一样的。**简单的说就是：**

当Primary节点完成数据操作后，Secondary会做出一系列的动作保证数据的同步：
1：检查自己local库的oplog.rs集合找出最近的时间戳。
2：检查Primary节点local库oplog.rs集合，找出大于此时间戳的记录。
3：将找到的记录插入到自己的oplog.rs集合中，并执行这些操作。

​       副本集的同步和主从同步一样，都是异步同步的过程，不同的是副本集有个自动故障转移的功能。其原理是：slave端从primary端获取日志，然后在自己身上完全顺序的执行日志所记录的各种操作（该日志是不记录查询操作的），这个日志就是local数据 库中的oplog.rs表，默认在64位机器上这个表是比较大的，占磁盘大小的5%，oplog.rs的大小可以在启动参数中设 定：--oplogSize 1000,单位是M。

​      注意：在副本集的环境中，要是所有的Secondary都宕机了，只剩下Primary。最后Primary会变成Secondary，不能提供服务。

## 部署复制集

> 如何用3台已有的 [`mongod`](http://www.mongoing.com/docs/reference/program/mongod.html#bin.mongod) 实例来部署一个由三个节点组成的 [*复制集*](http://www.mongoing.com/docs/reference/glossary.html#term-replica-set) 

### 概述

由三个节点组成的 [*复制集*](http://www.mongoing.com/docs/reference/glossary.html#term-replica-set) 为网络故障或是其他的系统故障提供了足够的冗余。该复制集也有足够的分布式读操作的能力。复制集应该保持奇数个节点，这也就保证了 [*选举*](http://www.mongoing.com/docs/core/replica-set-elections.html) 可以正常的进行。参见 `复制集概览` 以获得更多有关复制集设计的信息。

我们通常现从一个会成为复制集成员的 [`mongod`](http://www.mongoing.com/docs/reference/program/mongod.html#bin.mongod) 实例开始来配置复制集。然后为复制集新增实例。

### 要求

在生产环境的部署中，我们应该尽可能将复制集中得节点置于不同的机器上。当使用虚拟机的时候，我们应该将 [`mongod`](http://www.mongoing.com/docs/reference/program/mongod.html#bin.mongod) 实例置于拥有冗余电源和冗余网络的机器上。

在我们部署复制集之前，我们必须在 [*复制集*](http://www.mongoing.com/docs/reference/glossary.html#term-replica-set) 的每个机器上安装MongoDB实例。如果我们还没安装MongoDB，请参考 [*安装指南*](http://www.mongoing.com/docs/installation.html#tutorial-installation) 。

### 部署复制集的注意事项

#### 架构

在生产环境中，我们应该将每个节点部署在独立的机器上，并使用标准的MongoDB端口 `27017` 。使用 `bind_ip` 参数来限制访问MongoDB的应用程序的地址。

> 准备服务器

```
10.200.6.30
10.200.6.31
10.200.6.33
```

#### 连通性

确保各个节点之间可以正常通讯，且各个客户端都处于安全的可信的网络环境中。可以考虑以下事项：

- 建立虚拟的专用网络。确保各个节点之间的流量是在本地网络范围内路由的。（Establish a virtual private network. Ensure that your network topology routes all traffic between members within a single site over the local area network.）
- Configure access control to prevent connections from unknown clients to the replica set.
- 配置网络设置和防火墙规则来对将MongoDB的端口仅开放给应用程序，来让应用程序发的进出数据包可以与MongoDB正常交流。

最后请确保复制集各节点可以互相通过DNS或是主机名解析。我们需要配置DNS域名或是设置 `/etc/hosts` 文件来配置。

```shell
10.200.6.30 sh_01
10.200.6.31 sh_02
10.200.6.33 am_01
```

### 安装MongoDB

以下为安装脚本，下载到本地以后`bash install_mongodb.3.2.16.sh`

```
https://github.com/BoobooWei/booboo_mongodb/blob/master/scripts/install_mongodb.3.2.16.sh
```

### 修改配置文件

只需要开启：replSet 参数即可。格式为：

```
192.168.200.252: --replSet = mmm/192.168.200.245:27017  # mmm是副本集的名称，192.168.200.25:27017 为实例的位子。

192.168.200.245: --replSet = mmm/192.168.200.252:27017

192.168.200.25: --replSet = mmm/192.168.200.252:27017,192.168.200.245:27017 
```

**4：启动**

启动后会提示：

```
replSet info you may need to run replSetInitiate -- rs.initiate() in the shell -- if that is not already done
```

说明需要进行初始化操作，初始化操作只能执行一次。

**5：初始化副本集**

登入任意一台机器的MongoDB执行：因为是全新的副本集所以可以任意进入一台执行；要是有一台有数据，则需要在有数据上执行；要多台有数据则不能初始化。

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
zhoujy@zhoujy:~$ mongo --host=192.168.200.252
MongoDB shell version: 2.4.6
connecting to: 192.168.200.252:27017/test
> rs.initiate({"_id":"mmm","members":[
... {"_id":1,
... "host":"192.168.200.252:27017",
... "priority":1
... },
... {"_id":2,
... "host":"192.168.200.245:27017",
... "priority":1
... }
... ]})
{
    "info" : "Config now saved locally.  Should come online in about a minute.",
    "ok" : 1
}
######
"_id": 副本集的名称
"members": 副本集的服务器列表
"_id": 服务器的唯一ID
"host": 服务器主机
"priority": 是优先级，默认为1，优先级0为被动节点，不能成为活跃节点。优先级不位0则按照有大到小选出活跃节点。
"arbiterOnly": 仲裁节点，只参与投票，不接收数据，也不能成为活跃节点。

> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T04:03:53Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 76,
            "optime" : Timestamp(1392696191, 1),
            "optimeDate" : ISODate("2014-02-18T04:03:11Z"),
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 35,
            "optime" : Timestamp(1392696191, 1),
            "optimeDate" : ISODate("2014-02-18T04:03:11Z"),
            "lastHeartbeat" : ISODate("2014-02-18T04:03:52Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T04:03:53Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

**6：日志**

查看252上的日志：

```
Tue Feb 18 12:03:29.334 [rsMgr] replSet PRIMARY
…………
…………
Tue Feb 18 12:03:40.341 [rsHealthPoll] replSet member 192.168.200.245:27017 is now in state SECONDARY
```

至此，整个副本集已经搭建成功了。

上面的的副本集只有2台服务器，还有一台怎么添加？除了在初始化的时候添加，还有什么方法可以后期增删节点？
**二：维护操作**

**1：增删节点。**

把25服务加入到副本集中：

**rs.add("192.168.200.25:27017")**

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.add("192.168.200.25:27017")
{ "ok" : 1 }
mmm:PRIMARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T04:53:00Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 3023,
            "optime" : Timestamp(1392699177, 1),
            "optimeDate" : ISODate("2014-02-18T04:52:57Z"),
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 2982,
            "optime" : Timestamp(1392699177, 1),
            "optimeDate" : ISODate("2014-02-18T04:52:57Z"),
            "lastHeartbeat" : ISODate("2014-02-18T04:52:59Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T04:53:00Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 6,
            "stateStr" : "UNKNOWN",             #等一会就变成了 SECONDARY 
            "uptime" : 3,
            "optime" : Timestamp(0, 0),
            "optimeDate" : ISODate("1970-01-01T00:00:00Z"),
            "lastHeartbeat" : ISODate("2014-02-18T04:52:59Z"),
            "lastHeartbeatRecv" : ISODate("1970-01-01T00:00:00Z"),
            "pingMs" : 0,
            "lastHeartbeatMessage" : "still initializing"
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

把25服务从副本集中删除：

**rs.remove("192.168.200.25:27017")**

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.remove("192.168.200.25:27017")
Tue Feb 18 13:01:09.298 DBClientCursor::init call() failed
Tue Feb 18 13:01:09.299 Error: error doing query: failed at src/mongo/shell/query.js:78
Tue Feb 18 13:01:09.300 trying reconnect to 192.168.200.252:27017
Tue Feb 18 13:01:09.301 reconnect 192.168.200.252:27017 ok
mmm:PRIMARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T05:01:19Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 3522,
            "optime" : Timestamp(1392699669, 1),
            "optimeDate" : ISODate("2014-02-18T05:01:09Z"),
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 10,
            "optime" : Timestamp(1392699669, 1),
            "optimeDate" : ISODate("2014-02-18T05:01:09Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:01:19Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:01:18Z"),
            "pingMs" : 0,
            "lastHeartbeatMessage" : "syncing to: 192.168.200.252:27017",
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

192.168.200.25 的节点已经被移除。

**2：查看复制的情况**

 **db.printSlaveReplicationInfo()**

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> db.printSlaveReplicationInfo()
source:   192.168.200.245:27017
     syncedTo: Tue Feb 18 2014 13:02:35 GMT+0800 (CST)
         = 145 secs ago (0.04hrs)
source:   192.168.200.25:27017
     syncedTo: Tue Feb 18 2014 13:02:35 GMT+0800 (CST)
         = 145 secs ago (0.04hrs)
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

source：从库的ip和端口。

syncedTo：目前的同步情况，以及最后一次同步的时间。

从上面可以看出，在数据库内容不变的情况下他是不同步的，数据库变动就会马上同步。

**3：查看副本集的状态**

**rs.status()**

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T05:12:28Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 4191,
            "optime" : Timestamp(1392699755, 1),
            "optimeDate" : ISODate("2014-02-18T05:02:35Z"),
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 679,
            "optime" : Timestamp(1392699755, 1),
            "optimeDate" : ISODate("2014-02-18T05:02:35Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:12:27Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:12:27Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 593,
            "optime" : Timestamp(1392699755, 1),
            "optimeDate" : ISODate("2014-02-18T05:02:35Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:12:28Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:12:28Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

**4:副本集的配置**

**rs.conf()/rs.config()**

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.conf()
{
    "_id" : "mmm",
    "version" : 4,
    "members" : [
        {
            "_id" : 1,
            "host" : "192.168.200.252:27017"
        },
        {
            "_id" : 2,
            "host" : "192.168.200.245:27017"
        },
        {
            "_id" : 3,
            "host" : "192.168.200.25:27017"
        }
    ]
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

**5：操作Secondary**

默认情况下，Secondary是不提供服务的，即不能读和写。会提示：
error: { "$err" : "not master and slaveOk=false", "code" : 13435 }

在特殊情况下需要读的话则需要：
**rs.slaveOk() ，只对当前连接有效。**

```
mmm:SECONDARY> db.test.find()
error: { "$err" : "not master and slaveOk=false", "code" : 13435 }
mmm:SECONDARY> rs.slaveOk()
mmm:SECONDARY> db.test.find()
{ "_id" : ObjectId("5302edfa8c9151a5013b978e"), "a" : 1 }
```

**6：更新ing**

 

**三：测试**

**1：测试副本集数据复制功能**

在Primary（192.168.200.252:27017）上插入数据：

```
mmm:PRIMARY> for(var i=0;i<10000;i++){db.test.insert({"name":"test"+i,"age":123})}
mmm:PRIMARY> db.test.count()
10001
```

在Secondary上查看是否已经同步：

```
mmm:SECONDARY> rs.slaveOk()
mmm:SECONDARY> db.test.count()
10001
```

数据已经同步。

**2：测试副本集故障转移功能**

关闭Primary节点，查看其他2个节点的情况：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T05:38:54Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 5777,
            "optime" : Timestamp(1392701576, 2678),
            "optimeDate" : ISODate("2014-02-18T05:32:56Z"),
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 2265,
            "optime" : Timestamp(1392701576, 2678),
            "optimeDate" : ISODate("2014-02-18T05:32:56Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:38:54Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:38:53Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 2179,
            "optime" : Timestamp(1392701576, 2678),
            "optimeDate" : ISODate("2014-02-18T05:32:56Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:38:54Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:38:53Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}

#关闭
mmm:PRIMARY> use admin
switched to db admin
mmm:PRIMARY> db.shutdownServer()

#进入任意一台：
mmm:SECONDARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T05:47:41Z"),
    "myState" : 2,
    "syncingTo" : "192.168.200.25:27017",
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 0,
            "state" : 8,
            "stateStr" : "(not reachable/healthy)",
            "uptime" : 0,
            "optime" : Timestamp(1392701576, 2678),
            "optimeDate" : ISODate("2014-02-18T05:32:56Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:47:40Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:45:57Z"),
            "pingMs" : 0
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 5888,
            "optime" : Timestamp(1392701576, 2678),
            "optimeDate" : ISODate("2014-02-18T05:32:56Z"),
            "errmsg" : "syncing to: 192.168.200.25:27017",
            "self" : true
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 2292,
            "optime" : Timestamp(1392701576, 2678),
            "optimeDate" : ISODate("2014-02-18T05:32:56Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:47:40Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:47:39Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

看到192.168.200.25:27017 已经从 SECONDARY 变成了 PRIMARY。具体的信息可以通过日志文件得知。继续操作：

在新主上插入：

```
mmm:PRIMARY> for(var i=0;i<10000;i++){db.test.insert({"name":"test"+i,"age":123})}
mmm:PRIMARY> db.test.count()
20001
```

重启启动之前关闭的192.168.200.252:27017

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:SECONDARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T05:45:14Z"),
    "myState" : 2,
    "syncingTo" : "192.168.200.245:27017",
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 12,
            "optime" : Timestamp(1392702168, 8187),
            "optimeDate" : ISODate("2014-02-18T05:42:48Z"),
            "errmsg" : "syncing to: 192.168.200.245:27017",
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 11,
            "optime" : Timestamp(1392702168, 8187),
            "optimeDate" : ISODate("2014-02-18T05:42:48Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:45:13Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:45:12Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.25:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 9,
            "optime" : Timestamp(1392702168, 8187),
            "optimeDate" : ISODate("2014-02-18T05:42:48Z"),
            "lastHeartbeat" : ISODate("2014-02-18T05:45:13Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T05:45:13Z"),
            "pingMs" : 0
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

启动之前的主，发现其变成了SECONDARY，在新主插入的数据，是否已经同步：

```
mmm:SECONDARY> db.test.count()
Tue Feb 18 13:47:03.634 count failed: { "note" : "from execCommand", "ok" : 0, "errmsg" : "not master" } at src/mongo/shell/query.js:180
mmm:SECONDARY> rs.slaveOk()
mmm:SECONDARY> db.test.count()
20001
```

已经同步。

**注意**：

所有的Secondary都宕机、或则副本集中只剩下一个节点，则该节点只能为Secondary节点，也就意味着整个集群智能进行读操作而不能进行写操作，当其他的恢复时，之前的primary节点仍然是primary节点。

当某个节点宕机后重新启动该节点会有一段的时间（时间长短视集群的数据量和宕机时间而定）导致整个集群中所有节点都成为secondary而无法进行写操作（如果应用程序没有设置相应的ReadReference也可能不能进行读取操作）。

官方推荐的**最小的副本集也应该具备一个primary节点和两个secondary节点。两个节点的副本集不具备真正的故障转移能力。**

**四：应用**

**1：手动切换Primary节点到自己给定的节点**
上面已经提到过了优先集priority，因为默认的都是1，所以只需要把给定的服务器的priority加到最大即可。让245 成为主节点，操作如下：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.conf() #查看配置
{
    "_id" : "mmm",
    "version" : 6,  #每改变一次集群的配置，副本集的version都会加1。
    "members" : [
        {
            "_id" : 1,
            "host" : "192.168.200.252:27017"
        },
        {
            "_id" : 2,
            "host" : "192.168.200.245:27017"
        },
        {
            "_id" : 3,
            "host" : "192.168.200.25:27017"
        }
    ]
}
mmm:PRIMARY> rs.status() #查看状态
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T07:25:51Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 47,
            "optime" : Timestamp(1392708304, 1),
            "optimeDate" : ISODate("2014-02-18T07:25:04Z"),
            "lastHeartbeat" : ISODate("2014-02-18T07:25:50Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T07:25:50Z"),
            "pingMs" : 0,
            "lastHeartbeatMessage" : "syncing to: 192.168.200.25:27017",
            "syncingTo" : "192.168.200.25:27017"
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 47,
            "optime" : Timestamp(1392708304, 1),
            "optimeDate" : ISODate("2014-02-18T07:25:04Z"),
            "lastHeartbeat" : ISODate("2014-02-18T07:25:50Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T07:25:51Z"),
            "pingMs" : 0,
            "lastHeartbeatMessage" : "syncing to: 192.168.200.25:27017",
            "syncingTo" : "192.168.200.25:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 13019,
            "optime" : Timestamp(1392708304, 1),
            "optimeDate" : ISODate("2014-02-18T07:25:04Z"),
            "self" : true
        }
    ],
    "ok" : 1
}
mmm:PRIMARY> cfg=rs.conf() #
{
    "_id" : "mmm",
    "version" : 4,
    "members" : [
        {
            "_id" : 1,
            "host" : "192.168.200.252:27017"
        },
        {
            "_id" : 2,
            "host" : "192.168.200.245:27017"
        },
        {
            "_id" : 3,
            "host" : "192.168.200.25:27017"
        }
    ]
}
mmm:PRIMARY> cfg.members[1].priority=2  #修改priority
2
mmm:PRIMARY> rs.reconfig(cfg) #重新加载配置文件，强制了副本集进行一次选举，优先级高的成为Primary。在这之间整个集群的所有节点都是secondary

mmm:SECONDARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T07:27:38Z"),
    "myState" : 2,
    "syncingTo" : "192.168.200.245:27017",
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 71,
            "optime" : Timestamp(1392708387, 1),
            "optimeDate" : ISODate("2014-02-18T07:26:27Z"),
            "lastHeartbeat" : ISODate("2014-02-18T07:27:37Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T07:27:38Z"),
            "pingMs" : 0,
            "lastHeartbeatMessage" : "syncing to: 192.168.200.245:27017",
            "syncingTo" : "192.168.200.245:27017"
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 71,
            "optime" : Timestamp(1392708387, 1),
            "optimeDate" : ISODate("2014-02-18T07:26:27Z"),
            "lastHeartbeat" : ISODate("2014-02-18T07:27:37Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T07:27:38Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.25:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 13126,
            "optime" : Timestamp(1392708387, 1),
            "optimeDate" : ISODate("2014-02-18T07:26:27Z"),
            "errmsg" : "syncing to: 192.168.200.245:27017",
            "self" : true
        }
    ],
    "ok" : 1
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

这样，给定的245服务器就成为了主节点。

**2：添加仲裁节点**

把25节点删除，重启。再添加让其为仲裁节点：

```
rs.addArb("192.168.200.25:27017")
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-18T08:14:36Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 795,
            "optime" : Timestamp(1392711068, 100),
            "optimeDate" : ISODate("2014-02-18T08:11:08Z"),
            "lastHeartbeat" : ISODate("2014-02-18T08:14:35Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T08:14:35Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.245:27017"
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" : "PRIMARY",
            "uptime" : 14703,
            "optime" : Timestamp(1392711068, 100),
            "optimeDate" : ISODate("2014-02-18T08:11:08Z"),
            "self" : true
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 7,
            "stateStr" : "ARBITER",
            "uptime" : 26,
            "lastHeartbeat" : ISODate("2014-02-18T08:14:34Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-18T08:14:34Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}
mmm:PRIMARY> rs.conf()
{
    "_id" : "mmm",
    "version" : 9,
    "members" : [
        {
            "_id" : 1,
            "host" : "192.168.200.252:27017"
        },
        {
            "_id" : 2,
            "host" : "192.168.200.245:27017",
            "priority" : 2
        },
        {
            "_id" : 3,
            "host" : "192.168.200.25:27017",
            "arbiterOnly" : true
        }
    ]
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

上面说明已经让25服务器成为仲裁节点。副本集要求参与选举投票(vote)的节点数为奇数，当我们实际环境中因为机器等原因限制只有两个(或偶数)的节点，这时为了实现 Automatic Failover引入另一类节点：仲裁者（arbiter），仲裁者只参与投票不拥有实际的数据，并且不提供任何服务，因此它对物理资源要求不严格。

通过实际测试发现，当整个副本集集群中达到50%的节点（包括仲裁节点）不可用的时候，剩下的节点只能成为secondary节点，整个集群只能读不能 写。比如集群中有1个primary节点，2个secondary节点，加1个arbit节点时：当两个secondary节点挂掉了，那么剩下的原来的 primary节点也只能降级为secondary节点；当集群中有1个primary节点，1个secondary节点和1个arbit节点，这时即使 primary节点挂了，剩下的secondary节点也会自动成为primary节点。因为仲裁节点不复制数据，因此利用仲裁节点可以实现最少的机器开 销达到两个节点热备的效果。

**3：添加备份节点**

hidden（成员用于支持专用功能）：这样设置后此机器在读写中都不可见，并且不会被选举为Primary，但是可以投票，一般用于备份数据。

把25节点删除，重启。再添加让其为hidden节点：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.add({"_id":3,"host":"192.168.200.25:27017","priority":0,"hidden":true})
{ "down" : [ "192.168.200.25:27017" ], "ok" : 1 }
mmm:PRIMARY> rs.conf()
{
    "_id" : "mmm",
    "version" : 17,
    "members" : [
        {
            "_id" : 1,
            "host" : "192.168.200.252:27017"
        },
        {
            "_id" : 2,
            "host" : "192.168.200.245:27017"
        },
        {
            "_id" : 3,
            "host" : "192.168.200.25:27017",
            "priority" : 0,
            "hidden" : true
        }
    ]
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

测试其能否参与投票：关闭当前的Primary，查看是否自动转移Primary

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
关闭Primary（252）：
mmm:PRIMARY> use admin
switched to db admin
mmm:PRIMARY> db.shutdownServer()

连另一个链接察看：
mmm:PRIMARY> rs.status()
{
    "set" : "mmm",
    "date" : ISODate("2014-02-19T09:11:45Z"),
    "myState" : 1,
    "members" : [
        {
            "_id" : 1,
            "name" : "192.168.200.252:27017",
            "health" : 1,
            "state" : 1,
            "stateStr" :"(not reachable/healthy)",
            "uptime" : 4817,
            "optime" : Timestamp(1392801006, 1),
            "optimeDate" : ISODate("2014-02-19T09:10:06Z"),
            "self" : true
        },
        {
            "_id" : 2,
            "name" : "192.168.200.245:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "PRIMARY",
            "uptime" : 401,
            "optime" : Timestamp(1392801006, 1),
            "optimeDate" : ISODate("2014-02-19T09:10:06Z"),
            "lastHeartbeat" : ISODate("2014-02-19T09:11:44Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-19T09:11:43Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        },
        {
            "_id" : 3,
            "name" : "192.168.200.25:27017",
            "health" : 1,
            "state" : 2,
            "stateStr" : "SECONDARY",
            "uptime" : 99,
            "optime" : Timestamp(1392801006, 1),
            "optimeDate" : ISODate("2014-02-19T09:10:06Z"),
            "lastHeartbeat" : ISODate("2014-02-19T09:11:44Z"),
            "lastHeartbeatRecv" : ISODate("2014-02-19T09:11:43Z"),
            "pingMs" : 0,
            "syncingTo" : "192.168.200.252:27017"
        }
    ],
    "ok" : 1
}
上面说明Primary已经转移，说明hidden具有投票的权利，继续查看是否有数据复制的功能。
#####
mmm:PRIMARY> db.test.count()
20210
mmm:PRIMARY> for(var i=0;i<90;i++){db.test.insert({"name":"test"+i,"age":123})}
mmm:PRIMARY> db.test.count()
20300

Secondady:
mmm:SECONDARY> db.test.count()
Wed Feb 19 17:18:19.469 count failed: { "note" : "from execCommand", "ok" : 0, "errmsg" : "not master" } at src/mongo/shell/query.js:180
mmm:SECONDARY> rs.slaveOk()
mmm:SECONDARY> db.test.count()
20300
上面说明hidden具有数据复制的功能
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

后面大家可以在上面进行备份了，后一篇会介绍如何备份、还原以及一些日常维护需要的操作。

**4：添加延迟节点**

Delayed（成员用于支持专用功能）：可以指定一个时间延迟从primary节点同步数据。主要用于处理误删除数据马上同步到从节点导致的不一致问题。

把25节点删除，重启。再添加让其为Delayed节点：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> rs.add({"_id":3,"host":"192.168.200.25:27017","priority":0,"hidden":true,"slaveDelay":60})  #语法
{ "down" : [ "192.168.200.25:27017" ], "ok" : 1 }

mmm:PRIMARY> rs.conf()
{
    "_id" : "mmm",
    "version" : 19,
    "members" : [
        {
            "_id" : 1,
            "host" : "192.168.200.252:27017"
        },
        {
            "_id" : 2,
            "host" : "192.168.200.245:27017"
        },
        {
            "_id" : 3,
            "host" : "192.168.200.25:27017",
            "priority" : 0,
            "slaveDelay" : 60,   
            "hidden" : true
        }
    ]
}
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

测试：操作Primary，看数据是否60s后同步到delayed节点。

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
mmm:PRIMARY> db.test.count()
20300
mmm:PRIMARY> for(var i=0;i<200;i++){db.test.insert({"name":"test"+i,"age":123})}
mmm:PRIMARY> db.test.count()
20500

Delayed：
mmm:SECONDARY> db.test.count()
20300
#60秒之后
mmm:SECONDARY> db.test.count()
20500
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

上面说明delayed能够成功的把同步操作延迟60秒执行。除了上面的成员之外，还有：    

**Secondary-Only:**不能成为primary节点，只能作为secondary副本节点，防止一些性能不高的节点成为主节点。

**Non-Voting：**没有选举权的secondary节点，纯粹的备份数据节点。

**具体成员信息如下：**

|                | 成为primary | 对客户端可见 | 参与投票 | 延迟同步 | 复制数据 |
| -------------- | ----------- | ------------ | -------- | -------- | -------- |
| Default        | √           | √            | √        | ∕        | √        |
| Secondary-Only | ∕           | √            | √        | ∕        | √        |
| Hidden         | ∕           | ∕            | √        | ∕        | √        |
| Delayed        | ∕           | √            | √        | √        | √        |
| Arbiters       | ∕           | ∕            | √        | ∕        | ∕        |
| Non-Voting     | √           | √            | ∕        | ∕        | √        |

**5：读写分离**

MongoDB副本集对读写分离的支持是通过Read Preferences特性进行支持的，这个特性非常复杂和灵活。

应用程序驱动通过read reference来设定如何对副本集进行读取操作，默认的,客户端驱动所有的读操作都是直接访问primary节点的，从而保证了数据的严格一致性。

支持**五种的read preference模式**：[官网说明](http://docs.mongodb.org/manual/applications/replication/#replica-set-read-preference)

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
primary
主节点，默认模式，读操作只在主节点，如果主节点不可用，报错或者抛出异常。
primaryPreferred
首选主节点，大多情况下读操作在主节点，如果主节点不可用，如故障转移，读操作在从节点。
secondary
从节点，读操作只在从节点， 如果从节点不可用，报错或者抛出异常。
secondaryPreferred
首选从节点，大多情况下读操作在从节点，特殊情况（如单主节点架构）读操作在主节点。
nearest
最邻近节点，读操作在最邻近的成员，可能是主节点或者从节点，关于最邻近的成员请参考
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

注意：2.2版本之前的MongoDB对Read Preference支持的还不完全，如果客户端驱动采用primaryPreferred实际上读取操作都会被路由到secondary节点。

因为读写分离是通过修改程序的driver的，故这里就不做说明，具体的可以参考这篇[文章](http://blog.chinaunix.net/uid-15795819-id-3075952.html)或则可以在google上查阅。

**验证：（Python）**

通过python来验证MongoDB ReplSet的特性。

**1：主节点断开，看是否影响写入**

脚本：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
#coding:utf-8
import time
from pymongo import ReplicaSetConnection
conn = ReplicaSetConnection("192.168.200.201:27017,192.168.200.202:27017,192.168.200.204:27017", replicaSet="drug",read_preference=2, safe=True)
#打印Primary服务器
#print conn.primary
#打印所有服务器
#print conn.seeds
#打印Secondary服务器
#print conn.secondaries

#print conn.read_preference
#print conn.server_info()

for i in xrange(1000):
    try:
        conn.test.tt.insert({"name":"test" + str(i)})
        time.sleep(1)
        print conn.primary
        print conn.secondaries
    except:
        pass 
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

脚本执行打印出的内容：

![img](https://images.cnblogs.com/OutliningIndicators/ContractedBlock.gif) View Code

体操作如下：

在执行脚本的时候，模拟Primary宕机，再把其开启。看到其从201（Primary）上迁移到202上，201变成了Secondary。查看插入的数据发现其中间有一段数据丢失了。

```
{ "name" : "GOODODOO15" }
{ "name" : "GOODODOO592" }
{ "name" : "GOODODOO593" }
```

其实这部分数据是由于在选举过程期间丢失的，要是不允许数据丢失，则把在选举期间的数据放到队列中，等到找到新的Primary，再写入。

上面的脚本可能会出现操作时退出，这要看xrange()里的数量了，所以用一个循环修改（更直观）：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
#coding:utf-8
import time
from pymongo import ReplicaSetConnection
conn = ReplicaSetConnection("192.168.200.201:27017,192.168.200.202:27017,192.168.200.204:27017", replicaSet="drug",read_preference=2, safe=True)

#打印Primary服务器
#print conn.primary
#打印所有服务器
#print conn.seeds
#打印Secondary服务器
#print conn.secondaries

#print conn.read_preference
#print conn.server_info()

while True:
    try:
        for i in xrange(100):
            conn.test.tt.insert({"name":"test" + str(i)})
            print "test" + str(i)
            time.sleep(2)
            print conn.primary
            print conn.secondaries
            print '\n'
    except:
        pass
```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

**上面的实验证明了：**在Primary宕机的时候，程序脚本仍可以写入，不需要人为的去干预。只是期间需要10s左右（选举时间）的时间会出现不可用，进一步说明，写操作时在Primary上进行的。

**2：主节点断开，看是否影响读取**

脚本：

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

```
#coding:utf-8
import time
from pymongo import ReplicaSetConnection
conn = ReplicaSetConnection("192.168.200.201:27017,192.168.200.202:27017,192.168.200.204:27017", replicaSet="drug",read_preference=2, safe=True)

#打印Primary服务器
#print conn.primary
#打印所有服务器
#print conn.seeds
#打印Secondary服务器
#print conn.secondaries

#print conn.read_preference
#print conn.server_info()

for i in xrange(1000):
    
    time.sleep(1)
    obj=conn.test.tt.find({},{"_id":0,"name":1}).skip(i).limit(1)
    for item in obj:
        print item.values()
    print conn.primary
    print conn.secondaries

```

[![复制代码](https://common.cnblogs.com/images/copycode.gif)](javascript:void(0);)

脚本执行打印出的内容：

具体操作如下：

在执行脚本的时候，模拟Primary宕机，再把其开启。看到201（Primary）上迁移到202上，201变成了Secondary，读取数据没有间断。再让Primary宕机，不开启，读取也不受影响。

**上面的实验证明了：**在Primary宕机的时候，程序脚本仍可以读取，不需要人为的去干预。一进步说明，读取是在Secondary上面。

**总结：**

刚接触MongoDB，能想到的就这些，后期发现一些新的知识点会不定时更新该文章。