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

### 详细步骤

#### 安装MongoDB

以下为安装脚本，下载到本地以后`bash install_mongodb.3.2.16.sh`

```shell
$ curl -O 'https://raw.githubusercontent.com/BoobooWei/booboo_mongodb/master/scripts/install_mongodb.3.2.16.sh'
$ bash install_mongodb.3.2.16.sh
```

#### 修改配置文件

只需要开启：replSet 参数即可。格式为：

```shell
replication:
##oplog大小
 oplogSizeMB: 20
##复制集名称
 replSetName: booboo
```

#### 启动服务

每一个节点都启动

```shell
mongodb.server start
```



启动后会提示：

```
2018-08-16T17:57:46.700+0800 I REPL     [initandlisten] Did not find local voted for document at startup.
2018-08-16T17:57:46.700+0800 I REPL     [initandlisten] Did not find local replica set configuration document at startup;  NoMatchingDocument: Did not find replica set configuration document in local.system.replset
2018-08-16T17:57:46.700+0800 I NETWORK  [HostnameCanonicalizationWorker] Starting hostname canonicalization worker
2018-08-16T17:57:46.701+0800 I FTDC     [initandlisten] Initializing full-time diagnostic data capture with directory '/alidata/mongodb/data/27017/diagnostic.data'
2018-08-16T17:57:46.701+0800 I NETWORK  [initandlisten] waiting for connections on port 27017
```

说明需要进行初始化操作，初始化操作只能执行一次。

#### 初始化副本集

登入任意一台机器的MongoDB执行：因为是全新的副本集所以可以任意进入一台执行；要是有一台有数据，则需要在有数据上执行；要多台有数据则不能初始化。

```shell
> rs.initiate()
{
	"info2" : "no configuration specified. Using a default configuration for the set",
	"me" : "sh_01:27017",
	"ok" : 1
}
# 执行初始化后看到前缀发生了变化
booboo:PRIMARY> rs.config()
{
	"_id" : "booboo",
	"version" : 1,
	"protocolVersion" : NumberLong(1),
	"members" : [
		{
			"_id" : 0,
			"host" : "sh_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"getLastErrorModes" : {
			
		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5b754da04c30f36bbab72366")
	}
}
```



* "_id": 副本集的名称
* "members": 副本集的服务器列表
* "_id": 服务器的唯一ID
* "host": 服务器主机
* "priority": 是优先级，默认为1，优先级0为被动节点，不能成为活跃节点。优先级不位0则按照有大到小选出活跃节点。
* "arbiterOnly": 仲裁节点，只参与投票，不接收数据，也不能成为活跃节点。

#### 添加副本集节点

添加节点的命令如下：

```shell
rs.add()
```

执行操作

```shell
booboo:PRIMARY> rs.add('sh_02:27017')
{ "ok" : 1 }
booboo:PRIMARY> rs.add('am_01:27017')
{ "ok" : 1 }
booboo:PRIMARY> rs.config()
{
	"_id" : "booboo",
	"version" : 3,
	"protocolVersion" : NumberLong(1),
	"members" : [
		{
			"_id" : 0,
			"host" : "sh_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 1,
			"host" : "sh_02:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 2,
			"host" : "am_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"getLastErrorModes" : {
			
		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5b754da04c30f36bbab72366")
	}
}
```



**6：日志**

查看252上的日志：

```
2018-08-16T18:16:48.547+0800 I REPL     [ReplicationExecutor] New replica set config in use: { _id: "booboo", version: 3, protocolVersion: 1, members: [ { _id: 0, host: "sh_01:27017", arbiterOnly: false, buildIndexes: true, hidden: false, priority: 1.0, tags: {}, slaveDelay: 0, votes: 1 }, { _id: 1, host: "sh_02:27017", arbiterOnly: false, buildIndexes: true, hidden: false, priority: 1.0, tags: {}, slaveDelay: 0, votes: 1 }, { _id: 2, host: "am_01:27017", arbiterOnly: false, buildIndexes: true, hidden: false, priority: 1.0, tags: {}, slaveDelay: 0, votes: 1 } ], settings: { chainingAllowed: true, heartbeatIntervalMillis: 2000, heartbeatTimeoutSecs: 10, electionTimeoutMillis: 10000, getLastErrorModes: {}, getLastErrorDefaults: { w: 1, wtimeout: 0 }, replicaSetId: ObjectId('5b754da04c30f36bbab72366') } }
2018-08-16T18:16:48.548+0800 I REPL     [ReplicationExecutor] This node is sh_01:27017 in the config

2018-08-16T18:16:50.555+0800 I REPL     [ReplicationExecutor] Member am_01:27017 is now in state STARTUP2
2018-08-16T18:16:54.557+0800 I REPL     [ReplicationExecutor] Member am_01:27017 is now in state SECONDARY
```

