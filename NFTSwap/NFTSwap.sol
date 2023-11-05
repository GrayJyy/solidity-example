// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../ERC721/IERC721.sol";
import "../ERC721/IERC721Receiver.sol";
import "../ERC721/GrayApe.sol";

contract NFTSwap is IERC721Receiver {
    // 定义order结构体
    struct Order {
        address owner;
        uint256 price;
    }
    // NFT Order映射
    mapping(address => mapping(uint256 => Order)) public nftList;

    // 挂单
    event List(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );
    // 购买
    event Purchase(
        address indexed buyer,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 price
    );
    // 撤单
    event Revoke(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId
    );
    // 改价
    event Update(
        address indexed seller,
        address indexed nftAddr,
        uint256 indexed tokenId,
        uint256 newPrice
    );

    constructor() {}

    // fallback() external payable {}
    function onERC721Received(
        address,
        address,
        uint,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // 挂单list()：卖家创建NFT并创建订单，并释放List事件。
    // 参数为NFT合约地址_nftAddr，NFT对应的_tokenId，挂单价格_price（注意：单位是wei）。成功后，NFT会从卖家转到NFTSwap合约中。
    function list(address _nftAddr, uint256 _tokenId, uint256 _price) public {
        IERC721 _nft = IERC721(_nftAddr);
        require(_price > 0);
        require(_nft.ownerOf(_tokenId) == msg.sender, "Invalid owner"); // 检查nft是否为挂单人拥有
        require(_nft.getApproved(_tokenId) == address(this), "Need approved!");
        Order storage _order = nftList[_nftAddr][_tokenId];
        _order.owner = msg.sender;
        _order.price = _price;
        // 将NFT转账到合约
        _nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        // 释放List事件
        emit List(msg.sender, _nftAddr, _tokenId, _price);
    }

    /**
         撤单revoke()：卖家撤回挂单，并释放Revoke事件。
         参数为NFT合约地址_nftAddr，NFT对应的_tokenId。
         成功后，NFT会从NFTSwap合约转回卖家。
         */
    function revoke(address _nftAddr, uint256 _tokenId) public {
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.owner == msg.sender, "Not the owner");
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // 检查是否尚未出售;
        // 将NFT转给卖家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete nftList[_nftAddr][_tokenId]; // 删除order

        // 释放Revoke事件
        emit Revoke(msg.sender, _nftAddr, _tokenId);
    }

    /**
     *修改价格update()：卖家修改NFT订单价格，并释放Update事件。
     参数为NFT合约地址_nftAddr，NFT对应的_tokenId，更新后的挂单价格_newPrice（注意：单位是wei）。
     */

    function update(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _newPrice
    ) public {
        Order storage _order = nftList[_nftAddr][_tokenId];
        require(_order.owner == msg.sender, "Not the owner");
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // 检查是否尚未出售;
        // 调整NFT价格
        _order.price = _newPrice;

        // 释放Update事件
        emit Update(msg.sender, _nftAddr, _tokenId, _newPrice);
    }

    /**
     * 购买purchase：买家支付ETH购买挂单的NFT，并释放Purchase事件。
     * 参数为NFT合约地址_nftAddr，NFT对应的_tokenId。
     * 成功后，ETH将转给卖家，NFT将从NFTSwap合约转给买家。
     */
    function purchase(address _nftAddr, uint256 _tokenId) public payable {
        Order storage _order = nftList[_nftAddr][_tokenId];
        uint256 _price = _order.price;
        require(msg.value >= _price, "eth not enough");
        // 声明IERC721接口合约变量
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT尚未出售
        // 将NFT转给买家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        // 将ETH转给卖家，多余ETH给买家退款
        (bool success, ) = payable(_order.owner).call{value: _price}("");
        require(success, "sell failed");
        (bool success2, ) = payable(msg.sender).call{value: msg.value - _price}(
            ""
        );
        require(success2, "refund failed");
        // payable(_order.owner).transfer(_price);
        // payable(msg.sender).transfer(msg.value - _price);
        delete nftList[_nftAddr][_tokenId]; // 删除order

        // 释放Purchase事件
        emit Purchase(msg.sender, _nftAddr, _tokenId, _order.price);
    }
}
