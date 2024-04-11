// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PayinAVAXorUSDC is ReentrancyGuard {
    address constant private WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address constant private GMX = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address constant private USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant private Owner = 0x4B950FF682534Ba1547bd72D11562F43d11f613D;
    address immutable private FactoryAddress;
    IFactoryContract immutable FactoryContract;
    ILBRouter constant router = ILBRouter(0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30);
    IGMXListingsDataV3 constant GMXListingsDataV3 = IGMXListingsDataV3(0x10C2bb8d3e17D24F55a6E3638EC80Edd5ba5FaaC);

    receive() external payable {}
    
    fallback() external payable {}

    constructor (address _FactoryAddress) {
        FactoryAddress = _FactoryAddress;
        FactoryContract = IFactoryContract(FactoryAddress);
        
    }
    
    modifier OnlyOwner() {
        require(msg.sender == Owner);
        _;
    }

    modifier OnlyEscrows() {
        require(FactoryContract.EscrowsToOwners(msg.sender) != address(0), "This function can only be run by escrow accounts");
        _;
    }

    // Gets list of Escrow accounts currently for sale
    function GetListings(uint256 _Limit, uint256 _Offset) external view returns (address[] memory) {
        uint256 LimitPlusOffset = _Limit + _Offset;
        address[] memory ListingArray = FactoryContract.GetListingArray();
        require(ListingArray.length > 0, "There are currently no listings");
        require(_Limit <= ListingArray.length, "_Limit must be less than or equal to the total number of listings");
        require(_Offset < ListingArray.length, "_Offset must be less the total number of listings");
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
        address[] memory ListingArray = FactoryContract.GetListingArray();
        return ListingArray.length;
    }

    function FeeCalc(address _address, uint256 _price) external view returns (uint256 FeeBP, uint256 Payout, uint256 Fees) {
        IGMXListingsDataV3.GMXAccountData memory GMXAccountDataOut;
        GMXAccountDataOut = GMXListingsDataV3.GetGMXAccountData(_address);
        uint256 PendingMps = GMXAccountDataOut.PendingMPsBal;
        uint256 MPs = GMXAccountDataOut.MPsBal;
        uint256 PendingesGMX = GMXAccountDataOut.PendingesGMXBal;
        uint256 esGMX = GMXAccountDataOut.esGMXBal;
        uint256 StakedesGMX = GMXAccountDataOut.StakedesGMXBal;
        uint256 StakedGMX = GMXAccountDataOut.StakedGMXBal;
        uint256 GLP = GMXAccountDataOut.GLPBal;
        uint256 TotalTokens = PendingMps + MPs + PendingesGMX + esGMX + StakedesGMX + GLP + StakedGMX;
        uint256 TotalTokensexStakedGMX = PendingMps + MPs + PendingesGMX + esGMX + StakedesGMX + GLP;        
        if (((TotalTokensexStakedGMX * FactoryContract.FeeAmount()) / TotalTokens) == 0 && FactoryContract.FeeAmount() != 0) {
            FeeBP = FactoryContract.FeeAmountStakedGMX();
        }
        else if (((StakedGMX * FactoryContract.FeeAmountStakedGMX()) / TotalTokens) == 0 && FactoryContract.FeeAmountStakedGMX() != 0) {
            FeeBP = FactoryContract.FeeAmount();
        }
        else {
            FeeBP = ((TotalTokensexStakedGMX * FactoryContract.FeeAmount()) / TotalTokens) + ((StakedGMX * FactoryContract.FeeAmountStakedGMX()) / TotalTokens);
        }
        Payout = (10000 - FeeBP) * _price / 10000;
        Fees = _price - Payout;
    }

    // Escrow only function for buying with AVAX
    function AVAXGMX(uint256 amountOut, uint256 _pairBinSteps1, uint256 _version1, address _Buyer) external payable nonReentrant OnlyEscrows {
        ILBRouter.Version version1 = ConvertToVersion(_version1);
        uint256[] memory pairBinSteps = new uint256[](1);
        pairBinSteps[0] = _pairBinSteps1;
        IERC20[] memory tokenPath = new IERC20[](2);
        tokenPath[0] = IERC20(WAVAX);
        tokenPath[1] = IERC20(GMX);
        ILBRouter.Version[] memory PoolVersions = new ILBRouter.Version[](1);
        PoolVersions[0] = version1;
        ILBRouter.Path memory SwapPath;
        SwapPath.pairBinSteps = pairBinSteps;
        SwapPath.versions = PoolVersions;
        SwapPath.tokenPath = tokenPath;
        router.swapNATIVEForExactTokens{ value: msg.value }(
            amountOut,
            SwapPath,
            msg.sender,
            block.timestamp + 1
        );
        uint256 CurrentETH = address(this).balance;
        if (CurrentETH > 0) {
            (bool success,) = _Buyer.call{ value: CurrentETH }("");
            require(success, "refund failed");
        } 
    }

    // Escrow only function for buying with AVAX
    function USDCGMX(uint256 amountOut, uint256 amountInMax, uint256 _pairBinSteps1, uint256 _pairBinSteps2, uint256 _version1, uint256 _version2, address _Buyer) external payable nonReentrant OnlyEscrows {
        IERC20(USDC).approve(address(router), amountInMax);
        ILBRouter.Version version1 = ConvertToVersion(_version1);
        ILBRouter.Version version2 = ConvertToVersion(_version2);
        uint256[] memory pairBinSteps = new uint256[](2);
        pairBinSteps[0] = _pairBinSteps1;
        pairBinSteps[1] = _pairBinSteps2;
        IERC20[] memory tokenPath = new IERC20[](3);
        tokenPath[0] = IERC20(USDC);
        tokenPath[1] = IERC20(WAVAX);
        tokenPath[2] = IERC20(GMX);
        ILBRouter.Version[] memory PoolVersions = new ILBRouter.Version[](2);
        PoolVersions[0] = version1;
        PoolVersions[1] = version2;
        ILBRouter.Path memory SwapPath;
        SwapPath.pairBinSteps = pairBinSteps;
        SwapPath.versions = PoolVersions;
        SwapPath.tokenPath = tokenPath;
        router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            SwapPath,
            msg.sender,
            block.timestamp + 1
        );
        uint256 CurrentUSDC = IERC20(USDC).balanceOf(address(this));
        if (CurrentUSDC > 0) {
            IERC20(USDC).transfer(_Buyer, CurrentUSDC);
        }
    }

    // Withdraw all AVAX from this contract
    function WithdrawAVAX() external payable nonReentrant OnlyOwner {
        require(address(this).balance > 0, "No AVAX to withdraw");
        (bool sent, ) = Owner.call{value: address(this).balance}("");
        require(sent);
    }
    
    // Withdraw any ERC20 token from this contract
    function WithdrawToken(address _tokenaddress, uint256 _Amount) external nonReentrant OnlyOwner {
        IERC20(_tokenaddress).transfer(Owner, _Amount);
    }

    // Function to convert uint256 to enum
    function ConvertToVersion(uint256 _version) internal pure returns (ILBRouter.Version) {
        require(_version <= 2, "Invalid number for enum conversion");
        
        if (_version == 0) {
            return ILBRouter.Version.V1;
        } else if (_version == 1) {
            return ILBRouter.Version.V2;
        } else {
            return ILBRouter.Version.V2_1;
        }
    }
}

