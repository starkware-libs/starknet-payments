use core::num::traits::Zero;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::deployment::declare_and_deploy;
use starknet::ContractAddress;
use starknet_payments::errors;
use starknet_payments::interface::{
    IPaymentsDispatcher, IPaymentsDispatcherTrait, IPaymentsSafeDispatcher,
    IPaymentsSafeDispatcherTrait,
};
use starkware_utils_testing::test_utils::{
    assert_panic_with_error, assert_panic_with_felt_error, cheat_caller_address_once,
};
use starkware_utils_testing::{constants as testing_constants, test_utils};

pub mod constants {
    use super::*;
    pub const UPGRADE_DELAY: u64 = 0;
    pub const FEE_RECIPIENT: ContractAddress = 'FEE_RECIPIENT'.try_into().unwrap();
    pub const FEE: u128 = 0;
}

fn deploy_contract() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(testing_constants::GOVERNANCE_ADMIN);
    calldata.append_serde(constants::UPGRADE_DELAY);
    calldata.append_serde(constants::FEE_RECIPIENT);
    calldata.append_serde(constants::FEE);
    declare_and_deploy("payments", calldata)
}

pub fn init_contract_with_roles() -> ContractAddress {
    let contract_address = deploy_contract();
    test_utils::set_default_roles(
        contract: contract_address, governance_admin: testing_constants::GOVERNANCE_ADMIN,
    );
    contract_address
}

#[test]
fn test_successful_register_token() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };

    let token_a: ContractAddress = 'token_a'.try_into().unwrap();
    let token_b: ContractAddress = 'token_b'.try_into().unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_a);
    assert!(dispatcher.is_token_registered(token: token_a));
    assert!(!dispatcher.is_token_registered(token: token_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(token: token_b);
    assert!(dispatcher.is_token_registered(token: token_a));
    assert!(dispatcher.is_token_registered(token: token_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.remove_token(token: token_a);
    assert!(!dispatcher.is_token_registered(token: token_a));
    assert!(dispatcher.is_token_registered(token: token_b));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.remove_token(token: token_b);
    assert!(!dispatcher.is_token_registered(token: token_a));
    assert!(!dispatcher.is_token_registered(token: token_b));
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_register_token() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let token: ContractAddress = 'token'.try_into().unwrap();

    let result = dispatcher.remove_token(:token);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    let result = dispatcher.register_token(:token);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.remove_token(:token);
    assert_panic_with_felt_error(:result, expected_error: errors::TOKEN_NOT_REGISTERED);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.register_token(:token).unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.register_token(:token);
    assert_panic_with_felt_error(:result, expected_error: errors::TOKEN_ALREADY_REGISTERED);
}

#[test]
fn test_successful_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();

    assert!(dispatcher.get_fee() == constants::FEE);
    assert!(dispatcher.get_fee_recipient() == constants::FEE_RECIPIENT);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.set_fee(fee: 10000);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert!(dispatcher.get_fee() == 10000);
    assert!(dispatcher.get_fee_recipient() == fee_recipient);
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();

    let result = dispatcher.set_fee(fee: 321);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    let result = dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.set_fee_recipient(recipient: Zero::zero());
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_ADDRESS);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.set_fee(fee: 10001);
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_HIGH_FEE);
}
