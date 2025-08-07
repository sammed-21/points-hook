// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {MockERC20} from "solmate/src/test/utils/MockERC20.sol";
 
import {Test} from "forge-std/Test.sol";
 
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
 
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
 
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
 
import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHooks.sol";

 
 contract TestPointsHook  is Test , Deployers, ERC1155TokenReceiver {
    // 0000 0000 0100 0000
    // deployCodeTo 
    // MockERC20 token;

    uint160 POINTS_HOOK_FLAG =  Hooks.AFTER_SWAP_FLAG;

    PointsHook pointsHook;


    function setUp() public {
     address hooksAddress = address(POINTS_HOOK_FLAG); 

     //deploy the uniswap v4 poolmanager
     //PoolManager
     // SwapRouter
     // ModifyPositionRouter
    
     deployFreshManagerAndRouters();

     // Deploy the erc20 token 

     MockERC20 token = new MockERC20("TOKEN", "TN", 18);

     token.mint(address(this), 1000 ether);
     token.mint(address(1), 1000 ether);

     deployCodeTo("PointsHook.sol", abi.encode(address(manager)), hooksAddress);
     pointsHook = PointsHook(hooksAddress);
     
     //approve out toke for speding on the swap router and modify liquididy router
     // these variable are coming from the deployers contract

     token.approve(address(swapRouter), type(uint256).max);
     token.approve(address(modifyLiquidityRouter),  type(uint256).max);

     //initialize the pool (ETH <> TOKEN)

     (key,) = initPool(
         Currency.wrap(address(0)),           //Currency 0 = ETH
         Currency.wrap(address(token)),             // Currency 1 = TOKEN
         pointsHook, 
         3000, 
         SQRT_PRICE_1_1);



     // add liquidity to the pool so we can make the swap
    uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
    uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);
 
    uint256 ethToAdd = 0.003 ether;
    uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
        SQRT_PRICE_1_1,
        sqrtPriceAtTickUpper,
        ethToAdd
    );
    uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
        sqrtPriceAtTickLower,
        SQRT_PRICE_1_1,
        liquidityDelta
    );
 
    modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
        key,
        ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(uint256(liquidityDelta)),
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );



    }


function test_swap() public {
    uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
    uint256 pointsBalanceOriginal = pointsHook.balanceOf(
        address(this),
        poolIdUint
    );
 
    // Set user address in hook data
    bytes memory hookData = abi.encode(address(this));
 
    // Now we swap
    // We will swap 0.001 ether for tokens
    // We should get 20% of 0.001 * 10**18 points
    // = 2 * 10**14
    swapRouter.swap{value: 0.001 ether}(
        key,
        SwapParams({
            zeroForOne: true,
            amountSpecified: -0.001 ether, // Exact input for output swap
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
    );
    uint256 pointsBalanceAfterSwap = pointsHook.balanceOf(
        address(this),
        poolIdUint
    );
    assertEq(pointsBalanceAfterSwap - pointsBalanceOriginal, 2 * 10 ** 14);
}

 }