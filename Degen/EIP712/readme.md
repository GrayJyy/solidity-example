前我们介绍了 EIP191 签名标准（personal sign）见 Signature ，它可以给一段消息签名。但是它过于简单，当签名数据比较复杂时，用户只能看到一串十六进制字符串（数据的哈希），无法核实签名内容是否与预期相符。
EIP712类型化数据签名是一种更高级、更安全的签名方法。当支持 EIP712 的 Dapp 请求签名时，钱包会展示签名消息的原始数据，用户可以在验证数据符合预期之后签名。
EIP712 的应用一般包含链下签名（前端或脚本）和链上验证（合约）两部分.

### 链下签名
EIP721签名必须包括一个`EIP712Domain`部分，它包含了合约的 name，version（一般约定为 “1”），chainId，和 verifyingContract（验证签名的合约地址）。
```javascript
EIP712Domain: [
    { name: "name", type: "string" },
    { name: "version", type: "string" },
    { name: "chainId", type: "uint256" },
    { name: "verifyingContract", type: "address" },
]
```
这些信息会在用户签名时显示，并确保只有特定链的特定合约才能验证签名。你需要在脚本中传入相应参数.
```javascript
const domain = {
    name: "EIP712Storage",
    version: "1",
    chainId: "1",
    verifyingContract: "0xf8e81D47203A594245E36C48e151709F0C19fBe8",
};
```
你需要根据使用场景自定义一个签名的数据类型，他要与合约匹配。在 EIP712Storage 例子中，我们定义了一个 Storage 类型，它有两个成员: address 类型的 spender，指定了可以修改变量的调用者；uint256 类型的 number，指定了变量修改后的值。
```javascript
const types = {
    Storage: [
        { name: "spender", type: "address" },
        { name: "number", type: "uint256" },
    ],
};
```
创建一个 message 变量，传入要被签名的类型化数据。
```javascript
const message = {
    spender: "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",
    number: "100",
};
```
调用钱包对象的 signTypedData() 方法，传入前面步骤中的 domain，types，和 message 变量进行签名（这里使用 ethersjs v6）.
```javascript
// 获得provider
const provider = new ethers.BrowserProvider(window.ethereum)
// 获得signer后调用signTypedData方法进行eip712签名
const signature = await signer.signTypedData(domain, types, message);
console.log("Signature:", signature);
```


### 链上验证
接下来就是 EIP712Storage 合约部分，它需要验证签名，如果通过，则修改 number 状态变量。它有 5 个状态变量。

EIP712DOMAIN_TYPEHASH: EIP712Domain 的类型哈希，为常量。
STORAGE_TYPEHASH: Storage 的类型哈希，为常量。
DOMAIN_SEPARATOR: 这是混合在签名中的每个域 (Dapp) 的唯一值，由 EIP712DOMAIN_TYPEHASH 以及 EIP712Domain （name, version, chainId, verifyingContract）组成，在 constructor() 中初始化。
number: 合约中存储值的状态变量，可以被 permitStore() 方法修改。
owner: 合约所有者，在 constructor() 中初始化，在 permitStore() 方法中验证签名的有效性。
另外，EIP712Storage 合约有 3 个函数。

构造函数: 初始化 DOMAIN_SEPARATOR 和 owner。
retrieve(): 读取 number 的值。
permitStore: 验证 EIP712 签名，并修改 number 的值。首先，它先将签名拆解为 r, s, v。然后用 DOMAIN_SEPARATOR, STORAGE_TYPEHASH, 调用者地址，和输入的 _num 参数拼出签名的消息文本 digest。最后利用 ECDSA 的 recover() 方法恢复出签名者地址，如果签名有效，则更新 number 的值。