// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../ERC20/IERC20.sol";

/**
 * @title
 * 在去中心化交易所（DEX）中，比如Uniswap，交易是通过自动做市商（AMM）机制进行的，与中心化交易所（CEX）不同。在这里，用户或项目方需要提供资金池，以便其他用户能够即时进行代币的买卖交易。
 * 想象一下，你想在Uniswap上交易ETH和DAI这两种代币。你可以将一定数量的ETH和DAI质押到Uniswap的资金池中。作为回报，Uniswap会给你铸造一种叫做流动性提供者（LP）代币的凭证。这些LP代币证明你质押了相应的份额，并允许你收取一部分交易手续费。
 * 这个资金池实际上是由多个用户质押的代币组成的。当其他用户想要交易ETH和DAI时，他们会从资金池中购买这些代币。根据资金池中各个代币的供应量和价格，交易会在不同的价格点上进行。这种机制确保了市场的流动性，并且不需要中心化的交易对手方。
 * 当你持有LP代币时，你有权利按比例从交易手续费中获得收益。这是因为你参与了资金池的质押，为其他交易提供了流动性支持。你可以随时将你的LP代币赎回，取回你质押的代币，并收取相应的交易手续费。
 * 总结起来，去中心化交易所（DEX），如Uniswap，通过用户提供资金池来支持代币的交易。质押代币的用户会收到相应的流动性提供者（LP）代币，证明他们的贡献，并享受交易手续费的收益。这种机制确保了交易的流动性和去中心化的特性。
 * 如果项目方毫无征兆的撤出流动性池中的LP代币，那么投资者手中的代币就无法变现，直接归零了。这种行为也叫rug-pull。
 * 但是如果LP代币是锁仓在代币锁合约中，在锁仓期结束以前，项目方无法撤出流动性池，也没办法rug pull。因此代币锁可以防止项目方过早跑路（要小心锁仓期满跑路的情况）。
 * @dev
 * 开发者在部署合约时规定锁仓的时间，受益人地址，以及代币合约。
 * 开发者将代币转入TokenLocker合约。
 * 在锁仓期满，受益人可以取走合约里的代币。
 *
 *
 * 构造函数：初始化代币合约，受益人地址，以及锁仓时间。
 * release()：在锁仓期满后，将代币释放给受益人。需要受益人主动调用release()函数提取代币。
 */
contract TokenLocker {
    // 被锁仓的ERC20代币合约
    IERC20 public immutable token;
    // 受益人地址
    address public immutable beneficiary;
    // 锁仓时间(秒)
    uint256 public immutable lockTime;
    // 锁仓起始时间戳(秒)
    uint256 public immutable startTime;

    // 事件
    event TokenLockStart(address indexed beneficiary, address indexed token, uint256 startTime, uint256 lockTime);
    event Release(address indexed beneficiary, address indexed token, uint256 releaseTime, uint256 amount);

    constructor(IERC20 token_, address beneficiary_, uint256 lockTime_) {
        require(lockTime_ > 0, "TokenLock: lock time should greater than 0");
        token = token_;
        beneficiary = beneficiary_;
        lockTime = lockTime_;
        startTime = block.timestamp;
        emit TokenLockStart(beneficiary_, address(token_), block.timestamp, lockTime_);
    }

    /**
     * @dev 在锁仓时间过后，将代币释放给受益人。
     */
    function release() public {
        require(block.timestamp >= startTime + lockTime, "TokenLock: current time is before release time");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "TokenLock: no tokens to release");
        token.transfer(beneficiary, amount);
        emit Release(msg.sender, address(token), block.timestamp, amount);
    }
}
