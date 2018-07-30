# MongoDB Language

> 2018-07-29 BoobooWei

[TOC]



## mongo shell

>如果你不带任何参数运行 mongo ， mongo shell将尝试连接运行在``localhost``上端口号为``27017``的MongoDB实例。

```shell[root@mastera db]# mongo
[root@mongodb mongodb]# mongo
MongoDB shell version: 3.2.16
connecting to: test
```

>输入``db``，显示你当前正在使用的数据库：

```shell
> db
test
```

此操作将返回默认数据库``test``


>使用``show dbs``列出所有可用的数据库

```shell
> show dbs
admin  0.000GB
local  0.000GB

# 如果设置了认证需要先通过认证
> db
test
> show dbs
2018-07-28T22:56:17.042-0700 E QUERY    [thread1] Error: listDatabases failed:{
	"ok" : 0,
	"errmsg" : "not authorized on admin to execute command { listDatabases: 1.0 }",
	"code" : 13
} :
_getErrorWithCode@src/mongo/shell/utils.js:25:13
Mongo.prototype.getDBs@src/mongo/shell/mongo.js:62:1
shellHelper.show@src/mongo/shell/utils.js:769:19
shellHelper@src/mongo/shell/utils.js:659:15
@(shellhelp2):1:1

> db.auth('mongodb_root','uplooking')
Error: Authentication failed.
0
> use admin
switched to db admin
> db.auth('mongodb_root','uplooking')
1
> show dbs;
admin  0.000GB
local  0.000GB
test   0.000GB
```

>要切换数据库，使用``use <db>``，如下例所示：

```shell
> use local
switched to db local
> db
local
> use admin
switched to db admin
> db
admin
> use test
switched to db test
> db
test
```

### sql与mongodb术语对比

| SQL术语/概念 | MongoDB术语/概念                                             | 解释/说明                            |
| :----------- | :----------------------------------------------------------- | :----------------------------------- |
| database     | database                                                     | 数据库                               |
| table        | collection                                                   | 数据库表/集合                        |
| row          | document                                                     | 数据记录行/文档                      |
| column       | field                                                        | 数据字段/域                          |
| index        | index                                                        | 索引                                 |
| table joins  | [`$lookup`](https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/#pipe._S_lookup), embedded documents | 表连接,MongoDB version 3.2. 开始支持 |
| primary key  | primary key                                                  | 主键,MongoDB自动将_id字段设置为主键  |

### 数据库命名规范

系统已存在的三个数据库：

* Admin 数据库：一个权限数据库，如果创建用户的时候将该用户添加到admin 数据库中，那么该用户就自动继承了所有数据库的权限。
* Local 数据库：这个数据库永远不会被负责，可以用来存储本地单台服务器的任意集合。
* Config 数据库：当MongoDB 使用分片模式时，config 数据库在内部使用，用于保存分片的信息。

数据库也通过名字来标识。数据库名可以是满足以下条件的任意UTF-8字符串:

* 不能是空字符串（"")。
* 不得含有' '（空格)、.、$、/、\和\0 (空宇符)。
* 应全部小写。
* 最多64字节。


### 文档命名规范

文档是一个键值(key-value)对(即BSON)。MongoDB 的文档不需要设置相同的字段，并且相同的字段不需要相同的数据类型，这与关系型数据库有很大的区别，也是 MongoDB 非常突出的特点。

一个简单的文档例子如下：`{"site":"www.uplooking.com", "name":"尚观科技"}`

需要注意的是：

1. 文档中的键/值对是有序的。
2. 文档中的值不仅可以是在双引号里面的字符串，还可以是其他几种数据类型（甚至可以是整个嵌入的文档)。
3. MongoDB区分类型和大小写。
4. MongoDB的文档不能有重复的键。
5. 文档的键是字符串。除了少数例外情况，键可以使用任意UTF-8字符。

**文档键命名规范**

1. 键不能含有\0 (空字符)。这个字符用来表示键的结尾。
2. "."和"$"有特别的意义，只有在特定环境下才能使用。
3. 以下划线"_"开头的键是保留的(不是严格要求的)。

### 集合命名规范

集合就是 MongoDB 文档组，类似于 RDBMS （关系数据库管理系统：Relational Database Management System)中的表格。

集合存在于数据库中，集合没有固定的结构，这意味着你在对集合可以插入不同格式和类型的数据，但通常情况下我们插入集合的数据都会有一定的关联性。

比如，我们可以将以下不同数据结构的文档插入到集合中：

```shell
{"site":"www.baidu.com"}
{"site":"www.google.com","name":"Google"}
{"site":"www.uplooking.com","name":"尚观科技","num":1}
```

当第一个文档插入时，集合就会被创建。

**合法的集合名**

1. 集合名不能是空字符串""。
2. 集合名不能含有\0字符（空字符)，这个字符表示集合名的结尾。
3. 集合名不能以"system."开头，这是为系统集合保留的前缀。
4. 用户创建的集合名字不能含有保留字符。有些驱动程序的确支持在集合名里面包含，这是因为某些系统生成的集合中包含该字符。除非你要访问这种系统创建的集合，否则千万不要在名字里出现$。　


### 元数据

数据库的信息是存储在集合中。它们使用了系统的命名空间：`dbname.system.*`

在MongoDB数据库中名字空间 <dbname>.system.* 是包含多种系统信息的特殊集合(Collection)，如下:

| 集合命名空间             | 描述                                      |
| :----------------------- | :---------------------------------------- |
| dbname.system.namespaces | 列出所有名字空间。                        |
| dbname.system.indexes    | 列出所有索引。                            |
| dbname.system.profile    | 包含数据库概要(profile)信息。             |
| dbname.system.users      | 列出所有可访问数据库的用户。              |
| dbname.local.sources     | 包含复制对端（slave）的服务器信息和状态。 |

对于修改系统集合中的对象有如下限制。

* 在`{{system.indexes}}`插入数据，可以创建索引。但除此之外该表信息是不可变的(特殊的drop index命令将自动更新相关信息)。
* `{{system.users}}`是可修改的。 
* `{{system.profile}}`是可删除的。

### MongoDB 数据类型

下表为MongoDB中常用的几种数据类型。

| 数据类型           | 描述                                                         |
| :----------------- | :----------------------------------------------------------- |
| String             | 字符串。存储数据常用的数据类型。在 MongoDB 中，UTF-8 编码的字符串才是合法的。 |
| Integer            | 整型数值。用于存储数值。根据你所采用的服务器，可分为 32 位或 64 位。 |
| Boolean            | 布尔值。用于存储布尔值（真/假）。                            |
| Double             | 双精度浮点值。用于存储浮点值。                               |
| Min/Max keys       | 将一个值与 BSON（二进制的 JSON）元素的最低值和最高值相对比。 |
| Arrays             | 用于将数组或列表或多个值存储为一个键。                       |
| Timestamp          | 时间戳。记录文档修改或添加的具体时间。                       |
| Object             | 用于内嵌文档。                                               |
| Null               | 用于创建空值。                                               |
| Symbol             | 符号。该数据类型基本上等同于字符串类型，但不同的是，它一般用于采用特殊符号类型的语言。 |
| Date               | 日期时间。用 UNIX 时间格式来存储当前日期或时间。你可以指定自己的日期时间：创建 Date 对象，传入年月日信息。 |
| Object ID          | 对象 ID。用于创建文档的 ID。                                 |
| Binary Data        | 二进制数据。用于存储二进制数据。                             |
| Code               | 代码类型。用于在文档中存储 JavaScript 代码。                 |
| Regular expression | 正则表达式类型。用于存储正则表达式。                         |


