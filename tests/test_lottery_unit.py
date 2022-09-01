from web3 import Web3
from brownie import network,accounts,config, Lottery,exceptions
from scripts.deploy_lottery import deploy_lottery
import pytest
from scripts.helpful_scripts import LOCAL_BLOCKCHAIN_ENVIRONMENT, fund_with_link, get_account, get_contract


def test_get_entrance_fee():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    #Arrange
    lottery = deploy_lottery()
    #Act
    expected_entrance_fee = Web3.toWei(0.025,"ether")
    entrance_fee=lottery.getEntranceFee()
    #Assert
    assert entrance_fee==expected_entrance_fee

def test_cant_enter_unless_started():
    #Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    lottery = deploy_lottery()
    #Act/Assert
    with pytest.raises(exceptions.VirtualMachineError):
        lottery.enter({"from":get_account(),"value":lottery.getEntranceFee()})


def test_can_start_enter_lottery():
    #Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    lottery = deploy_lottery()
    account = get_account()
    lottery.startLottery({"from":account})
    #Act
    lottery.enter({"from":account,"value":lottery.getEntranceFee()})
    #Assert
    assert lottery.players(0) == account


def test_can_end_lottery(check_local_blockchain_envs, lottery_contract):
    # Arrange (by fixtures)

    account = get_account()
    lottery_contract.startLottery({"from": account})
    lottery_contract.enter(
        {"from": account, "value": lottery_contract.getEntranceFee()}
    )
    fund_with_link(lottery_contract)
    lottery_contract.endLottery({"from": account})
    assert lottery_contract.lottery_state() == 2


def test_can_pick_winner_correctly():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    lottery_contract = deploy_lottery()
    account = get_account()
    lottery_contract.startLottery({"from": account})
    lottery_contract.enter(
        {"from": account, "value": lottery_contract.getEntranceFee()}
    )
    lottery_contract.enter(
        {"from": get_account(index=1), "value": lottery_contract.getEntranceFee()}
    )
    lottery_contract.enter(
        {"from": get_account(index=2), "value": lottery_contract.getEntranceFee()}
    )
    fund_with_link(lottery_contract)
    starting_balance_of_account = account.balance()
    balance_of_lottery = lottery_contract.balance()
    transaction = lottery_contract.endLottery({"from": account})
    request_id = transaction.events["RequestedRandomness"]["requestId"]
    STATIC_RNG = 777
    get_contract("vrf_coordinator").callBackWithRandomness(
        request_id, STATIC_RNG, lottery_contract.address, {"from": account}
    )
    # 777 % 3 = 0
    assert lottery_contract.recentWinner() == account
    assert lottery_contract.balance() == 0
    assert account.balance() == starting_balance_of_account + balance_of_lottery