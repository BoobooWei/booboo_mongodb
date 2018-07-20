# MongoDB 配置文件详解

[TOC]

## 系统日志systemLog Options

```shell
systemLog:
   verbosity: <int>    #在3.0版更改，详细级别决定了MongoDB输出的信息量和调试量，默认为0     
   quiet: <boolean>    #静默模式，不推荐生产使用，不利于排查问题
   traceAllExceptions: <boolean>    #打印详细的调试信息。使用其他日志记录进行支持相关的故障排除。
   syslogFacility: <string>    #将消息记录到系统日志时使用的设施级别。
   path: <string>    #mongod或mongos应发送所有诊断日志信息的日志文件的路径，在指定的路径上创建日志文件
   logAppend: <boolean>    #为true，则在mongos或mongod 实例重新启动时将新条目附加到现有日志文件的末尾
   logRotate: <string>    #3.0.0新版功能，三个选项 rename,reopen,logAppend必须为true
   destination: <string>    #MongoDB发送所有日志输出的目的地两个选项：file or syslog
   timeStampFormat: <string> #Default: iso8601-local 1969-12-31T19:00:00.000-0500
   component:
      accessControl:
         verbosity: <int>
      command:
         verbosity: <int>
         
eg:
systemLog:
   destination: file
   path: "/alidata/mongodb/log/mongod_22001.log"
   logAppend: true
```

> verbosity: 
>
> 详细级别的范围可以从0到5：
>
> 0是MongoDB默认的日志详细级别，包含 信息性消息。
>
> 1到 5增加了详细级别以包含 调试消息。
>
> 参考地址：http://docs.mongoing.com/reference/log-messages.html#log-messages-configure-verbosity
>
> logRotate：
>
> rename：重命名日志文件。
> reopen：关闭并重新打开日志文件，遵循典型的Linux / Unix日志旋转行为。使用Linux / Unix的logrotate工具时要重新打开，以避免日志丢失。
> reopen：则还必须将systemLog.logAppend设置为true。

## 进程管理processManagement Options

```shell
processManagement:
   fork: <boolean>    #默认：False 启用在后台运行mongos或mongod进程的守护进程模式
   pidFilePath: <string>
```

## 网络选项Net Options

```shell
net:
   port: <int>    #默认：27017
   bindIp: <string>    #4.0默认只允许本地访问。3.2默认允许所有。mongos或mongod绑定的IP地址，以侦听来自应用程序的连接要绑定到多个IP地址，请输入逗号分隔值列表。
   maxIncomingConnections: <int>    #默认：65536。mongos或mongod可以接受的最大并发连接数。
   wireObjectCheck: <boolean>    #默认值：True
   ipv6: <boolean> #在版本3.0中删除。MongoDB 3.0和更高版本中，IPv6始终处于启用状态。
   unixDomainSocket:
      enabled: <boolean>
      pathPrefix: <string>    #默认：/ tmp
      filePermissions: <int>    #默认：0700 设置UNIX域套接字文件的权限 只适用于基于Unix的系统
   http:
      enabled: <boolean>    #Default: False 3.2 版后已移除
      JSONPEnabled: <boolean>
      RESTInterfaceEnabled: <boolean>
   ssl:
      sslOnNormalPorts: <boolean> # 2.6版后已移除。在3.0版本更改：大多数MongoDB发行版现在包含对TLS / SSL的支持
      mode: <string>    #2.6 新版功能.
      PEMKeyFile: <string>
      PEMKeyPassword: <string>
      clusterFile: <string>
      clusterPassword: <string>
      CAFile: <string>
      CRLFile: <string>
      allowConnectionsWithoutCertificates: <boolean>
      allowInvalidCertificates: <boolean>
      allowInvalidHostnames: <boolean>
      disabledProtocols: <string>
      FIPSMode: <boolean>
```

## 安全Security Options

