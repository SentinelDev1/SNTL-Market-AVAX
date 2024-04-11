// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
contract AccountEligible{
    address constant private EsGMXAddress = 0xFf1489227BbAAC61a9209A08929E4c2a526DdD17;
    address constant private WAVAXAddress = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address constant private GMXAddress = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address constant private GMXRewardRouterAddress = 0x82147C5A7E850eA4E28155DF107F2590fD4ba327;
    address constant private stakedGmxTracker = 0x2bD10f8E93B3669b6d42E74eEedC65dd1B0a1342;
    address constant private bonusGmxTracker = 0x908C4D94D34924765f1eDc22A1DD098397c59dD4;
    address constant private feeGmxTracker = 0x4d268a7d4C16ceB5a606c173Bd974984343fea13;
    address constant private gmxVester = 0x472361d3cA5F49c8E633FB50385BfaD1e018b445;
    address constant private stakedGlpTracker = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
    address constant private feeGlpTracker = 0xd2D1162512F927a7e282Ef43a362659E4F2a728F;
    address constant private glpVester = 0x62331A7Bd1dfB3A7642B7db50B5509E57CA3154A;
    function TransferEligible(address _receiver) external view returns (bool Eligible) {
        Eligible = true;
        if (IRewardTracker(stakedGmxTracker).averageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(stakedGmxTracker).cumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(bonusGmxTracker).averageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(bonusGmxTracker).cumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }       
        if (IRewardTracker(feeGmxTracker).averageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(feeGmxTracker).cumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }
        if (IVester(gmxVester).transferredAverageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IVester(gmxVester).transferredCumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(stakedGlpTracker).averageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(stakedGlpTracker).cumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(feeGlpTracker).averageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IRewardTracker(feeGlpTracker).cumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }
        if (IVester(glpVester).transferredAverageStakedAmounts(_receiver) > 0) {
            Eligible = false;
        }
        if (IVester(glpVester).transferredCumulativeRewards(_receiver) > 0) {
            Eligible = false;
        }
        if (IERC20(gmxVester).balanceOf(_receiver) > 0) {
            Eligible = false;
        }
        if (IERC20(glpVester).balanceOf(_receiver) > 0) {
            Eligible = false;
        }
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
interface IRewardTracker {
    function depositBalances(address _account, address _depositToken) external view returns (uint256);
    function stakedAmounts(address _account) external view returns (uint256);
    function updateRewards() external;
    function stake(address _depositToken, uint256 _amount) external;
    function stakeForAccount(address _fundingAccount, address _account, address _depositToken, uint256 _amount) external;
    function unstake(address _depositToken, uint256 _amount) external;
    function unstakeForAccount(address _account, address _depositToken, uint256 _amount, address _receiver) external;
    function tokensPerInterval() external view returns (uint256);
    function claim(address _receiver) external returns (uint256);
    function claimForAccount(address _account, address _receiver) external returns (uint256);
    function claimable(address _account) external view returns (uint256);
    function averageStakedAmounts(address _account) external view returns (uint256);
    function cumulativeRewards(address _account) external view returns (uint256);
}
interface IVester {
    function claimForAccount(address _account, address _receiver) external returns (uint256);
    function transferredAverageStakedAmounts(address _account) external view returns (uint256);
    function transferredCumulativeRewards(address _account) external view returns (uint256);
    function cumulativeRewardDeductions(address _account) external view returns (uint256);
    function bonusRewards(address _account) external view returns (uint256);
    function transferStakeValues(address _sender, address _receiver) external;
    function setTransferredAverageStakedAmounts(address _account, uint256 _amount) external;
    function setTransferredCumulativeRewards(address _account, uint256 _amount) external;
    function setCumulativeRewardDeductions(address _account, uint256 _amount) external;
    function setBonusRewards(address _account, uint256 _amount) external;
    function getMaxVestableAmount(address _account) external view returns (uint256);
    function getCombinedAverageStakedAmount(address _account) external view returns (uint256);
}
