// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../ERC721/IERC165.sol";
import "./IERC1155.sol";
import "./IERC1155MetadataURI.sol";
import "../ERC721/Address.sol";
import "./IERC1155Receiver.sol";
import "../ERC721/String.sol";

error ERC1155_ZeroAddress();
error ERC1155_LengthNotEqual();

/**
 * @dev
 * ERC1155标准，它支持一个合约包含多种代币
 * 在ERC721中，每个代币都有一个tokenId作为唯一标识，每个tokenId只对应一个代币；
 * 而在ERC1155中，每一种代币都有一个id作为唯一标识，每个id对应一种代币。
 * 这样，代币种类就可以非同质的在同一个合约里管理了，并且每种代币都有一个网址uri来存储它的元数据，类似ERC721的tokenURI。
 * 那么怎么区分ERC1155中的某类代币是同质化还是非同质化代币呢？
 * 其实很简单：如果某个id对应的代币总量为1，那么它就是非同质化代币，类似ERC721；
 * 如果某个id对应的代币总量大于1，那么他就是同质化代币，因为这些代币都分享同一个id，类似ERC20。
 *
 * name：代币名称
 * symbol：代币代号
 * _balances：代币持仓映射，记录代币种类id下某地址account的持仓量balances。
 * _operatorApprovals：批量授权映射，记录持有地址给另一个地址的授权情况。
 *
 * 构造函数：初始化状态变量name和symbol。
 * supportsInterface()：实现ERC165标准，声明它支持的接口，供其他合约检查。
 * balanceOf()：实现IERC1155的balanceOf()，查询持仓量。与ERC721标准不同，这里需要输入查询的持仓地址account以及币种id。
 * balanceOfBatch()：实现IERC1155的balanceOfBatch()，批量查询持仓量。
 * setApprovalForAll()：实现IERC1155的setApprovalForAll()，批量授权，释放ApprovalForAll事件。
 * isApprovedForAll()：实现IERC1155的isApprovedForAll()，查询批量授权信息。
 * safeTransferFrom()：实现IERC1155的safeTransferFrom()，单币种安全转账，释放TransferSingle事件。与ERC721不同，这里不仅需要填发出方from，接收方to，代币种类id，还需要填转账数额amount。
 * safeBatchTransferFrom()：实现IERC1155的safeBatchTransferFrom()，多币种安全转账，释放TransferBatch事件。
 * _mint()：单币种铸造函数。
 * _mintBatch()：多币种铸造函数。
 * _burn()：单币种销毁函数。
 * _burnBatch()：多币种销毁函数。
 * _doSafeTransferAcceptanceCheck调用，确保接收方为合约的情况下，实现了onERC1155Received()函数。
 * _doSafeBatchTransferAcceptanceCheck：多币种转账的安全检查，，被safeBatchTransferFrom调用，确保接收方为合约的情况下，实现了onERC1155BatchReceived()函数。
 * uri()：返回ERC1155的第id种代币存储元数据的网址，类似ERC721的tokenURI。
 * baseURI()：返回baseURI，uri就是把baseURI和id拼接在一起，需要开发重写。
 */