## 最基本的文档的读写更新删除 CRUD

### 创建数据库 use dbname

创建数据库的语法为：`use database_name`

学过mysql的同学会认为只有数据库存在才能use，但是在mongodb中use后面的数据库不存在就会创建。

> 课堂实战：创建数据库uplooking

```shell
> use uplooking
switched to db uplooking
> db
uplooking
```

如果此时用`show dbs`查看所有的数据库会发现刚才创建的uplooking库并不存在，这是因为uplooking库中没有数据导致的。

```shell
> show dbs
admin  0.000GB
local  0.000GB
```

### 删除数据库 db.dropDatabase()

MongoDB 删除数据库的语法格式如下：`db.dropDatabase()`

> 课堂实战：创建数据库booboo，再删除booboo数据库

```shell
> use booboo
switched to db booboo
> db
booboo
> db.dropDatabase()
{ "ok" : 1 }
```

### 插入文档 insert()

MongoDB中提供了以下方法来插入文档到一个集合:

```shell
db.collection.insert()
db.collection.insertOne() New in version 3.2
db.collection.insertMany() New in version 3.2
```

文档的数据结构和JSON基本一样。所有存储在集合中的数据都是BSON格式。

BSON是一种类json的一种二进制形式的存储格式,简称Binary JSON。

MongoDB 使用 insert() 或 save() 方法向集合中插入文档，语法如下：

`db.COLLECTION_NAME.insert(document)`

> 课堂实战：向uplooking库中booboo集合中插入文档

```shell
> use uplooking
switched to db uplooking
> db.booboo.insert({'title': 'mongodb',
... "description" : "mongodb is a nosql database",
... "by" : "www.uplooking.com",
... "tags" : [ "mongodb", "database", "nosql" ],
... "likes" : 100})
WriteResult({ "nInserted" : 1 })
```

插入的时候，key可以不加引号，因为默认key的数据类型只能是字符串类型。

以上实例中 booboo 是我们的集合名，如果该集合不在该数据库中， MongoDB 会自动创建该集合并插入文档。

查看已插入文档：`db.COLLECTION_NAME.find()`

```shell
> db.booboo.find()
{ "_id" : ObjectId("58818af08fce77b49860b790"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
```

我们也可以将数据定义为一个变量，如下所示：

```shell
> document=({'title': 'mongodb',
... "description" : "mongodb is a nosql database",
... "by" : "www.uplooking.com",
... "tags" : [ "mongodb", "database", "nosql" ],
... "likes" : 100})
{
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100
}
```

执行插入操作：

```shell
> db.booboo.insert(document)
WriteResult({ "nInserted" : 1 })
```

插入文档你也可以使用 `db.booboo.save(document)` 命令。如果不指定 `_id` 字段 `save()` 方法类似于 `insert()` 方法。如果指定 `_id` 字段，则会更新该 `_id` 的数据。



### 更新文档 update() save()

MongoDB 使用 `update()` 和 `save()` 方法来更新集合中的文档。接下来让我们详细来看下两个函数的应用及其区别。

**update() 方法**

update() 方法用于更新已存在的文档。语法格式如下：

```shell
db.collection.update(
   <query>,
   <update>,
   {
     upsert: <boolean>,
     multi: <boolean>,
     writeConcern: <document>
   }
)
```

参数说明：

* query : update的查询条件，类似sql update查询内where后面的。
* update : update的对象和一些更新的操作符（如$,$inc...）等，也可以理解为sql update查询内set后面的
* upsert : 可选，这个参数的意思是，如果不存在update的记录，是否插入objNew,true为插入，默认是false，不插入。
* multi : 可选，mongodb 默认是false,只更新找到的第一条记录，如果这个参数为true,就把按条件查出来多条记录全部更新。
* writeConcern :可选，抛出异常的级别。

实例

我们在集合 booboo 中的数据如下：

```shell
> db.booboo.find()
{ "_id" : ObjectId("58abae1bc7d333637aa4bb35"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaea0c7d333637aa4bb36"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaedfc7d333637aa4bb37"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
```

接着我们通过 update() 方法来更新标题(title):

```shell
> db.booboo.update({"title" : "mongodb"},{$set:{"title" : "MongoDB Learning"}})
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })

> db.booboo.find()
{ "_id" : ObjectId("58abae1bc7d333637aa4bb35"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaea0c7d333637aa4bb36"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaedfc7d333637aa4bb37"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
```

可以看到标题(title)由原来的 "MongoDB 教程" 更新为了 "MongoDB"。

以上语句只会修改第一条发现的文档，如果你要修改多条相同的文档，则需要设置 multi 参数为 true。

```shell
> db.booboo.update({"title" : "mongodb"},{$set:{"title" : "MongoDB Learning"}},{multi:true})
WriteResult({ "nMatched" : 2, "nUpserted" : 0, "nModified" : 2 })
> db.booboo.find()
{ "_id" : ObjectId("58abae1bc7d333637aa4bb35"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaea0c7d333637aa4bb36"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaedfc7d333637aa4bb37"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
```

`db.booboo.find().pretty()`美观的显示，可以自己试一下


**save() 方法**

save() 方法通过传入的文档来替换已有文档。语法格式如下：

```shell
db.collection.save(
   <document>,
   {
     writeConcern: <document>
   }
)
```

参数说明：

* document : 文档数据。
* writeConcern :可选，抛出异常的级别。

实例

以下实例中我们替换了 "_id" : ObjectId("58abae1bc7d333637aa4bb35") 的文档数据：

```shell
> db.booboo.save({"_id" : ObjectId("58abae1bc7d333637aa4bb35"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100,'url':'http://www.uplooking.com'})
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
> db.booboo.find()
{ "_id" : ObjectId("58abae1bc7d333637aa4bb35"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100, "url" : "http://www.uplooking.com" }
{ "_id" : ObjectId("58abaea0c7d333637aa4bb36"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abaedfc7d333637aa4bb37"), "title" : "MongoDB Learning", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
```

### 删除文档 remove()

MongoDB remove()函数是用来移除集合中的数据。

MongoDB数据更新可以使用update()函数。在执行remove()函数前先执行find()命令来判断执行的条件是否正确，这是一个比较好的习惯。

语法

remove() 方法的基本语法格式如下所示：

```shell
db.collection.remove(
   <query>,
   <justOne>
)
```

如果你的 MongoDB 是 2.6 版本以后的，语法格式如下：

