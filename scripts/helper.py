from brownie import network, config, accounts, MockV3Aggregator, Contract, MockWETH, MockDAI


LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local", "ganache", "mainnet-fork"]
FORKED_LOCAL_ENVIRONMENTS = ["mainnet-fork"]
DECIMALS = 18
INITIAL_VALUE = 2000000000000000000000


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


contract_to_mock = {
    "eth_usd_price_feed": MockV3Aggregator,
    "dai_usd_price_feed": MockV3Aggregator,
    "fau_token": MockDAI,
    "weth_token": MockWETH
}


def get_contract(contract_name):
    """
    This function will grab the contract addresses from the brownie config
    if defined, otherwise it will deploy a mocked version of that contract and
    return that mock contract

    Args:
        contract_name (string)

    Returns:
        brownie.network.contract.ProjectContracts: The most recently deployed
        version of this contract.
    """
    contract_type = contract_to_mock[contract_name]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        # MockV3Aggregator.length
        if len(contract_type) <= 0:
            deploy_mocks()
        # MockV3Aggregator[-1]
        contract = contract_type[-1]
    else:
        contract_address = config["networks"][network.show_active()][contract_name]
        # get contract from MockV3Aggregator._name, address and MockV3Aggregatgor.abi
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )
    return contract


def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    print(f"The active network is {network.show_active()}")
    account = get_account()
    print("Deploying Mock Price Feed")
    mock_price_feed = MockV3Aggregator.deploy(decimals, initial_value, {"from": account})
    print(f"Deployed to {mock_price_feed.address}")
    print("Deploying Mock DAI")
    dai_token = MockDAI.deploy({"from": account})
    print(f"Deployed to {dai_token.address}")
    print("Deploying Mock WETH")
    weth_token = MockWETH.deploy({"from": account})
    print(f"Deploying to {weth_token.address}")
    