```shell
 security:
   keyFile: <string>
   clusterAuthMode: <string>    #2.6新版功能。
   authorization: <string>    #默认：禁用 启用或禁用基于角色的访问控制（RBAC）来控制每个用户对数据库资源和操作的访问。
   transitionToAuth: <boolean>    #默认：False 3.4 新版功能: 
   javascriptEnabled:  <boolean>    #默认值：True 启用或禁用服务器端JavaScript执行
   redactClientLogData: <boolean>    #3.4新版功能：仅适用于MongoDB Enterprise。
   sasl:
      hostName: <string>
      serviceName: <string>
      saslauthdSocketPath: <string>
   enableEncryption: <boolean>    #默认：False 3.2新版功能：为WiredTiger存储引擎启用加密 仅在MongoDB Enterprise中可用
   encryptionCipherMode: <string>    #3.2新版功能 仅在MongoDB Enterprise中可用
   encryptionKeyFile: <string>    #仅在MongoDB Enterprise中可用
   kmip:
      keyIdentifier: <string>    #3.2新版功能
      rotateMasterKey: <boolean>
      serverName: <string>
      port: <string>
      clientCertificateFile: <string>
      clientCertificatePassword: <string>
      serverCAFile: <string>
   ldap:    #3.4新版功能：仅适用于MongoDB Enterprise。
      servers: <string>
      bind:
         method: <string>
         saslMechanism: <string>
         queryUser: <string>
         queryPassword: <string>
         useOSDefaults: <boolean>    #3.4新版功能：仅适用于Windows平台的MongoDB Enterprise。
      transportSecurity: <string>
      timeoutMS: <int>
      userToDNMapping: <string>
      authz:
         queryTemplate: <string>
```

## 参数设置setParameter Option

```shell
setParameter:
   <parameter1>: <value1>
   <parameter2>: <value2>
   
eg:
setParameter:
   enableLocalhostAuthBypass: false
   ldapUserCacheInvalidationInterval: <int> #默认：30
```

## 存储Storage Options

```shell
storage:
   dbPath: <string>    #缺省值：Linux和OS X上的/data/db，Windows上的\data\db
   indexBuildRetry: <boolean>    #默认值：True mongod是否在下次启动时重建不完整的索引 不适用于使用内存存储引擎的mongod实例
   repairPath: <string>    
   journal: 
      enabled: <boolean>    #Default: true on 64-bit systems, false on 32-bit systems
      commitIntervalMs: <num> #默认值：100或30 3.2新版功能
   directoryPerDB: <boolean>    #默认：False
   syncPeriodSecs: <int>   #默认：60 不要在生产系统上设置这个值。在几乎所有情况下，您都应该使用默认设置。
   engine: <string>    #在3.2版本更改：从MongoDB 3.2开始，wiredTiger是默认的
   mmapv1:
      preallocDataFiles: <boolean>    #默认值：True 2.6版后已移除
      nsSize: <int>    #默认：16
      quota:
         enforced: <boolean>    #默认：false MongoDB每个数据库最多有8个数据文件 使用storage.quota.maxFilesPerDB调整配额 。
         maxFilesPerDB: <int>    #默认：8
      smallFiles: <boolean>    #默认：False
      journal:
         debugFlags: <int>    #类型：整数 提供测试功能
         commitIntervalMs: <num>    #3.2版本已移除
   wiredTiger:
      engineConfig:
         cacheSizeGB: <number>    #类型：float WiredTiger将用于所有数据的内部缓存的最大大小，控制的物理内存
         #物理内存-wiredtiger-其他进程-系统所占用的内存=filesystem cache
         journalCompressor: <string>    #默认：snappy 3.0.0新版功能
         directoryForIndexes: <boolean>    #默认：false 3.0.0新版功能
      collectionConfig:
         blockCompressor: <string>    #默认：snappy 
      indexConfig:
         prefixCompression: <boolean>    #默认值：true 
   inMemory:
      engineConfig:
         inMemorySizeGB: <number>    #默认值：物理RAM的50％少于1 GB 在3.4版本更改：数值可以从256MB到10TB，可以是一个浮点数 仅在MongoDB Enterprise中可用
```

## OperationProfiling Options

