# MongoDB认证权限管理

[TOC]

虽然认证和 授权 关系非常紧密，认证和授权是两个不同的概念。

* 认证是用来识别用户的身份
* 授权控制已经认证的用户使用资源和行为的权限。 

本节初步了解和熟悉MongoDB的认证和权限，官方[3.4版本安全参考文献](http://www.mongoing.com/docs/reference/security.html)

## 认证

### 认证简介

MongoDB中的用户分为超级用户(super user)和普通的数据库用户(database user)：

- 超级用户存放在admin数据库中(在MongoDB的初始情况下，admin数据库默认是空的)，这种用户拥有最大权限，可以对所有数据库进行任意操作；
- 数据库用户则是存放在另外的数据库中，这种用户只能访问自己的数据库。所有的用户信息都存放在自己数据库的system.users表中。

具体的方法见MongoDB官方文档。



### 启动认证的一般流程

---

初始化安装情况下是没有开通认证的。

#### 1.不带访问控制的启动服务 

```shell
cd /alidata/mongodb
bash mongodb.server start
```

#### 2.连接实例

`mongo --port 27017`

#### 3.创建超级账户

```shell
> use admin
> db.createUser(
  {
    user: "myUserAdmin",
    pwd: "abc123",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
  }
)
```

#### 4.带访问控制重新启动实例 

修改配置文件后重启

```shell
vim /alidata/mongodb/conf/mongodb27017.conf
# http://www.mongoing.com/docs/reference/configuration-options.html#security.authorization
security:
    authorization=enabled
bash /alidata/mongodb/mongodb.server restart    
```

#### 5.连接并认证超级账户

```shell
# 第一种方法连接前认证——使用 -u -p --authenticationDatabase 数据库名
mongo --port 27017 -u "myUserAdmin" -p "abc123" --authenticationDatabase "admin"

# 第二种方法连接后认证，在mongo shell中使用 db.auth(<username>
mongo --port 27017
> use admin
> db.auth("myUserAdmin", "abc123" )
```

#### 6.根据开发要求创建其他用户

一旦成功认证了超级用户，就可以通过`db.createUser() `命令以及`内置或者用户自定义的角色（权限）`来创建其他用户

而`myUserAdmin`用户的权限只能管理用户和角色（权限）

接下来我们创建一个新用户`myTest`用户给`test`数据库，并且对`test`数据库拥有读写权限`readWrite role`，对`reporting`数据库有读的权限`read role`

```shell
use test
db.createUser(
  {
    user: "myTester",
    pwd: "xyz123",
    roles: [ { role: "readWrite", db: "test" },
             { role: "read", db: "reporting" } ]
  }
)
```

#### 7.用myTester用户连接和认证

在连接前认证

Start a mongo shell with the -u <username>, -p <password>, and the --authenticationDatabase <database> command line options:

```shell
mongo --port 27017 -u "myTester" -p "xyz123" --authenticationDatabase "test"
```

在连接后认证

```shell
# 连接
mongo --port 27017

# 认证
> use test
> db.auth("myTester", "xyz123" )

# 插入一个集合
> db.foo.insert( { x: 1, y: 1 } )

# 查看reporting数据库的集合信息
> use reporting
> db.a.find()
```

### 删除用户

> 记住所有对认证的操作，都需要到对应的认证库中进行操作即可。

删除用户的操作如下：

```shell
> use test
> db.system.users.remove({user:"myTester"})
```

### 更新用户

修改密码和角色

```shell
> use test
> db.updateUser('myTester',{user:'myTester',pwd:'admin',roles:[{role:'read',db:'test'}]})  
>
```

## 权限

### 重点说明

* `Read`：允许用户读取指定数据库
* `readWrite`：允许用户读写指定数据库
* `dbAdmin`：允许用户在指定数据库中执行管理函数，如索引创建、删除，查看统计或访问`system.profile`
* `userAdmin`：允许用户向`system.users`集合写入，可以找指定数据库里创建、删除和管理用户
* `clusterAdmin`：只在`admin`数据库中可用，赋予用户所有分片和复制集相关函数的管理权限。
* `readAnyDatabase`：只在admin数据库中可用，赋予用户所有数据库的读权限
* `readWriteAnyDatabas`：只在`admin`数据库中可用，赋予用户所有数据库的读写权限
* `userAdminAnyDatabase`：只在`admin`数据库中可用，赋予用户所有数据库的`userAdmin`权限
* `dbAdminAnyDatabase`：只在`admin`数据库中可用，赋予用户所有数据库的`dbAdmin`权限。
* `root`：只在`admin`数据库中可用。超级账号，超级权限

### 内置角色（权限）

```shell
  Built-In Roles（内置角色）：
    1. 数据库用户角色：read、readWrite;
    2. 数据库管理角色：dbAdmin、dbOwner、userAdmin；
    3. 集群管理角色：clusterAdmin、clusterManager、clusterMonitor、hostManager；
    4. 备份恢复角色：backup、restore；
    5. 所有数据库角色：readAnyDatabase、readWriteAnyDatabase、userAdminAnyDatabase、dbAdminAnyDatabase
    6. 超级用户角色：root  
    // 这里还有几个角色间接或直接提供了系统超级用户的访问（dbOwner 、userAdmin、userAdminAnyDatabase）
    7. 内部角色：__system 
```

## 总结

在MongoDB中，用户和权限有以下特性：

1. 数据库是由超级用户来创建的，一个数据库可以包含多个用户，一个用户只能在一个数据库下，不同数据库中的用户可以同名；
2. 如果在 admin 数据库中不存在用户，即使 mongod 启动时添加了 --auth参数，此时不进行任何认证还是可以做任何操作；
3. 在 admin 数据库创建的用户具有超级权限，可以对 MongoDB 系统内的任何数据库的数据对象进行操作；
4. 特定数据库比如 test1 下的用户 test_user1，不能够访问其他数据库 test2，但是可以访问本数据库下其他用户创建的数据；
5. 不同数据库中同名的用户不能够登录其他数据库。比如数据库 test1 和 test2 都有用户 test_user，以 test_user 登录 test1 后,不能够登录到 test2 进行数据库操作

## 课堂练习

### 1. 创建超级用户project_root，拥有管理所有数据库的账户和管理所有数据库的权限

```shell
# 安装mongodb3.2.16
# 无认证启动服务
# 通过客户端登陆
[root@sh_01 ~]# mongo
MongoDB shell version: 3.2.16
connecting to: test
Server has startup warnings: 
2018-07-20T17:00:10.204+0800 I CONTROL  [initandlisten] ** WARNING: You are running this process as the root user, which is not recommended.
2018-07-20T17:00:10.204+0800 I CONTROL  [initandlisten] 
> use admin
switched to db admin
> var info = {}
> info.user = 'project_root'
project_root
> info.pwd = 'uplooking'
uplooking
> info.roles = [{role:'userAdminAnyDatabase',db:'admin'},{role:'dbAdminAnyDatabase',db:'admin'}]
[
	{
		"role" : "userAdminAnyDatabase",
		"db" : "admin"
	},
	{
		"role" : "dbAdminAnyDatabase",
		"db" : "admin"
	}
]
> db.createUser(info)
Successfully added user: {
	"user" : "project_root",
	"roles" : [
		{
			"role" : "userAdminAnyDatabase",
			"db" : "admin"
		},
		{
			"role" : "dbAdminAnyDatabase",
			"db" : "admin"
		}
	]
}
> db.system.users.find()
{ "_id" : "admin.project_root", "user" : "project_root", "db" : "admin", "credentials" : { "SCRAM-SHA-1" : { "iterationCount" : 10000, "salt" : "RFqvJ3Qqcida/liGCwVlxw==", "storedKey" : "UoU3899FEBYiCMicsXC/dA9bonI=", "serverKey" : "zZiljnXV3ZK+bHfYG+JDoBV3Ovs=" } }, "roles" : [ { "role" : "userAdminAnyDatabase", "db" : "admin" }, { "role" : "dbAdminAnyDatabase", "db" : "admin" } ] }

```

### 2. 开启认证服务后通过project_root用户登陆并认证

```shell
# 修改配置文件
[root@sh_01 ~]# vim /alidata/mongodb/conf/mongodb27017.conf 
security:
 authorization: enabled 

# 重启服务
[root@sh_01 ~]# bash /alidata/mongodb/mongodb.server restart
killing process with pid: 17902

# 登陆mongodb
[root@sh_01 ~]# mongo
MongoDB shell version: 3.2.16
connecting to: test
# 认证用户
> use admin
switched to db admin
> db.auth('project_root','uplooking')
1
```



### 3. 建立一个test库的数据库管理账号test_admin

```shell
> 
> use test
switched to db test
> var info = {}
> info.user = 'test_admin'
test_admin
> info.pwd = 'uplooking'
uplooking
> info.roles = [{role:'dbadmin',db:'test'}]
[ { "role" : "dbadmin", "db" : "test" } ]
> info.roles = [{role:'dbAdmin',db:'test'}]
[ { "role" : "dbAdmin", "db" : "test" } ]
> db.createUser(info)
Successfully added user: {
	"user" : "test_admin",
	"roles" : [
		{
			"role" : "dbAdmin",
			"db" : "test"
		}
	]
}
```



### 4.建立一个test库的开发账号test_dev，拥有读写权限 

```shell
> use test
switched to db test
> var info = {}
> info.user = 'test_dev'
test_dev
> info.pwd = 'uplooking'
uplooking
> info.roles = [{role:'readWrite', db:'test'}]
[ { "role" : "readWrite", "db" : "test" } ]
> db.createUser(info)
Successfully added user: {
	"user" : "test_dev",
	"roles" : [
		{
			"role" : "readWrite",
			"db" : "test"
		}
	]
}
```

### 5. 验证所有的账号权限是否如官方文档所表述的

```shell
# 1. project_root用户拥有管理用户的权限，从2~4题已经可以验证
# 2. project_root用户拥有管理数据库的权限
> use admin
switched to db admin
> db.auth('project_root','uplooking')
1
> use test
switched to db test
> db.t1.find()
Error: error: {
	"ok" : 0,
	"errmsg" : "not authorized on test to execute command { find: \"t1\", filter: {} }",
	"code" : 13
}
> db.t1.insert({'id':1})
WriteResult({
	"writeError" : {
		"code" : 13,
		"errmsg" : "not authorized on test to execute command { insert: \"t1\", documents: [ { _id: ObjectId('5b51a960e6ef33d11bb6b95b'), id: 1.0 } ], ordered: true }"
	}
})
> db.system.profile.find()
> use admin
switched to db admin
> db.system.profile.find()
> db.logout()
{ "ok" : 1 }
# project_root用户拥有管理所有数据库的权限，因此可以查看所有数据库下的system.profile；但是没有对该库表的读写权限

# 3. test_admin拥有对test库的数据库管理权限

> use test
switched to db test
> db.auth('test_admin','uplooking')
1
> db.system.profile.find()
> db.t1.find(0
... )
Error: error: {
	"ok" : 0,
	"errmsg" : "not authorized on test to execute command { find: \"t1\", filter: {} }",
	"code" : 13
}
> db.t1.find()
Error: error: {
	"ok" : 0,
	"errmsg" : "not authorized on test to execute command { find: \"t1\", filter: {} }",
	"code" : 13
}
> db.logout()
{ "ok" : 1 }
# 只对系统表有权限，对普通的表没有任何权限

# 4. test_dev拥有对test库的读写权限
> use test
switched to db test
> db.auth('test_dev','uplooking')
1
> db.t1.insert({id:1})
WriteResult({ "nInserted" : 1 })
> db.t1.find()
{ "_id" : ObjectId("5b51ac4fe6ef33d11bb6b95c"), "id" : 1 }
> db.system.profile.find()
Error: error: {
	"ok" : 0,
	"errmsg" : "not authorized on test to execute command { find: \"system.profile\", filter: {} }",
	"code" : 13
}
# 只对普通的表有读写权限，对系统表是没有任何权限的。
```



### 6. 如果忘记了认证管理权限用户（超级用户）的认证信息，目前只有普通用户的权限，需求是新增一个新的用户。

```shell
# 1. 修改配置文件去除认证功能
# 2. 新增一个新的用户
# 3. 新增一个超级权限用户
# 4. 开启认证重启
```



