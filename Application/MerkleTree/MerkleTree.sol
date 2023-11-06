// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;
import "../ERC721/ERC721.sol";
import "./MerkleProof.sol";

error MerkleTree_NotVerified();
error MerkleTree_Minted();

/**
 * @dev
 * 合约只需要保存 root，leaf和proof可以存在服务端,节省gas
 */
contract MerkleTree is ERC721 {
    bytes32 public immutable root; // Merkle树的根
    mapping(address => bool) public mintedAddress; // 记录已经mint的地址

    // 构造函数，初始化NFT合集的名称、代号、Merkle树的根
    constructor(
        string memory name,
        string memory symbol,
        bytes32 merkleroot
    ) ERC721(name, symbol) {
        root = merkleroot;
    }

    // 计算MerkleTree叶子的哈希值
    function _leaf(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    // MerkleTree验证，调用MerkleProof库的verify()函数
    function _verify(
        bytes32 leaf,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    function mint(
        address account,
        uint256 tokenId,
        bytes32[] calldata proof
    ) external {
        if (!_verify(_leaf(account), proof)) {
            revert MerkleTree_NotVerified(); // 验证是否处于白名单
        }
        if (mintedAddress[account]) {
            revert MerkleTree_Minted(); // 验证是否已mint
        }
        mintedAddress[account] = true;
        _mint(account, tokenId);
    }
}
