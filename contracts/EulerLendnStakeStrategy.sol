// SPDX-License-Identifier: AGPL-3.0
// Feel free to change the license, but this is what we use

// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {
    BaseStrategy,
    BaseStrategyInitializable,
    StrategyParams
} from "@yearnvaults/contracts/BaseStrategy.sol";
import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import Euler interface
import {
    IEulerMarkets,
    IEulerEToken
} from "../interfaces/IEuler.sol";
// import Euler Staking Interface (based on SNX staking)
import {
    IStakingRewards
} from "../interfaces/IStakingRewards.sol";
import {
    IUniswapRouter,
    IQuoterV2,
    ISwapRouter
} from "../interfaces/IUniswap.sol";

// Define EulerLendStrategy that can be cloned and attached to any vault for which a market exists
contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Ropsten (https://github.com/euler-xyz/euler-contracts/blob/master/addresses/euler-addresses-ropsten.json):
    // "euler": "0xfC3DD73e918b931be7DEfd0cc616508391bcc001",
    // "markets": "0x7cf6Daa8923383500325D6E05554b673fdaaFf76",
    // Mainnet - depending on WANT token!
    // "stakingRewards_eUSDC": "0xE5aFE81e63f0A52a3a03B922b30f73B8ce74D570",
    // "stakingRewards_eUSDT": "0x7882F919e3acCa984babd70529100F937d90F860",
    // "stakingRewards_eWETH": "0x229443bf7F1297192394B7127427DB172a5bDe9E"



    // source: https://github.com/euler-xyz/euler-contracts/blob/master/addresses/euler-addresses-mainnet.json
    address public constant EULER = address(0x27182842E098f60e3D576794A5bFFb0777E025d3);
    IEulerMarkets public constant eMarkets = IEulerMarkets(address(0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3));
    IEulerEToken public immutable eToken;
    IStakingRewards public immutable eStaking;


    //Uniswap pools & fees - if unused compiler just ignores...usually we only need EUL, WETH and want...
    IERC20 public constant WETH9 = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    IERC20 public constant USDC = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    IERC20 public constant USDT = IERC20(address(0xdAC17F958D2ee523a2206206994597C13D831ec7));
    IERC20 public constant EULER_ERC20 = IERC20(address(0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b));
    IQuoterV2 public constant quoter = IQuoterV2(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    IUniswapRouter public constant uniswapRouter = IUniswapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);


    uint24 public constant poolFee030 = 3000;
    uint24 public constant poolFee005 = 500;
    uint24 public constant poolFee001 = 100;
    uint24 public constant poolFee100 = 10000;
  
    event PrepareReturnReport(uint256 _profit, uint256 _loss, uint256 _debtPayment);
    event AdjustPositionReport(uint256 _holdings, uint256 _debtOutstanding, uint256 _totalDebt);
    event DepositStaking (uint256 _token, uint256 _want);
    event DepositLending (uint256 _token, uint256 _want);
    event WithdrawStaking (uint256 _token, uint256 _want);
    event WithdrawLending (uint256 _token, uint256 _want);
    event ReportLocal(uint256 _want);

    constructor(address _vault, address _stakingContract) public BaseStrategy(_vault) {
        // You can set these parameters on deployment to whatever you want
        // maxReportDelay = 6300;
        // profitFactor = 100;
        // debtThreshold = 0;
        eToken = IEulerEToken(address(eMarkets.underlyingToEToken(vault.token())));
        //Staking contracts
        eStaking = IStakingRewards(address(_stakingContract));
        IERC20(address(eMarkets.underlyingToEToken(vault.token()))).approve(address(_stakingContract), type(uint).max);                    
        IERC20(address(vault.token())).approve(EULER, type(uint).max);
        IERC20(address(EULER_ERC20)).approve(address(uniswapRouter), type(uint).max);
    }


    // //set Euler contracts - decided to not do it statically or in the constructor, but I should probably lock this down.
    // //potential for a ghetto like the pickle jar hack...
    // function inizializeEulerContracts(address _markets, address _eToken, address _eStaking) external onlyAuthorized {
    //     eMarkets = IEulerMarkets(_markets);
    //     eToken = IEulerEToken(_eToken);
    //     eStaking = IStakingRewards(_eStaking);
    // }


    // ******** OVERRIDE THESE METHODS FROM BASE CONTRACT ************
    // internal function to be called
    function  _withdrawStaking(uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }
        uint256 balance = eStaking.balanceOf(address(this));
        if (balance >= _amount ){
            eStaking.withdraw(_amount);
            emit WithdrawStaking(_amount, eToken.convertBalanceToUnderlying(_amount));
        } else  {
            eStaking.withdraw(balance);
            emit WithdrawStaking(balance, eToken.convertBalanceToUnderlying(balance));
        }
    }
    function  _exitStaking() internal {
        if (eStaking.balanceOf(address(this)) > 0){
            uint256 amount = eStaking.balanceOf(address(this));
            eStaking.exit();
            emit WithdrawStaking(amount, eToken.convertBalanceToUnderlying(amount));
        }
    }
    function  _exitLending() internal {
        if (eToken.balanceOf(address(this)) > 0) {  
            uint256 amount = eToken.balanceOf(address(this));     
            eToken.withdraw(0, type(uint256).max);
            emit WithdrawLending(amount, eToken.convertBalanceToUnderlying(amount));
        }        
    }
    function  _depositStaking(uint256 _amount) internal {
        if (_amount > 0 && eToken.balanceOf(address(this)) >= _amount) {
             eStaking.stake(_amount);
             emit DepositStaking(_amount, eToken.convertBalanceToUnderlying(_amount));     
        }
    }
    function  _depositLending(uint256 _amount) internal {
        if (_amount > 0 && want.balanceOf(address(this)) >= _amount) {
            eToken.deposit(0, _amount);
            emit DepositLending(eToken.convertUnderlyingToBalance(_amount), _amount);
        }       
    }

    function name() external view override returns (string memory) {
        // DS TODO: Get TokenType from want or vault
        return string(abi.encodePacked("StrategyEulerLendnStake ", vault.symbol()));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        // DS TODO: Calculate Balance by adding balanceOfUnderlying eToken and balance of this address!
        // With Staking you need to use convertBalanceToUnderlying - staking and eTOken are 1:1
        // Ignore Euler Tokens. We will claim and swap them with harvest or tend, so they will be included eventually.
        uint256 local = want.balanceOf(address(this));
        uint256 lent = eToken.balanceOfUnderlying(address(this)); //should be zero
        uint256 staked = eToken.convertBalanceToUnderlying(eStaking.balanceOf(address(this)));
        return uint256(local.add(lent)).add(staked);
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // TODO: Do stuff here to free up any returns back into `want`
        // NOTE: Return `_profit` which is value generated by all positions, priced in `want`
        // NOTE: Should try to free up at least `_debtOutstanding` of underlying position

        // DS TODO: get total amout of assets
        // getRewards and change to want
        // free up (=unstake & withdraw from Euler) enough assets from lending so that we can pay back _debtOutstanding after taking the rewards! 
        // get totalDebt from vault and calculate profit or loss | uint256 debt = vault.strategies(address(this)).totalDebt;
        // if _debtOutstanding > totalAssets withdraw all
        //
        //check if we have euler tokens to liquidate (add switch to only liquidate if enough?)
        uint256 outstandingConvertible = eStaking.earned(address(this));
        // don't swap if its just dust...
        if (outstandingConvertible > 10**16) {
            eStaking.getReward();
            _sellEulerForWant();
        }


        // get positions
        // local in strategy in want
        uint256 local = want.balanceOf(address(this));
        // staked in want
        uint256 staked = eToken.convertBalanceToUnderlying(eStaking.balanceOf(address(this)));
        // lent in want - should be zero
        uint256 lent = eToken.balanceOfUnderlying(address(this));

        // total amount in want
        uint256 total = local.add(staked).add(lent);
        // total debt in want
        uint256 debt = vault.strategies(address(this)).totalDebt;


        // no withdrawals only reporting
        if (_debtOutstanding == 0) {
            _profit=total.sub(debt);
            _loss = 0;
            _debtPayment = 0;
            return (_profit, _loss, _debtPayment);
        }

        //something went wrong or we just need to withdraw all
        if (debt > total || _debtOutstanding >= total) {
            _loss = debt.sub(total);
            _profit = 0;
            _debtPayment = total;
            // unstake
            _exitStaking();
            // withdraw all lent out (removing max is a special case and liquidates the position)
            _exitLending();
        } else {
            _profit=total.sub(debt);
            _loss = 0;
            _debtPayment = _debtOutstanding;

            // Do we need to unstake stuff?
            if (local.add(lent) < _debtOutstanding) {
                // remaining debt to unwind in want
                uint256 remainingToFree = _debtOutstanding.sub(local.add(lent));
                // remaining debt to unwind in eTokens (round up - is caught in _withdrawStaking!)
                uint256 remainingToFreeETokens = eToken.convertUnderlyingToBalance(remainingToFree)+1;
                //unstake calculated amount -> goes into lent out
                _withdrawStaking(remainingToFreeETokens);
                _exitLending();

            // do we need to withdraw from lending?
            } else if (local.add(lent) >= _debtOutstanding && local < _debtOutstanding) {
                _exitLending();
            }

            _profit= estimatedTotalAssets().sub(debt);
            _loss = 0;
            _debtPayment = _debtOutstanding;            
        }
        emit ReportLocal(want.balanceOf(address(this)));
        emit PrepareReturnReport(_profit, _loss, _debtPayment);
        return (_profit, _loss, _debtPayment);
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        // TODO: Do something to invest excess `want` tokens (from the Vault) into your positions
        // NOTE: Try to adjust positions so that `_debtOutstanding` can be freed up on *next* harvest (not immediately)

        // DS TODO: invest all want tokens in the this strategy into Euler

        // Discuss: Check if we can withdraw _debtOutstanding from Euler (Maybe if borrow utilization is at 100% its not possible?!)
        // if _debtOutstanding is > than liquidity to withdraw in Euler + Safety Margin -> free up _debtOutstanding instantly to be safe
        
        uint256 local = want.balanceOf(address(this));
        uint256 totalDebt = vault.strategies(address(this)).totalDebt;
        emit AdjustPositionReport(local, _debtOutstanding, totalDebt);
        // if you can deposit something - do it.
        if (local > 0) {
            _depositLending(local);
            uint256 toStake= eToken.balanceOf(address(this));
            _depositStaking(toStake);
            emit ReportLocal(want.balanceOf(address(this)));
        }
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        // TODO: Do stuff here to free up to `_amountNeeded` from all positions back into `want`
        // NOTE: Maintain invariant `want.balanceOf(this) >= _liquidatedAmount`
        // NOTE: Maintain invariant `_liquidatedAmount + _loss <= _amountNeeded`

        //DS TODO: Free up requested amout from lent out tokens so that want.balanceOf(address(this) == _amountNeeded
        // if we can't just free up all and report loss
        // use exit on stakng - includes getRewards() - still needs to withdraw from eToken afterwards to get want
        
        //prepareReturn should free up all necessary things
        prepareReturn(_amountNeeded);
        uint256 totalAssets = want.balanceOf(address(this));
        emit ReportLocal(want.balanceOf(address(this)));
        // if we have less than needed get everything and report loss
        if (_amountNeeded > totalAssets) {
            _liquidatedAmount = totalAssets;
            _loss = _amountNeeded.sub(totalAssets);
        } else {
        // else just get what is needed
            _liquidatedAmount = _amountNeeded;
            _loss = 0;
        }
    }

    function liquidateAllPositions() internal override returns (uint256) {
        // TODO: Liquidate all positions and return the amount freed.
        
        // DS TODO free up all!
        _exitStaking();
        _exitLending(); 

        _sellEulerForWant();
        return want.balanceOf(address(this));
    }

    // NOTE: Can override `tendTrigger` and `harvestTrigger` if necessary

    function prepareMigration(address _newStrategy) internal override {
        // TODO: Transfer any non-`want` tokens to the new strategy
        // NOTE: `migrate` will automatically forward all `want` in this strategy to the new one

        //DS TODO: free up all positions and transfer to _netStrategy
        liquidateAllPositions();
        want.safeTransfer(_newStrategy, want.balanceOf(address(this)));
    }

    // Override this to add all tokens/tokenized positions this contract manages
    // on a *persistent* basis (e.g. not just for swapping back to want ephemerally)
    // NOTE: Do *not* include `want`, already included in `sweep` below
    //
    // Example:
    //
    //    function protectedTokens() internal override view returns (address[] memory) {
    //      address[] memory protected = new address[](3);
    //      protected[0] = tokenA;
    //      protected[1] = tokenB;
    //      protected[2] = tokenC;
    //      return protected;
    //    }

    //DS TODO: Add managed eTokens from the Euler Contract and Staked tokens + EulerERC20!
    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
    {
        address[] memory protected = new address[](3);
        protected[0]= address(eToken);
        protected[1] = address(eStaking);
        protected[2] = address(EULER_ERC20);
        return protected;
    }

    /**
     * @notice
     *  Provide an accurate conversion from `_amtInWei` (denominated in wei)
     *  to `want` (using the native decimal characteristics of `want`).
     * @dev
     *  Care must be taken when working with decimals to assure that the conversion
     *  is compatible. As an example:
     *
     *      given 1e17 wei (0.1 ETH) as input, and want is USDC (6 decimals),
     *      with USDC/ETH = 1800, this should give back 1800000000 (180 USDC)
     *
     * @param _amtInWei The amount (in wei/1e-18 ETH) to convert to `want`
     * @return The amount in `want` of `_amtInEth` converted to `want`
     **/

     //DS TODO: Return value of want in WEI using Uniswap (don't swap :D)
    function ethToWant(uint256 _amtInWei)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (address(want) == address(WETH9)){
            return _amtInWei;
        } else {
            IQuoterV2.QuoteExactInputSingleParams memory params =
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: address(want),
                tokenOut: address(WETH9),
                amountIn: _amtInWei,
                fee: poolFee030,
                sqrtPriceLimitX96: 0
            });
            (uint256 amountOut,,,) = quoter.quoteExactInputSingle(params);
            return amountOut;
        }
    }

    // DS TODO - implement
    function _sellEulerForWant() internal {
        // only execute if there is anything to swap
        if (EULER_ERC20.balanceOf(address(this)) > 0) {
            if (address(want) == address(WETH9)){
                ISwapRouter.ExactInputSingleParams memory params =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(EULER_ERC20),
                    tokenOut: address(WETH9),
                    fee: poolFee100,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: EULER_ERC20.balanceOf(address(this)),
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
                // The call to `exactInputSingle` executes the swap.
                uniswapRouter.exactInputSingle(params);
            } else {
                ISwapRouter.ExactInputParams memory params =
                ISwapRouter.ExactInputParams({
                    path: abi.encodePacked(address(EULER_ERC20), poolFee100, address(WETH9), poolFee030, address(want)),
                    recipient: msg.sender,
                    deadline: block.timestamp,
                    amountIn: EULER_ERC20.balanceOf(address(this)),
                    amountOutMinimum: 0
                });
                // Executes the swap.
                uniswapRouter.exactInput(params);
                }
        }
    }



    //HELPER Functions for debug or recovery
    function refundETH() external onlyEmergencyAuthorized {
        uniswapRouter.refundETH();
    }

    function getBalances() external view onlyEmergencyAuthorized returns (uint256, uint256, uint256) {
        return (WETH9.balanceOf(address(this)), eToken.balanceOf(address(this)), eStaking.balanceOf(address(this)));
    }
    function remaxApproval() external onlyEmergencyAuthorized {
        IERC20(address(vault.token())).approve(EULER, type(uint).max);
        IERC20(address(eToken)).approve(address(eStaking), type(uint).max);
        IERC20(address(EULER_ERC20)).approve(address(uniswapRouter), type(uint).max);
    }
    function revokeApproval() external onlyEmergencyAuthorized {
        IERC20(address(vault.token())).approve(EULER, 0);
        IERC20(address(eToken)).approve(address(eStaking), 0);
        IERC20(address(EULER_ERC20)).approve(address(uniswapRouter), 0);
    }

    function exitStake() external onlyEmergencyAuthorized {
        eStaking.exit();
    }
    function exitLending() external onlyEmergencyAuthorized {
        eToken.withdraw(0, type(uint256).max);
    }
}
