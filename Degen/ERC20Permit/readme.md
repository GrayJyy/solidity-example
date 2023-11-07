ERC20，以太坊最流行的代币标准。它流行的一个主要原因是 approve 和 transferFrom 两个函数搭配使用，使得代币不仅可以在外部拥有账户（EOA）之间转移，还可以被其他合约使用。

但是，ERC20的 approve 函数限制了只有代币所有者才能调用，这意味着所有 ERC20 代币的初始操作必须由 EOA 执行。举个例子，用户 A 在去中心化交易所使用 USDT 交换 ETH，必须完成两个交易：第一步用户 A 调用 approve 将 USDT 授权给合约，第二步用户 A 调用合约进行交换。非常麻烦，并且用户必须持有 ETH 用于支付交易的 gas。

EIP-2612 提出了 ERC20Permit，扩展了 ERC20 标准，添加了一个 permit 函数，允许用户通过 EIP-712 签名修改授权，而不是通过 msg.sender。这有两点好处：

授权这步仅需用户在链下签名，减少一笔交易。
签名后，用户可以委托第三方进行后续交易，不需要持有 ETH：用户 A 可以将签名发送给 拥有gas的第三方 B，委托 B 来执行后续交易。

一个简单的 ERC20Permit 合约，它实现了 IERC20Permit 定义的所有接口。合约包含 2 个状态变量:

_nonces: address -> uint 的映射，记录了所有用户当前的 nonce 值，
_PERMIT_TYPEHASH: 常量，记录了 permit() 函数的类型哈希。

合约包含 5 个函数:

构造函数: 初始化代币的 name 和 symbol。
permit(): ERC20Permit 最核心的函数，实现了 IERC20Permit 的 permit() 。它首先检查签名是否过期，然后用 _PERMIT_TYPEHASH, owner, spender, value, nonce, deadline 还原签名消息，并验证签名是否有效。如果签名有效，则调用ERC20的 _approve() 函数进行授权操作。
nonces(): 实现了 IERC20Permit 的 nonces() 函数。
DOMAIN_SEPARATOR(): 实现了 IERC20Permit 的 DOMAIN_SEPARATOR() 函数。
_useNonce(): 消费 nonce 的函数，返回用户当前的 nonce，并增加 1。