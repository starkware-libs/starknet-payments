use core::num::traits::Zero;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin_testing::deployment::declare_and_deploy;
use starknet::ContractAddress;
use starknet_payments::errors;
use starknet_payments::interface::{
    FulfilledStatus, IPaymentsDispatcher, IPaymentsDispatcherTrait, IPaymentsSafeDispatcher,
    IPaymentsSafeDispatcherTrait,
};
use starkware_utils::time::time::Time;
use starkware_utils_testing::test_utils::{
    assert_panic_with_error, assert_panic_with_felt_error, cheat_caller_address_once,
};
use starkware_utils_testing::{constants as testing_constants, test_utils};
use crate::order::Order;

pub mod constants {
    use super::*;
    pub const UPGRADE_DELAY: u64 = 0;
    pub const FEE_LIMIT: u128 = 1000;
    pub const FEE_RECIPIENT: ContractAddress = 'FEE_RECIPIENT'.try_into().unwrap();
    pub const FEE: u128 = 0;
}

fn deploy_contract() -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(testing_constants::GOVERNANCE_ADMIN);
    calldata.append_serde(constants::UPGRADE_DELAY);
    calldata.append_serde(constants::FEE_LIMIT);
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
    dispatcher.set_fee_limit(fee_limit: 2000);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee(fee: 1500);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert!(dispatcher.get_fee() == 1500);
    assert!(dispatcher.get_fee_recipient() == fee_recipient);
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_set_fee() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };
    let fee_recipient: ContractAddress = 'fee_recipient'.try_into().unwrap();

    let result = dispatcher.set_fee_limit(fee_limit: 10000);
    assert_panic_with_error(:result, expected_error: "ONLY_APP_GOVERNOR");

    let result = dispatcher.set_fee(fee: 1000);
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");

    let result = dispatcher.set_fee_recipient(recipient: fee_recipient);
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    let result = dispatcher.set_fee_recipient(recipient: Zero::zero());
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_ZERO_ADDRESS);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    let result = dispatcher.set_fee(fee: 1001);
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_HIGH_FEE);

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::APP_GOVERNOR);
    let result = dispatcher.set_fee_limit(fee_limit: 10001);
    assert_panic_with_felt_error(:result, expected_error: errors::INVALID_HIGH_FEE_LIMIT);
}


#[test]
fn test_successful_handle_order() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsDispatcher { contract_address };

    let order_1 = Order {
        salt: 1,
        expiry: Time::now(),
        address: testing_constants::DUMMY_ADDRESS,
        public_key: 123456789,
        token_a: 'token_a'.try_into().unwrap(),
        token_b: 'token_b'.try_into().unwrap(),
        amount_a: 123,
        amount_b: 456,
        recipient_addresses: array![].span(),
    };
    let order_2 = Order { salt: 2, ..order_1 };
    let order_3 = Order { amount_a: 132, ..order_1 };

    assert_eq!(dispatcher.get_order_fulfillment(order_1), FulfilledStatus::PartialFulfilled(0));
    assert_eq!(dispatcher.get_order_fulfillment(order_2), FulfilledStatus::PartialFulfilled(0));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.cancel_orders(orders: array![order_1].span());
    assert_eq!(dispatcher.get_order_fulfillment(order_1), FulfilledStatus::Canceled(0));
    assert_eq!(dispatcher.get_order_fulfillment(order_2), FulfilledStatus::PartialFulfilled(0));

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.cancel_orders(orders: array![order_2, order_3].span());
    assert_eq!(dispatcher.get_order_fulfillment(order_1), FulfilledStatus::Canceled(0));
    assert_eq!(dispatcher.get_order_fulfillment(order_2), FulfilledStatus::Canceled(0));
    assert_eq!(dispatcher.get_order_fulfillment(order_3), FulfilledStatus::Canceled(0));
}

#[test]
#[feature("safe_dispatcher")]
fn test_failed_handle_order() {
    let contract_address = init_contract_with_roles();
    let dispatcher = IPaymentsSafeDispatcher { contract_address };

    let order = Order {
        salt: 1,
        expiry: Time::now(),
        address: testing_constants::DUMMY_ADDRESS,
        public_key: 123456789,
        token_a: 'TOKEN_A'.try_into().unwrap(),
        token_b: 'TOKEN_B'.try_into().unwrap(),
        amount_a: 123,
        amount_b: 456,
        recipient_addresses: array![].span(),
    };

    let result = dispatcher.cancel_orders(orders: array![order].span());
    assert_panic_with_error(:result, expected_error: "ONLY_OPERATOR");

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    dispatcher.cancel_orders(orders: array![order].span()).unwrap();

    cheat_caller_address_once(:contract_address, caller_address: testing_constants::OPERATOR);
    let result = dispatcher.cancel_orders(orders: array![order].span());
    assert_panic_with_felt_error(:result, expected_error: errors::ORDER_ALREADY_CANCELED);
}
