from pathlib import Path

from brownie import Strategy, accounts, config, network, project, web3, interface, Contract, chain
from eth_utils import is_checksum_address
import click

API_VERSION = config["dependencies"][0].split("@")[-1]
Vault = project.load(
    Path.home() / ".brownie" / "packages" / config["dependencies"][0]
).Vault


def get_address(msg: str, default: str = None) -> str:
    val = click.prompt(msg, default=default)

    # Keep asking user for click.prompt until it passes
    while True:

        if is_checksum_address(val):
            return val
        elif addr := web3.ens.address(val):
            click.echo(f"Found ENS '{val}' [{addr}]")
            return addr

        click.echo(
            f"I'm sorry, but '{val}' is not a checksummed address or valid ENS record"
        )
        # NOTE: Only display default once
        val = click.prompt(msg)


def load_account(acc, want, interface):
    #any tokens we need
    euler="0x27182842E098f60e3D576794A5bFFb0777E025d3"
    ierc20 = interface.IERC20(want)
    ierc20.approve(euler,100*10**18,{"from": euler})
    ierc20.transferFrom(euler,acc,100*10**18,{"from": euler})

def load_account_eth(acc, interface):
    #get eth
    staking="0x00000000219ab540356cBB839Cbe05303d7705Fa"
    staker = accounts.at(staking, force=True)
    staker.transfer(acc, 10**18)




def main():
    print(f"You are using the '{network.show_active()}' network")
    strategist =  accounts.load('dev')
    print(f"You are using: 'dev' [{strategist.address}]")
    print(f"0xa258C4606Ca8206D8aA700cE2143D7db854D168c is yWETH")
    # if input("Is there a Vault for this strategy already? y/[N]: ").lower() == "y":
    #     vault = Vault.at(get_address("Deployed Vault: "))
    vault = Vault.at("0xa258C4606Ca8206D8aA700cE2143D7db854D168c")
    # // "stakingRewards_eUSDC": "0xE5aFE81e63f0A52a3a03B922b30f73B8ce74D570",
    # // "stakingRewards_eUSDT": "0x7882F919e3acCa984babd70529100F937d90F860",
    # // "stakingRewards_eWETH": "0x229443bf7F1297192394B7127427DB172a5bDe9E"
    print(
        f"""
    Strategy Parameters

       api: {API_VERSION}
     token: {vault.token()}
      name: '{vault.name()}'
    symbol: '{vault.symbol()}'
    """
    )

    strategy = Strategy.deploy(vault,"0x229443bf7F1297192394B7127427DB172a5bDe9E", {"from": strategist})
    gov = accounts.at(vault.governance(), force=True)
    yieldlenderstrat = "0xec2DB4A1Ad431CC3b102059FA91Ba643620F0826"
    other_strat = Contract.from_explorer(yieldlenderstrat)
    params = vault.strategies(yieldlenderstrat)
    print(f"You are deavtivating [{yieldlenderstrat}]")
    vault.updateStrategyDebtRatio(yieldlenderstrat, 0, {"from": gov})
    other_strat.harvest({"from": gov})
    # add Strategy
    vault.addStrategy(strategy, params[2], 0, 10**21, 1000, {"from": gov})

    # load Strategy with tokens
    # print(f"{strategy.getBalances()}");
    tx = (strategy.harvest({"from": gov}))
    print(f"{tx.info()}")
    tx = (strategy.tend({"from": gov}))
    print(f"{vault.strategies(strategy)}")
    chain.sleep(1000)
    vault.updateStrategyDebtRatio(strategy, 0, {"from": gov})
    tx = (strategy.harvest({"from": gov}))