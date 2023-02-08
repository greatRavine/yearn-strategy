

# TLDR

+ all the calculations regarding the EUL distribution happen off-chain
+ there is a  rest API that returns the distribution specific data (https://api-lambda.euler.finance/euldistribution)
+ distribution amount is fixed per epoch (~2weeks) for a specific lending pool (determined by voting gauges) 
+ Max distribution per epoch currently is ~8.5k EUL ( ~60k$) for WSETH, USDC, WETH, USDT - others are sub 1k EUL
+ only borrowers get distribution (staking eul rewards for lenders is already covered by the existing Euler gen lender plugin)
+ EUL distribution > borrow rate precondition for leveraged strategy being profitable
+ Very few assets where current EUL distribution > borrow rate - when they are its usually very low TVL, which means EUL distribution would deteriorate quickly if we added more TVL





# Notes

* Epoch is roughly 2 weeks

![image-20230208105616599](C:\Users\dsomm\AppData\Roaming\Typora\typora-user-images\image-20230208105616599.png)

* sorted by total borrowed assets

![image-20230208104012691](C:\Users\dsomm\AppData\Roaming\Typora\typora-user-images\image-20230208104012691.png)

Msg from Kasper:

**all the calculations regarding the EUL distribution happen off-chain** and unfortunately there's no API that would return you the APR itself, it's calculated in the UI. however, we have websocket API that returns issuance of EUL for a given market per epoch. having that, you can calculate the APR yourself. 
it should be easy, given that that you previously used the EulerGeneralView contract so you have all the data needed. except for the EUL price and other asset prices, you can get those from any other API (i.e. coingecko).

APR = number_of_epochs_in_a_year x amount_of_EUL_distributed_in_the_current_epoch_for_a_given_market x EUL_price / value_of_total_borrows_for_a_given_market

number_of_epochs_in_a_year - you can estimate given that as you have start and end of the epoch returned together with the issuance. it'd be 
number_of_epochs_in_a_year = number_of_sec_in_a_year / agv_block_time / (end_block - start_block)

value_of_total_borrows_for_a_given_market - this you got partially from the EulerGeneralView, you got totalBorrows.
value_of_total_borrows_for_a_given_market = totalBorrows * asset_price

as for the issuance API itself, take a look at this gist that I wrote. the API is prepared to use with immer, but because you don't really need to maintain that subscription as the data is not dynamic, you don't have to use it. treat EulerToolsClient.js as a library file to maintain the websocket connection, the index.js shows how to get the data
https://gist.github.com/kasperpawlowski/1fb2c0a70a57f845cc7b462aa3ebdca6



**as of today the process is a bit simpler. we have rest API that returns the distribution specific data**. one thing to note is that the calculations for gauges distribution is off-chain so you need to feed into the smart contract the distribution number for given asset in current epoch



https://api-lambda.euler.finance/euldistribution

or if you want to query specific underlying:
https://api-lambda.euler.finance/euldistribution?underlying=0x03ab458634910aad20ef5f1c8ee96f1d6ac54919

to sum up:

APR = number_of_epochs_in_a_year x amount_of_EUL_distributed_in_the_current_epoch_for_a_given_market x EUL_price / value_of_total_borrows_for_a_given_market

number_of_epochs_in_a_year - you can estimate given that as you have start and end of the epoch returned together with the issuance from the endpoint. it'd be 
number_of_epochs_in_a_year = number_of_sec_in_a_year / agv_block_time / (end_block - start_block)

in fact, number_of_epochs_in_a_year is constant unless distribution rules change but we don’t anticipate that

amount_of_EUL_distributed_in_the_current_epoch_for_a_given_market - you get it from the endpoint
EUL_price - self explanatory

value_of_total_borrows_for_a_given_market - you need to get total borrows for given market from our smart contract (either view or directly, depends on your implementation) and multiply it by the asset price:

value_of_total_borrows_for_a_given_market = totalBorrows * asset_price



