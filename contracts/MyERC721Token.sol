pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721TokenReceiver.sol";

contract MyERC721Token is IERC721 {
    string private name = "MyERC721";
    string private symbol = "MET";
    address contractOwner;

    //// @dev allow actions only when this is false
    bool public paused;

    //// @dev token id to owner address
    mapping(uint256 => address) internal idToOwner;

    //// @dev token id to approved address
    mapping(uint256 => address) internal idToApproval;

    //// @dev owner to total number of tokens owned
    mapping(address => uint256) private ownerToNFTokenCount;

    //// @dev owner to operator approvals
    mapping(address => mapping(address => bool)) internal ownerToOperators;

    constructor() {
        contractOwner = msg.sender;
        paused = false;
    }

    /**
        @dev transfer ownership of a token 
        @param _from current owner of NFT
        @param _to new owner
        @param _tokenId NFT's unique tokenId
        @param _data additional data
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    ) external override whenNotPaused {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }

    /**
        @dev overload of above function with _data set to ""
        @param _from current owner of NFT
        @param _to new owner
        @param _tokenId NFT's unique tokenId
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override whenNotPaused {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }

    /**
        @dev transfer ownership of token
        @param _from current owner of NFT
        @param _to new owner
        @param _tokenId NFT's unique tokenId
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
        external
        override
        canTransfer(_tokenId)
        validNFToken(_tokenId)
        whenNotPaused
    {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == _from, "Not an Owner");
        require(_to != address(0), "Address is zero");

        _transfer(_to, _tokenId);
    }

    /**
        @dev add external approver to a tokenId
        @param _approved address to be approved for
        @param _tokenId ID of token to be approved
     */
    function approve(address _approved, uint256 _tokenId)
        external
        override
        canOperate(_tokenId)
        validNFToken(_tokenId)
        whenNotPaused
    {
        address tokenOwner = idToOwner[_tokenId];
        require(_approved != tokenOwner, "Is Owner");

        idToApproval[_tokenId] = _approved;
        emit Approval(tokenOwner, _approved, _tokenId);
    }

    /**
        @dev add external approver for all of msg.senders tokens
        @param _operator address to be approved for
        @param _approved true to approve, false to revoke approval
     */
    function setApprovalForAll(address _operator, bool _approved)
        external
        override
        whenNotPaused
    {
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
        @dev returns number of tokens owned by _owner
        @param _owner for which this query is made
     */
    function balanceOf(address _owner)
        external
        view
        override
        whenNotPaused
        returns (uint256)
    {
        require(_owner != address(0), "Address is zero");
        return _getOwnerNFTCount(_owner);
    }

    /**
        @dev returns the owner of _tokenId
     */
    function ownerOf(uint256 _tokenId)
        external
        view
        override
        whenNotPaused
        returns (address _owner)
    {
        _owner = idToOwner[_tokenId];
        require(_owner != address(0), "Not valid NFTToken");
    }

    /**
        @dev get approved address for _toeknId
     */
    function getApproved(uint256 _tokenId)
        external
        view
        override
        validNFToken(_tokenId)
        returns (address)
    {
        return idToApproval[_tokenId];
    }

    /**
        @dev check if _operator is an approved operator for _owner
     */
    function isApprovedForAll(address _owner, address _operator)
        external
        view
        override
        returns (bool)
    {
        return ownerToOperators[_owner][_operator];
    }

    function _transfer(address _to, uint256 _tokenId)
        internal
        virtual
        whenNotPaused
    {
        address from = idToOwner[_tokenId];
        _clearApproval(_tokenId);

        _removeNFToken(from, _tokenId);
        _addNFToken(_to, _tokenId);

        emit Transfer(from, _to, _tokenId);
    }

    function _mint(address _to, uint256 _tokenId) public virtual whenNotPaused {
        require(msg.sender == contractOwner);
        require(idToOwner[_tokenId] == address(0), "NFT token already exists");

        _addNFToken(_to, _tokenId);

        emit Transfer(address(0), _to, _tokenId);
    }

    function _removeNFToken(address _from, uint256 _tokenId)
        internal
        virtual
        whenNotPaused
    {
        require(idToOwner[_tokenId] == _from, "Not an Owner");
        ownerToNFTokenCount[_from] -= 1;
        delete idToOwner[_tokenId];
    }

    function _addNFToken(address _to, uint256 _tokenId)
        internal
        virtual
        whenNotPaused
    {
        require(idToOwner[_tokenId] == address(0), "NFT token already exists");

        idToOwner[_tokenId] = _to;
        ownerToNFTokenCount[_to] += 1;
    }

    function _getOwnerNFTCount(address _owner)
        internal
        view
        virtual
        returns (uint256)
    {
        return ownerToNFTokenCount[_owner];
    }

    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) private canTransfer(_tokenId) validNFToken(_tokenId) whenNotPaused {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == _from, "Not an Owner");
        require(_to != address(0), "Address is zero");

        _transfer(_to, _tokenId);

        if (isContract(_to)) {
            bytes4 retval = IERC721TokenReceiver(_to).onERC721Received(
                msg.sender,
                _from,
                _tokenId,
                _data
            );
            require(
                retval ==
                    bytes4(
                        keccak256(
                            "onERC721Received(address,address,uint256,bytes)"
                        )
                    ),
                "Unable to receive NFT"
            );
        }
    }

    function _clearApproval(uint256 _tokenId) private whenNotPaused {
        delete idToApproval[_tokenId];
    }

    /**
        @dev allow the owner to pause all actions on this contract
     */
    function pause() public whenNotPaused returns (bool) {
        require(msg.sender == contractOwner, "Not an owner");
        paused = true;
        return true;
    }

    /**
        @dev allow the owner to unpause actions on this contract
     */
    function unpause() public whenPaused returns (bool) {
        require(msg.sender == contractOwner, "Not an owner");
        paused = false;
        return true;
    }

    /**
        @dev Returns whether the target address is a contract
        @param _addr address to check
        @return addressCheck true if _addr is a contract, false if not
    */
    function isContract(address _addr)
        internal
        view
        returns (bool addressCheck)
    {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly {
            codehash := extcodehash(_addr)
        } // solhint-disable-line
        addressCheck = (codehash != 0x0 && codehash != accountHash);
    }

    modifier canOperate(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender ||
                ownerToOperators[tokenOwner][msg.sender],
            "Not a token or operator"
        );
        _;
    }

    modifier canTransfer(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender ||
                idToApproval[_tokenId] == msg.sender ||
                ownerToOperators[tokenOwner][msg.sender],
            "Not owner approved or an operator"
        );
        _;
    }

    modifier validNFToken(uint256 _tokenId) {
        require(idToOwner[_tokenId] != address(0), "Not valid NFTToken");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    modifier whenPaused() {
        require(paused, "Contract is unpaused");
        _;
    }
}