至此，整个副本集已经搭建成功了。

查看副本集状态

```shell
booboo:PRIMARY> rs.status()
{
	"set" : "booboo",
	"date" : ISODate("2018-08-16T10:58:14.036Z"),
	"myState" : 1,
	"term" : NumberLong(1),
	"heartbeatIntervalMillis" : NumberLong(2000),
	"members" : [
		{
			"_id" : 0,
			"name" : "sh_01:27017",
			"health" : 1,
			"state" : 1,
			"stateStr" : "PRIMARY",
			"uptime" : 3628,
			"optime" : {
				"ts" : Timestamp(1534414608, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-08-16T10:16:48Z"),
			"electionTime" : Timestamp(1534414240, 2),
			"electionDate" : ISODate("2018-08-16T10:10:40Z"),
			"configVersion" : 3,
			"self" : true
		},
		{
			"_id" : 1,
			"name" : "sh_02:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 2492,
			"optime" : {
				"ts" : Timestamp(1534414608, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-08-16T10:16:48Z"),
			"lastHeartbeat" : ISODate("2018-08-16T10:58:12.645Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T10:58:12.325Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "sh_01:27017",
			"configVersion" : 3
		},
		{
			"_id" : 2,
			"name" : "am_01:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 2485,
			"optime" : {
				"ts" : Timestamp(1534414608, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-08-16T10:16:48Z"),
			"lastHeartbeat" : ISODate("2018-08-16T10:58:12.580Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T10:58:09.477Z"),
			"pingMs" : NumberLong(0),
			"configVersion" : 3
		}
	],
	"ok" : 1
}
```



#### 删副本集节点

> 删除sh_02节点

```
rs.remove()
```

操作明细

```
booboo:PRIMARY> rs.remove('sh_02:27017')
{ "ok" : 1 }
booboo:PRIMARY> rs.status()
{
	"set" : "booboo",
	"date" : ISODate("2018-08-16T11:06:03.031Z"),
	"myState" : 1,
	"term" : NumberLong(1),
	"heartbeatIntervalMillis" : NumberLong(2000),
	"members" : [
		{
			"_id" : 0,
			"name" : "sh_01:27017",
			"health" : 1,
			"state" : 1,
			"stateStr" : "PRIMARY",
			"uptime" : 4097,
			"optime" : {
				"ts" : Timestamp(1534417560, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-08-16T11:06:00Z"),
			"electionTime" : Timestamp(1534414240, 2),
			"electionDate" : ISODate("2018-08-16T10:10:40Z"),
			"configVersion" : 4,
			"self" : true
		},
		{
			"_id" : 2,
			"name" : "am_01:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 2954,
			"optime" : {
				"ts" : Timestamp(1534417560, 1),
				"t" : NumberLong(1)
			},
			"optimeDate" : ISODate("2018-08-16T11:06:00Z"),
			"lastHeartbeat" : ISODate("2018-08-16T11:06:02.598Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T11:06:00.609Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "sh_01:27017",
			"configVersion" : 4
		}
	],
	"ok" : 1
}

```

sh_02的节点已经被移除。

再将sh_02加回来`rs.add('sh_02:27017')`

#### 操作Secondary

默认情况下，Secondary是不提供服务的，即不能读和写。会提示：
error: { "$err" : "not master and slaveOk=false", "code" : 13435 }

在特殊情况下需要读的话则需要：
**rs.slaveOk() ，只对当前连接有效。**

```
booboo:SECONDARY> db.t1.find().limit(1)
Error: error: { "ok" : 0, "errmsg" : "not master and slaveOk=false", "code" : 13435 }
booboo:SECONDARY> rs.slaveOk()
booboo:SECONDARY> db.t1.find().limit(1)
{ "_id" : ObjectId("5b5ebb6796b8b74a73ee30f6"), "a" : 1, "b" : 2 }
```

## 测试副本集功能

当前副本集状态如下：

