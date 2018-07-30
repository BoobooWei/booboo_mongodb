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
| 数据文件备份         | `mongoexport` | ✔ | ✔ |          类似mysql -e 'select * from t1' > t1.xls;mysqlload < t1.xls|


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

### tar备份的一般步骤

1. 停服务
2. tar打包或者快照
3. 启服务

### tar还原的一般步骤

1. 停服务
2. 清环境
3. 导入数据
4. 启服务


## 逻辑备份工具mongodump

mongodump将数据库的数据备份保存为bson格式的文件；
备份数据为备份开始的时间点;

### 备份和恢复的权限说明

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

### 备份的一般步骤

1. fsync和lock保证备份过程中数据一致（可选，会导致服务不可用）
2. mongodump开始备份
3. 解锁unlock（第一步则有第三步）

说明：
* fsync：强制服务器将所有缓冲区写入磁盘，保证运行时复制数据目录页不会损坏数据（物理备份数据目录，除了停服，还可以选择fsync）。
* lock：只能读不能写

```shell
> use admin;  
switched to db admin  
> db.runCommand({"fsync" : 1, "lock" : 1});  
{  
        "info" : "now locked against writes, use db.fsyncUnlock() to unlock",  
        "seeAlso" : "http://www.mongodb.org/display/DOCS/fsync+Command",  
        "ok" : 1  
} 
```

注意运行fsync命令需要在admin数据库下进行！通过执行上述命令，缓冲区内数据已经被写入磁盘数据库文件中，并且数据库此时无法执行写操作（写操作阻塞）！这样，我们可以很安全地备份数据目录了！备份后，我们通过下面的调用，来解锁：

```shell
> use admin;  
switched to db admin  
> db.$cmd.sys.unlock.findOne();  
{ "ok" : 1, "info" : "unlock completed" }  
> db.currentOp();  
{ "inprog" : [ ] }  
```

#### mongodump 命令

* `-u` ：用户名
* `-p` ：密码
* `--authenticationDatabase`： 认证库
* `-d` ：指定备份库名
* `-c` ：制定备份集合名
* `-o ：制定备份数据存放目录，不存在会自动创建

#### mongodump 备份案例

| 案例                             | 命令                                                         |
| -------------------------------- | ------------------------------------------------------------ |
| 备份所有的库                     | `mongodump -uuser -ppwd --authenticationDatabase=db -o /alidata/backup` |
| 备份一个库test                   | `mongodump -uuser -ppwd --authenticationDatabase=db -d test -o /alidata/backup` |
| 备份一个库test中的一个集合t1     | `mongodump -uuser -ppwd --authenticationDatabase=db -d test -c t1 -o /alidata/backup` |
| 备份一个库test中的两个集合t1,t2  | `c=(t1 t2);for i in ${c[*]};do mongodump -uuser -ppwd --authenticationDatabase=db -d test -c $i -o /alidata/backup; done` |
| 备份两个库test，booboo           | `db=(test booboo);for i in ${db[*]};do mongodump -uuser -ppwd --authenticationDatabase=db -d $i -o /alidata/backup;done` |
| 备份test库中的t1和booboo库中的t1 | 见mongodump备份脚本                                          |

#### mongodump 备份脚本

[mongodump python备份脚本](scripts/backup_mongodump.py)

* 该脚本为了内部的devops平台，因此做成了接口的方式，而不是工具。
* 指定备份内容需要写成json格式，例

```shell
# 案例1——备份[所有的库all]/[指定某一个库]
'backup_db_collection': [
		{
	    	    'database':'all', #所有的库用'all',指定的单库用库名
		    'collection': ['all'] # 所有的表用['all']，多个集合用['t1','t2']
		}
	]
# 案例2——备份多个库
'backup_db_collection': [
		{
	    	    'database':'db1',
		    'collection': ['all']
		}，
		{
	    	    'database':'db2',
		    'collection': ['c1','c2']
		}
	]
