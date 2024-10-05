//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {console} from "forge-std/console.sol";

/// custom errors
error NotAuthorizedToMint(address _address, bool _isWhitelisted);
error NotEnoughMintAmount(address _address, uint256 _amount);
error NotProperMIntingWindow(uint256 _expectedStatus, uint256 _currentStatus);
error MoreThanAllotedAddress();
error MintLimitExceeding();
error NotEnoughContractBalance(uint256 _contractBalance, uint256 _amount);
error TransactionFailed();

/// @title A basic nft contract
/// @author Sudip ROy
/// @notice It is very basic and is not intented to be used on the mainnet or with any mainnet currency
/// @custom:experimental This is an experimental contract
contract RandomNft is ERC721, AccessControl, ERC721Pausable {
    enum MintingStatus {
        whitelistmint,
        publicmint,
        revealed
    }

    /// constants
    uint256 public constant COLLECTION_SIZE = 19;
    uint256 public constant WHITELIST_SIZE = 5;
    uint256 public constant PUBLIC_MINT_LIMIT_PER_ADDRESS = 2;
    uint256 public constant MINT_AMOUNT = 0.001 ether;
    bytes32 public constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    /// state variables
    string private s_baseURI;
    string private s_unrevealedURI;
    uint256 private s_tokenID;
    uint8 private s_numberOfWhitelistedAccounts;
    MintingStatus private s_currentMintingStatus;
    mapping(address => uint256) s_mintCountPerAddress;
    mapping(address => bool) private s_isWhitelisted;
    mapping(address => mapping(uint256 => bool)) private s_addressToTokenID;

    /// Events
    event MintingStatusChanged(MintingStatus indexed _status);
    event TokenMinted(uint256 indexed _tokenId, address indexed _minter);
    event FundWithdrawn(uint256 indexed _amount, address indexed _withdrawnBy);

    /// Initializing the contract with token name, symbol, MINT_ADMIN_ROLE and unrevealed uri of the collection
    constructor(string memory _name, string memory _symbol, address _mintAdmin, string memory _unrevealedURI)
        ERC721(_name, _symbol)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINT_ADMIN_ROLE, _mintAdmin);
        s_unrevealedURI = _unrevealedURI;
        _pause();
    }

    /// function to set the base uri, preferably after the mint is over.
    function setBaseURI(string memory baseURI) external onlyRole(MINT_ADMIN_ROLE) {
        s_baseURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return s_baseURI;
    }

    function pause() external onlyRole(MINT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    function unpause() external onlyRole(MINT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    /// function to update the mint status.
    function setMintStatus(MintingStatus _status) external onlyRole(MINT_ADMIN_ROLE) {
        s_currentMintingStatus = _status;
        emit MintingStatusChanged({_status: _status});
    }

    /// an array of addresses to be passed
    /// check is there to see number of whitelist addresses do not get exceeded
    function addToWhitelist(address[] calldata _whitelistAddresses) external onlyRole(MINT_ADMIN_ROLE) {
        if ((_whitelistAddresses.length + s_numberOfWhitelistedAccounts) > WHITELIST_SIZE) {
            revert MoreThanAllotedAddress();
        }
        for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
            s_isWhitelisted[_whitelistAddresses[i]] = true;
            s_numberOfWhitelistedAccounts++;
        }
    }

    /// checks are there for minting status, caller address is whitelisted and sent ether is valid
    /// changing whitelist status of the msg.sender to false before the minting process
    function whitelistMint() external payable whenNotPaused {
        if (s_currentMintingStatus != MintingStatus.whitelistmint) {
            revert NotProperMIntingWindow({
                _expectedStatus: uint256(MintingStatus.whitelistmint),
                _currentStatus: uint256(s_currentMintingStatus)
            });
        }
        if (!s_isWhitelisted[msg.sender]) {
            revert NotAuthorizedToMint({_address: msg.sender, _isWhitelisted: false});
        }
        if (msg.value < MINT_AMOUNT) {
            revert NotEnoughMintAmount({_address: msg.sender, _amount: msg.value});
        }

        s_isWhitelisted[msg.sender] = false;
        s_tokenID++;
        s_addressToTokenID[msg.sender][s_tokenID] = true;
        s_mintCountPerAddress[msg.sender] += 1;
        _safeMint(msg.sender, s_tokenID);
        emit TokenMinted({_tokenId: s_tokenID, _minter: msg.sender});
    }

    /// checks are there for minting status, public mint limit crossing and sent ether is valid
    /// incrementing minted token amount of the msg.sender before the minting process
    function publicMint() external payable whenNotPaused {
        if (s_currentMintingStatus != MintingStatus.publicmint) {
            revert NotProperMIntingWindow({
                _expectedStatus: uint256(MintingStatus.publicmint),
                _currentStatus: uint256(s_currentMintingStatus)
            });
        }
        if (msg.value < MINT_AMOUNT) {
            revert NotEnoughMintAmount({_address: msg.sender, _amount: msg.value});
        }
        if (s_mintCountPerAddress[msg.sender] >= PUBLIC_MINT_LIMIT_PER_ADDRESS) {
            revert MintLimitExceeding();
        }

        s_tokenID++;
        s_addressToTokenID[msg.sender][s_tokenID] = true;
        s_mintCountPerAddress[msg.sender] += 1;
        if (s_tokenID == COLLECTION_SIZE) {
            _pause();
        }
        _safeMint(msg.sender, s_tokenID);
        emit TokenMinted({_tokenId: s_tokenID, _minter: msg.sender});
    }

    /// tokenURI function overridden to check the status and serve the uri accordingly
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        if (s_currentMintingStatus != MintingStatus.revealed) {
            return s_unrevealedURI;
        }
        return super.tokenURI(_tokenId);
    }

    function withdraw(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_amount > address(this).balance) {
            revert NotEnoughContractBalance({_contractBalance: address(this).balance, _amount: _amount});
        }
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert TransactionFailed();
        }
        emit FundWithdrawn({_amount: _amount, _withdrawnBy: msg.sender});
    }

    function getBaseUri() external view returns (string memory) {
        if (s_currentMintingStatus != MintingStatus.revealed) {
            return s_unrevealedURI;
        }
        return s_baseURI;
    }

    function getCurrentStatus() external view returns (MintingStatus) {
        return s_currentMintingStatus;
    }

    function isAddressWhitelisted(address _address) external view returns (bool) {
        return s_isWhitelisted[_address];
    }

    function checkIfTokenMintedByAddress(address _address, uint256 _tokenID) external view returns (bool) {
        return s_addressToTokenID[_address][_tokenID];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
}
