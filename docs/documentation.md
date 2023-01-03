# Euler Lend Strategies

## Introduction

This document shall serve as due diligence report and as documentation for monitoring strategists, safe farming committee or yearn vault guardians.

Euler is a non-custodial protocol on Ethereum that allows users to lend and borrow almost any crypto asset -  similar to Aave or Compound. In the following we introduce 2 yield generating strategies utilizing Euler Finance.

## Overview

Resources:

* Whitepaper: https://docs.euler.finance/getting-started/white-paper
* Forum: https://forum.euler.finance/
* Documentation: https://docs.euler.finance/
* Github: https://github.com/euler-xyz/
* Audits: https://docs.euler.finance/security/audits



## Rug-ability

Euler uses a single storage contract with a base Euler contract with upgradable modules and a non-upgradable proxy architecture.

This means contract upgrades for existing tokens are possible. 

Currently it is protected by a 3/7 multi-sig. owned by the Euler Foundation. The holders of each address are not transparent and there is no time-lock implemented on these contracts.

Current multi-sig.:

https://gnosis-safe.io/app/eth:0x25Aa4a183800EcaB962d84ccC7ada58d4e126992/home 

The staking contract is derived from the SNX staking contract, which is battle tested and considered secure.



Just for completion - treasury multi-sig.:

https://gnosis-safe.io/app/eth:0xcAD001c30E96765aC90307669d578219D4fb1DCe/home



## Audit Reports

Audits are listed here: https://docs.euler.finance/security/audits



## Strategy Details

### EulerLendnStake

#### Summary

The `EulerLendnStake` strategy deposits `want` into the corresponding Euler lending pool and stakes the received LP tokens into Euler Staking to earn `Euler`.

This earns following rewards:

* lending interest from Euler lending
* staking rewards from Euler distribution, which are sold and redeposited

**Staking is only available for `WETH`,`USDC` and `USDT`.**

#### Current yield and outlook

| Asset | Lending APY | Staking APY | Total APY | Yearn Vault APY (from vault overview) | Current TVL (Euler Staking) |
| ----- | ----------- | ----------- | --------- | ------------------------------------- | --------------------------- |
| WETH  | 2.23%       | 2.29%       | 4.52%     | 2.62%                                 | $21.54M                     |
| USDC  | 1.17%       | 2.43%       | 3.60%     | 2.63%                                 | $20.31M                     |
| USDT  | 2.19%       | 2.71%       | 3.90%     | 2.28%                                 | $18.22M                     |

The most interesting vault for `EulerLendnStake` is probably WETH Vault. It is to be expected, that with Ethereum enabling withdrawals lending APYs on all lending platforms should come close to staking APYs, since borrowing and staking will be a viable arbitrage opportunity as long as borrowing rates are lower than the staking APY. The additional ~2% yield from staking and selling Euler are a nice addition and make the strategy competitive. 

#### Vault/Strategy Pitfalls

Staking is currently on a trial run, so the additional rewards might dry up in a couple of months if it's deemed unsuccessful. Deploying liquidity with yearn vaults increases the chance, that staking rewards continue as the staking mechanic would have achieved its goal of drawing in more liquidity and stabilizing lending rate on the most important assets.

Unlike SNX staking rewards, Euler staking rewards are claimable instantly. There is no risk of liquiditation, as there is no debt position.
If the borrow utilization of the Euler platform trends towards 100% it might be possible, that withdrawal is not possible, as all collateral is currently lent out. Since rates would be very high in this case, it is only likely in a emergency/exploit scenario. **If the strategy should check utilization rate and withdraw if liquidity to withdraw starts to dry up is open for discussion.**

#### Path-to-Prod

##### Target Prod Vault Comment

WETH Vault takes highest priority as it is the biggest boost. USDT 2nd and last USDC.

##### Prod Deployment Plan

##### Suggested position in withdrawQueue?

Up to discussion

##### Does strategy have any deposit/withdraw fees?

No

##### Suggested debtRatio?

WETH:
It should compete with the **StrategyLenderYieldOptimiser**, **88MPH WETH via Aave**, **SSBv3 WETH B-stETH-STABLE** which are currently providing much lower APY and have similar properties. Currently we propose 15%.

USDT:
It should compete with the **StrategyLenderYieldOptimiser** and **StrategyIdleV2 IdleUSDT v4 [Best yield]**.
Currently we propose 20%.

USDC:
TODO



##### Suggested max debtRatio to scale to?

WETH: 
Even with only lending it can compete with **StrategyLenderYieldOptimiser**, **88MPH WETH via Aave**, **SSBv3 WETH B-stETH-STABLE** from an APY perspective for up to $20M, which is roughly 20-30% debtRatio. This should be revisited at a later stage as it depends largely also on the growth of the Euler platform.

USDT:
It competes directly with **StrategyLenderYieldOptimiser** as it is largely dependent on lending rates and demand.
Currently 20% seems realistic also with growing deposits.

USDC:
TODO



### EulerLendnLeverage (not implemented yet)

#### Summary

The `EulerLendnLeverage` strategy deposits `want` into the corresponding Euler lending pool for interest. If the provided Euler distribution rate is high enough it will leverage up the position and mine Euler rewards. Leveraging up is possible inside the Euler platform with the `mint` functionality - liquiditation risk comes from fees and not from volatility. In absence of distribution rewards, the strategy become a simple lend strategy that earns lending rates.

This earns following rewards:

* lending interest from Euler lending
* Euler token distribution for borrowing (only if higher than borrow rate)

This is available for any token, as markets can be created in a permissionless way for any ERC20 tokens. If there is no demand to borrow the token, the lending rates are very low - as expected. But there are some niche assets for which lending might be competitive to all other available strategies. We provide some examples below.

#### Current yield and outlook

| Asset | Lending APY | Borrow APY | Euler Distribution for Borrowers APY | Current TVL |
| ----- | ----------- | ---------- | ------------------------------------ | ----------- |
| YFI   | 3.39%       | 9.50%      | 12.57%                               | $200K       |
| RAI   | 11.66%      | 29.01%     | 25.42%                               | $373K       |
| ENS   | 3.57%       | 10.63%     | 13.54%                               | $252K       |
| LUSD  | 3.67%       | 2.76%      | 9.53%                                | $1.38M      |
| LDO   | 22.34%      | 52.01%     | 3.47%                                | $1.59M      |

For most examples the TVL is underwhelmingly low, but the Euler platform is still growing and there might be opportunities in the future. In the long term it is realistic that yearn vaults integrate into all common lending platforms for sustainable yield without liquidity incentives.



### Vault/Strategy Pitfalls

TODO