```shell
db.collection.remove(
   <query>,
   {
     justOne: <boolean>,
     writeConcern: <document>
   }
)
```

参数说明：

* query :（可选）删除的文档的条件。
* justOne : （可选）如果设为 true 或 1，则只删除一个文档。
* writeConcern :（可选）抛出异常的级别。

实例

移除 title 为 'MongoDB Learning' 的文档：

```shell
> db.booboo.remove({"title" : "MongoDB Learning"})
WriteResult({ "nRemoved" : 3 })
> db.booboo.find()
```

如果你只想删除第一条找到的记录可以设置 justOne 为 1，如下所示：

`db.COLLECTION_NAME.remove(DELETION_CRITERIA,1)`

```shell
> db.booboo.insert({'title':'a','likes':20})
WriteResult({ "nInserted" : 1 })
> db.booboo.insert({'title':'a','likes':30})
WriteResult({ "nInserted" : 1 })
> db.booboo.insert({'title':'c','likes':9})
WriteResult({ "nInserted" : 1 })
> db.booboo.find()
{ "_id" : ObjectId("58abb894c7d333637aa4bb38"), "title" : "a", "likes" : 20 }
{ "_id" : ObjectId("58abb8b2c7d333637aa4bb39"), "title" : "a", "likes" : 30 }
{ "_id" : ObjectId("58abb8b8c7d333637aa4bb3a"), "title" : "c", "likes" : 9 }
> db.booboo.remove({"title" : "a"},1)
WriteResult({ "nRemoved" : 1 })
> db.booboo.find()
{ "_id" : ObjectId("58abb8b2c7d333637aa4bb39"), "title" : "a", "likes" : 30 }
{ "_id" : ObjectId("58abb8b8c7d333637aa4bb3a"), "title" : "c", "likes" : 9 }
```

如果你想删除所有数据，可以使用以下方式（类似常规 SQL 的 truncate 命令）：

```shell
> db.booboo.remove()
2017-02-21T11:53:09.280+0800 E QUERY    [main] Error: remove needs a query :
DBCollection.prototype._parseRemove@src/mongo/shell/collection.js:409:1
DBCollection.prototype.remove@src/mongo/shell/collection.js:434:18
@(shell):1:1
> db.booboo.remove({})
WriteResult({ "nRemoved" : 2 })
> db.booboo.find()
```

注意，db.booboo.remove()中一定写上"{}"，否则会报错哦！


### 删除集合 drop()

集合删除语法格式如下：`db.collection.drop()`

```shell
> show dbs	
admin      0.000GB
local      0.000GB
uplooking  0.000GB
> db
uplooking
> show collections
booboo
> db.booboo.drop()
true
> show collections
>
```

### 查询文档 find() pretty()

语法

MongoDB 查询数据的语法格式如下：

```shell
>db.COLLECTION_NAME.find()
```

find() 方法以非结构化的方式来显示所有文档。

如果你需要以易读的方式来读取数据，可以使用 pretty() 方法，语法格式如下：

```shell
>db.booboo.find().pretty()
```

pretty() 方法以格式化的方式来显示所有文档。

实例

以下实例我们查询了集合 booboo 中的数据：

```shell
> db.booboo.insert({"title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 })
WriteResult({ "nInserted" : 1 })

> db.booboo.find().pretty()
{
	"_id" : ObjectId("58abd086c7d333637aa4bb3b"),
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100
}
```

除了 find() 方法之外，还有一个 findOne() 方法，它只返回一个文档。

```shell
> db.booboo.insert({"title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 })
WriteResult({ "nInserted" : 1 })

> db.booboo.findOne()
{
	"_id" : ObjectId("58abd086c7d333637aa4bb3b"),
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100
}
```

> ### MongoDB 与 RDBMS Where 语句比较

如果你熟悉常规的 SQL 数据，通过下表可以更好的理解 MongoDB 的条件语句查询：

| 操作       | 格式                   | 范例                                                | RDBMS中的类似语句              |
| :--------- | :--------------------- | :-------------------------------------------------- | :----------------------------- |
| 等于       | {<key>:<value>}        | db.booboo.find({"by":"www.uplooking.com"}).pretty() | where by = 'www.uplooking.com' |
| 小于       | {<key>:{$lt:<value>}}  | db.booboo.find({"likes":{$lt:50}}).pretty()         | where likes < 50               |
| 小于或等于 | {<key>:{$lte:<value>}} | db.booboo.find({"likes":{$lte:50}}).pretty()        | where likes <= 50              |
| 大于       | {<key>:{$gt:<value>}}  | db.boobool.find({"likes":{$gt:50}}).pretty()        | where likes > 50               |
| 大于或等于 | {<key>:{$gte:<value>}} | db.booboo.find({"likes":{$gte:50}}).pretty()        | where likes >= 50              |
| 不等于     | {<key>:{$ne:<value>}}  | db.booboo.find({"likes":{$ne:50}}).pretty()         | where likes != 50              |

> ### MongoDB AND 条件

MongoDB 的 find() 方法可以传入多个键(key)，每个键(key)以逗号隔开，及常规 SQL 的 AND 条件。

语法格式如下：

```shell
>db.booboo.find({key1:value1, key2:value2}).pretty()
```

实例

以下实例查询键 by 值为 www.uplooking.com 和键 title 值为  mongodb 的数据

```shell
> db.booboo.find({'by':'www.uplooking.com','title':'mongodb'})
{ "_id" : ObjectId("58abd086c7d333637aa4bb3b"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
```

以上实例中类似于 WHERE 语句：WHERE by='www.uplooking.com' AND title='mongodb'

> ### MongoDB OR 条件

MongoDB OR 条件语句使用了关键字 $or,语法格式如下：

```shell
>db.booboo.find(
   {
      $or: [
	     {key1: value1}, {key2:value2}
      ]
   }
).pretty()
```

实例

以下实例中，我们演示了查询键 by 值为 www.uplooking.com 或键 title 值为 mongodb 的文档。

```shell
> db.booboo.find({$or:{'by':'www.uplooking.com','title':'mongodb'}}).pretty()
Error: error: {
	"ok" : 0,
	"errmsg" : "$or must be an array",
	"code" : 2,
	"codeName" : "BadValue"
}
> db.booboo.find({$or:[{'by':'www.uplooking.com'},{'title':'mongodb'}]}).pretty()
{
	"_id" : ObjectId("58abd086c7d333637aa4bb3b"),
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100
}
{
	"_id" : ObjectId("58abd0cbc7d333637aa4bb3c"),
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 90
}
```

> ### AND 和 OR 联合使用

以下实例演示了 AND 和 OR 联合使用，类似常规 SQL 语句为： 'where likes>50 AND (by = 'www.uplooking.com' OR title = 'mongodb')'