```shell
rs.config()
{
	"_id" : "booboo",
	"version" : 11,
	"protocolVersion" : NumberLong(1),
	"members" : [
		{
			"_id" : 2,
			"host" : "am_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 3,
			"host" : "sh_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 4,
			"host" : "sh_02:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"getLastErrorModes" : {
			
		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5b754da04c30f36bbab72366")
	}
}
booboo:PRIMARY> rs.status()
{
	"set" : "booboo",
	"date" : ISODate("2018-08-16T11:43:24.447Z"),
	"myState" : 1,
	"term" : NumberLong(8),
	"heartbeatIntervalMillis" : NumberLong(2000),
	"members" : [
		{
			"_id" : 2,
			"name" : "am_01:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 270,
			"optime" : {
				"ts" : Timestamp(1534419549, 1),
				"t" : NumberLong(8)
			},
			"optimeDate" : ISODate("2018-08-16T11:39:09Z"),
			"lastHeartbeat" : ISODate("2018-08-16T11:43:22.722Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T11:43:22.702Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "sh_02:27017",
			"configVersion" : 11
		},
		{
			"_id" : 3,
			"name" : "sh_01:27017",
			"health" : 1,
			"state" : 1,
			"stateStr" : "PRIMARY",
			"uptime" : 286,
			"optime" : {
				"ts" : Timestamp(1534419549, 1),
				"t" : NumberLong(8)
			},
			"optimeDate" : ISODate("2018-08-16T11:39:09Z"),
			"electionTime" : Timestamp(1534419548, 1),
			"electionDate" : ISODate("2018-08-16T11:39:08Z"),
			"configVersion" : 11,
			"self" : true
		},
		{
			"_id" : 4,
			"name" : "sh_02:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 275,
			"optime" : {
				"ts" : Timestamp(1534419549, 1),
				"t" : NumberLong(8)
			},
			"optimeDate" : ISODate("2018-08-16T11:39:09Z"),
			"lastHeartbeat" : ISODate("2018-08-16T11:43:22.733Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T11:43:22.768Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "sh_01:27017",
			"configVersion" : 11
		}
	],
	"ok" : 1
}
```

### 测试副本集数据复制功能

在Primary上插入数据：

```
booboo:PRIMARY> use test
switched to db test
booboo:PRIMARY> db.superman.insert({name:'jack',age:12})
WriteResult({ "nInserted" : 1 })
booboo:PRIMARY> db.superman.find({name:/a/i})
{ "_id" : ObjectId("5b755ff853976480e26b04c8"), "name" : "jack", "age" : 12 }
```

在Secondary上查看是否已经同步：

```
booboo:SECONDARY> db.superman.find().limit(1)
{ "_id" : ObjectId("5b755ff853976480e26b04c8"), "name" : "jack", "age" : 12 }
```

数据已经同步。

### 测试优先级更改功能

将sh_01的优先级改为0.5

```shell
booboo:PRIMARY> cfg = rs.config()
booboo:PRIMARY> cfg.members[1].priority = 2
booboo:PRIMARY> rs.reconfig(cfg)
```

更改优先级后

```shell
rs.config()
{
	"_id" : "booboo",
	"version" : 11,
	"protocolVersion" : NumberLong(1),
	"members" : [
		{
			"_id" : 2,
			"host" : "am_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 3,
			"host" : "sh_01:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 2,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 4,
			"host" : "sh_02:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"getLastErrorModes" : {
			
		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5b754da04c30f36bbab72366")
	}
}
```

### 测试副本集故障转移功能

关闭Primary节点，查看其他2个节点的情况：

```
[root@sh_01 ~]# mongodb.server stop
killing process with pid: 650
```

看到sh_02已经从 SECONDARY 变成了 PRIMARY。具体的信息可以通过日志文件得知。继续操作：

```shell
booboo:SECONDARY> use admin
switched to db admin
booboo:PRIMARY> use test
switched to db test
```

查看副本集状态

