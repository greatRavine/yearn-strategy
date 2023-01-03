import pytest
from brownie import config
from brownie import Contract


@pytest.fixture
def gov(accounts):
    yield accounts.at("0xFEB4acf3df3cDEA7399794D0869ef76A6EfAff52", force=True)


@pytest.fixture
def user(accounts):
    yield accounts[0]


@pytest.fixture
def rewards(accounts):
    yield accounts[1]


@pytest.fixture
def guardian(accounts):
    yield accounts[2]


@pytest.fixture
def management(accounts):
    yield accounts[3]


@pytest.fixture
def strategist(accounts):
    yield accounts[4]


@pytest.fixture
def keeper(accounts):
    yield accounts[5]


@pytest.fixture
def token():
    # weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    # usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    # usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    token_address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"  # this should be the address of the ERC-20 used by the strategy/vault (WETH9)
    yield Contract(token_address)

@pytest.fixture
def staking_contract():
    # staking 4 weth: "0x229443bf7F1297192394B7127427DB172a5bDe9E"
    # staking 4 usdc: "0xE5aFE81e63f0A52a3a03B922b30f73B8ce74D570"
    # staking 4 usdt: "0x7882F919e3acCa984babd70529100F937d90F860"
    token_address = "0x229443bf7F1297192394B7127427DB172a5bDe9E"  # this should be the address of the ERC-20 used by the strategy/vault (WETH9)
    yield Contract(token_address)

@pytest.fixture
def amount(accounts, token, user):
    amount = 2000 * 10 ** token.decimals()
    # In order to get some funds for the token you are about to use,
    # it impersonate an exchange address to use it's funds.
    # EULER = 0x27182842E098f60e3D576794A5bFFb0777E025d3
    reserve = accounts.at("0x2f0b23f53734252bda2277357e97e1517d6b042a", force=True)
    token.transfer(user, amount, {"from": reserve})
    yield amount


@pytest.fixture
def weth():
    token_address = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    yield Contract(token_address)


@pytest.fixture
def weth_amout(user, weth):
    weth_amout = 10 ** weth.decimals()
    user.transfer(weth, weth_amout)
    yield weth_amout


@pytest.fixture
def vault(pm, gov, rewards, guardian, management, token):
    Vault = pm(config["dependencies"][0]).Vault
    vault = guardian.deploy(Vault)
    vault.initialize(token, gov, rewards, "", "", guardian, management, {"from": gov})
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    vault.setManagement(management, {"from": gov})
    yield vault


@pytest.fixture
def strategy(strategist, keeper, vault, Strategy, gov, staking_contract):
    strategy = strategist.deploy(Strategy, vault, staking_contract)
    strategy.setKeeper(keeper)
    vault.addStrategy(strategy, 10_000, 0, 2 ** 256 - 1, 1_000, {"from": gov})
    yield strategy


@pytest.fixture(scope="session")
def RELATIVE_APPROX():
    yield 1e-4