```shell
> db.booboo.find({'likes':{$gt:50},$or:[{'by':'www.uplooking.com'},{'title':'mongodb'}]})
{ "_id" : ObjectId("58abd086c7d333637aa4bb3b"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
> db.booboo.find({'likes':{$gt:50},$or:[{'by':'www.uplooking.com'},{'title':'mongodb'}]}).pretty()
{
	"_id" : ObjectId("58abd086c7d333637aa4bb3b"),
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100
}
{
	"_id" : ObjectId("58abd0cbc7d333637aa4bb3c"),
	"title" : "mongodb",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 90
}
```

### 条件操作符

MongoDB中条件操作符有：

(>) 大于 - $gt

(<) 小于 - $lt

(>=) 大于等于 - $gte

(<= ) 小于等于 - $lte

操作符在上一节中已经学习了基本语法，下面请完成相应练习：

使用数据库uplooking，集合booboo中已有数据如下所示：

```shell
> db.booboo.find()
{ "_id" : ObjectId("58abd086c7d333637aa4bb3b"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
{ "_id" : ObjectId("58abd66bc7d333637aa4bb3d"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 50 }
{ "_id" : ObjectId("58abd66fc7d333637aa4bb3e"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 30 }
```

1. 获取 "booboo" 集合中 "likes" 大于 50 的数据
2. 获取 "booboo" 集合中 "likes" 小于 90 的数据
3. 获取 "booboo" 集合中 "likes" 大于等于 50 的数据
4. 获取 "booboo" 集合中 "likes" 小于等于 90 的数据
5. 获取 "booboo" 集合中 "likes" 大于 50 小于 100 的数据
6. 获取 "booboo" 集合中 "likes" 小于 50 或者 大于 90 的数据

答案如下：

```shell
> db.booboo.find({'likes':{$gt:50}})
{ "_id" : ObjectId("58abd086c7d333637aa4bb3b"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
> db.booboo.find({'likes':{$lt:90}})
{ "_id" : ObjectId("58abd66bc7d333637aa4bb3d"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 50 }
{ "_id" : ObjectId("58abd66fc7d333637aa4bb3e"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 30 }
> db.booboo.find({'likes':{$gte:50}})
{ "_id" : ObjectId("58abd086c7d333637aa4bb3b"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
{ "_id" : ObjectId("58abd66bc7d333637aa4bb3d"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 50 }
> db.booboo.find({'likes':{$lte:90}})
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
{ "_id" : ObjectId("58abd66bc7d333637aa4bb3d"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 50 }
{ "_id" : ObjectId("58abd66fc7d333637aa4bb3e"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 30 }
> db.booboo.find({'likes':{$gt:50,$lt:100}})
{ "_id" : ObjectId("58abd0cbc7d333637aa4bb3c"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 90 }
> db.booboo.find({$or:[{'likes':{$gt:90}},{'likes':{$lt:50}}]})
{ "_id" : ObjectId("58abd086c7d333637aa4bb3b"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100 }
{ "_id" : ObjectId("58abd66fc7d333637aa4bb3e"), "title" : "mongodb", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 30 }
```

### $type操作符和数据类型

$type操作符是基于BSON类型来检索集合中匹配的数据类型，并返回结果。

MongoDB 中可以使用的类型如下表所示：

| Type                    | Number | Alias                 | Notes               |
| :---------------------- | :----- | :-------------------- | :------------------ |
| Double                  | 1      | “double”              |                     |
| String                  | 2      | “string”              |                     |
| Object                  | 3      | “object”              |                     |
| Array                   | 4      | “array”               |                     |
| Binary data             | 5      | “binData”             |                     |
| Undefined               | 6      | “undefined”           | Deprecated.         |
| ObjectId                | 7      | “objectId”            |                     |
| Boolean                 | 8      | “bool”                |                     |
| Date                    | 9      | “date”                |                     |
| Null                    | 10     | “null”                |                     |
| Regular Expression      | 11     | “regex”               |                     |
| DBPointer               | 12     | “dbPointer”           | Deprecated.         |
| JavaScript              | 13     | “javascript”          |                     |
| Symbol                  | 14     | “symbol”              | Deprecated.         |
| JavaScript (with scope) | 15     | “javascriptWithScope” |                     |
| 32-bit integer          | 16     | “int”                 |                     |
| Timestamp               | 17     | “timestamp”           |                     |
| 64-bit integer          | 18     | “long”                |                     |
| Decimal128              | 19     | “decimal”             | New in version 3.4. |
| Min key                 | -1     | “minKey”              |                     |
| Max key                 | 127    | “maxKey”              |                     |

基本数据类型

null：用于表示空值或者不存在的字段，{“x”:null}

布尔型：布尔类型有两个值true和false，{“x”:true}

数值：shell默认使用64为浮点型数值。{“x”：3.14}或{“x”：3}。对于整型值，可以使用NumberInt（4字节符号整数）或NumberLong（8字节符号整数），{“x”:NumberInt(“3”)}{“x”:NumberLong(“3”)}

字符串：UTF-8字符串都可以表示为字符串类型的数据，{“x”：“呵呵”}

日期：日期被存储为自新纪元依赖经过的毫秒数，不存储时区，{“x”:new Date()}

正则表达式：查询时，使用正则表达式作为限定条件，语法与JavaScript的正则表达式相同，{“x”:/[abc]/}

数组：数据列表或数据集可以表示为数组，{“x”： [“a“，“b”,”c”]}

内嵌文档：文档可以嵌套其他文档，被嵌套的文档作为值来处理，{“x”:{“y”:3 }}

对象Id：对象id是一个12字节的字符串，是文档的唯一标识，{“x”: objectId() }

二进制数据：二进制数据是一个任意字节的字符串。它不能直接在shell中使用。如果要将非utf-字符保存到数据库中，二进制数据是唯一的方式。

代码：查询和文档中可以包括任何JavaScript代码，{“x”:function(){/*…*/}}

---

请先删除原有的集合booboo中的数据，插入新的数据

```shell
> db.booboo.remove({})
WriteResult({ "nRemoved" : 4 })
> db.booboo.find()

> db.booboo.insert({"title" : "MySQL", "description" : "MySQL is the most popular Open Source SQL database management system", "by" : "uplooking", "url" : "http://www.mysql.com", "tags" : [ "mysql", "database" ], "likes" : 200})
WriteResult({ "nInserted" : 1 })
> db.booboo.insert({"title" : "Python", "description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics", "by" : "uplooking", "url" : "http://www.python.org", "tags" : [ "language", "python" ], "likes" : 150})
WriteResult({ "nInserted" : 1 })
> db.booboo.insert({title:'MongoDB',description:'MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.',by:'uplooking',url:'http://www.mongodb.com',tags:['mongodb','database'],likes:100})
WriteResult({ "nInserted" : 1 })

> db.booboo.find().pretty()
{
	"_id" : ObjectId("58abddf6c7d333637aa4bb3f"),
	"title" : "MySQL",
	"description" : "MySQL is the most popular Open Source SQL database management system",
	"by" : "uplooking",
	"url" : "http://www.mysql.com",
	"tags" : [
		"mysql",
		"database"
	],
	"likes" : 200
}
{
	"_id" : ObjectId("58abdf0db1160d1f30d4f518"),
	"title" : "Python",
	"description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics",
	"by" : "uplooking",
	"url" : "http://www.python.org",
	"tags" : [
		"language",
		"python"
	],
	"likes" : 150
}
{
	"_id" : ObjectId("58abdf73b1160d1f30d4f519"),
	"title" : "MongoDB",
	"description" : "MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.",
	"by" : "uplooking",
	"url" : "http://www.mongodb.com",
	"tags" : [
		"mongodb",
		"database"
	],
	"likes" : 100
}
```

