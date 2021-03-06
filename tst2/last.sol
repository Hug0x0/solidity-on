// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/finance/PaymentSplitterUpgradeable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./HybridToken.sol";

// Ownable, Reentrancy, PaymentSplitter
contract NftCollectionV2 is ERC721AUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _nftIdCounter;

    HybridToken hybridToken;

    enum Steps { NotStarted, WhitelistedSale, PublicSale, SoldOut, Reveal }
    Steps public sellingStep;

    uint256 public MAX_SUPPLY_NFT;
    uint256 public publicSaleNftPrice;
    uint256 public whitelistSaleNftPrice;
    uint256 public maxNftPurchase;
    uint256 public totalStaked;

    string private baseURI;
    string private notRevealedURI;
    string private baseExtension;

    uint256 private rewardsPerBlock;

    bool public revealed;
    bool public stacking;
    bool public canChangeBaseURI;
    bool public canChangeNotRevealURI;

    struct Staking {
        uint256 nftId;
        uint256 stakingStartTime;
        address owner;
    }

    mapping(address => uint256) public nftsPerWallet;
    mapping(uint256 => Staking) public nftsStaked;

    event Staked(address indexed owner, uint tokenId, uint value);
    event Unstaked(address indexed owner, uint tokenId, uint value);
    event Claimed(address indexed owner, uint amount);

    function initialize(string memory _name, string memory _symbol, HybridToken _hybridToken) initializerERC721A initializer public {
        __ERC721A_init(_name, _symbol);
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        hybridToken = _hybridToken;
        rewardsPerBlock = 150;
        sellingStep = Steps.NotStarted;
        MAX_SUPPLY_NFT = 50000;
        publicSaleNftPrice = 25000000000000000;
        whitelistSaleNftPrice = 20000000000000000;
        maxNftPurchase = 3;
        revealed = false;
        stacking = false;
        canChangeBaseURI = true;
        canChangeNotRevealURI = true;
    }

    function _baseURI() internal view  virtual override returns (string memory) {
        return baseURI;
    }

    function publicMintNft(uint256 _ammount) external payable nonReentrant whenNotPaused {
        uint256 numberNftSold = totalSupply();

        require(totalSupply() < MAX_SUPPLY_NFT, "Sorry, no nfts left.");
        require(sellingStep == Steps.PublicSale, "Sale has not started yet.");
        require(nftsPerWallet[msg.sender] <= maxNftPurchase, "You can't mint more than X nfts");
        require(numberNftSold + _ammount <= MAX_SUPPLY_NFT, "Sale is almost done and we don't have enought NFTs left.");
        require(msg.value >= publicSaleNftPrice * _ammount, "You don't have enough funds.");

        if(numberNftSold + _ammount == MAX_SUPPLY_NFT) {
            sellingStep = Steps.SoldOut;
        }

        _safeMint(msg.sender, _ammount);
        
        for(uint256 i = 1 ; i <= _ammount ; i++) {
            nftsPerWallet[msg.sender]++;
        }
    }

    function whitelistMintNft(uint256 _ammount, bytes calldata signature) public payable nonReentrant whenNotPaused {
        uint256 numberNftSold = totalSupply();

        require(totalSupply() < MAX_SUPPLY_NFT, "Sorry, no nfts left.");
        require(sellingStep == Steps.WhitelistedSale, "WhitelistedSale has not started yet.");
        require(nftsPerWallet[msg.sender] <= maxNftPurchase, "You can't mint more than X nfts");
        require(numberNftSold + _ammount <= MAX_SUPPLY_NFT, "Sale is almost done and we don't have enought NFTs left.");
        require(msg.value >= whitelistSaleNftPrice * _ammount, "You don't have enough funds.");

        require(owner() == keccak256(
            abi.encodePacked(
                address(this),
                msg.sender
            )
        ).toEthSignedMessageHash().recover(signature), "Signer address mismatch.");

        _safeMint(msg.sender, _ammount);

        for(uint256 i = 1 ; i <= _ammount ; i++) {
            nftsPerWallet[msg.sender]++;
        }
    }

    function airdropNfts(address _recipient,uint256 _mintAmount) public payable onlyOwner whenNotPaused {
        uint256 supply = totalSupply();
        require(_mintAmount > 0, "Need to mint at least 1 NFT");
        require(supply + _mintAmount <= MAX_SUPPLY_NFT, "Max NFT limit");
        _safeMint(_recipient, _mintAmount);
        for (uint256 i = 1; i <= _mintAmount; i++) {
            nftsPerWallet[_recipient]++;
        }
    }

    function burnNft(uint256 _tokenId) external whenNotPaused {
        _burn(_tokenId);
    }

    function stake(uint256[] calldata nftIds) external {
        uint256 nftId;
        totalStaked += nftIds.length;

        for(uint256 i = 0; i < nftIds.length; i++) {
            nftId = nftIds[i];
            require(ownerOf(nftId) == msg.sender, "Not the owner");
            require(nftsStaked[nftId].stakingStartTime == 0, "Already Staked");

            transferFrom(msg.sender, address(this), nftId);

            nftsStaked[nftId] = Staking({
                nftId: nftId,
                stakingStartTime: block.timestamp,
                owner: msg.sender
            });
        }
    }

    function _unstakeMany(address owner, uint [] calldata nftIds) internal {
        uint nftId;
        totalStaked -= nftIds.length;

        for(uint i = 0 ; i < nftIds.length ; i++) {
            nftId = nftIds[i];
            require(nftsStaked[nftId].owner == msg.sender, "not owner");

            emit Unstaked(owner, nftId, block.timestamp);
            delete nftsStaked[nftId];

            transferFrom(address(this), owner, nftId);
        }
    }
    function claim(uint[] calldata nftIds) external {
        _claim(msg.sender, nftIds, false);
    }

    function unstake(uint[] calldata nftIds) external {
        _claim(msg.sender, nftIds, true);
    }

    function _claim(address owner, uint[] calldata nftIds, bool _unstake) internal {
        uint nftId;
        uint earned;
        uint totalEarned;

        for(uint i = 0 ; i < nftIds.length ; i++) {
            nftId = nftIds[i];
            Staking memory thisStake = nftsStaked[nftId];
            require(thisStake.owner == owner, "not owner cant claim reward");

            uint stakingStartTime = thisStake.stakingStartTime;
            //10k jeton /h /NFT
            earned = (block.timestamp - stakingStartTime) * rewardsPerBlock / 3600;
            totalEarned += earned;

            nftsStaked[nftId] = Staking({
                nftId: uint24(nftId),
                stakingStartTime: uint48(block.timestamp),
                owner: owner
            });
        }

        if(totalEarned > 0) {
            hybridToken.mint(owner, nftId, totalEarned, "");
        }
        if(_unstake) {
            _unstakeMany(owner, nftIds);
        }
        emit Claimed(owner, totalEarned);
    }

    function getRewardAmount(address owner, uint[] calldata nftIds) external view returns(uint) {
        uint nftId;
        uint earned;
        uint totalEarned;

        for(uint i = 0 ; i < nftIds.length ; i++) {
            nftId = nftIds[i];
            Staking memory thisStake = nftsStaked[nftId];
            require(thisStake.owner == owner, "not owner cant claim reward");

            uint stakingStartTime = thisStake.stakingStartTime;

            earned = (block.timestamp - stakingStartTime) * rewardsPerBlock / 3600;
            totalEarned += earned;
        }
        return totalEarned;
    }

    function tokenStakedByOwner(address owner) external view returns(uint[] memory) {
        uint totalSupply = totalSupply();
        uint[] memory tmp = new uint[](totalSupply);
        uint index = 0;

        for(uint i = 0 ; i < totalSupply ; i++) {
            if(nftsStaked[i].owner == owner) {
                tmp[index] = i;
                index++;
            }
        }
        
        uint[] memory tokens = new uint[](index);
        for(uint i = 0 ; i < index ; i++) {
            tokens[i] = tmp[i];
        }
        return tokens;
    }

    function changePublicSaleNftPrice(uint256 _publicSaleNftPrice) external onlyOwner {
        publicSaleNftPrice = _publicSaleNftPrice;
    }

    function changeWhitelisteSaleNftPrice(uint256 _whitelistSaleNftPrice) external onlyOwner {
        whitelistSaleNftPrice = _whitelistSaleNftPrice;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        require(canChangeBaseURI == true, "You can change the uri only once");
        baseURI = _newBaseURI;
        canChangeBaseURI = false;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        require(canChangeNotRevealURI == true, "You can change the uri only once");
        notRevealedURI = _notRevealedURI;
        canChangeNotRevealURI = false;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if(revealed == false) {
            return bytes(notRevealedURI).length > 0
            ? string(abi.encodePacked(notRevealedURI, tokenId.toString(),".json"))
            : "";
        }

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(),".json"))
            : "";
    }

    function launchPublicSale() external onlyOwner whenNotPaused {
        sellingStep = Steps.PublicSale;
    }

    function launchWhitelistedSale() external onlyOwner whenNotPaused {
        sellingStep = Steps.WhitelistedSale;
    }

    function reveal() external onlyOwner whenNotPaused {
        sellingStep = Steps.Reveal;
        revealed = true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function isRevealed() public view returns (bool){
        return revealed;
    }

    function getPublicSaleNftPrice() public view returns (uint256) {
        return publicSaleNftPrice;
    }

    function getWhitelistSaleNftPrice() public view returns (uint256) {
        return whitelistSaleNftPrice;
    }

    function getInitialTotalSupply() public view returns (uint256) {
        return MAX_SUPPLY_NFT;
    }

    function getSignerRecovery(bytes calldata signature) external view returns (address) {
        return keccak256(
            abi.encodePacked(
                address(this),
                msg.sender
            )
        ).toEthSignedMessageHash().recover(signature);
    }

}