interface IFactoryContract {
    function EscrowsToOwners(address _Address) external view returns (address);
    function FeeAmount() external view returns (uint256);
    function FeeAmountStakedGMX() external view returns (uint256);
    function GetListingArray() external view returns (address[] memory);
}

interface IGMXListingsDataV3 {
    struct GMXAccountData {
        uint256 StakedGMXBal;
        uint256 esGMXBal;
        uint256 StakedesGMXBal;
        uint256 esGMXMaxVestGMXBal;
        uint256 esGMXMaxVestGLPBal;
        uint256 TokensToVest;
        uint256 GLPToVest;
        uint256 GLPBal;
        uint256 MPsBal;
        uint256 PendingWAVAXBal;
        uint256 PendingesGMXBal;
        uint256 PendingMPsBal;
    }

    function GetGMXAccountData(address _Address) external view returns (GMXAccountData memory);
}

interface ILBRouter {
    enum Version {
        V1,
        V2,
        V2_1
    }
    struct Path {
        uint256[] pairBinSteps;
        Version[] versions;
        IERC20[] tokenPath;
    }

    function swapNATIVEForExactTokens(uint256 amountOut, Path memory path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amountsIn);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        Path memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amountsIn);
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

interface IWAVAX is IERC20 {
    function deposit() external payable;
    function withdraw(uint amount) external;
}