```
booboo:SECONDARY> use admin
switched to db admin
booboo:PRIMARY> use test
switched to db test
booboo:PRIMARY> rs.status()
{
	"set" : "booboo",
	"date" : ISODate("2018-08-16T11:47:30.019Z"),
	"myState" : 1,
	"term" : NumberLong(9),
	"heartbeatIntervalMillis" : NumberLong(2000),
	"members" : [
		{
			"_id" : 2,
			"name" : "am_01:27017",
			"health" : 1,
			"state" : 2,
			"stateStr" : "SECONDARY",
			"uptime" : 513,
			"optime" : {
				"ts" : Timestamp(1534420009, 1),
				"t" : NumberLong(9)
			},
			"optimeDate" : ISODate("2018-08-16T11:46:49Z"),
			"lastHeartbeat" : ISODate("2018-08-16T11:47:29.020Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T11:47:28.720Z"),
			"pingMs" : NumberLong(0),
			"syncingTo" : "sh_02:27017",
			"configVersion" : 11
		},
		{
			"_id" : 3,
			"name" : "sh_01:27017",
			"health" : 0,
			"state" : 8,
			"stateStr" : "(not reachable/healthy)",
			"uptime" : 0,
			"optime" : {
				"ts" : Timestamp(0, 0),
				"t" : NumberLong(-1)
			},
			"optimeDate" : ISODate("1970-01-01T00:00:00Z"),
			"lastHeartbeat" : ISODate("2018-08-16T11:47:29.086Z"),
			"lastHeartbeatRecv" : ISODate("2018-08-16T11:46:38.901Z"),
			"pingMs" : NumberLong(0),
			"lastHeartbeatMessage" : "Connection refused",
			"configVersion" : -1
		},
		{
			"_id" : 4,
			"name" : "sh_02:27017",
			"health" : 1,
			"state" : 1,
			"stateStr" : "PRIMARY",
			"uptime" : 524,
			"optime" : {
				"ts" : Timestamp(1534420009, 1),
				"t" : NumberLong(9)
			},
			"optimeDate" : ISODate("2018-08-16T11:46:49Z"),
			"infoMessage" : "could not find member to sync from",
			"electionTime" : Timestamp(1534420008, 1),
			"electionDate" : ISODate("2018-08-16T11:46:48Z"),
			"configVersion" : 11,
			"self" : true
		}
	],
	"ok" : 1
}
```

重新启动sh_01，由于其优先级别最高，所以会重新选举primary为sh_01

```
[root@sh_01 ~]# mongodb.server start
[root@sh_01 ~]# mongo
MongoDB shell version: 3.2.16
connecting to: test
Server has startup warnings: 
2018-08-16T19:48:53.817+0800 I CONTROL  [initandlisten] ** WARNING: You are running this process as the root user, which is not recommended.
2018-08-16T19:48:53.817+0800 I CONTROL  [initandlisten] 
booboo:SECONDARY> use test
switched to db test
booboo:SECONDARY> use test
switched to db test
booboo:PRIMARY> 
```



**注意**：

所有的Secondary都宕机、或则副本集中只剩下一个节点，则该节点只能为Secondary节点，也就意味着整个集群智能进行读操作而不能进行写操作，当其他的恢复时，之前的primary节点仍然是primary节点。

当某个节点宕机后重新启动该节点会有一段的时间（时间长短视集群的数据量和宕机时间而定）导致整个集群中所有节点都成为secondary而无法进行写操作（如果应用程序没有设置相应的ReadReference也可能不能进行读取操作）。

官方推荐的**最小的副本集也应该具备一个primary节点和两个secondary节点。两个节点的副本集不具备真正的故障转移能力。**

## 副本集应用

修改rs.config()中的相应value即可达到目的：

