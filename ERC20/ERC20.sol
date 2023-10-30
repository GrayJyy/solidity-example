// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "./IERC20.sol";

error ERC20_NOTOWNER();

contract ERC20 is IERC20 {
    string private s_name; // token 名称
    string private s_symbol; // token 代号
    uint8 private s_decimals = 18; // 小数位数
    uint256 public override totalSupply; // token 总供给
    mapping(address => uint256) public override balanceOf; // 对应地址余额
    mapping(address => mapping(address => uint256)) public override allowance; // 授权额度
    address private s_owner; // 合约地址

    /**
events 在 IERC20 中
 */

    constructor(string memory name_, string memory symbol_) {
        s_name = name_;
        s_symbol = symbol_;
        s_owner = msg.sender;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowance[msg.sender][spender] += amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(uint amount) external OnlyOwner {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(uint amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    modifier OnlyOwner() {
        if (msg.sender != s_owner) revert ERC20_NOTOWNER();
        _;
    }

    // getter
    function name() public view returns (string memory) {
        return s_name;
    }

    function symbol() public view returns (string memory) {
        return s_symbol;
    }

    function decimals() public view returns (uint256) {
        return s_decimals;
    }
}
