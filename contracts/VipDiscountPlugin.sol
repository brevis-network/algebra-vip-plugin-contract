// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import '@cryptoalgebra/integral-core/contracts/libraries/Plugins.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPlugin.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraDynamicFeePlugin.sol';
import '@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol';

import {VipDiscountMap} from "./VipDiscountMap.sol";
import {BrevisApp} from "./BrevisApp.sol";
import {Ownable} from "./Ownable.sol";

/// @notice VipDiscountPlugin is a contract that provides fee discount based on VIP tiers
contract VipDiscountPlugin is IAlgebraPlugin, IAlgebraDynamicFeePlugin, VipDiscountMap, BrevisApp, Ownable {
    event FeeUpdated(uint16 fee); // origFee is updated
    event BrevisReqUpdated(address addr);
    event PoolUpdated(address addr);
    event VkHashUpdated(bytes32 vkhash);

    // need this to proper tracking "user"
    event TxOrigin(address indexed addr); // index field to save zk parsinig cost

    bytes32 public vkHash; // BrevisApp to ensure correct circuit
    address public pool; // associated algebra pool address

    uint8 public pluginConfig =
        uint8(Plugins.BEFORE_SWAP_FLAG | Plugins.DYNAMIC_FEE);

    // minimal constructor args as this contract is intended to by used via proxy
    constructor(address _brevisRequest) BrevisApp(_brevisRequest) {
    }

    // called by proxy to properly set storage of proxy contract
    function init(uint16 _origFee, address _brevisRequest, address _pool, bytes32 _vkHash) external {
        initOwner(); // will fail if not called via delegateCall b/c owner is set in Ownable constructor
        // no need to emit event as it's first set in proxy state
        _setBrevisRequest(_brevisRequest);
        origFee = _origFee;
        vkHash = _vkHash;
        pool = _pool;
        pluginConfig = uint8(Plugins.BEFORE_SWAP_FLAG | Plugins.DYNAMIC_FEE);
    }

    // satisfy IAlgebraDynamicFeePlugin. orig fee without any discount
    function getCurrentFee() external view returns (uint16 fee) {
        return origFee;
    }
    // satisfy IAlgebraPlugin
    function defaultPluginConfig() external view returns (uint8) {
        return pluginConfig;
    }

    function beforeSwap(
        address sender,
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        bool withPaymentInAdvance,
        bytes calldata data
    ) external returns (bytes4)
    {
        uint16 dynFee = getFee(tx.origin);
        emit TxOrigin(tx.origin);
        IAlgebraPool(pool).setFee(dynFee);
        return this.beforeSwap.selector;
    }
    // other hooks, to satisfy IAlgebraPlugin
    function beforeInitialize(address sender, uint160 sqrtPriceX96) external returns (bytes4) {
        return this.beforeInitialize.selector;
    }
    function afterInitialize(address sender, uint160 sqrtPriceX96, int24 tick) external returns (bytes4) {
        return this.afterInitialize.selector;
    }
    function beforeModifyPosition(
        address sender,
        address recipient,
        int24 bottomTick,
        int24 topTick,
        int128 desiredLiquidityDelta,
        bytes calldata data
    ) external returns (bytes4) {
        return this.beforeModifyPosition.selector;
    }
    function afterModifyPosition(
        address sender,
        address recipient,
        int24 bottomTick,
        int24 topTick,
        int128 desiredLiquidityDelta,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external returns (bytes4){
        return this.afterModifyPosition.selector;
    }
    function afterSwap(
        address sender,
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) external returns (bytes4){
        return this.afterSwap.selector;
    }
    function beforeFlash(address sender, address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external returns (bytes4) {
        return this.beforeFlash.selector;
    }
    function afterFlash(
        address sender,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1,
        bytes calldata data
    ) external returns (bytes4){
        return this.afterFlash.selector;
    }

    // brevisApp interface
    function handleProofResult(bytes32 _vkHash, bytes calldata _appCircuitOutput) internal override {
        require(vkHash == _vkHash, "invalid vk");
        updateBatch(_appCircuitOutput);
    }

    // must call after pool owner did pool.setPlugin so plugin can be called on hooks
    function setConfigInPool() external onlyOwner {
        IAlgebraPool(pool).setPluginConfig(pluginConfig);
    }

    function updatePluginConfig(uint8 newcfg) external onlyOwner {
        pluginConfig = newcfg;
        IAlgebraPool(pool).setPluginConfig(pluginConfig);
    }

    function setPool(address _pool) external onlyOwner {
        pool = _pool;
        emit PoolUpdated(_pool);
    }

    function setFee(uint16 _newfee) external onlyOwner {
        origFee = _newfee;
        emit FeeUpdated(_newfee);
    }

    function setVkHash(bytes32 _vkh) external onlyOwner {
        vkHash = _vkh;
        emit VkHashUpdated(_vkh);        
    }

    function setBrevisRequest(address _brevisRequest) external onlyOwner {
        _setBrevisRequest(_brevisRequest);
        emit BrevisReqUpdated(_brevisRequest);
    }
}
