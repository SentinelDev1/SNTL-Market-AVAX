// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DeployEscrow is ReentrancyGuard {
    address immutable public Owner;
    address public Keeper;
    address public FeeAddress;

    bool public AllowPurchases = true;
    
    mapping(address => address) public Escrows;
    mapping(address => address) public EscrowsToOwners;
    mapping(address => address) public ListingsToOwners;
    
    address[] public EscrowOwnerArray;
    address[] public ListingArray;
    
    event DeployedEscrow(address indexed Escrow, address indexed EscrowOwner);
    
    receive() external payable {}
    
    fallback() external payable {}
    
    // Owner is the team's Gnosis Safe multisig address with 2/3 confirmations needed to transact, Keeper and FeeAddress can be changed by Owner
    constructor () {
        Owner = 0x4B950FF682534Ba1547bd72D11562F43d11f613D;
        Keeper = 0x26DcbdA37FC1D8abF1FF016947a11Ef972dCb306;
        FeeAddress = 0xc7a5e5E3e2aba9aAa5a4bbe33aAc7ee2b2AA7bE4;
    }
    modifier OnlyOwner() {
        require(msg.sender == Owner, "This function can only be run by the contract owner");
        _;
    }

    modifier OnlyEscrows() {
        require(EscrowsToOwners[msg.sender] != address(0), "This function can only be run by escrow accounts");
        _;
    }

    // Deploy Escrow account for user
    function Deploy() external nonReentrant returns (address Address) {
        address payable _EscrowOwner = payable(msg.sender);
        require(Escrows[msg.sender] == address(0), "Can only have 1 Escrow at a time, close other Escrow before creating new one!");
        GMXEscrow NewEscrow = new GMXEscrow(_EscrowOwner);
        Address = address(NewEscrow);
        require(Address != address(0), "Deploy Escrow failed!");
        emit DeployedEscrow(Address, _EscrowOwner);
        Escrows[_EscrowOwner] = Address;
        EscrowsToOwners[Address] = _EscrowOwner;
        EscrowOwnerArray.push(_EscrowOwner);
    }
    
    // Deploy buyer Escrow account during offer/purchase
    function DeployBuyerEscrow(address payable _BuyerAddress) external OnlyEscrows nonReentrant returns (address EscrowAddress) {
        require(Escrows[_BuyerAddress] == address(0), "Buyer already has an escrow account!");
        GMXEscrow NewEscrow = new GMXEscrow(_BuyerAddress);
        EscrowAddress = address(NewEscrow);
        require(EscrowAddress != address(0), "Deploy Escrow failed!");
        emit DeployedEscrow(EscrowAddress, _BuyerAddress);
        Escrows[_BuyerAddress] = EscrowAddress;
        EscrowsToOwners[EscrowAddress] = _BuyerAddress;
        EscrowOwnerArray.push(_BuyerAddress);
    }

    // Gets list of Escrow accounts currently for sale
    function GetListings(uint256 _Limit, uint256 _Offset) external view returns (address[] memory) {
        uint256 LimitPlusOffset = _Limit + _Offset;
        require(_Limit <= ListingArray.length, "Please ensure Limit is less than or equal to the ListingArray current length");
        require(_Offset < ListingArray.length, "Please ensure Offset is less than the ListingArray current length");
        uint256 n = 0;
        address[] memory Listings = new address[](_Limit);
        if (LimitPlusOffset > ListingArray.length) {
            LimitPlusOffset = ListingArray.length;
        }
        for (uint256 i = _Offset; i < LimitPlusOffset; i++) {
            address ListingAddress = ListingArray[i];
            Listings[n] = ListingAddress;
            n++;
        }
        return Listings;
    }

    // Gets the number of listings in the ListingsArray
    function GetNumberOfListings() external view returns (uint256) {
        return ListingArray.length;
    }

    // Cleans up array/mappings related to buyer and seller Escrow accounts when closed
    function ResetCloseEscrow(address _Address) external OnlyEscrows nonReentrant {
        uint256 Index = IndexOfEscrowOwnerArray(_Address);
        delete Escrows[_Address];
        delete EscrowsToOwners[msg.sender];
        EscrowOwnerArray[Index] = EscrowOwnerArray[EscrowOwnerArray.length - 1];
        EscrowOwnerArray.pop();
    }

    // Cleans up array/mappings related listings when ended
    function DeleteListing(address _Address) external OnlyEscrows nonReentrant {
        uint256 Index = IndexOfListingArray(_Address);
        delete ListingsToOwners[msg.sender];
        ListingArray[Index] = ListingArray[ListingArray.length - 1];
        ListingArray.pop();
    }

    // Sets ListingsToOwners mapping
    function SetListingsToOwners(address _Address) external OnlyEscrows nonReentrant {
        ListingsToOwners[msg.sender] = _Address;
    }

    // Push new Listing in ListingArray
    function PushListing() external OnlyEscrows nonReentrant {
        ListingArray.push(msg.sender);
    }

    // Delete any expired listings from ListingsArray and ListingsToOwners
    function CleanListings() external nonReentrant {
        require(msg.sender == Keeper, "Only the Keeper can run this function");
        for (uint256 i = 0; i < ListingArray.length; i++) {
            if (GMXEscrow(payable(ListingArray[i])).EndAt() <= block.timestamp) {
                delete ListingsToOwners[ListingArray[i]];
                ListingArray[i] = ListingArray[ListingArray.length - 1];
                ListingArray.pop();
            }
        }
    }

    // Checks if any listings are expired, if any are expired returns true if not returns false
    function CheckForExpired() external view returns (bool) {
        for (uint256 i = 0; i < ListingArray.length; i++) {
            if (GMXEscrow(payable(ListingArray[i])).EndAt() <= block.timestamp) {
                return true;
            }
        }
        return false;
    }

    // Sets the keeper address
    function SetKeeper(address _Address) external OnlyOwner nonReentrant {
        Keeper = _Address;
    }

    // Sets the keeper address
    function SetFeeAddress(address _Address) external OnlyOwner nonReentrant {
        FeeAddress = _Address;
    }

    // Sets whAVAXer or not sales can be completed in the marketplace (for turning off in case of end of life)
    function SetAllowPurchases(bool _Bool) external OnlyOwner nonReentrant {
        AllowPurchases = _Bool;
    }
    
    // Withdraw all AVAX from this contract
    function WithdrawAVAX() external payable OnlyOwner nonReentrant {
        require(address(this).balance > 0, "No AVAX to withdraw");
        (bool sent, ) = Owner.call{value: address(this).balance}("");
        require(sent);
    }
    
    // Withdraw any ERC20 token from this contract
    function WithdrawToken(address _tokenaddress, uint256 _Amount) external OnlyOwner nonReentrant {
        IERC20(_tokenaddress).transfer(Owner, _Amount);
    }
    
    // Private function for internal use
    function IndexOfEscrowOwnerArray(address _Target) private view returns (uint256) {
        for (uint256 i = 0; i < EscrowOwnerArray.length; i++) {
            if (EscrowOwnerArray[i] == _Target) {
                return i;
            }
        }
        revert("Not found");
    }

    // Private function for internal use
    function IndexOfListingArray(address _Target) private view returns (uint256) {
        for (uint256 i = 0; i < ListingArray.length; i++) {
            if (ListingArray[i] == _Target) {
                return i;
            }
        }
        revert("Not found");
    }
}

