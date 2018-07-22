# MongoDB备份与恢复

[TOC]

## 备份的分类

* 冷备
* 热备
* 异地灾备

| 备份的分类 | 解释                                                         | 人为误操作 | 硬件故障 | 恢复速度   |
| ---------- | ------------------------------------------------------------ | ---------- | -------- | ---------- |
| 冷备       | 将数据以隔离的方存放，备份数据不受原数据的影响               | ✔          | ✔        | 还原速度慢 |
| 热备       | 搭建冗余的环境，例如主从(master-slave)和复制集(replication set) | ×          | ✔        | 瞬间还原   |

## 冷备

> 将数据以隔离的方存放，备份数据不受原数据的影响

### 备份的两大要素

| 备份要素   | 说明                         |
| ---------- | ---------------------------- |
| 数据一致性 | 备份的数据是否有准确的时间点 |
| 服务可用性 | 备份过程中是否读写功能正常   |

### 冷备的分类

按照备份数据的类型分类，是bson数据还是物理文件：

* 物理备份
* 逻辑备份

| 分类     | 备份方法      | 数据一致性 | 服务可用性 |与MySQL对比|
| -------- | ------------- | ---------- | ---------- |---|
| 物理备份 | `tar`         | ✔         | ×         |mysql的tar备份保证数据一致性需要停服|
|          | `snapshot`    | ✔           |×            |mysql的快照备份保证数据一致需要加全局读锁|
| 逻辑备份 | `mongodump`   |  ✔          | ✔           |mysqldump逻辑备份只有备份innodb存储引擎的表可以做到数据一致服务可用|
| 数据文件备份         | `mongoexport` |            |  |          类似mysql -e 'select * from t1' > t1.xls;mysqlload < t1.xls|


## 物理备份工具_tar和snapshot
 
物理备份就是备份文件系统中的文件。需要停服或者加锁，保证没有新数据写入的情况下去备份数据目录，否则备份出来的数据是已损坏的，将无法正确恢复。

### MongoDB数据文件概览