> ### MongoDB 操作符 - $type 实例

获取 "booboo" 集合中 title 为 String 的数据


```shell
> db.booboo.find({'title':{$type:2}})
{ "_id" : ObjectId("58abddf6c7d333637aa4bb3f"), "title" : "MySQL", "description" : "MySQL is the most popular Open Source SQL database management system", "by" : "uplooking", "url" : "http://www.mysql.com", "tags" : [ "mysql", "database" ], "likes" : 200 }
{ "_id" : ObjectId("58abdf0db1160d1f30d4f518"), "title" : "Python", "description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics", "by" : "uplooking", "url" : "http://www.python.org", "tags" : [ "language", "python" ], "likes" : 150 }
{ "_id" : ObjectId("58abdf73b1160d1f30d4f519"), "title" : "MongoDB", "description" : "MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.", "by" : "uplooking", "url" : "http://www.mongodb.com", "tags" : [ "mongodb", "database" ], "likes" : 100 }
```

如果value为字典，即对象

```shell
> db.t2.find().pretty()
{
	"_id" : ObjectId("5b5d68654453d9fede06a588"),
	"title" : "mysql",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100,
	"ti" : "mysql"
}
{
	"_id" : ObjectId("5b5d68654453d9fede06a577"),
	"title" : "mysql",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100,
	"ti" : "mysql"
}
{
	"_id" : ObjectId("5b5d68654453d9fede06a599"),
	"title" : "mysql",
	"description" : "mongodb is a nosql database",
	"by" : "www.uplooking.com",
	"tags" : [
		"mongodb",
		"database",
		"nosql"
	],
	"likes" : 100,
	"ti" : "mysql",
	"test" : {
		"a" : 1,
		"b" : 2
	}
}
> db.t2.find({test:{$type:1}})
> db.t2.find({test:{$type:2}})
> db.t2.find({test:{$type:3}})
{ "_id" : ObjectId("5b5d68654453d9fede06a599"), "title" : "mysql", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100, "ti" : "mysql", "test" : { "a" : 1, "b" : 2 } }
```

如果value为list，却以list中的元素为最终

```shell
> db.t2.find({tags:{$type:2}})
{ "_id" : ObjectId("5b5d68654453d9fede06a588"), "title" : "mysql", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100, "ti" : "mysql" }
{ "_id" : ObjectId("5b5d68654453d9fede06a577"), "title" : "mysql", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100, "ti" : "mysql" }
{ "_id" : ObjectId("5b5d68654453d9fede06a599"), "title" : "mysql", "description" : "mongodb is a nosql database", "by" : "www.uplooking.com", "tags" : [ "mongodb", "database", "nosql" ], "likes" : 100, "ti" : "mysql", "test" : { "a" : 1, "b" : 2 } }


> db.t2.find()
{ "_id" : ObjectId("5b5d6e684453d9fede06a505"), "test_lsit" : [ 1, 2, 3 ] }
> db.t2.find({test_lsit:{$type:1}})
{ "_id" : ObjectId("5b5d6e684453d9fede06a505"), "test_lsit" : [ 1, 2, 3 ] }
# 留下一个疑问，arrary代表什么呢？
```




### limit和skip方法

**MongoDB Limit() 方法**

如果你需要在MongoDB中读取指定数量的数据记录，可以使用MongoDB的Limit方法，limit()方法接受一个数字参数，该参数指定从MongoDB中读取的记录条数。

语法

limit()方法基本语法如下所示：

```shell
>db.COLLECTION_NAME.find().limit(NUMBER)
```

实例：只查询集合 booboo 中两条记录

```shell
> db.booboo.find().limit(2).pretty()
{
	"_id" : ObjectId("58abddf6c7d333637aa4bb3f"),
	"title" : "MySQL",
	"description" : "MySQL is the most popular Open Source SQL database management system",
	"by" : "uplooking",
	"url" : "http://www.mysql.com",
	"tags" : [
		"mysql",
		"database"
	],
	"likes" : 200
}
{
	"_id" : ObjectId("58abdf0db1160d1f30d4f518"),
	"title" : "Python",
	"description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics",
	"by" : "uplooking",
	"url" : "http://www.python.org",
	"tags" : [
		"language",
		"python"
	],
	"likes" : 150
}
```

**MongoDB Skip() 方法**

我们除了可以使用limit()方法来读取指定数量的数据外，还可以使用skip()方法来跳过指定数量的数据，skip方法同样接受一个数字参数作为跳过的记录条数。

语法

skip() 方法脚本语法格式如下：

```shell
>db.COLLECTION_NAME.find().limit(NUMBER).skip(NUMBER)
```

skip()方法默认参数为 0

实例:

1. 跳过一条数据，显示两条
2. 跳过两条数据，显示一条

```shell
> db.booboo.find().limit(2).skip(1)
{ "_id" : ObjectId("58abdf0db1160d1f30d4f518"), "title" : "Python", "description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics", "by" : "uplooking", "url" : "http://www.python.org", "tags" : [ "language", "python" ], "likes" : 150 }
{ "_id" : ObjectId("58abdf73b1160d1f30d4f519"), "title" : "MongoDB", "description" : "MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.", "by" : "uplooking", "url" : "http://www.mongodb.com", "tags" : [ "mongodb", "database" ], "likes" : 100 }
> db.booboo.find().limit(1).skip(2)
{ "_id" : ObjectId("58abdf73b1160d1f30d4f519"), "title" : "MongoDB", "description" : "MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.", "by" : "uplooking", "url" : "http://www.mongodb.com", "tags" : [ "mongodb", "database" ], "likes" : 100 }
```

### 排序

MongoDB sort()方法

在MongoDB中使用使用sort()方法对数据进行排序，sort()方法可以通过参数指定排序的字段，并使用 1 和 -1 来指定排序的方式，其中 1 为升序排列，而-1是用于降序排列。

注： 如果没有指定sort()方法的排序方式，默认按照文档的升序排列。

语法

sort()方法基本语法如下所示：

```shell
>db.COLLECTION_NAME.find().sort({KEY:1})
```

实例：

1.  booboo 集合中的数据按字段 likes 的降序排列