contract ERC1155 is IERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;
    using Strings for uint256;

    string public name;
    string public symbol;
    mapping(uint256 => mapping(address => uint256)) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || interfaceId == type(IERC1155MetadataURI).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    /**
     * @dev 持仓查询 实现IERC1155的balanceOf，返回account地址的id种类代币持仓量。
     */
    function balanceOf(address account, uint256 id) public view returns (uint256) {
        if (account == address(0)) {
            revert ERC1155_ZeroAddress();
        }
        return _balances[id][account];
    }

    /**
     * @dev 批量持仓查询
     * 要求:
     * - `accounts` 和 `ids` 数组长度相等.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        if (accounts.length != ids.length) {
            revert ERC1155_LengthNotEqual();
        }
        // 固定长度的静态数组无法通过 push 方法新增元素
        uint256[] memory _batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            _batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return _batchBalances;
    }

    /**
     * @dev 批量授权，调用者授权operator使用其所有代币
     * 释放{ApprovalForAll}事件
     * 条件：msg.sender != operator
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(msg.sender != operator);
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev 查询批量授权.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev 安全转账，将`amount`单位的`id`种类代币从`from`转账到`to`
     * 释放 {TransferSingle} 事件.
     * 要求:
     * - to 不能是0地址.
     * - from拥有足够的持仓量，且调用者拥有授权
     * - 如果 to 是智能合约, 他必须支持 IERC1155Receiver-onERC1155Received.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        require(to != address(0));
        uint256 _prevBalance = _balances[id][from];
        require(_prevBalance >= amount);
        require(from == msg.sender || isApprovedForAll(from, msg.sender));
        // 安全检查
        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
        unchecked {
            // 使用unchecked是因为前面已经判断_prevBalance >= amount，在这里可以避免solidity 的自动检查减少 gas 消耗
            _balances[id][from] = _prevBalance - amount;
        }
        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    /**
     * @dev 批量安全转账，将`amounts`数组单位的`ids`数组种类代币从`from`转账到`to`
     * 释放 {TransferSingle} 事件.
     * 要求:
     * - to 不能是0地址.
     * - from拥有足够的持仓量，且调用者拥有授权
     * - 如果 to 是智能合约, 他必须支持 IERC1155Receiver-onERC1155BatchReceived.
     * - ids和amounts数组长度相等
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        require(to != address(0));
        require(ids.length == amounts.length);
        require(from == msg.sender || isApprovedForAll(from, msg.sender));
        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 _prevBalance = _balances[ids[i]][from];
            require(_prevBalance >= amounts[i]);
            _balances[ids[i]][from] = _prevBalance - amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }
    /**
     *
     * @dev ERC1155的安全转账检查
     * 当一个合约没有实现 ERC1155 相关函数（如 transferFrom、safeTransferFrom 等），
     * 并且没有提供其他途径将 NFT 转移出去时，会导致 NFT 被称为进入了“黑洞”，
     * 无法再从该合约中转出。
     * 所以需要对合约地址进行检测，查看其是否实现了 ERC1155 相关函数。（ERC721 合约同理）
     */

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @dev _doSafeBatchTransferAcceptanceCheck函数重载
     * 使得_doSafeBatchTransferAcceptanceCheck可以支持 id 和 amount 的传参
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    /**
     * @dev 铸造
     * 释放 {TransferSingle} 事件.
     */
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        address operator = msg.sender;
        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);
    }

    /**
     * @dev 批量铸造
     * 释放 {TransferBatch} 事件.
     */
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        virtual
    {
        require(to != address(0));
        require(ids.length == amounts.length);
        address operator = msg.sender;
        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }
        emit TransferBatch(operator, address(0), to, ids, amounts);
    }

    /**
     * @dev 销毁
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        address operator = msg.sender;
        uint256 _prevBalance = _balances[id][from];
        require(_prevBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = _prevBalance - amount;
        }
        emit TransferSingle(operator, from, address(0), id, amount);
    }

    /**
     * @dev 批量销毁
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = msg.sender;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 _prevBalance = _balances[id][from];
            require(_prevBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = _prevBalance - amount;
            }
        }
        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    /**
     * @dev 返回ERC1155的id种类代币的uri，存储metadata，类似ERC721的tokenURI.
     * 关于abi.encodePacked的思考：
     * 使用 `abi.encodePacked` 对不同类型的参数进行编码时，得到的字节长度可能会有所不同。`abi.encodePacked` 函数执行紧密打包，这意味着它会将参数串联在一起而不使用任何填充。具体的字节长度取决于参数的类型和值。
     *
     * 1. **不同类型的参数**:
     *    - **uint256**: 总是占用32字节，因为它是一个256位的整数。
     *    - **string**: 字节长度取决于字符串的长度。
     *    - **address**: 总是占用20字节。
     *    - **bool**: 占用1字节。
     * 对于一个 `uint256` 类型的 `id`，其值为10：
     *    - 当 `id` 被转换为字符串后，它变成了 "10"，这是一个长度为2的字符串。因此，编码后的字节长度是2。
     *    - 如果直接传递 `id`，它作为一个 `uint256` 被编码，占用32字节。
     * 至于 abi.encodePacked 接受的参数的编码长度限制，它并没有明确的限制。然而，需要注意的是，Solidity 合约中的函数调用有一个总的输入数据大小限制，也称为 gas 限制。这个限制默认情况下是 4KB（4,096 字节），但可以在编译合约时进行配置。
     * 
     * 如果 abi.encodePacked 的参数导致编码后的结果超过了 gas 限制的大小，那么在合约执行过程中可能会引发错误。因此，在使用 abi.encodePacked 时，你应该留意编码后的结果大小，以确保不会超出合约的 gas 限制。
     */
    function uri(uint256 id) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        // 需要注意在 solidity 中 uint256 类型没有内置的 toString() 函数,所以在前面引入了字符串转换库 Strings来将 uint256 类型转换为字符串
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, id.toString())) : "";
    }

    /**
     * 计算{uri}的BaseURI，uri就是把baseURI和tokenId拼接在一起，需要开发重写.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }
}
