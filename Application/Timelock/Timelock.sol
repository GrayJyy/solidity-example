// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title
 * 时间锁（Timelock）是银行金库和其他高安全性容器中常见的锁定机制。它是一种计时器，旨在防止保险箱或保险库在预设时间之前被打开，即便开锁的人知道正确密码。
 * 在区块链，时间锁被DeFi和DAO大量采用。它是一段代码，他可以将智能合约的某些功能锁定一段时间,它可以大大改善智能合约的安全性.
 * 举个例子，假如一个黑客黑了Uniswap的多签，准备提走金库的钱，但金库合约加了2天锁定期的时间锁，那么黑客从创建提钱的交易，到实际把钱提走，需要2天的等待期。在这一段时间，项目方可以找应对办法，投资者可以提前抛售代币减少损失。
 *
 * @notice
 * 时间锁Timelock合约的逻辑并不复杂：
 * 在创建Timelock合约时，项目方可以设定锁定期，并把合约的管理员设为自己。
 * 时间锁主要有三个功能：
 * 创建交易，并加入到时间锁队列。
 * 在交易的锁定期满后，执行交易。
 * 后悔了，取消时间锁队列中的某些交易。
 * 项目方一般会把时间锁合约设为重要合约的管理员，例如金库合约，再通过时间锁操作他们。
 * 时间锁合约的管理员一般为项目的多签钱包，保证去中心化。
 *
 * @dev
 * 构造函数：初始化交易锁定时间（秒）和管理员地址。
 *
 * queueTransaction()：创建交易并添加到时间锁队列中。参数比较复杂，因为要描述一个完整的交易：
 * target：目标合约地址
 * value：发送ETH数额
 * signature：调用的函数签名（function signature）
 * data：交易的call data
 * executeTime：交易执行的区块链时间戳。
 * 调用这个函数时，要保证交易预计执行时间executeTime大于当前区块链时间戳+锁定时间delay。交易的唯一标识符为所有参数的哈希值，利用getTxHash()函数计算。进入队列的交易会更新在queuedTransactions变量中，并释放QueueTransaction事件。
 *
 * executeTransaction()：执行交易。它的参数与queueTransaction()相同。要求被执行的交易在时间锁队列中，达到交易的执行时间，且没有过期。执行交易时用到了solidity的低级成员函数call，在第22讲中有介绍。
 *
 * cancelTransaction()：取消交易。它的参数与queueTransaction()相同。它要求被取消的交易在队列中，会更新queuedTransactions并释放CancelTransaction事件。
 *
 * changeAdmin()：修改管理员地址，只能被Timelock合约调用。
 *
 * getBlockTimestamp()：获取当前区块链时间戳。
 *
 * getTxHash()：返回交易的标识符，为很多交易参数的hash。
 */
