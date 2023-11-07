// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MultisigWallet {
    address[] public owners; // 多签持有人数组
    mapping(address => bool) public isOwner; // 记录一个地址是否为多签持有人
    uint256 public ownerCount; // 多签持有人数量
    uint256 public threshold; // 多签执行门槛，交易至少有n个多签人签名才能被执行。
    uint256 public nonce; // nonce，防止签名重放攻击

    event ExecutionSuccess(bytes32 txHash); // 交易成功事件
    event ExecutionFailure(bytes32 txHash); // 交易失败事件

    constructor(address[] memory owners_, uint256 threshold_) {
        _setupOwners(owners_, threshold_);
    }

    function _setupOwners(address[] memory _owners, uint256 _threshold) private {
        require(threshold == 0);
        require(_threshold > 0 && _threshold <= _owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0));
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        ownerCount = _owners.length;
        threshold = _threshold;
    }
}
