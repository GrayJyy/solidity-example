/**
 这里，我们实现一个简版的ERC20水龙头，逻辑非常简单：我们将一些ERC20代币转到水龙头合约里，用户可以通过合约的requestToken()函数来领取100单位的代币，每个地址只能领一次。
 我们在水龙头合约中定义3个状态变量

amountAllowed设定每次能领取代币数量（默认为100，不是一百枚，因为代币有小数位数）。
tokenContract记录发放的ERC20代币合约地址。
requestedAddress记录领取过代币的地址。

水龙头合约中定义了1个SendToken事件，记录了每次领取代币的地址和数量，在requestTokens()函数被调用时释放。

构造函数：初始化tokenContract状态变量，确定发放的ERC20代币地址。
requestTokens()函数，用户调用它可以领取ERC20代币。
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../ERC20/IERC20.sol";
error Faucet_OnlyRequestOnce();
error Faucet_Empty();

contract Faucet {
    uint256 public amountAllowed = 100;
    address public tokenContract;
    mapping(address => bool) requestedAddress;

    // SendToken事件
    event SendToken(address indexed Receiver, uint256 indexed Amount);

    constructor(address tokenContract_) {
        tokenContract = tokenContract_;
    }

    function requestTokens() external returns (bool) {
        if (requestedAddress[msg.sender] == true) {
            revert Faucet_OnlyRequestOnce(); // 每个地址只允许领取一次
        }
        IERC20 token = IERC20(tokenContract); // 创建ERC20代币合约
        if (token.balanceOf(address(this)) <= amountAllowed) {
            revert Faucet_Empty(); // 检查余额
        }
        requestedAddress[msg.sender] = true; // 标记为已赠送地址
        token.transfer(msg.sender, amountAllowed); // 赠送代币
        emit SendToken(msg.sender, amountAllowed); // 发送事件
        return true;
    }
}
