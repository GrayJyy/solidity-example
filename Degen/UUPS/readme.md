UUPS全称通用可升级代理(universal upgradeable proxy standard)
将升级函数放在逻辑合约中。这样一来，如果有其它函数与升级函数存在“选择器冲突”，编译时就会报错。
相比于透明代理更加节省 gas，缺点是更复杂。