contract Timelock {
    // 状态变量
    address public admin; // 管理员地址
    uint256 public constant GRACE_PERIOD = 7 days; // 交易有效期，过期的交易作废
    uint256 public delay; // 交易锁定时间 （秒）
    mapping(bytes32 => bool) public queuedTransactions; // txHash到bool，记录所有在时间锁队列中的交易

    // 事件
    // 交易取消事件
    event CancelTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 executeTime
    );
    // 交易执行事件
    event ExecuteTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 executeTime
    );
    // 交易创建并进入队列 事件
    event QueueTransaction(
        bytes32 indexed txHash, address indexed target, uint256 value, string signature, bytes data, uint256 executeTime
    );
    // 修改管理员地址的事件
    event NewAdmin(address indexed newAdmin);

    /**
     * @dev 构造函数，初始化交易锁定时间 （秒）和管理员地址
     */
    constructor(uint256 delay_) {
        delay = delay_;
        admin = msg.sender;
    }

    // onlyOwner modifier
    modifier onlyOwner() {
        require(msg.sender == admin, "Timelock: Caller not admin");
        _;
    }

    // onlyTimelock modifier
    modifier onlyTimelock() {
        require(msg.sender == address(this), "Timelock: Caller not Timelock");
        _;
    }

    /**
     * @dev 改变管理员地址，调用者必须是Timelock合约。
     */
    function changeAdmin(address newAdmin) public onlyTimelock {
        admin = newAdmin;

        emit NewAdmin(newAdmin);
    }

    /**
     * @dev 创建交易并添加到时间锁队列中。
     * @param target: 目标合约地址
     * @param value: 发送eth数额
     * @param signature: 要调用的函数签名（function signature）
     * @param data: call data，里面是一些参数
     * @param executeTime: 交易执行的区块链时间戳
     *
     * 要求：executeTime 大于 当前区块链时间戳+delay
     */
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) public returns (bytes32) {
        require(executeTime > block.timestamp + delay);
        // 计算交易的唯一识别符：一堆东西的hash
        bytes32 _txHash = getTxHash(target, value, signature, data, executeTime);
        // 将交易添加到队列
        queuedTransactions[_txHash] = true;
        emit QueueTransaction(_txHash, target, value, signature, data, executeTime);
        return _txHash;
    }

    /**
     * @dev 取消特定交易。
     *
     * 要求：交易在时间锁队列中
     */
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) public onlyOwner {
        // 计算交易的唯一识别符：一堆东西的hash
        bytes32 _txHash = getTxHash(target, value, signature, data, executeTime);
        // 检查：交易在时间锁队列中
        require(queuedTransactions[_txHash], "Timelock::cancelTransaction: Transaction hasn't been queued.");
        // 将交易移出队列
        queuedTransactions[_txHash] = false;

        emit CancelTransaction(_txHash, target, value, signature, data, executeTime);
    }

    /**
     * @dev 执行特定交易。
     *
     * 要求：
     * 1. 交易在时间锁队列中
     * 2. 达到交易的执行时间
     * 3. 交易没过期
     */
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 executeTime
    ) public payable onlyOwner returns (bytes memory) {
        bytes32 _txHash = getTxHash(target, value, signature, data, executeTime);
        // 检查：交易是否在时间锁队列中
        require(queuedTransactions[_txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        // 检查：达到交易的执行时间
        require(
            getBlockTimestamp() >= executeTime, "Timelock::executeTransaction: Transaction hasn't surpassed time lock."
        );
        // 检查：交易没过期
        require(
            getBlockTimestamp() <= executeTime + GRACE_PERIOD, "Timelock::executeTransaction: Transaction is stale."
        );
        // 将交易移出队列
        queuedTransactions[_txHash] = false;

        // 获取call data
        /**
         * @dev
         * 在函数中，_callData 被设置为一个编码后的数据，这样做是为了构建正确的函数调用数据。
         * 在以太坊中，函数调用的方式是通过 ABI（应用二进制接口）来定义的。对于函数调用，需要将函数的签名和参数编码为特定的格式，以便正确地调用目标合约中的函数。
         * 在这里，signature 是一个字符串参数，它表示目标函数的方法签名（即函数名和参数类型的组合）。为了得到正确的函数调用数据，需要先将 signature 转换为对应的函数选择器（function selector）。
         * 函数选择器是一个 4 字节的哈希值，它是函数签名的前四个字节（即函数标识符）。函数选择器的计算方式是对函数签名的前四个字节进行 Keccak-256 哈希计算，然后取哈希结果的前四个字节。
         * 在这里，keccak256(bytes(signature)) 将函数签名转换为一个 Keccak-256 哈希值，然后 bytes4(...) 将哈希值截取前四个字节，得到函数选择器。最后，使用 abi.encodePacked 将函数选择器和参数数据拼接在一起，构建最终的调用数据 _callData。
         * 通过这样的转换，可以确保在执行函数调用时，目标合约能够正确解析函数签名和参数，并执行相应的操作。
         */
        bytes memory _callData;
        if (bytes(signature).length == 0) {
            _callData = data;
        } else {
            _callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // 利用call执行交易
        (bool success, bytes memory returnData) = target.call{value: value}(_callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(_txHash, target, value, signature, data, executeTime);

        return returnData;
    }

    /**
     * @dev 获取当前区块链时间戳
     */
    function getBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev 将一堆东西拼成交易的标识符
     */
    function getTxHash(address target, uint256 value, string memory signature, bytes memory data, uint256 executeTime)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(target, value, signature, data, executeTime));
    }
}
