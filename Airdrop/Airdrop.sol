/**
 因为每次接收空投的用户很多，项目方不可能一笔一笔的转账。利用智能合约批量发放ERC20代币，可以显著提高空投效率。
 利用循环，一笔交易将ERC20代币发送给多个地址。

 getSum()函数：返回uint数组的和

 multiTransferToken()函数：发送ERC20代币空投，包含3个参数：
_token：代币合约地址（address类型）
_addresses：接收空投的用户地址数组（address[]类型）
_amounts：空投数量数组，对应_addresses里每个地址的数量（uint[]类型）

multiTransferETH()函数：发送ETH空投，包含2个参数：
_addresses：接收空投的用户地址数组（address[]类型）
_amounts：空投数量数组，对应_addresses里每个地址的数量（uint[]类型）
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../ERC20/IERC20.sol";
error Airdrop_LengthNotEqual();
error Airdrop_NeedApproved();
error Airdrop_EthError();
error Airdrop_NoAmount();
error Airdrop_ManualFailed();

contract Airdrop {
    mapping(address => uint) public failTransferList;

    constructor() {}

    function getSum(uint256[] calldata _arr) internal pure returns (uint sum) {
        for (uint i = 0; i < _arr.length; i++) sum += _arr[i];
    }

    function multiTransferToken(
        address _token,
        address[] calldata _addresses,
        uint[] calldata _amounts
    ) internal {
        if (_addresses.length != _amounts.length) {
            revert Airdrop_LengthNotEqual(); // 检查接收者数组长度与数量数组长度是否匹配
        }
        IERC20 token = IERC20(_token); // 创建 ERC20 合约
        uint totalSupply = getSum(_amounts);
        if (token.allowance(msg.sender, address(this)) < totalSupply) {
            revert Airdrop_NeedApproved(); // 检查授权额度
        }
        for (uint i = 0; i < _addresses.length; i++) {
            token.transferFrom(msg.sender, _addresses[i], _amounts[i]); // 批量发送代币
        }
    }

    function multiTransferETH(
        address[] calldata _addresses,
        uint[] calldata _amounts
    ) public payable {
        if (_addresses.length != _amounts.length) {
            revert Airdrop_LengthNotEqual(); // 检查接收者数组长度与数量数组长度是否匹配
        }
        uint totalSupply = getSum(_amounts);
        if (msg.value != totalSupply) {
            revert Airdrop_EthError(); // 检查提供的 eth 数量是否与需要的相等
        }
        for (uint i = 0; i < _addresses.length; i++) {
            /**
             需要注意，这里不能使用 _addresses[i].transfer,因为transfer 有 gas 限制，一旦某一个地址失败，全部交易回滚，导致所有转账无法正常运作，也就是 DOS(拒绝服务) 攻击。
             原理就是调用方接收 eth 时会自动触发receive/fallback函数，恶意调用方会在这两个回调里执行复杂逻辑或故意抛出错误导致转账失败。
             而用_addresses[i].call的方法，失败不会自动 revert 交易，可以手动处理，继续执行下一次交易。
             */
            (bool success, ) = _addresses[i].call{value: _amounts[i]}(""); // 批量转账 eth
            if (!success) {
                failTransferList[_addresses[i]] = _amounts[i]; // 记录失败地址
            }
        }
    }

    function withdrawFromFailList(address _to) external returns (bool) {
        uint amount = failTransferList[msg.sender];
        if (amount <= 0) {
            revert Airdrop_NoAmount(); // 避免无失败地址转账
        }
        (bool success, ) = _to.call{value: amount}("");
        if (!success) {
            revert Airdrop_ManualFailed();
        }
        return success;
    }
}