```shell
> 
> db.booboo.find().sort({'likes':-1})
{ "_id" : ObjectId("58abddf6c7d333637aa4bb3f"), "title" : "MySQL", "description" : "MySQL is the most popular Open Source SQL database management system", "by" : "uplooking", "url" : "http://www.mysql.com", "tags" : [ "mysql", "database" ], "likes" : 200 }
{ "_id" : ObjectId("58abdf0db1160d1f30d4f518"), "title" : "Python", "description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics", "by" : "uplooking", "url" : "http://www.python.org", "tags" : [ "language", "python" ], "likes" : 150 }
{ "_id" : ObjectId("58abdf73b1160d1f30d4f519"), "title" : "MongoDB", "description" : "MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.", "by" : "uplooking", "url" : "http://www.mongodb.com", "tags" : [ "mongodb", "database" ], "likes" : 100 }
> db.booboo.find().sort({'likes':1})
{ "_id" : ObjectId("58abdf73b1160d1f30d4f519"), "title" : "MongoDB", "description" : "MongoDB is an open-source document database that provides high performance, high availability, and automatic scaling.", "by" : "uplooking", "url" : "http://www.mongodb.com", "tags" : [ "mongodb", "database" ], "likes" : 100 }
{ "_id" : ObjectId("58abdf0db1160d1f30d4f518"), "title" : "Python", "description" : "Python is an interpreted, object-oriented, high-level programming language with dynamic semantics", "by" : "uplooking", "url" : "http://www.python.org", "tags" : [ "language", "python" ], "likes" : 150 }
{ "_id" : ObjectId("58abddf6c7d333637aa4bb3f"), "title" : "MySQL", "description" : "MySQL is the most popular Open Source SQL database management system", "by" : "uplooking", "url" : "http://www.mysql.com", "tags" : [ "mysql", "database" ], "likes" : 200 }
```

## 各种不同类型的索引的创建与使用

### MongoDB 索引

索引通常能够极大的提高查询的效率，如果没有索引，MongoDB在读取数据时必须扫描集合中的每个文件并选取那些符合查询条件的记录。

这种扫描全集合的查询效率是非常低的，特别在处理大量的数据时，查询可以要花费几十秒甚至几分钟，这对网站的性能是非常致命的。

索引是特殊的数据结构，索引存储在一个易于遍历读取的数据集合中，索引是对数据库表中一列或多列的值进行排序的一种结构

### 单键索引

MongoDB使用 createIndex() 方法来创建索引。

语法

ensureIndex()方法基本语法格式如下所示：

```shell
>db.COLLECTION_NAME.createIndex({KEY:1})
```

语法中 Key 值为你要创建的索引字段，1为指定按升序创建索引，如果你想按降序来创建索引指定为-1即可。

实例

```shell
# 数据库uplooking中，新建一个集合test，循环插入10万个文档

> for (var i=0;i<100000;i++){
... db.test.insert({username:'user'+i})
... }
WriteResult({ "nInserted" : 1 })
```

