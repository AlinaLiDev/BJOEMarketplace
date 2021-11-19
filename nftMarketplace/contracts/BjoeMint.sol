//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BjoeMint is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;
    using Counters for Counters.Counter;

    struct Bjoes {
        uint256 id;
        uint256 birth;
        address minter;
        string uri;
    }

    struct TopHolder {
        address holder;
        uint256 balance;
        uint256 withdrawAmount;
        bool equalBalance;
        bool paidOut;
    }

    uint256 public maxSupply;
    uint256 public reservedSupply = 0;
    uint256 public reservedMaxSupply;
    uint256 public price;
    uint256 public maxMintRequest;
    uint256 public availableFunds;
    uint256 public reflectionBalance;
    uint256 public totalDividend;
    uint256 public fees = 20;
    string public baseTokenURI;
    string public baseExtension;

    TopHolder public topHolder;
    Counters.Counter private _tokenIds;

    Bjoes[] public bjoes;
    address[] public funds;
    mapping(uint256 => uint256) public lastDividendAt;

    event Mint(uint256 tokenId, address to);

    function getBjoes(uint256 _tokenId) public view returns (Bjoes memory) {
        return bjoes[_tokenId];
    }

    function getReflectionBalance(uint256 _tokenId) public view returns (uint256) {
        return totalDividend.sub(lastDividendAt[_tokenId]);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    constructor(
        uint256 _maxSupply,
        uint256 _reservedMaxSupply,
        uint256 _price,
        uint256 _maxMintRequest,
        string memory _baseTokenURI,
        string memory _baseExtension,
        address[] memory _funds,
        uint256 _withdrawValueTopHolder
    ) ERC721("Bjoe Mint", "BJM") {
        maxSupply = _maxSupply;
        reservedMaxSupply = _reservedMaxSupply;
        price = _price;
        maxMintRequest = _maxMintRequest;
        baseTokenURI = _baseTokenURI;
        baseExtension = _baseExtension;
        funds = _funds;
        topHolder.withdrawAmount = _withdrawValueTopHolder;
    }

    receive() external payable {}

    function claimRewards() external returns (bool) {
        require(_msgSender() != owner(), "Owner can't claim rewards");
        uint256 count = balanceOf(_msgSender());
        uint256 balance = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_msgSender(), i);
            if (tokenId >= reservedMaxSupply) {
                balance = balance.add(getReflectionBalance(tokenId));
            }
            lastDividendAt[tokenId] = totalDividend;
        }
        payable(_msgSender()).transfer(balance);
        return true;
    }

    function mint(uint256 _amount) external payable {
        address owner = owner();
        address sender = _msgSender();
        require(!Address.isContract(sender), "Sender is a contract");
        require(_amount > 0, "Requested mint amount must be greater than zero");
        require(_tokenIds.current() < maxSupply, "Max mint supply reached");
        require(_amount.add(_tokenIds.current()) <= maxSupply, "Requested mint amount overflows maximum mint supply");
        if (sender != owner) {
            require(reservedSupply == reservedMaxSupply, "Sale can't start untill reserved supply has been minted");
            require(msg.value >= _amount.mul(price), "Insufficient value sent");
            require(_amount <= maxMintRequest, "Requested mint amount is bigger than max authorized mint request");
        } else {
            require(reservedSupply < reservedMaxSupply, "Maximum reserved mint supply reached");
            require(_amount.add(reservedSupply) <= reservedMaxSupply, "Requested mint amount overflows reserved maximum mint supply");
            reservedSupply = reservedSupply.add(_amount);
        }
        uint256 localfees = 0;
        for (uint256 i = 0; i < _amount; i++) {
            string memory newTokenURI = string(abi.encodePacked(baseTokenURI, Strings.toString(_tokenIds.current()), baseExtension));
            bjoes.push(Bjoes(_tokenIds.current(), block.timestamp, sender, newTokenURI));
            _safeMint(sender, _tokenIds.current());
            _setTokenURI(_tokenIds.current(), newTokenURI);
            if (sender != owner) {
                lastDividendAt[_tokenIds.current()] = totalDividend;
                reflectDividend((price.div(100)).mul(fees));
                localfees = localfees.add((price.div(100)).mul(fees));
            } else {
                lastDividendAt[_tokenIds.current()] = 0;
            }
            emit Mint(_tokenIds.current(), sender);
            _tokenIds.increment();
        }
        availableFunds = availableFunds.add(msg.value.sub(localfees));
        _setTopHolder(address(0), sender);
    }

    function setBaseTokenURI(string memory _baseURI) public onlyOwner returns (bool) {
        require(_tokenIds.current() == 0, "Can't change URI once mint started");
        baseTokenURI = _baseURI;
        return true;
    }

    function withdrawFunds(uint256 amount) external onlyOwner returns (bool) {
        require(amount > 0, "Available funds is zero");
        require(availableFunds > 0, "Available funds is zero");
        require(amount <= availableFunds, "Amount better available");
        uint256 shareFund = amount.div(funds.length);
        availableFunds = availableFunds.sub(amount);
        for (uint256 i = 0; i < funds.length; i++) {
            payable(funds[i]).transfer(shareFund);
        }
        return true;
    }

    function withdrawTopHolder() public returns (bool) {
        require(_tokenIds.current() >= maxSupply, "Collection not purchased");
        require(!topHolder.equalBalance, "Top holder is not the only one");
        require(!topHolder.paidOut, "The reward has already been paid");
        payable(topHolder.holder).transfer(topHolder.withdrawAmount);
        topHolder.paidOut = true;
        return true;
    }

    function reflectDividend(uint256 _amount) private {
        reflectionBalance = reflectionBalance.add(_amount);
        totalDividend = totalDividend.add(_amount.div(_tokenIds.current().sub(reservedMaxSupply).add(1)));
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        return ERC721URIStorage._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._transfer(from, to, tokenId);
        _setTopHolder(from, to);
    }

    function _setTopHolder(address from, address holder) private returns (bool) {
        uint256 balanceHolder = balanceOf(holder);
        if (from != address(0) && from == topHolder.holder) {
            topHolder.balance = balanceOf(from);
        }
        if (balanceHolder > topHolder.balance) {
            topHolder.holder = holder;
            topHolder.balance = balanceHolder;
            topHolder.equalBalance = false;
        }
        if (balanceHolder == topHolder.balance && holder != topHolder.holder) {
            topHolder.equalBalance = true;
        }
        return true;
    }
}