```shell
operationProfiling:
   slowOpThresholdMs: <int>    #默认值：100 数据库分析器认为查询的阈值（以毫秒为单位）变慢。
   mode: <string>    #默认：关闭 数据库分析可能会影响数据库性能 off,slowOp,all
```

## 复制Replication Options

```shell
replication:
   oplogSizeMB: <int>    #ype: integer 以兆字节为单位 对于64位系统，oplog通常是可用磁盘空间的5％
   replSetName: <string>   #类型：字符串
   secondaryIndexPrefetch: <string>    #默认：全部 仅在 mmapv1 存储引擎中可用 none,all,_id_only
   enableMajorityReadConcern: <boolean>    #默认：False 3.2新版功能  
```

## 集群分片sharding Options

```shell
sharding:
   clusterRole: <string>    #configsvr 默认启动端口27019 shardsvr 默认启动端口27018
   archiveMovedChunks: <boolean>    #3.2版本更改：从3.2开始，MongoDB 默认使用false 在块迁移期间，分片不保存从分片迁移的文档
```

## 检查日志AuditLog Options

> 注解
>
> Available only in?[MongoDB Enterprise](http://www.mongodb.com/products/mongodb-enterprise?jmp=docs)

```shell
auditLog:
   destination: <string>    #2.6 新版功能
   format: <string>
   path: <string>
   filter: <string>
```

## 简单网络管理协议 snmp Options

```shell
snmp:
   subagent: <boolean>
   master: <boolean>
```

## Mongos-only Options

```shell
replication:
   localPingThresholdMs: <int>    #Default: 15 以毫秒为单位

sharding:
   configDB: <string> #从MongoDB 3.2开始，分片集群的配置服务器可以部署为一个副本集。副本集配置服务器必须运行WiredTiger存储引擎。MongoDB 3.2弃用配置服务器的三个镜像 mongod实例。

eg：
sharding：
  configDB：<configReplSetName> /cfg1.example.net:27017，cfg2.example.net:27017，...
```

## Windows Service Options

```shell
processManagement:
   windowsService:    
      serviceName: <string>    # default: MongoDB
      displayName: <string>
      description: <string>
      serviceUser: <string>
      servicePassword: <string>
```

# MongoDB WT建议配置项

## 单实例配置

```shell
systemLog:
 destination: file
###日志存储位置
 path: /data/mongodb/log/mongod.log
 logAppend: true
storage:
##journal配置
 journal:
  enabled: true
##数据文件存储位置
 dbPath: /data/zhou/mongo1/
##是否一个库一个文件夹
 directoryPerDB: true
##数据引擎
 engine: wiredTiger
##WT引擎配置
 wiredTiger:
  engineConfig:
##WT最大使用cache（根据服务器实际情况调节）
   cacheSizeGB: 10
##是否将索引也按数据库名单独存储
   directoryForIndexes: true
##表压缩配置
  collectionConfig:
   blockCompressor: zlib
##索引配置
  indexConfig:
   prefixCompression: true
##端口配置
net:
 port: 27017
```

## 复制集配置

（在上述配置上加入如下几个配置）：

```shell
replication:
##oplog大小
 oplogSizeMB: 20
##复制集名称
 replSetName: zhou1
```

## 分片集群配置

分片复制集配置

（单实例节点的基础上）：

```shell
replication:
##oplog大小
 oplogSizeMB: 20
##复制集名称
 replSetName: zhou1
##分片配置
sharding:
##分片角色
 clusterRole: shardsvr
```

## config server配置

（单实例节点的基础上）

```shell
##分片配置
sharding:
##分片角色
 clusterRole: configsvr

```

## Mongos配置

（与单实例不同）：

```shell
##日志配置
systemLog:
 destination: file
##日志位置
 path: /data/mongos/mongod.log
 logAppend: true
##网路配置
net:
##端口配置
 port: 29020
##分片配置
sharding:
##指定config server
 configDB: 10.96.29.2:29017,10.96.29.2:29018,10.96.29.2:29019
```