```


### 恢复的一般步骤

1. 确定恢复的对象为全库还是某个库
2. 确定数据是合并还是覆盖
3. 开始恢复

#### mongorestore 命令

> 基于collection的并发

* `-d` 还原库名
* `-c` 还原集合名
* `--drop` 清空库中的所有集合
* `--dir=` 指定备份文件

#### mongorestore 还原案例

1. 将压缩过的逻辑备份，以覆盖的方式导入test库

```shell
[root@sh_01 backup]# mongorestore -ubackup -puplooking --authenticationDatabase=admin --gzip -d test --drop --dir=/alidata/backup/test
2018-07-24T14:40:16.961+0800	building a list of collections to restore from /alidata/backup/test dir
2018-07-24T14:40:16.962+0800	reading metadata for test.t1 from /alidata/backup/test/t1.metadata.json.gz
2018-07-24T14:40:16.976+0800	restoring test.t1 from /alidata/backup/test/t1.bson.gz
2018-07-24T14:40:16.977+0800	restoring indexes for collection test.t1 from metadata
2018-07-24T14:40:16.977+0800	finished restoring test.t1 (1 document)
2018-07-24T14:40:16.977+0800	done
```

2. 将压缩过的逻辑备份，以合并的方式导入test库(不加`--drop`)

```shell
# 备份数据为test.t1 { "_id" : ObjectId("5b55b8623496bc5ff3fb047e"), "id" : 1 }
## 场景1 
#> 当前数据为test.t1 
> db.t1.find()
{ "_id" : ObjectId("5b55b8623496bc5ff3fb047e"), "id" : 1 }

#> 导入数据时会发现存在报错，跳过了重复的文档（行）
[root@sh_01 backup]# mongorestore -ubackup -puplooking --authenticationDatabase=admin --gzip -d test  --dir=/alidata/backup/test
2018-07-24T14:49:14.472+0800	building a list of collections to restore from /alidata/backup/test dir
2018-07-24T14:49:14.473+0800	reading metadata for test.t1 from /alidata/backup/test/t1.metadata.json.gz
2018-07-24T14:49:14.473+0800	restoring test.t1 from /alidata/backup/test/t1.bson.gz
2018-07-24T14:49:14.475+0800	error: E11000 duplicate key error collection: test.t1 index: _id_ dup key: { : ObjectId('5b55b8623496bc5ff3fb047e') }
2018-07-24T14:49:14.475+0800	restoring indexes for collection test.t1 from metadata
2018-07-24T14:49:14.475+0800	finished restoring test.t1 (1 document)
2018-07-24T14:49:14.475+0800	done
#> 恢复结果
> db.t1.find()
{ "_id" : ObjectId("5b55b8623496bc5ff3fb047e"), "id" : 1 }

## 场景2 
#> 当前数据为test.t1
> db.t1.find()
{ "_id" : ObjectId("5b55b8623496bc5ff3fb047e"), "id" : 1 }
{ "_id" : ObjectId("5b56cc3eaa626db6a5bc7141"), "name" : "booboo" }
#> 导入数据时会发现存在报错，跳过了重复的文档（行）
[root@sh_01 backup]# mongorestore -ubackup -puplooking --authenticationDatabase=admin --gzip -d test  --dir=/alidata/backup/test
2018-07-24T14:56:48.230+0800	building a list of collections to restore from /alidata/backup/test dir
2018-07-24T14:56:48.231+0800	reading metadata for test.t1 from /alidata/backup/test/t1.metadata.json.gz
2018-07-24T14:56:48.232+0800	restoring test.t1 from /alidata/backup/test/t1.bson.gz
2018-07-24T14:56:48.233+0800	error: E11000 duplicate key error collection: test.t1 index: _id_ dup key: { : ObjectId('5b55b8623496bc5ff3fb047e') }
2018-07-24T14:56:48.233+0800	restoring indexes for collection test.t1 from metadata
2018-07-24T14:56:48.234+0800	finished restoring test.t1 (1 document)
2018-07-24T14:56:48.234+0800	done
#> 恢复结果
> db.t1.find()
{ "_id" : ObjectId("5b55b8623496bc5ff3fb047e"), "id" : 1 }
{ "_id" : ObjectId("5b56cc3eaa626db6a5bc7141"), "name" : "booboo" }

