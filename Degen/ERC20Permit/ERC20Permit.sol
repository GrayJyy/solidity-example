// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Permit is ERC20, IERC20Permit, EIP712 {
    using ECDSA for bytes32;

    mapping(address => uint256) private _nonces;
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @dev 初始化 EIP712 的 name 以及 ERC20 的 name 和 symbol
     */
    constructor(string memory name_, string memory symbol_) EIP712(name_, "1") ERC20(name_, symbol_) {}

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        virtual
        override
    {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");
        bytes32 _structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));
        // _hashTypedDataV4() 会调用 MessageHashUtils.toTypedDataHash()，作用是把结构体的哈希值和域分隔符的哈希值进行哈希，这个函数定义在EIP712.sol中
        bytes32 _hash = _hashTypedDataV4(_structHash);
        address _signer = _hash.recover(v, r, s);
        require(_signer == owner, "ERC20Permit: invalid signature");
        _approve(owner, spender, value);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "消费nonce": 返回 `owner` 当前的 `nonce`，并增加 1。
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        current = _nonces[owner];
        _nonces[owner] += 1;
    }
}