> 初步了解存储引擎WiredTiger数据存储情况。
>
> 参考[【MongoDB Wiredtiger存储引擎实现原理】](http://www.mongoing.com/archives/2540)

Mongodb里一个典型的Wiredtiger数据库存储布局大致如下：

```
$tree
.
├── journal
│   ├── WiredTigerLog.0000000003
│   └── WiredTigerPreplog.0000000001
├── WiredTiger
├── WiredTiger.basecfg
├── WiredTiger.lock
├── WiredTiger.turtle
├── admin
│   ├── table1.wt
│   └── table2.wt
├── local
│   ├── table1.wt
│   └── table2.wt
└── WiredTiger.wt
```

- WiredTiger.basecfg存储基本配置信息
- WiredTiger.lock用于防止多个进程连接同一个Wiredtiger数据库
- table*.wt存储各个tale（数据库中的表）的数据
- WiredTiger.wt是特殊的table，用于存储所有其他table的元数据信息
- WiredTiger.turtle存储WiredTiger.wt的元数据信息
- journal存储Write ahead log

![0102-zyd-MongoDB WiredTiger存储引擎实现原理-4](http://www.mongoing.com/wp-content/uploads/2016/01/0102-zyd-MongoDB-WiredTiger%E5%AD%98%E5%82%A8%E5%BC%95%E6%93%8E%E5%AE%9E%E7%8E%B0%E5%8E%9F%E7%90%86-4-300x176.jpg)


### tar和snapshot工具

tar命令对mongodb的数据目录打包压缩即可
snapshot需要提前使用lvm，并挂接mongodb的数据目录使用，才可以使用。

#### 备份的一般步骤

1. 停服务
2. tar打包或者快照
3. 启服务


### 逻辑备份工具mongodump

#### 备份和恢复的权限说明

最小权限为backup和restore;认证数据库必须为admin

```shell
> use admin
switched to db admin

> db.createUser({user:'backup',pwd:'uplooking',roles:[{role:'backup',db:'admin'},{role:"restore",db:'test'}]})
2018-07-22T02:14:11.124-0700 E QUERY    [thread1] Error: couldn't add user: No role named restore@test :
_getErrorWithCode@src/mongo/shell/utils.js:25:13
DB.prototype.createUser@src/mongo/shell/db.js:1267:15
@(shell):1:1

> db.createUser({user:'backup',pwd:'uplooking',roles:[{role:'backup',db:'admin'},{role:"restore",db:'admin'}]})
Successfully added user: {
	"user" : "backup",
	"roles" : [
		{
			"role" : "backup",
			"db" : "admin"
		},
		{
			"role" : "restore",
			"db" : "admin"
		}
	]
}


```


#### mongodump

通过一次查询获取当前服务器快照，并将快照写入磁盘中

在获取快照后，服务器还会有数据写入，为了保证备份的安全，还是可以利用fsync和lock使服务器数据暂时写入缓存中

grant [`find`](https://docs.mongodb.com/manual/reference/privilege-actions/#find) action for each database to back up.


##### mongodump命令

mongodump 
`-u` ：用户名
`-p` ：密码
`--authenticationDatabase`： 认证库
`-d` ：指定备份库名
`-c` ：制定备份集合名
`-0` ：制定备份数据存放目录，不存在会自动创建


#### mongodump练习

1. 备份单库test
2. 导入数据时以覆盖的方式

```shell
# 待备份库test数据明细
> use test
switched to db test
> show collections;
t1
> db.t1.find()
{ "_id" : ObjectId("5b54457d9f05972521015e36"), "id" : 1 }

# 备份单库 test
[root@localhost mongodb]# mongodump -u backup -p uplooking --authenticationDatabase=admin -d test -c t1 -o  /alidata/backup
2018-07-22T02:44:39.288-0700	writing test.t1 to 
2018-07-22T02:44:39.289-0700	done dumping test.t1 (1 document)
# 查看备份文件
[root@localhost mongodb]# ll /alidata/backup/test/
total 8
-rw-r--r--. 1 root root 34 Jul 22 02:44 t1.bson
-rw-r--r--. 1 root root 79 Jul 22 02:44 t1.metadata.json
[root@localhost test]# hexdump -c t1.bson
0000000   "  \0  \0  \0  \a   _   i   d  \0   [   T   E   } 237 005 227
0000010   %   ! 001   ^   6 001   i   d  \0  \0  \0  \0  \0  \0  \0 360
0000020   ?  \0                                                        
0000022

# 插入数据
> db.t1.insert({'id':2})
WriteResult({ "nInserted" : 1 })
> db.t1.find()
{ "_id" : ObjectId("5b54457d9f05972521015e36"), "id" : 1 }
{ "_id" : ObjectId("5b5453b08eb232836ac6a089"), "id" : 2 }

# 恢复数据，覆盖test库
[root@localhost test]# mongorestore --drop -u backup -p uplooking --authenticationDatabase=admin -d test  -o  /alidata/backup
2018-07-22T02:52:42.623-0700	error parsing command line options: unknown option "o"
2018-07-22T02:52:42.623-0700	try 'mongorestore --help' for more information
[root@localhost test]# mongorestore --drop -u backup -p uplooking --authenticationDatabase=admin -d test  /alidata/backup/test
2018-07-22T02:53:00.325-0700	building a list of collections to restore from /alidata/backup/test dir
2018-07-22T02:53:00.326-0700	reading metadata for test.t1 from /alidata/backup/test/t1.metadata.json
2018-07-22T02:53:00.332-0700	restoring test.t1 from /alidata/backup/test/t1.bson
2018-07-22T02:53:00.334-0700	restoring indexes for collection test.t1 from metadata
2018-07-22T02:53:00.334-0700	finished restoring test.t1 (1 document)
2018-07-22T02:53:00.334-0700	done
# 查看导入后的t1表情况
> db.t1.find()
{ "_id" : ObjectId("5b54457d9f05972521015e36"), "id" : 1 }

```



#### 等等
```shell
[root@hjx01 hjxdb]# ll
总用量 948640
-rw-r--r--. 1 root root       266 12月 20 10:22 col.bson
-rw-r--r--. 1 root root       139 12月 20 10:22 col.metadata.json
-rw-r--r--. 1 root root       414 12月 20 10:22 posts_01.bson
-rw-r--r--. 1 root root        86 12月 20 10:22 posts_01.metadata.json
-rw-r--r--. 1 root root       566 12月 20 10:22 posts.bson
-rw-r--r--. 1 root root        83 12月 20 10:22 posts.metadata.json
-rw-r--r--. 1 root root     27218 12月 20 10:22 system.profile.bson
-rw-r--r--. 1 root root        55 12月 20 10:22 system.profile.metadata.json
-rw-r--r--. 1 root root     29109 12月 20 10:22 test.bson
-rw-r--r--. 1 root root        82 12月 20 10:22 test.metadata.json
-rw-r--r--. 1 root root 147777780 12月 20 10:23 userinfo.bson
-rw-r--r--. 1 root root        86 12月 20 10:22 userinfo.metadata.json
-rw-r--r--. 1 root root 823523880 12月 20 10:24 zhuyuninfo.bson
-rw-r--r--. 1 root root        88 12月 20 10:22 zhuyuninfo.metadata.json
```


### 逻辑备份恢复工具mongostore


#### mongorestore 语法

```shell
[root@hjx01 ~]# mongorestore -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -d hjxdb2 --dir=/tmp/col/hjxdb/
```

#### 恢复过程

```shell
[root@hjx01 ~]# mongorestore -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -d hjxdb2 --dir=/tmp/col/hjxdb/
2017-12-20T10:40:09.010+0800	building a list of collections to restore from /tmp/col/hjxdb dir
2017-12-20T10:40:09.012+0800	reading metadata for hjxdb2.zhuyuninfo from /tmp/col/hjxdb/zhuyuninfo.metadata.json
2017-12-20T10:40:09.013+0800	reading metadata for hjxdb2.userinfo from /tmp/col/hjxdb/userinfo.metadata.json
2017-12-20T10:40:09.014+0800	reading metadata for hjxdb2.test from /tmp/col/hjxdb/test.metadata.json
2017-12-20T10:40:09.017+0800	reading metadata for hjxdb2.posts from /tmp/col/hjxdb/posts.metadata.json
2017-12-20T10:40:09.282+0800	restoring hjxdb2.zhuyuninfo from /tmp/col/hjxdb/zhuyuninfo.bson
2017-12-20T10:40:09.300+0800	restoring hjxdb2.test from /tmp/col/hjxdb/test.bson
2017-12-20T10:40:09.334+0800	restoring hjxdb2.posts from /tmp/col/hjxdb/posts.bson
2017-12-20T10:40:09.338+0800	restoring hjxdb2.userinfo from /tmp/col/hjxdb/userinfo.bson
2017-12-20T10:40:09.537+0800	restoring indexes for collection hjxdb2.posts from metadata
2017-12-20T10:40:09.544+0800	finished restoring hjxdb2.posts (6 documents)
2017-12-20T10:40:09.592+0800	restoring indexes for collection hjxdb2.test from metadata
2017-12-20T10:40:09.616+0800	finished restoring hjxdb2.test (1003 documents)
2017-12-20T10:40:09.635+0800	reading metadata for hjxdb2.posts_01 from /tmp/col/hjxdb/posts_01.metadata.json
2017-12-20T10:40:09.636+0800	reading metadata for hjxdb2.col from /tmp/col/hjxdb/col.metadata.json
2017-12-20T10:40:09.701+0800	restoring hjxdb2.col from /tmp/col/hjxdb/col.bson
2017-12-20T10:40:09.732+0800	restoring hjxdb2.posts_01 from /tmp/col/hjxdb/posts_01.bson
2017-12-20T10:40:09.763+0800	restoring indexes for collection hjxdb2.col from metadata
2017-12-20T10:40:09.815+0800	restoring indexes for collection hjxdb2.posts_01 from metadata
2017-12-20T10:40:09.822+0800	finished restoring hjxdb2.col (6 documents)
2017-12-20T10:40:09.844+0800	finished restoring hjxdb2.posts_01 (3 documents)
2017-12-20T10:40:12.015+0800	[........................]  hjxdb2.zhuyuninfo  10.8MB/785MB  (1.4%)
2017-12-20T10:40:12.015+0800	[#.......................]    hjxdb2.userinfo  10.7MB/141MB  (7.6%)
2017-12-20T10:40:12.015+0800	
2017-12-20T10:40:15.014+0800	[........................]  hjxdb2.zhuyuninfo  22.7MB/785MB   (2.9%)
2017-12-20T10:40:15.014+0800	[###.....................]    hjxdb2.userinfo  21.8MB/141MB  (15.5%)
2017-12-20T10:40:15.014+0800	
2017-12-20T10:40:18.017+0800	[........................]  hjxdb2.zhuyuninfo  32.1MB/785MB   (4.1%)
2017-12-20T10:40:18.017+0800	[#####...................]    hjxdb2.userinfo  31.8MB/141MB  (22.6%)
2017-12-20T10:40:18.017+0800	
2017-12-20T10:40:21.015+0800	[#.......................]  hjxdb2.zhuyuninfo  44.5MB/785MB   (5.7%)
2017-12-20T10:40:21.015+0800	[#######.................]    hjxdb2.userinfo  45.0MB/141MB  (31.9%)
2017-12-20T10:40:21.015+0800	
2017-12-20T10:40:24.028+0800	[#.......................]  hjxdb2.zhuyuninfo  59.2MB/785MB   (7.5%)
2017-12-20T10:40:24.028+0800	[##########..............]    hjxdb2.userinfo  58.9MB/141MB  (41.8%)
2017-12-20T10:40:24.028+0800	
2017-12-20T10:40:27.018+0800	[##......................]  hjxdb2.zhuyuninfo  72.2MB/785MB   (9.2%)
2017-12-20T10:40:27.018+0800	[############............]    hjxdb2.userinfo  71.6MB/141MB  (50.8%)
2017-12-20T10:40:27.018+0800	
2017-12-20T10:40:30.012+0800	[##......................]  hjxdb2.zhuyuninfo  84.3MB/785MB  (10.7%)
2017-12-20T10:40:30.012+0800	[#############...........]    hjxdb2.userinfo  81.1MB/141MB  (57.5%)
2017-12-20T10:40:30.012+0800	
2017-12-20T10:40:33.014+0800	[##......................]  hjxdb2.zhuyuninfo  94.3MB/785MB  (12.0%)
2017-12-20T10:40:33.014+0800	[###############.........]    hjxdb2.userinfo  90.7MB/141MB  (64.3%)
2017-12-20T10:40:33.014+0800	
2017-12-20T10:40:36.061+0800	[###.....................]  hjxdb2.zhuyuninfo  105MB/785MB  (13.4%)
2017-12-20T10:40:36.061+0800	[#################.......]    hjxdb2.userinfo  102MB/141MB  (72.2%)
2017-12-20T10:40:36.061+0800	
2017-12-20T10:40:39.017+0800	[###.....................]  hjxdb2.zhuyuninfo  113MB/785MB  (14.4%)
2017-12-20T10:40:39.017+0800	[##################......]    hjxdb2.userinfo  109MB/141MB  (77.7%)
2017-12-20T10:40:39.017+0800	
2017-12-20T10:40:42.018+0800	[###.....................]  hjxdb2.zhuyuninfo  118MB/785MB  (15.0%)
2017-12-20T10:40:42.018+0800	[###################.....]    hjxdb2.userinfo  114MB/141MB  (80.7%)
2017-12-20T10:40:42.018+0800	
2017-12-20T10:40:45.125+0800	[###.....................]  hjxdb2.zhuyuninfo  124MB/785MB  (15.8%)
2017-12-20T10:40:45.125+0800	[####################....]    hjxdb2.userinfo  119MB/141MB  (84.8%)
2017-12-20T10:40:45.125+0800	
2017-12-20T10:40:48.105+0800	[####....................]  hjxdb2.zhuyuninfo  131MB/785MB  (16.7%)
2017-12-20T10:40:48.105+0800	[#####################...]    hjxdb2.userinfo  126MB/141MB  (89.1%)
2017-12-20T10:40:48.105+0800	
2017-12-20T10:40:51.066+0800	[####....................]  hjxdb2.zhuyuninfo  138MB/785MB  (17.5%)
2017-12-20T10:40:51.066+0800	[######################..]    hjxdb2.userinfo  132MB/141MB  (93.8%)
2017-12-20T10:40:51.066+0800	
2017-12-20T10:40:54.884+0800	[####....................]  hjxdb2.zhuyuninfo  141MB/785MB  (17.9%)
2017-12-20T10:40:54.884+0800	[#######################.]    hjxdb2.userinfo  137MB/141MB  (97.3%)
2017-12-20T10:40:54.884+0800	
2017-12-20T10:40:56.820+0800	[########################]  hjxdb2.userinfo  141MB/141MB  (100.0%)
2017-12-20T10:40:56.855+0800	restoring indexes for collection hjxdb2.userinfo from metadata
2017-12-20T10:40:57.065+0800	[####....................]  hjxdb2.zhuyuninfo  146MB/785MB  (18.6%)
2017-12-20T10:40:58.177+0800	finished restoring hjxdb2.userinfo (1000000 documents)
2017-12-20T10:41:00.067+0800	[####....................]  hjxdb2.zhuyuninfo  157MB/785MB  (20.0%)
2017-12-20T10:41:03.525+0800	[####....................]  hjxdb2.zhuyuninfo  162MB/785MB  (20.6%)
2017-12-20T10:41:06.250+0800	[#####...................]  hjxdb2.zhuyuninfo  176MB/785MB  (22.4%)
2017-12-20T10:41:09.233+0800	[#####...................]  hjxdb2.zhuyuninfo  187MB/785MB  (23.8%)
2017-12-20T10:41:12.065+0800	[######..................]  hjxdb2.zhuyuninfo  206MB/785MB  (26.2%)
2017-12-20T10:41:15.084+0800	[######..................]  hjxdb2.zhuyuninfo  210MB/785MB  (26.8%)
2017-12-20T10:41:18.014+0800	[######..................]  hjxdb2.zhuyuninfo  217MB/785MB  (27.7%)
2017-12-20T10:41:21.027+0800	[######..................]  hjxdb2.zhuyuninfo  219MB/785MB  (27.9%)
2017-12-20T10:41:24.021+0800	[######..................]  hjxdb2.zhuyuninfo  228MB/785MB  (29.0%)
2017-12-20T10:41:27.016+0800	[#######.................]  hjxdb2.zhuyuninfo  239MB/785MB  (30.4%)
2017-12-20T10:41:30.029+0800	[#######.................]  hjxdb2.zhuyuninfo  254MB/785MB  (32.3%)
2017-12-20T10:41:33.019+0800	[########................]  hjxdb2.zhuyuninfo  264MB/785MB  (33.6%)
2017-12-20T10:41:36.012+0800	[########................]  hjxdb2.zhuyuninfo  276MB/785MB  (35.1%)
2017-12-20T10:41:39.057+0800	[########................]  hjxdb2.zhuyuninfo  285MB/785MB  (36.3%)
2017-12-20T10:41:42.083+0800	[#########...............]  hjxdb2.zhuyuninfo  295MB/785MB  (37.6%)
2017-12-20T10:41:45.013+0800	[#########...............]  hjxdb2.zhuyuninfo  301MB/785MB  (38.4%)
2017-12-20T10:41:48.012+0800	[#########...............]  hjxdb2.zhuyuninfo  310MB/785MB  (39.5%)
2017-12-20T10:41:51.048+0800	[#########...............]  hjxdb2.zhuyuninfo  320MB/785MB  (40.8%)
2017-12-20T10:41:54.173+0800	[#########...............]  hjxdb2.zhuyuninfo  327MB/785MB  (41.6%)
2017-12-20T10:41:57.015+0800	[##########..............]  hjxdb2.zhuyuninfo  337MB/785MB  (42.9%)
2017-12-20T10:42:00.017+0800	[##########..............]  hjxdb2.zhuyuninfo  347MB/785MB  (44.2%)
2017-12-20T10:42:03.013+0800	[##########..............]  hjxdb2.zhuyuninfo  357MB/785MB  (45.4%)
2017-12-20T10:42:06.012+0800	[###########.............]  hjxdb2.zhuyuninfo  364MB/785MB  (46.3%)
2017-12-20T10:42:09.012+0800	[###########.............]  hjxdb2.zhuyuninfo  375MB/785MB  (47.7%)
2017-12-20T10:42:12.013+0800	[###########.............]  hjxdb2.zhuyuninfo  381MB/785MB  (48.5%)
2017-12-20T10:42:15.201+0800	[###########.............]  hjxdb2.zhuyuninfo  389MB/785MB  (49.5%)
2017-12-20T10:42:18.023+0800	[############............]  hjxdb2.zhuyuninfo  397MB/785MB  (50.6%)
2017-12-20T10:42:21.015+0800	[############............]  hjxdb2.zhuyuninfo  408MB/785MB  (52.0%)
2017-12-20T10:42:24.090+0800	[############............]  hjxdb2.zhuyuninfo  416MB/785MB  (52.9%)
2017-12-20T10:42:27.040+0800	[############............]  hjxdb2.zhuyuninfo  421MB/785MB  (53.6%)
2017-12-20T10:42:30.012+0800	[#############...........]  hjxdb2.zhuyuninfo  430MB/785MB  (54.8%)
2017-12-20T10:42:33.114+0800	[#############...........]  hjxdb2.zhuyuninfo  438MB/785MB  (55.8%)
2017-12-20T10:42:36.062+0800	[#############...........]  hjxdb2.zhuyuninfo  446MB/785MB  (56.8%)
2017-12-20T10:42:39.063+0800	[#############...........]  hjxdb2.zhuyuninfo  453MB/785MB  (57.6%)
2017-12-20T10:42:42.071+0800	[##############..........]  hjxdb2.zhuyuninfo  461MB/785MB  (58.7%)
2017-12-20T10:42:45.023+0800	[##############..........]  hjxdb2.zhuyuninfo  466MB/785MB  (59.3%)
2017-12-20T10:42:48.023+0800	[##############..........]  hjxdb2.zhuyuninfo  475MB/785MB  (60.5%)
2017-12-20T10:42:51.297+0800	[##############..........]  hjxdb2.zhuyuninfo  482MB/785MB  (61.4%)
2017-12-20T10:42:54.018+0800	[###############.........]  hjxdb2.zhuyuninfo  494MB/785MB  (62.8%)
2017-12-20T10:42:57.164+0800	[###############.........]  hjxdb2.zhuyuninfo  502MB/785MB  (63.9%)
2017-12-20T10:43:00.013+0800	[###############.........]  hjxdb2.zhuyuninfo  522MB/785MB  (66.5%)
2017-12-20T10:43:03.066+0800	[################........]  hjxdb2.zhuyuninfo  542MB/785MB  (69.0%)
2017-12-20T10:43:06.465+0800	[################........]  hjxdb2.zhuyuninfo  549MB/785MB  (70.0%)
2017-12-20T10:43:09.129+0800	[#################.......]  hjxdb2.zhuyuninfo  567MB/785MB  (72.2%)
2017-12-20T10:43:12.088+0800	[#################.......]  hjxdb2.zhuyuninfo  582MB/785MB  (74.1%)
2017-12-20T10:43:15.201+0800	[#################.......]  hjxdb2.zhuyuninfo  587MB/785MB  (74.8%)
2017-12-20T10:43:18.013+0800	[##################......]  hjxdb2.zhuyuninfo  591MB/785MB  (75.3%)
2017-12-20T10:43:21.013+0800	[##################......]  hjxdb2.zhuyuninfo  597MB/785MB  (76.1%)
2017-12-20T10:43:24.016+0800	[##################......]  hjxdb2.zhuyuninfo  606MB/785MB  (77.2%)
2017-12-20T10:43:27.012+0800	[##################......]  hjxdb2.zhuyuninfo  619MB/785MB  (78.8%)
2017-12-20T10:43:30.061+0800	[###################.....]  hjxdb2.zhuyuninfo  629MB/785MB  (80.0%)
2017-12-20T10:43:33.081+0800	[###################.....]  hjxdb2.zhuyuninfo  650MB/785MB  (82.8%)
2017-12-20T10:43:36.060+0800	[####################....]  hjxdb2.zhuyuninfo  656MB/785MB  (83.6%)
2017-12-20T10:43:39.123+0800	[####################....]  hjxdb2.zhuyuninfo  666MB/785MB  (84.7%)
2017-12-20T10:43:42.089+0800	[####################....]  hjxdb2.zhuyuninfo  679MB/785MB  (86.4%)
2017-12-20T10:43:45.097+0800	[#####################...]  hjxdb2.zhuyuninfo  696MB/785MB  (88.6%)
2017-12-20T10:43:48.134+0800	[#####################...]  hjxdb2.zhuyuninfo  709MB/785MB  (90.3%)
2017-12-20T10:43:51.019+0800	[######################..]  hjxdb2.zhuyuninfo  720MB/785MB  (91.7%)
2017-12-20T10:43:54.064+0800	[######################..]  hjxdb2.zhuyuninfo  729MB/785MB  (92.8%)
2017-12-20T10:43:57.230+0800	[######################..]  hjxdb2.zhuyuninfo  740MB/785MB  (94.2%)
2017-12-20T10:44:00.142+0800	[######################..]  hjxdb2.zhuyuninfo  751MB/785MB  (95.6%)
2017-12-20T10:44:03.064+0800	[#######################.]  hjxdb2.zhuyuninfo  763MB/785MB  (97.1%)
2017-12-20T10:44:06.113+0800	[#######################.]  hjxdb2.zhuyuninfo  777MB/785MB  (98.9%)
2017-12-20T10:44:09.240+0800	[#######################.]  hjxdb2.zhuyuninfo  783MB/785MB  (99.7%)
2017-12-20T10:44:11.258+0800	[########################]  hjxdb2.zhuyuninfo  785MB/785MB  (100.0%)
2017-12-20T10:44:11.307+0800	restoring indexes for collection hjxdb2.zhuyuninfo from metadata
2017-12-20T10:44:12.576+0800	finished restoring hjxdb2.zhuyuninfo (5504974 documents)
2017-12-20T10:44:12.630+0800	done
```

#### 恢复后查看

```shell
[root@hjx01 col]# mongo 127.0.0.1:22000/admin -u root -p root123
MongoDB shell version: 3.2.16
connecting to: 127.0.0.1:22000/admin
> show dbs
admin   0.000GB
hjxdb   0.128GB
hjxdb2  0.129GB
local   0.000GB
> use hjxdb2
switched to db hjxdb2
> show collections
col
posts
posts_01
system.profile
test
userinfo
zhuyuninfo
> db.col.find()
{ "_id" : ObjectId("5a2f76c46f85c40e6adcbf1a"), "age" : 25, "e" : "Tom" }
{ "_id" : ObjectId("5a2f76ed6f85c40e7972dd8c"), "age" : 25, "e" : "Tom" }
{ "_id" : ObjectId("5a2f76fb6f85c40e87c17940"), "age" : 25, "e" : "Tom" }
{ "_id" : ObjectId("5a2f7d154f034c6478c21507"), "id" : 100, "author" : "curry" }
{ "_id" : ObjectId("5a2f80564f034c6478c21508"), "id" : 100, "author" : "curry" }
{ "_id" : ObjectId("5a338bde667a143384c19b2c"), "user" : "leo" }
> 
```

#### 扩展

```shell
[root@hjx01 col]# mongo 127.0.0.1:22000/hjxdb2 -u hjx -p hjx123
MongoDB shell version: 3.2.16
connecting to: 127.0.0.1:22000/hjxdb2
2017-12-20T10:47:59.317+0800 E QUERY    [thread1] Error: Authentication failed. :
DB.prototype._authOrThrow@src/mongo/shell/db.js:1441:20
@(auth):6:1
@(auth):1:2

exception: login failed
```

> 整库备份认证信息不会被备份和恢复

# 三、单个collection备份

### mongoexport 帮助

```shell
[root@hjx01 col]# mongoexport --help
Usage:
  mongoexport <options>

Export data from MongoDB in CSV or JSON format.

See http://docs.mongodb.org/manual/reference/program/mongoexport/ for more information.

general options:
      --help                                      print usage
      --version                                   print the tool version and exit

verbosity options:
  -v, --verbose=<level>                           more detailed log output (include multiple times for more verbosity, e.g. -vvvvv, or specify a numeric value, e.g. --verbose=N)
      --quiet                                     hide all log output

connection options:
  -h, --host=<hostname>                           mongodb host to connect to (setname/host1,host2 for replica sets)
      --port=<port>                               server port (can also use --host hostname:port)

ssl options:
      --ssl                                       connect to a mongod or mongos that has ssl enabled
      --sslCAFile=<filename>                      the .pem file containing the root certificate chain from the certificate authority
      --sslPEMKeyFile=<filename>                  the .pem file containing the certificate and key
      --sslPEMKeyPassword=<password>              the password to decrypt the sslPEMKeyFile, if necessary
      --sslCRLFile=<filename>                     the .pem file containing the certificate revocation list
      --sslAllowInvalidCertificates               bypass the validation for server certificates
      --sslAllowInvalidHostnames                  bypass the validation for server name
      --sslFIPSMode                               use FIPS mode of the installed openssl library

authentication options:
  -u, --username=<username>                       username for authentication
  -p, --password=<password>                       password for authentication
      --authenticationDatabase=<database-name>    database that holds the user's credentials
      --authenticationMechanism=<mechanism>       authentication mechanism to use

namespace options:
  -d, --db=<database-name>                        database to use
  -c, --collection=<collection-name>              collection to use

output options:
  -f, --fields=<field>[,<field>]*                 comma separated list of field names (required for exporting CSV) e.g. -f "name,age"
      --fieldFile=<filename>                      file with field names - 1 per line
      --type=<type>                               the output format, either json or csv (defaults to 'json')
  -o, --out=<filename>                            output file; if not specified, stdout is used
      --jsonArray                                 output to a JSON array rather than one object per line
      --pretty                                    output JSON formatted to be human-readable

querying options:
  -q, --query=<json>                              query filter, as a JSON string, e.g., '{x:{$gt:1}}'
      --queryFile=<filename>                      path to a file containing a query filter (JSON)
  -k, --slaveOk                                   allow secondary reads if available (default true)
      --readPreference=<string>|<json>            specify either a preference name or a preference json object
      --forceTableScan                            force a table scan (do not use $snapshot)
      --skip=<count>                              number of documents to skip
      --limit=<count>                             limit the number of documents to export
      --sort=<json>                               sort order, as a JSON string, e.g. '{x:1}'
      --assertExists                              if specified, export fails if the collection does not exist (false)
```

### mongoexport语法

```shell
[root@hjx01 ~]# mongoexport -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -d hjxdb2 -c col -f age -o /tmp/col.txt
2017-12-20T11:16:53.066+0800	connected to: 127.0.0.1:22000
2017-12-20T11:16:53.174+0800	exported 6 records

[root@hjx01 ~]# cat /tmp/col.txt 
{"_id":{"$oid":"5a2f76c46f85c40e6adcbf1a"},"age":25}
{"_id":{"$oid":"5a2f76ed6f85c40e7972dd8c"},"age":25}
{"_id":{"$oid":"5a2f76fb6f85c40e87c17940"},"age":25}
{"_id":{"$oid":"5a2f7d154f034c6478c21507"}}
{"_id":{"$oid":"5a2f80564f034c6478c21508"}}
{"_id":{"$oid":"5a338bde667a143384c19b2c"}}
```

# 四、单个collection恢复

### mongoimport帮助

```shell
[root@hjx01 ~]# mongoimport --help
Usage:
  mongoimport <options> <file>

Import CSV, TSV or JSON data into MongoDB. If no file is provided, mongoimport reads from stdin.

See http://docs.mongodb.org/manual/reference/program/mongoimport/ for more information.

general options:
      --help                                      print usage
      --version                                   print the tool version and exit

verbosity options:
  -v, --verbose=<level>                           more detailed log output (include multiple times for more verbosity, e.g. -vvvvv, or specify a numeric value, e.g. --verbose=N)
      --quiet                                     hide all log output

connection options:
  -h, --host=<hostname>                           mongodb host to connect to (setname/host1,host2 for replica sets)
      --port=<port>                               server port (can also use --host hostname:port)

ssl options:
      --ssl                                       connect to a mongod or mongos that has ssl enabled
      --sslCAFile=<filename>                      the .pem file containing the root certificate chain from the certificate authority
      --sslPEMKeyFile=<filename>                  the .pem file containing the certificate and key
      --sslPEMKeyPassword=<password>              the password to decrypt the sslPEMKeyFile, if necessary
      --sslCRLFile=<filename>                     the .pem file containing the certificate revocation list
      --sslAllowInvalidCertificates               bypass the validation for server certificates
      --sslAllowInvalidHostnames                  bypass the validation for server name
      --sslFIPSMode                               use FIPS mode of the installed openssl library

authentication options:
  -u, --username=<username>                       username for authentication
  -p, --password=<password>                       password for authentication
      --authenticationDatabase=<database-name>    database that holds the user's credentials
      --authenticationMechanism=<mechanism>       authentication mechanism to use

namespace options:
  -d, --db=<database-name>                        database to use
  -c, --collection=<collection-name>              collection to use

input options:
  -f, --fields=<field>[,<field>]*                 comma separated list of field names, e.g. -f name,age
      --fieldFile=<filename>                      file with field names - 1 per line
      --file=<filename>                           file to import from; if not specified, stdin is used
      --headerline                                use first line in input source as the field list (CSV and TSV only)
      --jsonArray                                 treat input source as a JSON array
      --type=<type>                               input format to import: json, csv, or tsv (defaults to 'json')

ingest options:
      --drop                                      drop collection before inserting documents
      --ignoreBlanks                              ignore fields with empty values in CSV and TSV
      --maintainInsertionOrder                    insert documents in the order of their appearance in the input source
  -j, --numInsertionWorkers=<number>              number of insert operations to run concurrently (defaults to 1)
      --stopOnError                               stop importing at first insert/upsert error
      --upsert                                    insert or update objects that already exist
      --upsertFields=<field>[,<field>]*           comma-separated fields for the query part of the upsert
      --writeConcern=<write-concern-specifier>    write concern options e.g. --writeConcern majority, --writeConcern '{w: 3, wtimeout: 500, fsync: true, j: true}' (defaults to
                                                  'majority')
      --bypassDocumentValidation                  bypass document validation

```

### mongoimport语法

```shell
[root@hjx01 ~]# mongoimport -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -d hjxdb3 -c col --file=/tmp/col.csv 
2017-12-20T13:25:31.684+0800	connected to: 127.0.0.1:22000
2017-12-20T13:25:31.986+0800	imported 6 documents
```

#### 恢复后查看

```shell
[root@hjx01 col]# mongo 127.0.0.1:22000/admin -u root -p root123
MongoDB shell version: 3.2.16
connecting to: 127.0.0.1:22000/admin
> show dbs
admin   0.000GB
hjxdb   0.128GB
hjxdb2  0.129GB
hjxdb3  0.000GB
local   0.000GB
> use hjxdb3
switched to db hjxdb3
> show collections
col
system.profile
> db.col.find()
{ "_id" : ObjectId("5a2f76c46f85c40e6adcbf1a"), "age" : 25 }
{ "_id" : ObjectId("5a2f76ed6f85c40e7972dd8c"), "age" : 25 }
{ "_id" : ObjectId("5a2f76fb6f85c40e87c17940"), "age" : 25 }
{ "_id" : ObjectId("5a2f7d154f034c6478c21507") }
{ "_id" : ObjectId("5a2f80564f034c6478c21508") }
{ "_id" : ObjectId("5a338bde667a143384c19b2c") }
> 

```

# 案例

### dropDatabase后恢复

#### oplog 恢复

```shell
h1:PRIMARY> db.b.save({name:"apple"})
WriteResult({ "nInserted" : 1 })
h1:PRIMARY> for (var i =0;i<=100;i++){
... db.c.insert({name:"leo"+i})
... }
WriteResult({ "nInserted" : 1 })
h1:PRIMARY> db.b.drop()
true
h1:PRIMARY> db.c.remove({})
WriteResult({ "nRemoved" : 101 })
h1:PRIMARY> db.c.insert({name:"hhhhhhhhhh"})
WriteResult({ "nInserted" : 1 })

# 导出所有备份
[root@hjx01 local]# mongodump -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -o /tmp/mongo/

# 导出oplog集合
[root@hjx01 local]# mongodump -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -d local -c oplog.rs -o /tmp/mongo/

## oplog集合的数据
[root@hjx01 local]# mv oplog.rs.bson oplog.bson

## 查看oplog，截取drop数据库部分
[root@hjx01 local]# bsondump oplog.bson|grep -B 1'"drop":"b"'
{"ts":{"$timestamp":{"t":1513843826,"i":1}},"t":{"$numberLong":"2"},"h":{"$numberLong":"-3965151384504157994"},"v":2,"op":"c","ns":"test3.$cmd","o":{"drop":"b"}}

# 重放oplog
[root@hjx01 local]# mongorestore -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin --drop --oplogReplay --oplogLimit "1513843826:1" /tmp/mongo/local/
[root@hjx01 local]# mongorestore -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin --oplogReplay --oplogLimit "1513843846:20" /tmp/mongo/local/
```

>  复制集，这时还有一线希望，可以通过 oplog 来尽可能的恢复数据,MongoDB 复制集的每一条修改操作都会记录一条 oplog。
>
>  --oplogReplay --oplogLimit "1513843846:20" 这两个参数必须连用，是会恢复到1513843846 这个操作的第20次

#### 通过分析数据文件恢复

| 引擎           | MMAPV1                           | WIREDTIGER           |
| -------------- | -------------------------------- | -------------------- |
| dropDatabase   | 数据文件立即会被删除             | 数据文件立即会被删除 |
| dropCollection | 不会立即从磁盘删除，空间会被复用 | 数据文件立即会被删除 |

|


