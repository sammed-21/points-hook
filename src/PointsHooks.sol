// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

/**
 * @dev we will use afterSwap hook function
 * @dev issue points to users in the form of ERC1155 tokens
 *
 */
contract PointsHook is BaseHook, ERC1155 {
    constructor(IPoolManager _manager) BaseHook(_manager) {}

    //set up hook permissions ot return true
    // for the two hook functions we are suing

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function uri(uint256) public view virtual override returns (string memory) {
        return "https://api.example.com/token/{id}";
    }

    //almost all the hook function have the hookData parameter that come with it .abi
    //this param can be used to atatach arbitrary data for usage by the hook.
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        //make sure the is eth - Token pool
        if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);

        //we only mint point if user is buyying token with eth

        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);

        // since its a zeroForOne swap:
        //if amountSpecified <0:
        // this is an 'exact input for output" swap
        // amount of eth they spent is equal to mountsepeicifted
        // if amountSpecified > 0;
        // this is an exact output for intput swap
        // amount of ETH they spent is equal to balanceDelta.amount0()
        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
        uint256 pointForSwap = ethSpendAmount / 5;

        _assignPoints(key.toId(), hookData, pointForSwap);

        return (this.afterSwap.selector, 0);
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 points
    ) internal {
        if (hookData.length == 0) return;

        //extract user address from hoookdata

        address user = abi.decode(hookData, (address));

        if (user == address(0)) return;

        //Mint point to the user

        uint256 poolIdUnit = uint256(PoolId.unwrap(poolId));
        _mint(user, poolIdUnit, points, "");
    }
}
