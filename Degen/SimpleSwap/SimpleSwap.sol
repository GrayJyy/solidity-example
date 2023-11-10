// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleSwap is ERC20 {
    using Math for uint256;
    // 代币合约

    IERC20 public token0;
    IERC20 public token1;

    // 代币储备量
    uint256 public reserve0;
    uint256 public reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender, uint256 amountIn, address indexed tokenIn, uint256 amountOut, address indexed tokenOut
    );

    // 构造器，初始化代币地址
    constructor(IERC20 _token0, IERC20 _token1) ERC20("SimpleSwap", "SS") {
        token0 = _token0;
        token1 = _token1;
    }

    // 添加流动性，转进代币，铸造LP
    // @param amount0Desired 添加的token0数量
    // @param amount1Desired 添加的token1数量
    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired) external returns (uint256 liquidity) {
        token0.transferFrom(msg.sender, address(this), amount0Desired);
        token1.transferFrom(msg.sender, address(this), amount1Desired);
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            // 如果是第一次添加流动性，铸造 L = sqrt(x * y) 单位的LP（流动性提供者）代币
            liquidity = (amount0Desired * amount1Desired).sqrt();
        } else {
            // 如果不是第一次添加流动性，按添加代币的数量比例铸造LP，取两个代币更小的那个比例
            liquidity = (amount0Desired * reserve0 / _totalSupply).min(amount1Desired * reserve1 / _totalSupply);
        }
        // 检查铸造的LP数量
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        // 给流动性提供者铸造LP代币，代表他们提供的流动性
        _mint(msg.sender, liquidity);
        emit Mint(msg.sender, amount0Desired, amount1Desired);
    }

    /**
     *
     * @param liquidity 移除的流动性数量
     * @dev
     * 移除流动性，销毁LP，转出代币
     * 转出数量 = (liquidity / totalSupply_LP) * reserve
     *
     * 获取合约中的代币余额。
     * 按LP的比例计算要转出的代币数量。
     * 检查代币数量。
     * 销毁LP份额。
     * 将相应的代币转账给用户。
     * 更新储备量。
     * 释放 Burn 事件。
     */
    function removeLiquidity(uint256 liquidity) external returns (uint256 amount0, uint256 amount1) {
        // 获取合约中的代币余额
        uint256 _balance0 = token0.balanceOf(address(this));
        uint256 _balance1 = token1.balanceOf(address(this));
        // 按LP的比例计算要转出的代币数量
        uint256 _totalSupply = totalSupply();
        amount0 = liquidity * _balance0 / _totalSupply;
        amount1 = liquidity * _balance1 / _totalSupply;
        // 检查代币数量
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(msg.sender, liquidity);
        // 将代币退还
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        // 更新储备量
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
        // 释放 Burn 事件
        emit Burn(msg.sender, amount0, amount1);
    }

    // 给定一个资产的数量和代币对的储备，计算交换另一个代币的数量
    // k = x * y,k = (x + dX)联立得 * (y + dY) dY = y * dX / (x + dX)
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "INSUFFICIENT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        amountOut = amountIn * reserveOut / (reserveIn + amountIn);
    }

    /**
     * @param amountIn 用于交换的代币数量
     * @param tokenIn 用于交换的代币合约地址
     * @param amountOutMin 交换出另一种代币的最低数量
     * @dev
     * 用户在调用函数时指定用于交换的代币数量，交换的代币地址，以及换出另一种代币的最低数量。
     * 判断是 token0 交换 token1，还是 token1 交换 token0。
     * 利用上面的公式，计算交换出代币的数量。
     * 判断交换出的代币是否达到了用户指定的最低数量，这里类似于交易的滑点。
     * 将用户的代币转入合约。
     * 将交换的代币从合约转给用户。
     * 更新合约的代币储备量。
     * 释放 Swap 事件。
     */
    function swap(uint256 amountIn, IERC20 tokenIn, uint256 amountOutMin)
        external
        returns (uint256 amountOut, IERC20 tokenOut)
    {
        require(amountIn > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        require(tokenIn == token0 || tokenIn == token1, "INVALID_TOKEN");

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        if (tokenIn == token0) {
            // 如果是token0交换token1
            tokenOut = token1;
            // 计算能交换出的token1数量
            amountOut = getAmountOut(amountIn, balance0, balance1);
            require(amountOut > amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
            // 进行交换
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);
        } else {
            // 如果是token1交换token0
            tokenOut = token0;
            // 计算能交换出的token1数量
            amountOut = getAmountOut(amountIn, balance1, balance0);
            require(amountOut > amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
            // 进行交换
            tokenIn.transferFrom(msg.sender, address(this), amountIn);
            tokenOut.transfer(msg.sender, amountOut);
        }

        // 更新储备量
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));

        emit Swap(msg.sender, amountIn, address(tokenIn), amountOut, address(tokenOut));
    }
}
