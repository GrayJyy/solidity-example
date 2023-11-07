// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract EIP712Storage {
    using ECDSA for bytes32;

    bytes32 private constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant STORAGE_TYPEHASH = keccak256("Storage(address spender,uint256 number)");
    bytes32 private DOMAIN_SEPARATOR;
    uint256 number;
    address owner;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH, // type hash
                keccak256(bytes("EIP712Storage")), // name
                keccak256(bytes("1")), // version
                block.chainid, // chain id
                address(this) // contract address
            )
        );
        owner = msg.sender;
    }

    /**
     * @dev Return value
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256) {
        return number;
    }

    function permitStore(uint256 _num, bytes memory _signature) public {
        // 检查签名长度，65是标准r,s,v签名的长度
        require(_signature.length == 65, "invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            // 从签名中提取r,s,v
            /*
            前32 bytes存储签名的长度 (动态数组存储规则)
            add(sig, 32) = sig的指针 + 32
            等效为略过signature的前32 bytes
            mload(p) 载入从内存地址p起始的接下来32 bytes数据
            */
            // 读取长度数据后的32 bytes
            r := mload(add(_signature, 32))
            // 读取之后的32 bytes
            s := mload(add(_signature, 64))
            // 读取最后一个byte
            v := byte(0, mload(add(_signature, 96)))
        }
        // 获取签名消息hash
        /**
         * @dev
         * 在这段代码中，计算签名消息的哈希遵循了EIP-712标准，该标准旨在使以太坊上的签名数据更可读、更安全。EIP-712定义了一种结构化数据的签名方法，它允许你在用户界面中清晰地展示签名的数据内容，同时确保签名数据的完整性和防篡改性。下面是EIP-712哈希计算过程的解释：
         *
         * 1. **域分隔符（`DOMAIN_SEPARATOR`）：**
         *    EIP-712要求定义一个域分隔符，这是一个常量，用于区分不同的签名请求，防止跨域的签名重放攻击。它是一组描述签名域的特定值的哈希，包括合约名称、版本、链ID、合约地址等。
         *
         * 2. **类型哈希（`STORAGE_TYPEHASH`）：**
         *    类型哈希是对数据类型的描述的哈希，它通常是对一个固定格式的字符串进行哈希，字符串描述了数据的结构，如`"Data(uint256 num,address sender)"`。这确保了签名的数据结构被正确地传达和使用。
         *
         * 3. **编码待签名数据：**
         *    `abi.encode`是一种将多个参数打包成ABI编码形式的方法。在这里，它将`STORAGE_TYPEHASH`，`msg.sender`，和`_num`打包在一起。这确保了签名的数据能够按照预期的结构被编码和解码。
         * abi.encode(STORAGE_TYPEHASH, msg.sender, _num) 的参数打包是严格按照STORAGE_TYPEHASH的类型规定
         *
         * 4. **创建签名的消息哈希（`digest`）：**
         *    消息哈希是由两部分构成的：`"\x19\x01"`是一个前缀，按照EIP-712标准，它是固定的，用于避免与其他类型的签名数据混淆；然后是`DOMAIN_SEPARATOR`和编码后的数据的哈希值的连接。这整个结构再进行一次`keccak256`哈希，得到了最终用于签名的`digest`。
         *
         * 代码中的这种计算方法确保了签名的安全性和唯一性。通过使用EIP-712标准，签名者能够明确知道他们在签名什么内容，而且这些内容不会被恶意构造或篡改。此外，由于`digest`的创建涉及了`msg.sender`和`_num`，这就意味着这个签名是特定于发起者和传入的数值的，保证了签名的有效性和一次性。
         */
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(STORAGE_TYPEHASH, msg.sender, _num)))
        );

        // recover方法是定义在了 ECDSA.sol 中的，用于从签名中恢复签名者的地址
        address signer = digest.recover(v, r, s); // 恢复签名者
        require(signer == owner, "EIP712Storage: Invalid signature"); // 检查签名

        // 修改状态变量
        number = _num;
    }
}
