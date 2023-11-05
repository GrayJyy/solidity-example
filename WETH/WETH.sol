// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice
 * WETH (Wrapped ETH)是ETH的带包装版本。
 * 2015年ERC20 标准出现，该代币标准旨在为以太坊上的代币制定一套标准化的规则，从而简化了新代币的发布，并使区块链上的所有代币相互可比。
 * 不幸的是，以太币本身并不符合ERC20标准。WETH的开发是为了提高区块链之间的互操作性 ，并使ETH可用于去中心化应用程序（dApps）。
 * 它就像是给原生代币穿了一件智能合约做的衣服：穿上衣服的时候，就变成了WETH，符合ERC20同质化代币标准，可以跨链，可以用于dApp；脱下衣服，它可1:1兑换ETH。
 * WETH 的优势：
 * 与ERC20互操作性：WETH遵循ERC20标准，这使得它能够与其他ERC20代币进行无缝交互。通过使用WETH，以太坊用户可以将其ETH转换为WETH，并将其与其他ERC20代币一起使用，例如在去中心化交易所（DEX）进行交易或提供流动性。
 *
 * 去中心化交易所（DEX）支持：许多去中心化交易所（如Uniswap和SushiSwap）在其交易对中使用WETH作为基础代币。这使得用户可以直接以WETH作为中间代币进行交易，而不必在每次交易之间进行ETH和ERC20代币之间的转换。
 *
 * 交易标准化和可预测性：使用WETH作为代币，交易和智能合约的编写变得更加标准化和可预测。由于ETH是以太坊网络的原生货币，其具有固定的十进制位数（18位小数）。而其他ERC20代币的小数位数可以不同。通过使用WETH，可以避免在交易和合约中处理不同代币的小数位数问题。
 *
 * 交易费用和批量操作：WETH的使用可以简化交易和批量操作。在某些情况下，将ETH转换为WETH可以更有效地管理交易费用，因为ETH交易通常需要更高的燃气费用。此外，对于批量操作，使用WETH可以减少批量交易中的交易数量，从而降低整体交易成本。
 *
 * 总之，WETH作为以太坊上的封装代币，为用户提供了与ERC20代币的互操作性和标准化，以及在去中心化交易所中的便利性。它在以太坊生态系统中具有重要的作用，并满足了一些特定的需求和使用案例。
 *
 * @dev
 * WETH符合ERC20标准，它比普通的ERC20多了两个功能：
 *
 * 存款：包装，用户将ETH存入WETH合约，并获得等量的WETH。
 *
 * 取款：拆包装，用户销毁WETH，并获得等量的ETH。
 */
contract WETH is ERC20 {
    // 事件：存款和取款
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // 构造函数，初始化ERC20的名字和代号
    constructor() ERC20("WETH", "WETH") {}

    // 回调函数，当用户往WETH合约转ETH时，会触发deposit()函数
    fallback() external payable {
        deposit();
    }
    // 回调函数，当用户往WETH合约转ETH时，会触发deposit()函数

    receive() external payable {
        deposit();
    }

    // 存款函数，当用户存入ETH时，给他铸造等量的WETH
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    // 提款函数，用户销毁WETH，取回等量的ETH
    function withdraw(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount);
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }
}
