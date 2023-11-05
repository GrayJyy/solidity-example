// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

error PaymentSplit_LengthIsZero();
error PaymentSplit_LengthNotEqual();

/**
 * @title
 * 分账就是按照一定比例分钱财。
 * 在现实中，经常会有“分赃不均”的事情发生；而在区块链的世界里，Code is Law，我们可以事先把每个人应分的比例写在智能合约中，获得收入后，再由智能合约来进行分账。
 *
 * @dev
 * 分账合约(PaymentSplit)具有以下几个特点：
 * 在创建合约时定好分账受益人payees和每人的份额shares。
 * 份额可以是相等，也可以是其他任意比例。
 * 在该合约收到的所有ETH中，每个受益人将能够提取与其分配的份额成比例的金额。
 * 分账合约遵循Pull Payment模式，付款不会自动转入账户，而是保存在此合约中。受益人通过调用release()函数触发实际转账。
 *
 * 分账合约中的函数：
 * 构造函数：始化受益人数组_payees和分账份额数组_shares，其中数组长度不能为0，两个数组长度要相等。_shares中元素要大于0，_payees中地址不能为0地址且不能有重复地址。
 * receive()：回调函数，在分账合约收到ETH时释放PaymentReceived事件。
 * release()：分账函数，为有效受益人地址_account分配相应的ETH。任何人都可以触发这个函数，但ETH会转给受益人地址account。调用了releasable()函数。
 * releasable()：计算一个受益人地址应领取的ETH。调用了pendingPayment()函数。
 * pendingPayment()：根据受益人地址_account, 分账合约总收入_totalReceived和该地址已领取的钱_alreadyReleased，计算该受益人现在应分的ETH。
 * _addPayee()：新增受益人函数及其份额函数。在合约初始化的时候被调用，之后不能修改。
 */
contract PaymentSplit {
    uint256 public totalShares; // 总份额
    uint256 public totalReleased; // 总支付
    mapping(address => uint256) public shares; // 每个受益人的份额
    mapping(address => uint256) public released; // 支付给每个受益人的金额
    address[] public payees; // 受益人数组

    // 事件
    event PayeeAdded(address account, uint256 shares); // 增加受益人事件
    event PaymentReleased(address to, uint256 amount); // 受益人提款事件
    event PaymentReceived(address from, uint256 amount); // 合约收款事件

    constructor(address[] memory payees_, uint256[] memory shares_) {
        if (payees_.length == 0) {
            revert PaymentSplit_LengthIsZero();
        }
        if (payees_.length != shares_.length) {
            revert PaymentSplit_LengthNotEqual();
        }
        for (uint256 i = 0; i < payees_.length; i++) {
            // 新增受益人
            _addPayee(payees_[i], shares_[i]);
        }
    }

    /**
     * @dev 回调函数，收到ETH释放PaymentReceived事件
     */
    receive() external payable virtual {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev 新增受益人_account以及对应的份额_accountShares。只能在构造器中被调用，不能修改。
     */
    function _addPayee(address _account, uint256 _accountShares) private {
        require(_account != address(0));
        require(shares[_account] == 0); // 受益人是首次添加（避免重复）
        require(_accountShares > 0);
        payees.push(_account);
        shares[_account] = _accountShares;
        totalShares += _accountShares;
        emit PayeeAdded(_account, _accountShares);
    }

    /**
     * @dev 为有效受益人地址_account分帐，相应的ETH直接发送到受益人地址。任何人都可以触发这个函数，但钱会打给account地址(因为受益人是不确定的，可以随意添加，所以 release 函数需要设置为任何人都能调用)。
     * 调用了releasable()函数。
     */
    function release(address payable account) public virtual {
        require(shares[account] > 0); // _account是受益人
            // uint256 len = payees.length;
            // for (uint256 i = 0; i < len; i++) {
            //     (bool success,) = payees[i].call{value: shares[payees[i]]}("");
            // }
    }

    /**
     * @dev 计算一个账户能够领取的eth。
     * 调用了pendingPayment()函数。
     */
    function releasable(address account) public view returns (uint256) {
        // 计算分账合约总收入totalReceived
        uint256 totalReceived = address(this).balance + totalReleased;
        // 调用_pendingPayment计算account应得的ETH
        return pendingPayment(account, totalReceived, released[account]);
    }

    /**
     * @dev 根据受益人地址`_account`, 分账合约总收入`_totalReceived`和该地址已领取的钱`_alreadyReleased`，计算该受益人现在应分的`ETH`。
     */
    function pendingPayment(address account, uint256 totalReceived, uint256 alreadyReleased)
        public
        view
        returns (uint256)
    {
        // account应得的ETH = 总应得ETH - 已领到的ETH
        return (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }
}