在任意游标(例如 查询）后面附加 explain() 方法可以返回一个含有查询过程的统计数据的文档，包括所使用的索引，扫描过的文档数，查询所消耗的毫秒数。

```shell
> db.test.find({username:'user1234'}).explain('executionStats')
{
	"queryPlanner" : {
		"plannerVersion" : 1,
		"namespace" : "uplooking.test",
		"indexFilterSet" : false,
		"parsedQuery" : {
			"username" : {
				"$eq" : "user1234"
			}
		},
		"winningPlan" : {
			"stage" : "COLLSCAN",
			"filter" : {
				"username" : {
					"$eq" : "user1234"
				}
			},
			"direction" : "forward"
		},
		"rejectedPlans" : [ ]
	},
	"executionStats" : {
		"executionSuccess" : true,
		"nReturned" : 1,
		"executionTimeMillis" : 329,
		"totalKeysExamined" : 0,
		"totalDocsExamined" : 100000,
		"executionStages" : {
			"stage" : "COLLSCAN",
			"filter" : {
				"username" : {
					"$eq" : "user1234"
				}
			},
			"nReturned" : 1,
			"executionTimeMillisEstimate" : 307,
			"works" : 100002,
			"advanced" : 1,
			"needTime" : 100000,
			"needYield" : 0,
			"saveState" : 791,
			"restoreState" : 791,
			"isEOF" : 1,
			"invalidates" : 0,
			"direction" : "forward",
			"docsExamined" : 100000
		}
	},
	"serverInfo" : {
		"host" : "mastera.uplooking.com",
		"port" : 27017,
		"version" : "3.4.1",
		"gitVersion" : "5e103c4f5583e2566a45d740225dc250baacfbd7"
	},
	"ok" : 1
}
```

参数很多，目前我们只关注其中的"totalDocsExamined" : 100000和"executionTimeMillis" : 329

在完成这个查询过程中扫描的文档总数为10万，执行的总时长为30毫秒。

如果数据有1000万个，如果每次查询文档都要遍历一遍，那么时间是相当的长的。

对于此类查询，索引是一个非常好的解决方案。

```shell
> db.test.createIndex({'username':1})
{
	"createdCollectionAutomatically" : false,
	"numIndexesBefore" : 1,
	"numIndexesAfter" : 2,
	"ok" : 1
}
> db.test.find({username:'user1234'}).explain('executionStats')
{
	"queryPlanner" : {
		"plannerVersion" : 1,
		"namespace" : "uplooking.test",
		"indexFilterSet" : false,
		"parsedQuery" : {
			"username" : {
				"$eq" : "user1234"
			}
		},
		"winningPlan" : {
			"stage" : "FETCH",
			"inputStage" : {
				"stage" : "IXSCAN",
				"keyPattern" : {
					"username" : 1
				},
				"indexName" : "username_1",
				"isMultiKey" : false,
				"multiKeyPaths" : {
					"username" : [ ]
				},
				"isUnique" : false,
				"isSparse" : false,
				"isPartial" : false,
				"indexVersion" : 2,
				"direction" : "forward",
				"indexBounds" : {
					"username" : [
						"[\"user1234\", \"user1234\"]"
					]
				}
			}
		},
		"rejectedPlans" : [ ]
	},
	"executionStats" : {
		"executionSuccess" : true,
		"nReturned" : 1,
		"executionTimeMillis" : 56,
		"totalKeysExamined" : 1,
		"totalDocsExamined" : 1,
		"executionStages" : {
			"stage" : "FETCH",
			"nReturned" : 1,
			"executionTimeMillisEstimate" : 20,
			"works" : 2,
			"advanced" : 1,
			"needTime" : 0,
			"needYield" : 0,
			"saveState" : 1,
			"restoreState" : 1,
			"isEOF" : 1,
			"invalidates" : 0,
			"docsExamined" : 1,
			"alreadyHasObj" : 0,
			"inputStage" : {
				"stage" : "IXSCAN",
				"nReturned" : 1,
				"executionTimeMillisEstimate" : 20,
				"works" : 2,
				"advanced" : 1,
				"needTime" : 0,
				"needYield" : 0,
				"saveState" : 1,
				"restoreState" : 1,
				"isEOF" : 1,
				"invalidates" : 0,
				"keyPattern" : {
					"username" : 1
				},
				"indexName" : "username_1",
				"isMultiKey" : false,
				"multiKeyPaths" : {
					"username" : [ ]
				},
				"isUnique" : false,
				"isSparse" : false,
				"isPartial" : false,
				"indexVersion" : 2,
				"direction" : "forward",
				"indexBounds" : {
					"username" : [
						"[\"user1234\", \"user1234\"]"
					]
				},
				"keysExamined" : 1,
				"seeks" : 1,
				"dupsTested" : 0,
				"dupsDropped" : 0,
				"seenInvalidated" : 0
			}
		}
	},
	"serverInfo" : {
		"host" : "mastera.uplooking.com",
		"port" : 27017,
		"version" : "3.4.1",
		"gitVersion" : "5e103c4f5583e2566a45d740225dc250baacfbd7"
	},
	"ok" : 1
}
```

可以看到"executionTimeMillis" : 56,"totalDocsExamined" : 1

一共只扫描了1个文档，总执行时间为56毫秒

的确有点不可思议，查询在瞬间完成，因为通过索引只查找了一条数据，而不是100000条。

当然使用索引是也是有代价的：对于添加的每一条索引，每次写操作（插入、更新、删除）都将耗费更多的时间。这是因为，当数据发生变化时，不仅要更新文档，还要更新级集合上的所有索引。因此，mongodb限制每个集合最多有64个索引。通常，在一个特定的集合上，不应该拥有两个以上的索引。


### 复合索引

复合索引可以支持要求匹配多个键的查询。

索引的值是按一定顺序排列的，所以使用索引键对文档进行排序非常快。

```shell
>db.COLLECTION_NAME.createIndex({KEY:1,KEY:1})
```

这里先根据age排序再根据username排序，所以username在这里发挥的作用并不大。为了优化这个排序，可能需要在age和username上建立索引。

```shell
db.users.ensureIndex({'age':1, 'username': 1})
```

这就建立了一个复合索引（建立在多个字段上的索引），如果查询条件包括多个键，这个索引就非常有用。

建立复合索引后，每个索引条目都包括一个age字段和一个username字段，并且指向文档在磁盘上的存储位置。

此时，age字段是严格升序排列的，如果age相等时再按照username升序排列。

语法

```shell
db.users.createIndex({name:1,age:1})
```


实例

新建users集合并循环插入文档

```shell
> for (var i=1;i<1000;i++){ for (var j=100;j>1;j--) { db.users.insert({name:'user'+i,age:j})   }}
WriteResult({ "nInserted" : 1 })
```

测试一下查询{name:'user123',age:{$lt:5}}耗时多少

```shell
> db.users.find({name:'user123',age:{$lt:5}})
{ "_id" : ObjectId("58ad368e89f7c6bec3f0a3c8"), "name" : "user123", "age" : 4 }
{ "_id" : ObjectId("58ad368e89f7c6bec3f0a3c9"), "name" : "user123", "age" : 3 }
{ "_id" : ObjectId("58ad368e89f7c6bec3f0a3ca"), "name" : "user123", "age" : 2 }

> db.users.find({name:'user123',age:{$lt:5}}).explain('executionStats')
{
	"queryPlanner" : {
		"plannerVersion" : 1,
		"namespace" : "uplooking.users",
		"indexFilterSet" : false,
		"parsedQuery" : {
			"$and" : [
				{
					"name" : {
						"$eq" : "user123"
					}
				},
				{
					"age" : {
						"$lt" : 5
					}
				}
			]
		},
		"winningPlan" : {
			"stage" : "COLLSCAN",
			"filter" : {
				"$and" : [
					{
						"name" : {
							"$eq" : "user123"
						}
					},
					{
						"age" : {
							"$lt" : 5
						}
					}
				]
			},
			"direction" : "forward"
		},
		"rejectedPlans" : [ ]
	},
	"executionStats" : {
		"executionSuccess" : true,
		"nReturned" : 3,
		"executionTimeMillis" : 98,
		"totalKeysExamined" : 0,
		"totalDocsExamined" : 98901,
		"executionStages" : {
			"stage" : "COLLSCAN",
			"filter" : {
				"$and" : [
					{
						"name" : {
							"$eq" : "user123"
						}
					},
					{
						"age" : {
							"$lt" : 5
						}
					}
				]
			},
			"nReturned" : 3,
			"executionTimeMillisEstimate" : 58,
			"works" : 98903,
			"advanced" : 3,
			"needTime" : 98899,
			"needYield" : 0,
			"saveState" : 775,
			"restoreState" : 775,
			"isEOF" : 1,
			"invalidates" : 0,
			"direction" : "forward",
			"docsExamined" : 98901
		}
	},
	"serverInfo" : {
		"host" : "mastera.uplooking.com",
		"port" : 27017,
		"version" : "3.4.1",
		"gitVersion" : "5e103c4f5583e2566a45d740225dc250baacfbd7"
	},
	"ok" : 1
}
```

重点观察以下参数

* "executionTimeMillis" : 98,
* "totalKeysExamined" : 0,
* "totalDocsExamined" : 98901,

耗时98毫秒，一共扫描了9万多个文档


创建复合索引{name:1,age:1}后，再查询耗时又为多少？

```shell
> db.users.createIndex({name:1,age:1})
{
	"createdCollectionAutomatically" : false,
	"numIndexesBefore" : 1,
	"numIndexesAfter" : 2,
	"ok" : 1
}
> db.users.find({name:'user123',age:{$lt:5}}).explain('executionStats')
{
	"queryPlanner" : {
		"plannerVersion" : 1,
		"namespace" : "uplooking.users",
		"indexFilterSet" : false,
		"parsedQuery" : {
			"$and" : [
				{
					"name" : {
						"$eq" : "user123"
					}
				},
				{
					"age" : {
						"$lt" : 5
					}
				}
			]
		},
		"winningPlan" : {
			"stage" : "FETCH",
			"inputStage" : {
				"stage" : "IXSCAN",
				"keyPattern" : {
					"name" : 1,
					"age" : 1
				},
				"indexName" : "name_1_age_1",
				"isMultiKey" : false,
				"multiKeyPaths" : {
					"name" : [ ],
					"age" : [ ]
				},
				"isUnique" : false,
				"isSparse" : false,
				"isPartial" : false,
				"indexVersion" : 2,
				"direction" : "forward",
				"indexBounds" : {
					"name" : [
						"[\"user123\", \"user123\"]"
					],
					"age" : [
						"[-inf.0, 5.0)"
					]
				}
			}
		},
		"rejectedPlans" : [ ]
	},
	"executionStats" : {
		"executionSuccess" : true,
		"nReturned" : 3,
		"executionTimeMillis" : 53,
		"totalKeysExamined" : 3,
		"totalDocsExamined" : 3,
		"executionStages" : {
			"stage" : "FETCH",
			"nReturned" : 3,
			"executionTimeMillisEstimate" : 0,
			"works" : 4,
			"advanced" : 3,
			"needTime" : 0,
			"needYield" : 0,
			"saveState" : 0,
			"restoreState" : 0,
			"isEOF" : 1,
			"invalidates" : 0,
			"docsExamined" : 3,
			"alreadyHasObj" : 0,
			"inputStage" : {
				"stage" : "IXSCAN",
				"nReturned" : 3,
				"executionTimeMillisEstimate" : 0,
				"works" : 4,
				"advanced" : 3,
				"needTime" : 0,
				"needYield" : 0,
				"saveState" : 0,
				"restoreState" : 0,
				"isEOF" : 1,
				"invalidates" : 0,
				"keyPattern" : {
					"name" : 1,
					"age" : 1
				},
				"indexName" : "name_1_age_1",
				"isMultiKey" : false,
				"multiKeyPaths" : {
					"name" : [ ],
					"age" : [ ]
				},
				"isUnique" : false,
				"isSparse" : false,
				"isPartial" : false,
				"indexVersion" : 2,
				"direction" : "forward",
				"indexBounds" : {
					"name" : [
						"[\"user123\", \"user123\"]"
					],
					"age" : [
						"[-inf.0, 5.0)"
					]
				},
				"keysExamined" : 3,
				"seeks" : 1,
				"dupsTested" : 0,
				"dupsDropped" : 0,
				"seenInvalidated" : 0
			}
		}
	},
	"serverInfo" : {
		"host" : "mastera.uplooking.com",
		"port" : 27017,
		"version" : "3.4.1",
		"gitVersion" : "5e103c4f5583e2566a45d740225dc250baacfbd7"
	},
	"ok" : 1
}
```

没有创建索引前，耗时98毫秒，一共扫描了9万多个文档，现在只消耗了53毫秒，扫描3个文档。

### 多键索引

在MongoDB中可以基于数组来创建索引。MongoDB为数组每一个元素创建索引值。

多键索引支持数组字段的高效查询。多键索引能够基于字符串，数字数组以及嵌套文档进行创建。

基于一个数组创建索引，MongoDB会自动创建为多键索引，无需刻意指定

1. 多键索引也可以基于内嵌文档来创建
2. 多键索引的边界值的计算依赖于特定的规则

> 注，多键索引不等于在文档上的多列创建索引(复合索引)

创建语法

```shell
            db.coll.createIndex( { <field>: < 1 or -1 > } )
```

复合多键索引

1. 对于一个复合多键索引，每个索引最多可以包含一个数组。

2. 在多于一个数组的情形下来创建复合多键索引不被支持。

> 假定存在如下集合

`{ _id: 1, a: [ 1, 2 ], b: [ 1, 2 ], category: "AB - both arrays" }`

不能基于一个基于{ a: 1, b: 1 }  的多键索引，因为a和b都是数组


> 假定存在如下集合

```shell
{ _id: 1, a: [1, 2], b: 1, category: "A array" }
{ _id: 2, a: 1, b: [1, 2], category: "B array" }
```

则可以基于每一个文档创建一个基于{ a: 1, b: 1 }的复合多键索引

原因是每一个索引的索引字段只有一个数组


一些限制

* 不能够指定一个多键索引为分片片键索引
* 哈希索引不能够成为多键索引
* 多键索引不支持覆盖查询

基于整体查询数组字段

* 当一个查询筛选器将一个数组作为整体实现精确匹配时，MongoDB可以使用多键索引查找数组的第一个元素，
* 但不能使用多键索引扫描寻找整个数组。相反，使用多键索引查找查询数组的第一个元素后，MongoDB检索
* 相关文档并且过滤出那些复合匹配条件的文档。


### 文本索引

### 2dsphere索引

### 2d索引

### Hashed索引

### 索引属性

### 索引创建

### 索引交集

### 管理索引

### 衡量索引的使用情况

### 索引策略



## 复杂的聚合查询

## 总结

### MongoDB术语

| SQL术语/概念 | MongoDB术语/概念                                             | 解释/说明                            |
| :----------- | :----------------------------------------------------------- | :----------------------------------- |
| database     | database                                                     | 数据库                               |
| table        | collection                                                   | 数据库表/集合                        |
| row          | document                                                     | 数据记录行/文档                      |
| column       | field                                                        | 数据字段/域                          |
| index        | index                                                        | 索引                                 |
| table joins  | [`$lookup`](https://docs.mongodb.com/manual/reference/operator/aggregation/lookup/#pipe._S_lookup), embedded documents | 表连接,MongoDB version 3.2. 开始支持 |
| primary key  | primary key                                                  | 主键,MongoDB自动将_id字段设置为主键  |


### 增删改查

| 操作       | 格式                   | 范例                                                | RDBMS中的类似语句              |
| :--------- | :--------------------- | :-------------------------------------------------- | :----------------------------- |
| 等于       | {<key>:<value>}        | db.booboo.find({"by":"www.uplooking.com"}).pretty() | where by = 'www.uplooking.com' |
| 小于       | {<key>:{$lt:<value>}}  | db.booboo.find({"likes":{$lt:50}}).pretty()         | where likes < 50               |
| 小于或等于 | {<key>:{$lte:<value>}} | db.booboo.find({"likes":{$lte:50}}).pretty()        | where likes <= 50              |
| 大于       | {<key>:{$gt:<value>}}  | db.boobool.find({"likes":{$gt:50}}).pretty()        | where likes > 50               |
| 大于或等于 | {<key>:{$gte:<value>}} | db.booboo.find({"likes":{$gte:50}}).pretty()        | where likes >= 50              |
| 不等于     | {<key>:{$ne:<value>}}  | db.booboo.find({"likes":{$ne:50}}).pretty()         | where likes != 50              |

### 逻辑与或

| 逻辑   | MongoDB                        | RDBMS                   |
| ------ | ------------------------------ | ----------------------- |
| 与     | {{`表达式1`},{`表达式2`}}      | `表达式1` and `表达式2` |
| 或     | {$or:{{`表达式1`},{`表达式2`}} | `表达式1` or `表达式2`  |
| 与和或 | {{A,{$or:{{`B`},{`C`}}}        | `A` and ( `B `or `C`)   |

### 判断value类型

| $type            | float             | string            | object            |
| ---------------- | ----------------- | ----------------- | ----------------- |
| 关系型没有此判断 | {filed:{$type:1}} | {filed:{$type:2}} | {filed:{$type:3}} |

### 排序和限制

| 对比 | MongoDB                                    | MySQL             |
| ---- | ------------------------------------------ | ----------------- |
| 排序 | db.test.find().order({filedA:1,filedB:-1}) | order by A,B desc |
| 限制 | db.test.find().limit(1)                    | limit 0,1         |
|      | db.test.find().skip(1)                     |                   |

### 分组

| 对比 | MongoDB                                    | MySQL             |
| ---- | ------------------------------------------ | ----------------- |
| 分组 |  | group by col |

### 索引

| 索引类型 | 语法                                             | 案例                                   |
| -------- | ------------------------------------------------ | -------------------------------------- |
| 单键索引 | `db.collection.createIndex({filed:1})`           | `db.test.createIndex({'username':1})`  |
| 符合索引 | `db.collection.createIndex({filedA:1,filedB:1})` | `db.users.createIndex({name:1,age:1})` |

多键索引

文本索引

2dsphere索引

2d索引

Hashed索引