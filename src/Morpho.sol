// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {IMorpho} from "./interfaces/IMorpho.sol";
import {IPositionsManager} from "./interfaces/IPositionsManager.sol";
import {IRewardsController} from "@aave/periphery-v3/contracts/rewards/interfaces/IRewardsController.sol";

import {Events} from "./libraries/Events.sol";
import {Errors} from "./libraries/Errors.sol";
import {DelegateCall} from "@morpho-utils/DelegateCall.sol";
import {ERC20, SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {MorphoStorage} from "./MorphoStorage.sol";
import {MorphoGetters} from "./MorphoGetters.sol";
import {MorphoSetters} from "./MorphoSetters.sol";

contract Morpho is IMorpho, MorphoGetters, MorphoSetters {
    using DelegateCall for address;
    using SafeTransferLib for ERC20;

    /// CONSTRUCTOR ///

    constructor(address addressesProvider) MorphoStorage(addressesProvider) {}

    /// EXTERNAL ///

    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxLoops)
        external
        returns (uint256 supplied)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.supplyLogic.selector, underlying, amount, msg.sender, onBehalf, maxLoops
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function supplyCollateral(address underlying, uint256 amount, address onBehalf)
        external
        returns (uint256 supplied)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.supplyCollateralLogic.selector, underlying, amount, msg.sender, onBehalf
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxLoops)
        external
        returns (uint256 borrowed)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.borrowLogic.selector, underlying, amount, onBehalf, receiver, maxLoops
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function repay(address underlying, uint256 amount, address onBehalf, uint256 maxLoops)
        external
        returns (uint256 repaid)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.repayLogic.selector, underlying, amount, msg.sender, onBehalf, maxLoops
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function withdraw(address underlying, uint256 amount, address to, uint256 maxLoops)
        external
        returns (uint256 withdrawn)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.withdrawLogic.selector, underlying, amount, msg.sender, to, maxLoops
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function withdrawCollateral(address underlying, uint256 amount, address to) external returns (uint256 withdrawn) {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.withdrawCollateralLogic.selector, underlying, amount, msg.sender, to
            )
        );

        return (abi.decode(returnData, (uint256)));
    }

    function liquidate(address underlyingBorrowed, address underlyingCollateral, address user, uint256 amount)
        external
        returns (uint256 repaid, uint256 seized)
    {
        bytes memory returnData = _positionsManager.functionDelegateCall(
            abi.encodeWithSelector(
                IPositionsManager.liquidateLogic.selector,
                underlyingBorrowed,
                underlyingCollateral,
                amount,
                user,
                msg.sender
            )
        );

        return (abi.decode(returnData, (uint256, uint256)));
    }

    function allow(address manager, bool isAllowed) external {
        _isAllowed[msg.sender][manager] = isAllowed;
        emit Events.Approval(msg.sender, manager, isAllowed);
    }

    /// @notice Claims rewards for the given assets.
    /// @param assets The assets to claim rewards from (aToken or variable debt token).
    /// @param onBehalf The address for which rewards are claimed and sent to.
    /// @return rewardTokens The addresses of each reward token.
    /// @return claimedAmounts The amount of rewards claimed (in reward tokens).
    function claimRewards(address[] calldata assets, address onBehalf)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts)
    {
        if (_isClaimRewardsPaused) revert Errors.ClaimRewardsPaused();

        (rewardTokens, claimedAmounts) = _rewardsManager.claimRewards(assets, onBehalf);
        IRewardsController(_rewardsManager.getRewardsController()).claimAllRewardsToSelf(assets);

        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 claimedAmount = claimedAmounts[i];

            if (claimedAmount > 0) {
                ERC20(rewardTokens[i]).safeTransfer(onBehalf, claimedAmount);
                emit Events.RewardsClaimed(onBehalf, rewardTokens[i], claimedAmount);
            }
        }
    }
}