## 场景3 
#> 当前数据为test.t1
> db.t1.find()
{ "_id" : ObjectId("5b56ce7caa626db6a5bc7142"), "justice" : 1 }
#> 导入数据
[root@sh_01 backup]# mongorestore -ubackup -puplooking --authenticationDatabase=admin --gzip -d test  --dir=/alidata/backup/test
2018-07-24T15:00:38.507+0800	building a list of collections to restore from /alidata/backup/test dir
2018-07-24T15:00:38.508+0800	reading metadata for test.t1 from /alidata/backup/test/t1.metadata.json.gz
2018-07-24T15:00:38.508+0800	restoring test.t1 from /alidata/backup/test/t1.bson.gz
2018-07-24T15:00:38.511+0800	restoring indexes for collection test.t1 from metadata
2018-07-24T15:00:38.511+0800	finished restoring test.t1 (1 document)
2018-07-24T15:00:38.511+0800	done

#> 恢复结果
> db.t1.find()
{ "_id" : ObjectId("5b55b8623496bc5ff3fb047e"), "id" : 1 }
{ "_id" : ObjectId("5b56cc3eaa626db6a5bc7141"), "name" : "booboo" }
```

## 集合数据导出导入

> mongoexport可以将集合导出为csv和json格式，适合给到运营以及开发人员

### mongoexport 导出

- `-d` 数据库
- `-c` 集合名
- `-f` 域名（列名）
- `--type=<json(default),csv>`  导出的文件类型
- `-o` 导出文件名

```shell
> db.t1.find()
{ "_id" : ObjectId("5b56d7f58b5b92f4efb176b6"), "id" : 1, "name" : "superman" }
{ "_id" : ObjectId("5b56d7fc8b5b92f4efb176b7"), "id" : 2, "name" : "batman" }

```

### mongoimport 导入

* `-d` 导入数据库
* `-c` 导入集合名
* `--file=` 待导入的文件

```shell
[root@hjx01 ~]# mongoimport -h 127.0.0.1:22000 -u root -p root123 --authenticationDatabase=admin -d hjxdb3 -c col --file=/tmp/col.csv 
2017-12-20T13:25:31.684+0800	connected to: 127.0.0.1:22000
2017-12-20T13:25:31.986+0800	imported 6 documents

[root@sh_01 test]# mongoexport -ubackup -puplooking --authenticationDatabase=admin -d test -c t1 -f id,name --type=cs
2018-07-24T15:41:17.020+0800	connected to: localhost
2018-07-24T15:41:17.020+0800	exported 2 records
[root@sh_01 test]# cat /tmp/backup_mongodb.csv 
id,name
1,superman
2,batman



> db.t2.find()
{ "_id" : ObjectId("5b56d91e290d3a3eb2e1b02d"), "id" : 1, "name" : [ { "a" : 1, "b" : { "xx" : 1 } }, { "a" : 200, "
[root@sh_01 test]# mongoexport -ubackup -puplooking --authenticationDatabase=admin -d test -c t2 -f id,name --type=js
2018-07-24T15:50:42.691+0800	connected to: localhost
2018-07-24T15:50:42.693+0800	exported 1 record
[root@sh_01 test]# cat /tmp/backup_mongodb.csv 
{"_id":{"$oid":"5b56d91e290d3a3eb2e1b02d"},"id":1.0,"name":[{"a":1.0,"b":{"xx":1.0}},{"a":200.0,"b":{"xx":30.0}}]}
```

## MongoDB备份恢复实战

### 单库备份和恢复

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

### dropDatabase后恢复

#### 通过分析数据文件恢复

| 引擎           | MMAPV1                           | WIREDTIGER           |
| -------------- | -------------------------------- | -------------------- |
| dropDatabase   | 数据文件立即会被删除             | 数据文件立即会被删除 |
| dropCollection | 不会立即从磁盘删除，空间会被复用 | 数据文件立即会被删除 |

#### oplog 恢复

> 复制集，这时还有一线希望，可以通过 oplog 来尽可能的恢复数据,MongoDB 复制集的每一条修改操作都会记录一条 oplog。

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

>  --oplogReplay --oplogLimit "1513843846:20" 这两个参数必须连用，是会恢复到1513843846 这个操作的第20次