contract GMXEscrow is ReentrancyGuard {
    address immutable public Owner;
    
    DeployEscrow immutable MasterContract;
    GMXEscrow EscrowContract;
    
    address payable immutable public EscrowOwner;
    
    address constant private GMXEligible = 0x16288A694EbBfaaD7996141084755086fE72B187;
    address constant private EsGMX = 0xFf1489227BbAAC61a9209A08929E4c2a526DdD17;
    address constant private WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address constant private GMX = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address constant private GMXRewardRouter = 0x82147C5A7E850eA4E28155DF107F2590fD4ba327;
    address constant private stakedGmxTracker = 0x2bD10f8E93B3669b6d42E74eEedC65dd1B0a1342;
    address constant private bonusGmxTracker = 0x908C4D94D34924765f1eDc22A1DD098397c59dD4;
    address constant private feeGmxTracker = 0x4d268a7d4C16ceB5a606c173Bd974984343fea13;
    address constant private gmxVester = 0x472361d3cA5F49c8E633FB50385BfaD1e018b445;
    address constant private stakedGlpTracker = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
    address constant private feeGlpTracker = 0xd2D1162512F927a7e282Ef43a362659E4F2a728F;
    address constant private glpVester = 0x62331A7Bd1dfB3A7642B7db50B5509E57CA3154A;
    
    ILBRouter constant router = ILBRouter(0xE3Ffc583dC176575eEA7FD9dF2A7c65F7E23f4C3);
    address GMXRewardContract = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;
    address tokenIn = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address tokenOut = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    
    uint256 constant private MaxApproveValue = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    
    uint256 public SalePrice = 0;
    uint256 public EndAt;
    
    bool public SaleIneligible = false;
    bool public IsSold = false;
    bool public IsPurchased = false;
    bool public IsActive = true;
    
    event Listed(address indexed Lister);
    event Purchased(address indexed Purchaser, address indexed Lister);
    
    constructor (address payable _EscrowOwner) {
        Owner = msg.sender;
        MasterContract = DeployEscrow(payable(Owner));
        EscrowOwner = payable(_EscrowOwner);
    }  
    modifier OnlyEscrowOwner() {
        require(msg.sender == EscrowOwner);
        _;
    }
    modifier OnlyOwner() {
        require(msg.sender == Owner);
        _;
    }

    modifier ClosedEscrow() {
        require(IsActive, "This Escrow account is closed, only WithdraWAVAX() and WithdrawToken() still function");
        _;
    }
    
    receive() external payable {}
    
    fallback() external payable {}
    
    // Compound Escrow account and claim rewards for Escrow Owner (choice of receiving as AVAX (true) or WAVAX (false)
    function CompoundAndClaim() external payable nonReentrant ClosedEscrow OnlyEscrowOwner {
        IGMXRewardRouter(GMXRewardRouter).handleRewards(
            false,
            false,
            true,
            true,
            true,
            true,
            true
        );
        (bool sent, ) = EscrowOwner.call{value: address(this).balance}("");
        require(sent);
    }
    
    // Transfer GMX account out of Escrow to _Receiver
    function TransferOut(address _Receiver) external nonReentrant ClosedEscrow OnlyEscrowOwner {
        IERC20(GMX).approve(stakedGmxTracker, MaxApproveValue);
        IGMXRewardRouter(GMXRewardRouter).signalTransfer(_Receiver);
        if (MasterContract.ListingsToOwners(address(this)) != address(0)) {
            IGMXDeployEscrow(Owner).DeleteListing(address(this));
        }
        SalePrice = 0;
        SaleIneligible = true;
        EndAt = block.timestamp;
    }
    
    // Transfer GMX account out of Escrow to Escrow Owner
    function TransferOutEscrowOwner() external nonReentrant ClosedEscrow {
        require((MasterContract.EscrowsToOwners(msg.sender)) != address(0));
        IERC20(GMX).approve(stakedGmxTracker, MaxApproveValue);
        IGMXRewardRouter(GMXRewardRouter).signalTransfer(EscrowOwner);
        SalePrice = 0;
        SaleIneligible = true;
        EndAt = block.timestamp;
    }
    
    // Transfer GMX account in to Escrow
    function TransferIn() public nonReentrant ClosedEscrow {
        IGMXRewardRouter(GMXRewardRouter).acceptTransfer(msg.sender);
    }
    
    // Transfer GMX account in to Escrow private function
    function TransferInPrivate() private {
        IGMXRewardRouter(GMXRewardRouter).acceptTransfer(msg.sender);
    }

    // Set Escrow GMX account for sale
    function SetForSale(uint256 _SalePrice, uint8 _Length) external nonReentrant ClosedEscrow OnlyEscrowOwner {
        bool Eligible = IGMXEligible(GMXEligible).TransferEligible(address(this));
        if (Eligible) {
            IERC20(GMX).approve(stakedGmxTracker, MaxApproveValue);
            TransferInPrivate();
        }
        require(SaleIneligible == false, "Escrow not eligible for sale");
        require(SalePrice == 0 || block.timestamp >= EndAt, "Already Listed");
        require(IERC20(feeGmxTracker).balanceOf(address(this)) != 0 || IERC20(stakedGlpTracker).balanceOf(address(this)) != 0, "Escrow Account Can't be empty when listing for sale");
        require(_SalePrice > 0, "Choose a price greater than 0");
        require(_Length <= 30, "Max sale length = 30 days");
        IsPurchased = false;
        SalePrice = _SalePrice;
        EndAt = block.timestamp + _Length * 1 days;
        if (MasterContract.ListingsToOwners(address(this)) == address(0)) {
            MasterContract.SetListingsToOwners(EscrowOwner);
            MasterContract.PushListing();
        }
        emit Listed(address(this));
    }
    
    // Change price for Escrow
    function ChangePrice(uint256 _NewPrice) external nonReentrant ClosedEscrow OnlyEscrowOwner {
        require(SalePrice > 0, "Not currently for sale");
        require(block.timestamp < EndAt, "Listing is expired");
        SalePrice = _NewPrice;
    }
    
    // Make GMX account in Escrow no longer for sale (but potentially still accepting offers)
    function EndEarly() external nonReentrant ClosedEscrow OnlyEscrowOwner {
        require(SalePrice > 0, "Not currently for sale");
        require(block.timestamp < EndAt, "Already Expired");
        SalePrice = 0;
        EndAt = block.timestamp;
        IGMXDeployEscrow(Owner).DeleteListing(address(this));
    }
    
    // Allow buyer to make purchase at sellers list price (if Escrow is listed)
    function MakePurchase(bool _StartTransferOut, bool _PayInAVAX, uint256 _PoolFee) external payable nonReentrant ClosedEscrow {
        address Receiver = (MasterContract.Escrows(msg.sender));
        require(MasterContract.AllowPurchases(), "Purchase transactions are turned off for this contract!");
        require(SaleIneligible == false, "Escrow not eligible for sale");
        require(SalePrice > 0, "Not For Sale");
        require(block.timestamp < EndAt, "Ended/Not Available");
        if (_PayInAVAX) {
            AVAXGMX(SalePrice, _PoolFee);
        }
        require(IERC20(GMX).balanceOf(msg.sender) >= SalePrice, "Insufficient Funds");
        require(IERC20(GMX).allowance(msg.sender, address(this)) >= SalePrice, "Please approve this contract to use your GMX");
        if (Receiver == address(0)) {
            Receiver = IGMXDeployEscrow(Owner).DeployBuyerEscrow(msg.sender);
        }
        uint256 Payout = 39 * SalePrice / 40;
        uint256 Fees = SalePrice - Payout;
        IGMXRewardRouter(GMXRewardRouter).handleRewards(
            false,
            false,
            false,
            false,
            false,
            true,
            true
        );
        (bool sent, ) = EscrowOwner.call{value: address(this).balance}("");
        require(sent);
        IERC20(GMX).transferFrom(msg.sender, EscrowOwner, Payout);
        IERC20(GMX).transferFrom(msg.sender, MasterContract.FeeAddress(), Fees);
        IGMXRewardRouter(GMXRewardRouter).signalTransfer(Receiver);
        IERC20(GMX).approve(stakedGmxTracker, MaxApproveValue);
        IGMXEscrow(Receiver).TransferIn();
        if (_StartTransferOut) {
            bool Eligible = IGMXEligible(GMXEligible).TransferEligible(msg.sender);
            require(Eligible, "Please purchase using an account that has never staked GMX/esGMX or held GLP");
            IGMXEscrow(Receiver).TransferOutEscrowOwner();
        }
        EndAt = block.timestamp;
        SalePrice = 0;
        IGMXEscrow(Receiver).SetIsPurchased();
        IsSold = true;
        IGMXDeployEscrow(Owner).DeleteListing(address(this));
        emit Purchased(Receiver, address(this));
    }
    
    // Close Escrow once empty
    function CloseEscrow() external nonReentrant ClosedEscrow OnlyEscrowOwner {
    	require(IERC20(GMX).balanceOf(address(this)) == 0, "Please Remove GMX");
        require(IERC20(WAVAX).balanceOf(address(this)) == 0, "Please Remove WAVAX");
        require(IERC20(stakedGlpTracker).balanceOf(address(this)) == 0, "Please Remove GLP");
        require(IERC20(feeGmxTracker).balanceOf(address(this)) == 0, "Please Remove staked GMX and/or bonus points");
        IGMXDeployEscrow(Owner).ResetCloseEscrow(EscrowOwner);
        IsActive = false;
    }
    
    // Withdraw all AVAX from this contract
    function WithdrawAVAX() external payable nonReentrant OnlyEscrowOwner {
        require(address(this).balance > 0, "No AVAX to withdraw");
        (bool sent, ) = EscrowOwner.call{value: address(this).balance}("");
        require(sent);
    }
    
    // Withdraw any ERC20 token from this contract
    function WithdrawToken(address _tokenaddress, uint256 _Amount) external nonReentrant OnlyEscrowOwner {
        IERC20(_tokenaddress).transfer(EscrowOwner, _Amount);
    }
    
    // Allow purchasing Escrow account to set selling Escrow account "IsPurchased" to true during purchase
    function SetIsPurchased() external nonReentrant ClosedEscrow {
        require(MasterContract.EscrowsToOwners(msg.sender) != address(0));
        IsPurchased = true;
    }

    // Internal function for buying with AVAX
    function AVAXGMX(uint256 amountOut, uint256 _pairBinSteps) private {
        uint256[] memory pairBinSteps = new uint256[](1);
        pairBinSteps[0] = _pairBinSteps;
        IERC20[] memory tokenPath = new IERC20[](2);
        tokenPath[0] = IERC20(WAVAX);
        tokenPath[1] = IERC20(GMX);
        router.swapAVAXForExactTokens{ value: msg.value }(
            amountOut,
            pairBinSteps,
            tokenPath,
            msg.sender,
            block.timestamp
        );
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IGMXRewardRouter {
    function stakeGmx(uint256 _amount) external;
    function stakeEsGmx(uint256 _amount) external;
    function unstakeGmx(uint256 _amount) external;
    function unstakeEsGmx(uint256 _amount) external;
    function claim() external;
    function claimEsGmx() external;
    function claimFees() external;
    function compound() external;
    function handleRewards(
        bool _shouldClaimGmx,
        bool _shouldStakeGmx,
        bool _shouldClaimEsGmx,
        bool _shouldStakeEsGmx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWAVAX,
        bool _shouldConvertWAVAXToAVAX
    ) external;
    function signalTransfer(address _receiver) external;
    function acceptTransfer(address _sender) external;
}

interface IWAVAX is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
}

interface IPriceConsumerV3 {
    function getLatestPrice() external view;
}

interface IGMXEscrow {
    function TransferOutEscrowOwner() external;
    function TransferIn() external;
    function SetIsPurchased() external;
}

interface IGMXDeployEscrow {
    function DeployBuyerEscrow(address _Address) external returns (address addr);
    function ResetCloseEscrow(address _address) external;
    function DeleteListing(address _address) external;
    function SetListingsToOwners(address _Address) external;
}

interface IGMXEligible {
    function TransferEligible(address _receiver) external view returns (bool Eligible);
}

interface IPeripheryPayments {
    function refundAVAX() external payable;
}

interface ILBRouter {
    function swapAVAXForExactTokens(
        uint256 amountOut,
        uint256[] memory pairBinSteps,
        IERC20[] memory tokenPath,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amountsIn);
}
