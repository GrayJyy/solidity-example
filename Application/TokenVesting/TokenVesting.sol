// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../ERC20/IERC20.sol";

/**
 * @title
 * 项目方一般会约定代币归属条款（token vesting），在归属期内逐步释放代币，减缓抛压，并防止团队和资本方过早躺平
 * @dev
 * 构造函数：初始化受益人地址，归属期(秒), 起始时间戳。参数为受益人地址beneficiaryAddress和归属期durationSeconds。为了方便，起始时间戳用的部署时的区块链时间戳block.timestamp。
 * release()：提取代币函数，将已释放的代币转账给受益人。调用了vestedAmount()函数计算可提取的代币数量，释放ERC20Released事件，然后将代币transfer给受益人。参数为代币地址token。
 * vestedAmount()：根据线性释放公式，查询已经释放的代币数量。开发者可以通过修改这个函数，自定义释放方式。参数为代币地址token和查询的时间戳timestamp。
 */
contract TokenVesting {
    // 状态变量
    mapping(address => uint256) public erc20Released; // 代币地址->释放数量的映射，记录已经释放的代币
    address public immutable beneficiary; // 受益人地址
    uint256 public immutable start; // 起始时间戳
    uint256 public immutable duration; // 归属期

    // 事件
    event ERC20Released(address indexed token, uint256 amount); // 提币事件

    constructor(address _beneficiaryAddress, uint256 _durationSeconds) {
        beneficiary = _beneficiaryAddress;
        start = block.timestamp;
        duration = _durationSeconds;
    }

    function vestedAmount(address token, uint256 timestamp) public view returns (uint256) {
        uint256 totalAmount_ = IERC20(token).balanceOf(address(this)) + erc20Released[token]; // 合约中现有 token+已释放 token
        // 根据线性释放公式，计算已经释放的数量
        if (timestamp < start) {
            return 0;
        } else if (timestamp > start + duration) {
            return totalAmount_;
        } else {
            return (totalAmount_ * (timestamp - start)) / duration;
        }
    }

    function release(address token) public {
        // 调用vestedAmount()函数计算可提取的代币数量
        uint256 amount_ = vestedAmount(token, uint256(block.timestamp)) - erc20Released[token];
        require(amount_ > 0);
        // 更新已释放代币数量
        erc20Released[token] += amount_;
        IERC20(token).transfer(msg.sender, amount_);
        emit ERC20Released(token, amount_);
    }
}