| 副本集应用 | 说明 | 方法                                                 |
| ---------- | ---- | ------------- |
|[*修改复制集节点的优先级*](http://www.mongoing.com/docs/tutorial/adjust-replica-set-member-priority.html) |修改复制集节点在选举中的优先级|`cfg.members[0].priority = 0.5`|
|[*禁止从节点升职为主节点*](http://www.mongoing.com/docs/tutorial/configure-secondary-only-replica-set-member.html)|防止从节点在选举中升职为主节点| `cfg.members[1].priority = 0` |
|[*配置一个隐藏节点*](http://www.mongoing.com/docs/tutorial/configure-a-hidden-replica-set-member.html)|将从节点设置为应用程序不可见来用其提供特殊需求，如备份等| `cfg.members[0].priority = 0;cfg.members[0].hidden = true` |
|[*配置一个延时复制节点*](http://www.mongoing.com/docs/tutorial/configure-a-delayed-replica-set-member.html)|将从节点设置为延时复制节点，来提高数据安全性| `cfg.members[0].priority = 0;cfg.members[0].hidden = true;cfg.members[0].slaveDelay = 3600` |
|[*配置一个不参与投票的节点*](http://www.mongoing.com/docs/tutorial/configure-a-non-voting-replica-set-member.html)|配置一个拥有数据但是不可进行投票的从节点| `cfg.members[3].votes = 0` |
|[*将从节点转换为投票节点*](http://www.mongoing.com/docs/tutorial/convert-secondary-into-arbiter.html)|将一个从节点变为投票节点| |

### 修改复制集节点的优先级

```shell
# 修改复制集节点的优先级
cfg = rs.conf()
cfg.members[0].priority = 0.5
rs.reconfig(cfg)
```

### 禁止从节点升职为主节点

```shell
# 禁止从节点升职为主节点
cfg = rs.conf()
cfg.members[1].priority = 0
rs.reconfig(cfg)
```

### 配置一个隐藏节点

```shell
# 配置一个隐藏节点
cfg = rs.conf()
cfg.members[0].priority = 0
cfg.members[0].hidden = true
rs.reconfig(cfg)
```

### 配置一个延时复制节点

```shell
# 配置一个延时复制节点
cfg = rs.conf()
cfg.members[0].priority = 0
cfg.members[0].hidden = true
cfg.members[0].slaveDelay = 3600
rs.reconfig(cfg)
```

### 配置一个不参与投票的节点

```shell
# 配置一个不参与投票的节点
cfg = rs.conf()
cfg.members[3].votes = 0
rs.reconfig(cfg)
```

### 将从节点转换为投票节点

```shell
# 将从节点转换为投票节点
## way1 我们可以将投票节点的端口设置的与之前的从节点一致。那么我们就必须关闭从节点并移除其数据文件，再重启与重新将其配置为投票节点。
rs.remove("<hostname><:port>")
rs.conf()
mv /data/db /data/db-old
mkdir /data/db
mongod --port 27021 --dbpath /data/db --replSet rs
rs.addArb("<hostname><:port>")
rs.conf()
投票节点必须要包含如下信息：

"arbiterOnly" : true
## way2 将投票节点以新的端口运行。我们可以在关闭已有的从节点之前就启动并配置一个投票节点。
```

## 读写分离

MongoDB副本集对读写分离的支持是通过Read Preferences特性进行支持的，这个特性非常复杂和灵活。

应用程序驱动通过read reference来设定如何对副本集进行读取操作，默认的,客户端驱动所有的读操作都是直接访问primary节点的，从而保证了数据的严格一致性。

支持**五种的read preference模式**：[官网说明](http://docs.mongodb.org/manual/applications/replication/#replica-set-read-preference)

| 复制集读选项模式                                             | 详细说明                                                     |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [`primary`](http://www.mongoing.com/docs/reference/read-preference.html#primary) | 默认模式，所有的读操作都在复制集的 [*主节点*](http://www.mongoing.com/docs/reference/glossary.html#term-primary) 进行的。 |
| [`primaryPreferred`](http://www.mongoing.com/docs/reference/read-preference.html#primaryPreferred) | 在大多数情况时，读操作在 [*主节点*](http://www.mongoing.com/docs/reference/glossary.html#term-primary) 上进行，但是如果主节点不可用了，读操作就会转移到 [*从节点*](http://www.mongoing.com/docs/reference/glossary.html#term-secondary) 上执行。 |
| [`secondary`](http://www.mongoing.com/docs/reference/read-preference.html#secondary) | All operations read from the [*secondary*](http://www.mongoing.com/docs/reference/glossary.html#term-secondary) members of the replica set. |
| [`secondaryPreferred`](http://www.mongoing.com/docs/reference/read-preference.html#secondaryPreferred) | 在大多数情况下，读操作都是在 [*从节点*](http://www.mongoing.com/docs/reference/glossary.html#term-secondary) 上进行的，但是当 [*从节点*](http://www.mongoing.com/docs/reference/glossary.html#term-secondary) 不可用了，读操作会转移到 [*主节点*](http://www.mongoing.com/docs/reference/glossary.html#term-primary) 上进行。 |
| [`nearest`](http://www.mongoing.com/docs/reference/read-preference.html#nearest) | 读操作会在 [*复制集*](http://www.mongoing.com/docs/reference/glossary.html#term-replica-set) 中网络延时最小的节点上进行，与节点类型无关。 |

### python连接mongo副本集

脚本：

```
#coding:utf-8
import time
from pymongo import *
client = MongoClient('10.200.6.30',replicaset='booboo')
db = client.db1
collection = db.t1
print db
print collection
collection.find_one()
db.client.address
```

脚本执行打印出的内容：

```shell
[root@sh_01 ~]# python m1.py
Database(MongoClient([u'sh_01:27017', u'sh_02:27017', u'am_01:27017']), u'db1')
Collection(Database(MongoClient([u'sh_01:27017', u'sh_02:27017', u'am_01:27017']), u'db1'), u't1')
{u'_id': ObjectId('5b757a58057999e331202554'), u'id': 1.0}
Collection(Database(MongoClient([u'sh_01:27017', u'sh_02:27017', u'am_01:27017']), u'db1'), u'client.address')
```

### 模拟主节点故障



## 总结

### 搭建副本集

| No.  | 步骤           | 操作                   |
| ---- | -------------- | ---------------------- |
| 1    | 修改配置文件   | `replSetName: booboo`  |
| 2    | 启动服务       | `mongodb.server start` |
| 3    | 初始化副本集   | `rs.initiate()`        |
| 4    | 确认初始化配置 | `rs.conf()`            |
| 5    | 添加副本集节点 | `rs.add()`             |
| 6    | 检查副本集状态 | `rs.status()`          |

### 副本集的方法

| 名称                                                         | 描述                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [`rs.add（）`](http://www.mongoing.com/docs/reference/method/rs.add.html#rs.add) | 将成员添加到副本集。                                         |
| [`rs.addArb（）`](http://www.mongoing.com/docs/reference/method/rs.addArb.html#rs.addArb) | 将[*仲裁器*](http://www.mongoing.com/docs/reference/glossary.html#term-arbiter)添加到副本集。 |
| [`rs.conf（）`](http://www.mongoing.com/docs/reference/method/rs.conf.html#rs.conf) | 返回副本集配置文档。                                         |
| [`rs.freeze（）`](http://www.mongoing.com/docs/reference/method/rs.freeze.html#rs.freeze) | 防止现任成员在一段时间内选举为主要成员。                     |
| [`rs.help（）`](http://www.mongoing.com/docs/reference/method/rs.help.html#rs.help) | 返回[*副本集*](http://www.mongoing.com/docs/reference/glossary.html#term-replica-set)函数的基本帮助文本。 |
| [`rs.initiate（）`](http://www.mongoing.com/docs/reference/method/rs.initiate.html#rs.initiate) | 初始化新的副本集。                                           |
| [`rs.printReplicationInfo（）`](http://www.mongoing.com/docs/reference/method/rs.printReplicationInfo.html#rs.printReplicationInfo) | 从主数据库的角度打印副本集状态的报告。                       |
| [`rs.printSlaveReplicationInfo（）`](http://www.mongoing.com/docs/reference/method/rs.printSlaveReplicationInfo.html#rs.printSlaveReplicationInfo) | 从辅助节点的角度打印副本集状态的报告。                       |
| [`rs.reconfig（）`](http://www.mongoing.com/docs/reference/method/rs.reconfig.html#rs.reconfig) | 通过应用新的副本集配置对象重新配置副本集。                   |
| [`rs.remove（）`](http://www.mongoing.com/docs/reference/method/rs.remove.html#rs.remove) | 从副本集中删除成员。                                         |
| [`rs.slaveOk（）`](http://www.mongoing.com/docs/reference/method/rs.slaveOk.html#rs.slaveOk) | 设置当前连接的`slaveOk`属性。已过时。使用[`readPref（）`](http://www.mongoing.com/docs/reference/method/cursor.readPref.html#cursor.readPref)和[`Mongo.setReadPref（）`](http://www.mongoing.com/docs/reference/method/Mongo.setReadPref.html#Mongo.setReadPref)来设置[*读取首选项*](http://www.mongoing.com/docs/reference/glossary.html#term-read-preference)。 |
| [`rs.status（）`](http://www.mongoing.com/docs/reference/method/rs.status.html#rs.status) | 返回包含有关副本集状态的信息的文档。                         |
| [`rs.stepDown（）`](http://www.mongoing.com/docs/reference/method/rs.stepDown.html#rs.stepDown) | 导致当前的[*初选*](http://www.mongoing.com/docs/reference/glossary.html#term-primary)成为强制[*选举*](http://www.mongoing.com/docs/reference/glossary.html#term-election)的次要。 |
| [`rs.syncFrom（）`](http://www.mongoing.com/docs/reference/method/rs.syncFrom.html#rs.syncFrom) | 设置此副本集成员将同步的成员，覆盖默认同步目标选择逻辑。     |

